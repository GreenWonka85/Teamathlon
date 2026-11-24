-- Teamathlon: Grundschema
--
-- Trennt Rohdaten (activities) von abgeleiteten Daten (score_entries), damit
-- sich Wertungsregeln ändern und alle Punkte neu berechnen lassen.
-- Zugriffsregeln (Row Level Security) sorgen dafür, dass jeder nur Daten der
-- Challenges sieht, in denen er Mitglied ist. Einzelne Aktivitäten sieht nur
-- ihr Besitzer; Ranglisten liefern nur Summen.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Aufzählungen
-- ---------------------------------------------------------------------------

create type public.sport as enum ('swim', 'bike', 'run');
create type public.activity_source as enum ('health_connect', 'healthkit', 'garmin');
create type public.recording_method as enum ('recorded', 'manual');
create type public.activity_status as enum ('valid', 'flagged', 'rejected');
create type public.member_role as enum ('admin', 'participant');
create type public.member_status as enum ('active', 'requested', 'removed');
create type public.join_policy as enum ('open', 'domain', 'approval');

-- ---------------------------------------------------------------------------
-- Tabellen
-- ---------------------------------------------------------------------------

-- Server-Informationen, z.B. für den Versionsabgleich mit der App.
create table public.server_settings (
    id boolean primary key default true check (id),
    name text not null default 'Teamathlon',
    schema_version integer not null default 1,
    min_app_version integer not null default 1
);
insert into public.server_settings default values;

-- Ein Profil je Nutzer aus Supabase Auth. Gespeichert werden nur Anzeigename
-- und Einstellungen; die E-Mail-Adresse bleibt in auth.users.
create table public.profiles (
    id uuid primary key references auth.users (id) on delete cascade,
    display_name text not null default '' check (char_length(display_name) <= 40),
    -- Nur Organisatoren dürfen Challenges eröffnen. Vergibt der Serverbetreiber.
    is_organizer boolean not null default false,
    language text not null default 'de',
    -- Ausblenden aus Personen-Ranglisten, Teilnahme im Team bleibt.
    hidden_in_rankings boolean not null default false,
    created_at timestamptz not null default now()
);

-- Einwilligungen mit Version des Textes, jederzeit widerrufbar.
create table public.consents (
    id bigint generated always as identity primary key,
    user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
    purpose text not null,
    text_version text not null,
    granted_at timestamptz not null default now(),
    revoked_at timestamptz
);

-- Verbundene Datenquellen. Zugangsschlüssel (z.B. Garmin) kommen später in
-- eine eigene Tabelle, die nur der Server lesen kann.
create table public.data_source_connections (
    user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
    source public.activity_source not null,
    status text not null default 'connected',
    last_sync_at timestamptz,
    preferred boolean not null default false,
    created_at timestamptz not null default now(),
    primary key (user_id, source)
);

create table public.challenges (
    id uuid primary key default gen_random_uuid(),
    name text not null check (char_length(name) between 1 and 80),
    created_by uuid not null default auth.uid() references public.profiles (id),
    starts_at timestamptz not null,
    ends_at timestamptz not null,
    -- Regelwerk als JSON, gleiche Felder wie Ruleset im Modul shared.
    ruleset jsonb not null default '{
        "version": 1,
        "sports": ["swim", "bike", "run"],
        "indoor_allowed": true,
        "points_per_norm_distance": 100,
        "norm_distance_m": {"swim": 3800, "bike": 180000, "run": 42195},
        "max_speed_kmh": {"swim": 6, "bike": 60, "run": 25}
    }'::jsonb,
    team_size_min integer not null default 3 check (team_size_min >= 1),
    team_size_max integer not null default 6,
    join_policy public.join_policy not null default 'open',
    allowed_email_domain text,
    max_participants integer check (max_participants > 0),
    ended boolean not null default false,
    created_at timestamptz not null default now(),
    check (ends_at > starts_at),
    check (team_size_max >= team_size_min),
    check (join_policy <> 'domain' or allowed_email_domain is not null)
);

