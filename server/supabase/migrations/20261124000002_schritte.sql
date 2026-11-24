-- Teamathlon: Schritte-Wertung
--
-- Schritte bilden eine eigene Wertung mit eigener Rangliste und zählen nicht
-- zu den Triathlon-Punkten, da auch beim Laufen Schritte entstehen. Je
-- Challenge zuschaltbar; eine Challenge kann auch nur aus Schritten bestehen.
-- Gespeichert wird nur die Tagessumme je Quelle.

-- Zeitzone des Servers, nach der Challenge-Zeiträume in Kalendertage
-- umgerechnet werden.
alter table public.server_settings add column timezone text not null default 'Europe/Berlin';

-- Regelwerk: Schritte standardmäßig an, Grenze für die Plausibilitätsprüfung.
alter table public.challenges alter column ruleset set default '{
    "version": 1,
    "sports": ["swim", "bike", "run"],
    "indoor_allowed": true,
    "points_per_norm_distance": 100,
    "norm_distance_m": {"swim": 3800, "bike": 180000, "run": 42195},
    "max_speed_kmh": {"swim": 6, "bike": 60, "run": 25},
    "steps_enabled": true,
    "max_daily_steps": 100000
}'::jsonb;

create function public.ruleset_steps_enabled(p_ruleset jsonb)
returns boolean language sql immutable set search_path = ''
as $$
    select coalesce((p_ruleset ->> 'steps_enabled')::boolean, true);
$$;

-- Mindestens eine Sportart oder die Schritte-Wertung muss aktiv sein.
alter table public.challenges add constraint challenges_has_category check (
    jsonb_array_length(coalesce(ruleset -> 'sports', '[]'::jsonb)) > 0
    or public.ruleset_steps_enabled(ruleset)
);

create table public.daily_steps (
    user_id uuid not null default auth.uid() references public.profiles (id) on delete cascade,
    source public.activity_source not null,
    -- Kalendertag in der Zeitzone des Nutzers.
    day date not null,
    steps integer not null,
    recording_method public.recording_method not null default 'recorded',
    status public.activity_status not null default 'valid',
    status_reason text,
    updated_at timestamptz not null default now(),
    -- Je Tag und Quelle ein Eintrag; die App aktualisiert ihn im Laufe des Tages.
    primary key (user_id, source, day)
);
create index on public.daily_steps (user_id, day);

-- Prüfung wie StepsCheck im Modul shared. Die Grenze ist der Standardwert;
-- eine Challenge mit eigener Grenze wertet zusätzlich in der Rangliste.
create function public.check_daily_steps()
returns trigger language plpgsql set search_path = ''
as $$
begin
    new.updated_at := now();
    if new.recording_method = 'manual' then
        new.status := 'rejected';
        new.status_reason := 'manual_entry';
    elsif new.steps < 0 then
        new.status := 'rejected';
        new.status_reason := 'invalid_values';
    elsif new.steps > 100000 then
        new.status := 'flagged';
        new.status_reason := 'steps_too_high';
    else
        new.status := 'valid';
        new.status_reason := null;
    end if;
    return new;
end;
$$;

create trigger daily_steps_check
    before insert or update on public.daily_steps
    for each row execute function public.check_daily_steps();

alter table public.daily_steps enable row level security;
grant select, delete on public.daily_steps to authenticated;
grant insert (source, day, steps, recording_method) on public.daily_steps to authenticated;
grant update (steps, recording_method) on public.daily_steps to authenticated;
create policy daily_steps_select on public.daily_steps for select to authenticated
    using (user_id = auth.uid());
create policy daily_steps_insert on public.daily_steps for insert to authenticated
    with check (user_id = auth.uid() and source in ('health_connect', 'healthkit'));
create policy daily_steps_update on public.daily_steps for update to authenticated
    using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy daily_steps_delete on public.daily_steps for delete to authenticated
    using (user_id = auth.uid());

