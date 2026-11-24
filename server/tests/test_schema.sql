-- Tests für das Grundschema. Bricht beim ersten Fehler ab (ON_ERROR_STOP).
\set ON_ERROR_STOP on
set client_min_messages = notice;

-- Hilfsfunktion: als Nutzer handeln (wie ein Aufruf aus der App).
create function pg_temp.als(p_user uuid, p_email text) returns void language plpgsql as $$
begin
    perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'email', p_email)::text, false);
    execute 'set role authenticated';
end;
$$;

create function pg_temp.erwarte(p_ok boolean, p_text text) returns void language plpgsql as $$
begin
    if not coalesce(p_ok, false) then raise exception 'Test fehlgeschlagen: %', p_text; end if;
    raise notice 'ok: %', p_text;
end;
$$;

insert into auth.users values
    ('00000000-0000-0000-0000-00000000000a', 'orga@uni-example.de'),
    ('00000000-0000-0000-0000-00000000000b', 'anna@uni-example.de'),
    ('00000000-0000-0000-0000-00000000000c', 'ben@uni-example.de'),
    ('00000000-0000-0000-0000-00000000000d', 'fremd@gmail.com');
update public.profiles set is_organizer = true where id = '00000000-0000-0000-0000-00000000000a';
update public.profiles set display_name = 'Anna' where id = '00000000-0000-0000-0000-00000000000b';
update public.profiles set display_name = 'Ben' where id = '00000000-0000-0000-0000-00000000000c';

select pg_temp.erwarte((select count(*) = 4 from public.profiles), 'Profile werden bei Registrierung angelegt');
select pg_temp.erwarte(round(public.activity_points('swim', 3800, '{}'), 3) = 100, 'Ironman-Distanz Schwimmen = 100 Punkte');
select pg_temp.erwarte(round(public.activity_points('bike', 360000, '{}'), 3) = 200, 'Keine Obergrenze: 360 km Rad = 200 Punkte');

-- Teilnehmer dürfen keine Challenge eröffnen.
select pg_temp.als('00000000-0000-0000-0000-00000000000b', 'anna@uni-example.de');
do $$ begin
    insert into public.challenges (name, starts_at, ends_at) values ('Verboten', now(), now() + interval '30 days');
    raise exception 'Teilnehmer konnte Challenge eröffnen';
exception when insufficient_privilege then raise notice 'ok: Nur Organisatoren eröffnen Challenges';
end $$;
-- Teilnehmer können sich nicht selbst zum Organisator machen.
do $$ begin
    update public.profiles set is_organizer = true where id = auth.uid();
    raise exception 'Teilnehmer konnte is_organizer setzen';
exception when insufficient_privilege then raise notice 'ok: is_organizer nicht änderbar';
end $$;
reset role;

-- Organisator eröffnet eine Challenge, nur für die Uni-Domain.
select pg_temp.als('00000000-0000-0000-0000-00000000000a', 'orga@uni-example.de');
insert into public.challenges (id, name, starts_at, ends_at, join_policy, allowed_email_domain)
values ('11111111-1111-1111-1111-111111111111', 'Sommer', now() - interval '1 day', now() + interval '30 days', 'domain', 'uni-example.de');
select pg_temp.erwarte(public.is_challenge_admin('11111111-1111-1111-1111-111111111111'), 'Ersteller wird Admin');
select public.create_invitation('11111111-1111-1111-1111-111111111111') as code \gset
reset role;
select pg_temp.erwarte(:'code' ~ '^[A-Z0-9]{8}$', 'Einladungscode hat 8 Zeichen');

-- Anna tritt bei und gründet ein Team.
select pg_temp.als('00000000-0000-0000-0000-00000000000b', 'anna@uni-example.de');
select pg_temp.erwarte((public.join_with_code(lower(:'code')) ->> 'status') = 'active', 'Beitritt per Code');
select public.create_team('11111111-1111-1111-1111-111111111111', 'Hörsaal 3') as team \gset
-- Aktivitäten: gültig, manuell nachgetragen, zu schnell, vor der Challenge.
insert into public.activities (source, external_id, sport, started_at, duration_s, distance_m, recording_method) values
    ('health_connect', 'a1', 'run', now(), 3000, 10000, 'recorded'),
    ('health_connect', 'a2', 'run', now(), 3000, 10000, 'manual'),
    ('health_connect', 'a3', 'bike', now(), 3600, 90000, 'recorded'),
    ('health_connect', 'a4', 'swim', now() - interval '10 days', 1800, 1000, 'recorded');