create table public.challenge_members (
    challenge_id uuid not null references public.challenges (id) on delete cascade,
    user_id uuid not null references public.profiles (id) on delete cascade,
    role public.member_role not null default 'participant',
    status public.member_status not null default 'active',
    joined_at timestamptz not null default now(),
    primary key (challenge_id, user_id)
);
create index on public.challenge_members (user_id);

create table public.teams (
    id uuid primary key default gen_random_uuid(),
    challenge_id uuid not null references public.challenges (id) on delete cascade,
    name text not null check (char_length(name) between 1 and 40),
    captain_id uuid references public.profiles (id) on delete set null,
    created_at timestamptz not null default now(),
    unique (challenge_id, name)
);

create table public.team_memberships (
    id bigint generated always as identity primary key,
    team_id uuid not null references public.teams (id) on delete cascade,
    challenge_id uuid not null references public.challenges (id) on delete cascade,
    user_id uuid not null references public.profiles (id) on delete cascade,
    joined_at timestamptz not null default now(),
    left_at timestamptz
);
-- Je Challenge höchstens ein aktuelles Team pro Person.
create unique index team_memberships_one_active
    on public.team_memberships (challenge_id, user_id) where left_at is null;

create table public.invitations (
    code text primary key check (code ~ '^[A-Z0-9]{6,12}$'),
    challenge_id uuid not null references public.challenges (id) on delete cascade,
    team_id uuid references public.teams (id) on delete cascade,
    created_by uuid not null references public.profiles (id) on delete cascade,
    valid_until timestamptz,
    max_uses integer check (max_uses > 0),
    uses integer not null default 0,
    revoked boolean not null default false,
    created_at timestamptz not null default now()
);

-- Rohdaten: nur Sportart, Start, Dauer und Distanz. Keine GPS-Strecken,
-- keine Herzfrequenz.
create table public.activities (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
    source public.activity_source not null,
    external_id text not null,
    sport public.sport not null,
    started_at timestamptz not null,
    duration_s integer not null,
    distance_m double precision not null,
    indoor boolean not null default false,
    recording_method public.recording_method not null default 'recorded',
    status public.activity_status not null default 'valid',
    status_reason text,
    created_at timestamptz not null default now(),
    -- Verhindert doppelte Importe.
    unique (source, external_id)
);
create index on public.activities (user_id, started_at);

-- Abgeleitet: Punkte einer Aktivität je Challenge.
create table public.score_entries (
    activity_id uuid not null references public.activities (id) on delete cascade,
    challenge_id uuid not null references public.challenges (id) on delete cascade,
    user_id uuid not null references public.profiles (id) on delete cascade,
    sport public.sport not null,
    started_at timestamptz not null,
    points numeric(12, 3) not null,
    ruleset_version integer not null,
    primary key (activity_id, challenge_id)
);
create index on public.score_entries (challenge_id, user_id);

-- ---------------------------------------------------------------------------
-- Hilfsfunktionen
-- ---------------------------------------------------------------------------