-- Gezählte Schritte einer Person in einer Challenge: je Tag der höchste Wert
-- aller Quellen (gegen doppelte Zählung), nur gültige Einträge, nur Tage im
-- Zeitraum der Challenge und im optionalen Filterzeitraum.
create function public.challenge_steps(
    p_challenge uuid,
    p_user uuid,
    p_from timestamptz default null,
    p_to timestamptz default null
)
returns bigint language sql stable security definer set search_path = ''
as $$
    with settings as (select timezone from public.server_settings),
    c as (
        select ch.*, (ch.starts_at at time zone s.timezone)::date as first_day,
               ((ch.ends_at at time zone s.timezone) - interval '1 microsecond')::date as last_day,
               (p_from at time zone s.timezone)::date as from_day,
               ((p_to at time zone s.timezone) - interval '1 microsecond')::date as to_day
        from public.challenges ch, settings s
        where ch.id = p_challenge
    ),
    per_day as (
        select d.day, max(d.steps) as steps
        from public.daily_steps d, c
        where d.user_id = p_user and d.status = 'valid'
          and d.day between c.first_day and c.last_day
          and (c.from_day is null or d.day >= c.from_day)
          and (c.to_day is null or d.day <= c.to_day)
          and d.steps <= coalesce((c.ruleset ->> 'max_daily_steps')::integer, 100000)
        group by d.day
    )
    select case when public.ruleset_steps_enabled((select ruleset from c))
                then coalesce((select sum(steps) from per_day), 0)::bigint
                else 0::bigint end;
$$;
revoke execute on function public.challenge_steps(uuid, uuid, timestamptz, timestamptz) from public, anon, authenticated;

-- Ranglisten um Schritte erweitern. Der Rückgabetyp ändert sich, daher neu anlegen.
drop function public.leaderboard_persons(uuid, timestamptz, timestamptz);
drop function public.leaderboard_teams(uuid, timestamptz, timestamptz);

-- Personen: Punkte je Sportart, Triathlon-Summe (ohne Schritte) und Schritte.
create function public.leaderboard_persons(
    p_challenge uuid,
    p_from timestamptz default null,
    p_to timestamptz default null
)
returns table (
    user_id uuid, display_name text, team_name text,
    swim numeric, bike numeric, run numeric, total numeric, steps bigint
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
           coalesce(sum(s.points), 0),
           public.challenge_steps(p_challenge, m.user_id, p_from, p_to)
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
    order by 7 desc, 8 desc, 2;
end;
$$;

-- Teams: Durchschnitt je aktuellem Mitglied, auch für Schritte.
create function public.leaderboard_teams(
    p_challenge uuid,
    p_from timestamptz default null,
    p_to timestamptz default null
)
returns table (
    team_id uuid, team_name text, members integer,
    swim numeric, bike numeric, run numeric, total numeric, steps numeric
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
               coalesce(sum(s.points) filter (where s.sport = 'run'), 0) as run,
               public.challenge_steps(p_challenge, tm.user_id, p_from, p_to) as steps
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
           round(coalesce(avg(pm.swim + pm.bike + pm.run), 0), 3),
           round(coalesce(avg(pm.steps), 0), 1)
    from public.teams t
    left join per_member pm on pm.team_id = t.id
    where t.challenge_id = p_challenge
    group by t.id, t.name
    order by 7 desc, 8 desc, 2;
end;
$$;

revoke execute on function
    public.leaderboard_persons(uuid, timestamptz, timestamptz),
    public.leaderboard_teams(uuid, timestamptz, timestamptz),
    public.ruleset_steps_enabled(jsonb)
from public, anon;
grant execute on function
    public.leaderboard_persons(uuid, timestamptz, timestamptz),
    public.leaderboard_teams(uuid, timestamptz, timestamptz),
    public.ruleset_steps_enabled(jsonb)
to authenticated;