select pg_temp.erwarte((select status from public.activities where external_id = 'a2') = 'rejected', 'Manuelle Einträge werden verworfen');
select pg_temp.erwarte((select status from public.activities where external_id = 'a3') = 'flagged', 'Zu schnelle Aktivität wird markiert');
select pg_temp.erwarte((select count(*) = 1 from public.score_entries), 'Nur gültige Aktivität im Zeitraum zählt');
-- Status darf die App nicht selbst setzen.
do $$ begin
    update public.activities set status = 'valid' where external_id = 'a3';
    raise exception 'Nutzer konnte Status ändern';
exception when insufficient_privilege then raise notice 'ok: Status nur durch den Server';
end $$;
-- Garmin-Daten kommen nur vom Server, nicht aus der App.
do $$ begin
    insert into public.activities (source, external_id, sport, started_at, duration_s, distance_m)
    values ('garmin', 'g1', 'run', now(), 3000, 10000);
    raise exception 'App konnte Garmin-Aktivität anlegen';
exception when insufficient_privilege then raise notice 'ok: Garmin nur serverseitig';
end $$;
reset role;

-- Doppelter Import wird abgewiesen.
do $$ begin
    insert into public.activities (user_id, source, external_id, sport, started_at, duration_s, distance_m)
    values ('00000000-0000-0000-0000-00000000000b', 'health_connect', 'a1', 'run', now(), 3000, 10000);
    raise exception 'Doppelter Import möglich';
exception when unique_violation then raise notice 'ok: Doppelte Importe verhindert';
end $$;

-- Ben tritt per Team-Einladung bei; Fremde mit falscher Domain nicht.
select pg_temp.als('00000000-0000-0000-0000-00000000000b', 'anna@uni-example.de');
select public.create_invitation('11111111-1111-1111-1111-111111111111', :'team') as teamcode \gset
reset role;
select pg_temp.als('00000000-0000-0000-0000-00000000000c', 'ben@uni-example.de');
select pg_temp.erwarte((public.join_with_code(:'teamcode') ->> 'team_id') = :'team', 'Beitritt per Team-Einladung');
insert into public.activities (source, external_id, sport, started_at, duration_s, distance_m)
values ('health_connect', 'b1', 'swim', now(), 1800, 1900);
-- Ben sieht Annas Aktivitäten nicht, aber die Rangliste.
select pg_temp.erwarte((select count(*) = 1 from public.activities), 'Nur eigene Aktivitäten sichtbar');
select pg_temp.erwarte((select count(*) = 3 from public.leaderboard_persons('11111111-1111-1111-1111-111111111111')), 'Personen-Rangliste (Organisator, Anna, Ben)');
select pg_temp.erwarte(
    (select total = round((100.0 * 10000 / 42195 + 50) / 2, 3) and members = 2
     from public.leaderboard_teams('11111111-1111-1111-1111-111111111111')),
    'Team-Rangliste = Durchschnitt je Mitglied');
reset role;

select pg_temp.als('00000000-0000-0000-0000-00000000000d', 'fremd@gmail.com');
select pg_temp.erwarte((select count(*) = 0 from public.challenges), 'Nichtmitglied sieht keine Challenge');
do $$ begin
    perform public.leaderboard_persons('11111111-1111-1111-1111-111111111111');
    raise exception 'Nichtmitglied sieht Rangliste';
exception when raise_exception then
    if sqlerrm like 'Nichtmitglied%' then raise; end if;
    raise notice 'ok: Rangliste nur für Mitglieder';
end $$;
reset role;
select set_config('test.code', :'code', false);
select pg_temp.als('00000000-0000-0000-0000-00000000000d', 'fremd@gmail.com');
do $$ begin
    perform public.join_with_code(current_setting('test.code'));
    raise exception 'Beitritt mit falscher Domain möglich';
exception when raise_exception then
    if sqlerrm like 'Beitritt mit falscher%' then raise; end if;
    raise notice 'ok: Domain-Beschränkung greift';
end $$;
reset role;

-- Anonyme Nutzer sehen nur die Server-Informationen.
set role anon;
select pg_temp.erwarte((public.server_info() ->> 'schema_version') = '1', 'server_info() für anonyme Nutzer');
do $$ begin
    perform count(*) from public.profiles;
    raise exception 'Anonym kann Profile lesen';