create function public.is_challenge_member(p_challenge uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
    select exists (
        select 1 from public.challenge_members
        where challenge_id = p_challenge and user_id = auth.uid() and status = 'active'
    );
$$;

create function public.is_challenge_admin(p_challenge uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
    select exists (
        select 1 from public.challenge_members
        where challenge_id = p_challenge and user_id = auth.uid()
          and status = 'active' and role = 'admin'
    );
$$;

create function public.is_organizer()
returns boolean language sql stable security definer set search_path = ''
as $$
    select coalesce((select is_organizer from public.profiles where id = auth.uid()), false);
$$;

-- Ob der aktuelle Nutzer mit einer anderen Person in einer Challenge ist.
create function public.shares_challenge_with(p_user uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
    select exists (
        select 1
        from public.challenge_members a
        join public.challenge_members b on b.challenge_id = a.challenge_id
        where a.user_id = auth.uid() and a.status = 'active'
          and b.user_id = p_user and b.status = 'active'
    );
$$;

-- ---------------------------------------------------------------------------
-- Wertung (identisch mit Scoring und ActivityCheck im Modul shared)
-- ---------------------------------------------------------------------------

-- Punkte = Punkte je Normdistanz * Distanz / Normdistanz. Keine Obergrenze.
create function public.activity_points(p_sport public.sport, p_distance_m double precision, p_ruleset jsonb)
returns numeric language sql immutable set search_path = ''
as $$
    select case when p_distance_m <= 0 then 0::numeric else round((
        coalesce((p_ruleset ->> 'points_per_norm_distance')::numeric, 100)
        * p_distance_m::numeric
        / coalesce(
            (p_ruleset -> 'norm_distance_m' ->> p_sport::text)::numeric,
            case p_sport when 'swim' then 3800 when 'bike' then 180000 else 42195 end
        )
    ), 3) end;
$$;

-- Prüft jede neue Aktivität: Von Hand nachgetragene und unmögliche Einträge
-- werden verworfen, unrealistisch schnelle markiert. Geschwindigkeitsgrenzen
-- aus dem Standard-Regelwerk.
create function public.check_activity()
returns trigger language plpgsql set search_path = ''
as $$
declare
    v_speed_kmh double precision;
    v_limit double precision;
begin
    if new.recording_method = 'manual' then
        new.status := 'rejected';
        new.status_reason := 'manual_entry';
    elsif new.distance_m <= 0 or new.duration_s <= 0 then
        new.status := 'rejected';
        new.status_reason := 'invalid_values';
    else
        v_speed_kmh := new.distance_m / new.duration_s * 3.6;
        v_limit := case new.sport when 'swim' then 6 when 'bike' then 60 else 25 end;
        if v_speed_kmh > v_limit then
            new.status := 'flagged';
            new.status_reason := 'speed_too_high';
        else
            new.status := 'valid';
            new.status_reason := null;
        end if;
    end if;
    return new;
end;
$$;

create trigger activities_check
    before insert on public.activities
    for each row execute function public.check_activity();

-- Berechnet die Punkte einer Aktivität in allen laufenden Challenges des
-- Nutzers neu. Eine Aktivität zählt in jeder Challenge, deren Zeitraum sie
-- abdeckt.
create function public.refresh_activity_scores(p_activity uuid)
returns void language plpgsql security definer set search_path = ''
as $$
begin
    delete from public.score_entries where activity_id = p_activity;

    insert into public.score_entries (activity_id, challenge_id, user_id, sport, started_at, points, ruleset_version)
    select a.id, c.id, a.user_id, a.sport, a.started_at,
           public.activity_points(a.sport, a.distance_m, c.ruleset),
           coalesce((c.ruleset ->> 'version')::integer, 1)
    from public.activities a
    join public.challenge_members m on m.user_id = a.user_id and m.status = 'active'
    join public.challenges c on c.id = m.challenge_id
    where a.id = p_activity
      and a.status = 'valid'
      and a.started_at >= c.starts_at and a.started_at < c.ends_at
      and c.ruleset -> 'sports' ? a.sport::text
      and (not a.indoor or coalesce((c.ruleset ->> 'indoor_allowed')::boolean, true));
end;
$$;

-- Alle Punkte einer Challenge neu berechnen, z.B. nach einer Regeländerung.
create function public.recompute_challenge_scores(p_challenge uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
    v_activity uuid;
begin
    if auth.uid() is not null and not public.is_challenge_admin(p_challenge) then
        raise exception 'Nur Admins der Challenge dürfen die Punkte neu berechnen';
    end if;
    delete from public.score_entries where challenge_id = p_challenge;
    for v_activity in
        select a.id from public.activities a
        join public.challenge_members m on m.user_id = a.user_id and m.challenge_id = p_challenge and m.status = 'active'
    loop
        perform public.refresh_activity_scores(v_activity);
    end loop;
end;
$$;

create function public.activities_after_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
    perform public.refresh_activity_scores(new.id);
    return null;
end;
$$;

create trigger activities_score
    after insert or update of status, sport, distance_m, started_at, indoor on public.activities
    for each row execute function public.activities_after_change();

-- ---------------------------------------------------------------------------
-- Automatische Abläufe
-- ---------------------------------------------------------------------------

-- Profil anlegen, sobald sich jemand zum ersten Mal anmeldet.
create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
    insert into public.profiles (id) values (new.id) on conflict do nothing;
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- Wer eine Challenge eröffnet, wird ihr Admin.
create function public.handle_new_challenge()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
    insert into public.challenge_members (challenge_id, user_id, role, status)
    values (new.id, new.created_by, 'admin', 'active');
    return new;
end;
$$;

create trigger on_challenge_created
    after insert on public.challenges
    for each row execute function public.handle_new_challenge();

-- Wer neu (oder wieder) aktives Mitglied wird, bekommt die Punkte seiner
-- bereits importierten Aktivitäten im Zeitraum gutgeschrieben.
create function public.handle_member_change()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
    v_activity uuid;
begin
    for v_activity in select id from public.activities where user_id = new.user_id loop
        perform public.refresh_activity_scores(v_activity);
    end loop;
    return null;
end;
$$;

create trigger on_member_change
    after insert or update of status on public.challenge_members
    for each row execute function public.handle_member_change();

-- Wer austritt oder entfernt wird, verschwindet aus der Rangliste.
create function public.handle_member_delete()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
    delete from public.score_entries where challenge_id = old.challenge_id and user_id = old.user_id;
    update public.team_memberships set left_at = now()
    where challenge_id = old.challenge_id and user_id = old.user_id and left_at is null;
    return null;
end;
$$;

create trigger on_member_delete
    after delete on public.challenge_members
    for each row execute function public.handle_member_delete();

-- ---------------------------------------------------------------------------
-- Aufrufe der App (RPC)
-- ---------------------------------------------------------------------------

create function public.server_info()
returns jsonb language sql stable security definer set search_path = ''
as $$
    select jsonb_build_object('name', name, 'schema_version', schema_version, 'min_app_version', min_app_version)
    from public.server_settings;
$$;

-- Erzeugt einen Einladungscode für eine Challenge (Admin) oder ein Team (Kapitän).
create function public.create_invitation(
    p_challenge uuid,
    p_team uuid default null,
    p_valid_until timestamptz default null,
    p_max_uses integer default null
)
returns text language plpgsql security definer set search_path = ''
as $$
declare
    v_alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    v_bytes bytea;
    v_code text;
begin
    if p_team is null then
        if not public.is_challenge_admin(p_challenge) then
            raise exception 'Nur Admins der Challenge dürfen einladen';
        end if;
    elsif not exists (
        select 1 from public.teams t
        where t.id = p_team and t.challenge_id = p_challenge and t.captain_id = auth.uid()
    ) and not public.is_challenge_admin(p_challenge) then
        raise exception 'Nur der Kapitän darf in das Team einladen';
    end if;

    loop
        v_bytes := extensions.gen_random_bytes(8);
        v_code := '';
        for i in 0..7 loop
            v_code := v_code || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
        end loop;
        exit when not exists (select 1 from public.invitations where code = v_code);
    end loop;

    insert into public.invitations (code, challenge_id, team_id, created_by, valid_until, max_uses)
    values (v_code, p_challenge, p_team, auth.uid(), p_valid_until, p_max_uses);
    return v_code;
end;
$$;

-- Beitritt per Einladungscode. Liefert die Challenge und den Mitgliedsstatus
-- ('active' oder 'requested', wenn der Admin freigeben muss).
create function public.join_with_code(p_code text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
declare
    v_inv public.invitations;
    v_challenge public.challenges;
    v_status public.member_status;
    v_existing public.member_status;
    v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
    if auth.uid() is null then
        raise exception 'Nicht angemeldet';
    end if;

    select * into v_inv from public.invitations where code = upper(trim(p_code)) for update;
    if not found or v_inv.revoked
       or (v_inv.valid_until is not null and v_inv.valid_until < now())
       or (v_inv.max_uses is not null and v_inv.uses >= v_inv.max_uses) then
        raise exception 'Einladung ungültig oder abgelaufen';
    end if;

    select * into v_challenge from public.challenges where id = v_inv.challenge_id;
    if v_challenge.ended or v_challenge.ends_at < now() then
        raise exception 'Die Challenge ist beendet';
    end if;

    select status into v_existing from public.challenge_members
    where challenge_id = v_challenge.id and user_id = auth.uid();
    if v_existing = 'removed' then
        raise exception 'Kein Beitritt möglich';
    end if;

    if v_existing is null then
        if v_challenge.join_policy = 'domain'
           and v_email not like '%@' || lower(v_challenge.allowed_email_domain) then
            raise exception 'Beitritt nur mit E-Mail-Adresse der Domain %', v_challenge.allowed_email_domain;
        end if;
        if v_challenge.max_participants is not null and (
            select count(*) from public.challenge_members
            where challenge_id = v_challenge.id and status <> 'removed'
        ) >= v_challenge.max_participants then
            raise exception 'Die Challenge ist voll';
        end if;
        v_status := case when v_challenge.join_policy = 'approval' then 'requested' else 'active' end;
        insert into public.challenge_members (challenge_id, user_id, status)
        values (v_challenge.id, auth.uid(), v_status);
    else
        v_status := v_existing;
    end if;

    update public.invitations set uses = uses + 1 where code = v_inv.code;

    if v_inv.team_id is not null and v_status = 'active' then
        perform public.join_team(v_inv.team_id);
    end if;

    return jsonb_build_object('challenge_id', v_challenge.id, 'status', v_status, 'team_id', v_inv.team_id);
end;
$$;

-- Team gründen. Der Gründer wird Kapitän und tritt bei.
create function public.create_team(p_challenge uuid, p_name text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare
    v_team uuid;
begin
    if not public.is_challenge_member(p_challenge) then
        raise exception 'Nur Mitglieder der Challenge dürfen Teams gründen';
    end if;
    insert into public.teams (challenge_id, name, captain_id)
    values (p_challenge, trim(p_name), auth.uid())
    returning id into v_team;
    perform public.join_team(v_team);
    return v_team;
end;
$$;

-- Einem Team beitreten. Ein bisheriges Team derselben Challenge wird verlassen.
create function public.join_team(p_team uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
    v_team public.teams;
    v_size integer;
    v_max integer;
begin
    select * into v_team from public.teams where id = p_team;
    if not found or not public.is_challenge_member(v_team.challenge_id) then
        raise exception 'Team nicht gefunden';
    end if;
    if exists (
        select 1 from public.team_memberships
        where team_id = p_team and user_id = auth.uid() and left_at is null
    ) then
        return;
    end if;
    select count(*) into v_size from public.team_memberships where team_id = p_team and left_at is null;
    select team_size_max into v_max from public.challenges where id = v_team.challenge_id;
    if v_size >= v_max then
        raise exception 'Das Team ist voll';
    end if;
    update public.team_memberships set left_at = now()
    where challenge_id = v_team.challenge_id and user_id = auth.uid() and left_at is null;
    insert into public.team_memberships (team_id, challenge_id, user_id)
    values (p_team, v_team.challenge_id, auth.uid());
end;
$$;

create function public.leave_team(p_challenge uuid)
returns void language sql security definer set search_path = ''
as $$
    update public.team_memberships set left_at = now()
    where challenge_id = p_challenge and user_id = auth.uid() and left_at is null;
$$;

-- Rangliste der Personen: nur Anzeigename und Punkte, keine einzelnen
-- Aktivitäten. p_from/p_to schränken auf eine Woche oder einen Monat ein.
create function public.leaderboard_persons(
    p_challenge uuid,
    p_from timestamptz default null,
    p_to timestamptz default null
)
returns table (
    user_id uuid, display_name text, team_name text,
    swim numeric, bike numeric, run numeric, total numeric
)
language plpgsql stable security definer set search_path = ''
as $$
#variable_conflict use_column
begin
    if not public.is_challenge_member(p_challenge) then
        raise exception 'Nur für Mitglieder der Challenge';
    end if;
    return query
    select m.user_id, p.display_name, t.name,
           coalesce(sum(s.points) filter (where s.sport = 'swim'), 0),
           coalesce(sum(s.points) filter (where s.sport = 'bike'), 0),
           coalesce(sum(s.points) filter (where s.sport = 'run'), 0),
           coalesce(sum(s.points), 0)
    from public.challenge_members m
    join public.profiles p on p.id = m.user_id
    left join public.team_memberships tm on tm.challenge_id = m.challenge_id and tm.user_id = m.user_id and tm.left_at is null
    left join public.teams t on t.id = tm.team_id
    left join public.score_entries s on s.challenge_id = m.challenge_id and s.user_id = m.user_id
        and (p_from is null or s.started_at >= p_from)
        and (p_to is null or s.started_at < p_to)
    where m.challenge_id = p_challenge and m.status = 'active'
      and (not p.hidden_in_rankings or m.user_id = auth.uid())
    group by m.user_id, p.display_name, t.name
    order by 7 desc, 2;
end;
$$;

-- Rangliste der Teams: Durchschnitt je aktuellem Mitglied, damit kleine Teams
-- nicht benachteiligt sind.
create function public.leaderboard_teams(
    p_challenge uuid,
    p_from timestamptz default null,
    p_to timestamptz default null
)
returns table (
    team_id uuid, team_name text, members integer,
    swim numeric, bike numeric, run numeric, total numeric
)
language plpgsql stable security definer set search_path = ''
as $$
#variable_conflict use_column
begin
    if not public.is_challenge_member(p_challenge) then
        raise exception 'Nur für Mitglieder der Challenge';
    end if;
    return query
    with per_member as (
        select tm.team_id, tm.user_id,
               coalesce(sum(s.points) filter (where s.sport = 'swim'), 0) as swim,
               coalesce(sum(s.points) filter (where s.sport = 'bike'), 0) as bike,
               coalesce(sum(s.points) filter (where s.sport = 'run'), 0) as run
        from public.team_memberships tm
        join public.challenge_members m on m.challenge_id = tm.challenge_id and m.user_id = tm.user_id and m.status = 'active'
        left join public.score_entries s on s.challenge_id = tm.challenge_id and s.user_id = tm.user_id
            and (p_from is null or s.started_at >= p_from)
            and (p_to is null or s.started_at < p_to)
        where tm.challenge_id = p_challenge and tm.left_at is null
        group by tm.team_id, tm.user_id
    )
    select t.id, t.name, count(pm.user_id)::integer,
           round(coalesce(avg(pm.swim), 0), 3),
           round(coalesce(avg(pm.bike), 0), 3),
           round(coalesce(avg(pm.run), 0), 3),
           round(coalesce(avg(pm.swim + pm.bike + pm.run), 0), 3)
    from public.teams t
    left join per_member pm on pm.team_id = t.id
    where t.challenge_id = p_challenge
    group by t.id, t.name
    order by 7 desc, 2;
end;
$$;

-- ---------------------------------------------------------------------------
-- Zugriffsregeln
-- ---------------------------------------------------------------------------

alter table public.server_settings enable row level security;
alter table public.profiles enable row level security;
alter table public.consents enable row level security;
alter table public.data_source_connections enable row level security;
alter table public.challenges enable row level security;
alter table public.challenge_members enable row level security;
alter table public.teams enable row level security;
alter table public.team_memberships enable row level security;
alter table public.invitations enable row level security;
alter table public.activities enable row level security;
alter table public.score_entries enable row level security;

-- Grundsätzlich nichts für anonyme Nutzer, nur server_info().
revoke all on all tables in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function public.server_info() to anon, authenticated;

-- Profile: eigenes lesen und ändern; andere nur, wenn man gemeinsam in einer
-- Challenge ist. is_organizer kann nur der Serverbetreiber setzen.
grant select on public.profiles to authenticated;
grant update (display_name, language, hidden_in_rankings) on public.profiles to authenticated;
create policy profiles_select on public.profiles for select to authenticated
    using (id = auth.uid() or public.shares_challenge_with(id));
create policy profiles_update on public.profiles for update to authenticated
    using (id = auth.uid()) with check (id = auth.uid());

grant select, insert on public.consents to authenticated;
grant update (revoked_at) on public.consents to authenticated;
create policy consents_own on public.consents for all to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update, delete on public.data_source_connections to authenticated;
create policy connections_own on public.data_source_connections for all to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Challenges: sehen nur Mitglieder (auch angefragte), eröffnen nur Organisatoren.
grant select, insert on public.challenges to authenticated;
grant update (name, starts_at, ends_at, ruleset, team_size_min, team_size_max,
              join_policy, allowed_email_domain, max_participants, ended)
    on public.challenges to authenticated;
create policy challenges_select on public.challenges for select to authenticated
    using (created_by = auth.uid() or exists (
        select 1 from public.challenge_members m
        where m.challenge_id = challenges.id and m.user_id = auth.uid() and m.status <> 'removed'
    ));
create policy challenges_insert on public.challenges for insert to authenticated
    with check (public.is_organizer() and created_by = auth.uid());
create policy challenges_update on public.challenges for update to authenticated
    using (public.is_challenge_admin(id)) with check (public.is_challenge_admin(id));

-- Mitglieder: sichtbar für Mitglieder; Admins ändern Rolle und Status;
-- jeder kann selbst austreten. Beitritt nur über join_with_code().
grant select, delete on public.challenge_members to authenticated;
grant update (role, status) on public.challenge_members to authenticated;
create policy members_select on public.challenge_members for select to authenticated
    using (user_id = auth.uid() or public.is_challenge_member(challenge_id));
create policy members_update on public.challenge_members for update to authenticated
    using (public.is_challenge_admin(challenge_id)) with check (public.is_challenge_admin(challenge_id));
create policy members_delete on public.challenge_members for delete to authenticated
    using (user_id = auth.uid() and role <> 'admin');

-- Teams: sichtbar für Mitglieder, Namen ändert der Kapitän. Gründen und
-- Beitreten über create_team() und join_team().
grant select on public.teams to authenticated;
grant update (name) on public.teams to authenticated;
create policy teams_select on public.teams for select to authenticated
    using (public.is_challenge_member(challenge_id));
create policy teams_update on public.teams for update to authenticated
    using (captain_id = auth.uid()) with check (captain_id = auth.uid());

grant select on public.team_memberships to authenticated;
create policy team_memberships_select on public.team_memberships for select to authenticated
    using (public.is_challenge_member(challenge_id));

-- Einladungen: sehen und widerrufen Admins der Challenge und Kapitäne.
grant select on public.invitations to authenticated;
grant update (revoked) on public.invitations to authenticated;
create policy invitations_select on public.invitations for select to authenticated
    using (public.is_challenge_admin(challenge_id) or created_by = auth.uid());
create policy invitations_update on public.invitations for update to authenticated
    using (public.is_challenge_admin(challenge_id) or created_by = auth.uid())
    with check (public.is_challenge_admin(challenge_id) or created_by = auth.uid());

-- Aktivitäten: nur die eigenen. Die App lädt sie hoch, Status und Punkte
-- setzt der Server. Eine manuelle Eingabe gibt es nicht.
grant select, delete on public.activities to authenticated;
grant insert (source, external_id, sport, started_at, duration_s, distance_m, indoor, recording_method)
    on public.activities to authenticated;
create policy activities_select on public.activities for select to authenticated
    using (user_id = auth.uid());
create policy activities_insert on public.activities for insert to authenticated
    with check (user_id = auth.uid() and source in ('health_connect', 'healthkit'));
create policy activities_delete on public.activities for delete to authenticated
    using (user_id = auth.uid());

grant select on public.score_entries to authenticated;
create policy score_entries_select on public.score_entries for select to authenticated
    using (user_id = auth.uid());

grant execute on function
    public.create_invitation(uuid, uuid, timestamptz, integer),
    public.join_with_code(text),
    public.create_team(uuid, text),
    public.join_team(uuid),
    public.leave_team(uuid),
    public.leaderboard_persons(uuid, timestamptz, timestamptz),
    public.leaderboard_teams(uuid, timestamptz, timestamptz),
    public.recompute_challenge_scores(uuid),
    public.is_challenge_member(uuid),
    public.is_challenge_admin(uuid),
    public.is_organizer(),
    public.shares_challenge_with(uuid),
    public.activity_points(public.sport, double precision, jsonb)
to authenticated;