exception when insufficient_privilege then raise notice 'ok: Anonym keine Tabellen';
end $$;
reset role;

-- Austritt entfernt aus der Rangliste.
select pg_temp.als('00000000-0000-0000-0000-00000000000c', 'ben@uni-example.de');
delete from public.challenge_members where user_id = auth.uid();
reset role;
select pg_temp.erwarte((select count(*) = 0 from public.score_entries where user_id = '00000000-0000-0000-0000-00000000000c'), 'Austritt entfernt Punkte');

-- Schritte-Wertung ----------------------------------------------------------
select pg_temp.als('00000000-0000-0000-0000-00000000000b', 'anna@uni-example.de');
insert into public.daily_steps (source, day, steps) values
    ('health_connect', (now() at time zone 'Europe/Berlin')::date, 8000),
    ('health_connect', (now() at time zone 'Europe/Berlin')::date - 1, 6000),
    ('health_connect', (now() at time zone 'Europe/Berlin')::date - 30, 7000);
insert into public.daily_steps (source, day, steps, recording_method) values
    ('healthkit', (now() at time zone 'Europe/Berlin')::date - 1, 20000, 'manual');
-- Im Laufe des Tages aktualisiert die App die Tagessumme.
insert into public.daily_steps (source, day, steps) values ('health_connect', (now() at time zone 'Europe/Berlin')::date, 8500)
    on conflict (user_id, source, day) do update set steps = excluded.steps;
select pg_temp.erwarte((select status from public.daily_steps where recording_method = 'manual') = 'rejected', 'Manuell nachgetragene Schritte werden verworfen');
reset role;
-- Garmin meldet für denselben Tag etwas mehr: nur der höchste Wert zählt.
insert into public.daily_steps (user_id, source, day, steps)
values ('00000000-0000-0000-0000-00000000000b', 'garmin', (now() at time zone 'Europe/Berlin')::date, 9000);
select pg_temp.als('00000000-0000-0000-0000-00000000000b', 'anna@uni-example.de');
select pg_temp.erwarte(
    (select steps = 9000 + 6000 from public.leaderboard_persons('11111111-1111-1111-1111-111111111111') where user_id = auth.uid()),
    'Schritte: je Tag höchster Wert, nur gültige Tage im Zeitraum');
select pg_temp.erwarte(
    (select total = round(100.0 * 10000 / 42195, 3) from public.leaderboard_persons('11111111-1111-1111-1111-111111111111') where user_id = auth.uid()),
    'Schritte zählen nicht zu den Triathlon-Punkten');
select pg_temp.erwarte(
    (select steps = 15000 from public.leaderboard_teams('11111111-1111-1111-1111-111111111111')),
    'Team-Schritte = Durchschnitt je Mitglied');
do $$ begin
    insert into public.daily_steps (source, day, steps) values ('garmin', current_date, 100);
    raise exception 'App konnte Garmin-Schritte anlegen';
exception when insufficient_privilege then raise notice 'ok: Garmin-Schritte nur serverseitig';
end $$;
reset role;

-- Reine Schritte-Challenge.
select pg_temp.als('00000000-0000-0000-0000-00000000000a', 'orga@uni-example.de');
insert into public.challenges (id, name, starts_at, ends_at, ruleset)
values ('22222222-2222-2222-2222-222222222222', 'Schritte Dezember', now() - interval '2 days', now() + interval '30 days',
        '{"sports": [], "steps_enabled": true}');
do $$ begin
    insert into public.challenges (name, starts_at, ends_at, ruleset)
    values ('Leer', now(), now() + interval '1 day', '{"sports": [], "steps_enabled": false}');
    raise exception 'Challenge ohne Wertung möglich';
exception when check_violation then raise notice 'ok: Challenge braucht Sportart oder Schritte';
end $$;
select public.create_invitation('22222222-2222-2222-2222-222222222222') as stepcode \gset
reset role;
select pg_temp.als('00000000-0000-0000-0000-00000000000b', 'anna@uni-example.de');
select public.join_with_code(:'stepcode');
select pg_temp.erwarte(
    (select steps = 15000 and total = 0 from public.leaderboard_persons('22222222-2222-2222-2222-222222222222') where user_id = auth.uid()),
    'Schritte-Challenge zählt Schritte, aber keine Sportpunkte');
reset role;

do $$ begin raise notice 'Alle Tests bestanden.'; end $$;
