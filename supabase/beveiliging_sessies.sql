-- OPTIONEEL maar aangeraden zodra de app openbaar op internet staat.
-- Probleem nu: een pincode van 4 cijfers kan iedereen via de API in een paar minuten raden.
-- Na dit script:
--   * alleen kt_login accepteert nog een pincode; na 8 foute pogingen per IP in 10 min wordt dat IP 10 min geblokkeerd
--   * daarna gebruikt de app een willekeurige sessietoken (64 tekens, 4 dagen geldig) i.p.v. de pincode
--   * pincode wijzigen in Beheer logt die gebruiker overal uit
-- De app (public/index.html) werkt met en zonder dit script. Plak in de Supabase SQL-editor (project HHCdatabase).

create table if not exists public.kt_sessions(
  token text primary key,
  user_id int not null references public.kt_users(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_seen timestamptz not null default now());
alter table public.kt_sessions enable row level security;
create table if not exists public.kt_login_fail(
  id bigserial primary key, ip text not null, at timestamptz not null default now());
create index if not exists kt_login_fail_ip_at on public.kt_login_fail(ip, at);
alter table public.kt_login_fail enable row level security;
revoke all on public.kt_sessions, public.kt_login_fail from anon, authenticated;

create or replace function public.kt__ip() returns text language sql stable
set search_path to 'public','pg_temp' as $$
  select coalesce(split_part(nullif(current_setting('request.headers', true),'')::json->>'x-forwarded-for', ',', 1), 'onbekend')
$$;

create or replace function public.kt__user(p_token text) returns public.kt_users
language sql stable security definer set search_path to 'public','pg_temp' as $$
  select u.* from public.kt_sessions s join public.kt_users u on u.id = s.user_id
   where s.token = p_token and p_token is not null and length(p_token) >= 40
     and s.created_at > now() - interval '4 days' limit 1
$$;

create or replace function public.kt__need(p_pin text, p_admin boolean default false) returns public.kt_users
language plpgsql security definer set search_path to 'public','pg_temp' as $$
declare u public.kt_users;
begin
  u := public.kt__user(p_pin);
  if u.id is null then raise exception 'ONGELDIGE_PIN'; end if;
  if p_admin and u.role <> 'admin' then raise exception 'ALLEEN_BEHEERDER'; end if;
  return u;
end $$;

drop function if exists public.kt_login(text);
create function public.kt_login(p_pin text) returns jsonb
language plpgsql security definer set search_path to 'public','pg_temp' as $$
declare u public.kt_users; my_ip text := public.kt__ip(); fails int; tok text;
begin
  delete from public.kt_login_fail where at < now() - interval '1 day';
  select count(*) into fails from public.kt_login_fail f where f.ip = my_ip and f.at > now() - interval '10 minutes';
  if fails >= 8 then return jsonb_build_object('ok', false, 'blocked', true); end if;
  select * into u from public.kt_users where pin = p_pin and p_pin is not null and p_pin <> '' limit 1;
  if u.id is null then
    insert into public.kt_login_fail(ip) values (my_ip);
    return jsonb_build_object('ok', false, 'left', greatest(0, 7 - fails));
  end if;
  tok := replace(gen_random_uuid()::text,'-','') || replace(gen_random_uuid()::text,'-','');
  delete from public.kt_sessions where created_at < now() - interval '4 days';
  insert into public.kt_sessions(token, user_id) values (tok, u.id);
  return jsonb_build_object('ok', true, 'token', tok, 'role', u.role, 'name', u.name, 'team_id', u.team_id);
end $$;

create or replace function public.kt_whoami(p_token text) returns jsonb
language plpgsql security definer set search_path to 'public','pg_temp' as $$
declare u public.kt_users;
begin
  u := public.kt__user(p_token);
  if u.id is null then return jsonb_build_object('ok', false); end if;
  update public.kt_sessions set last_seen = now() where token = p_token;
  return jsonb_build_object('ok', true, 'role', u.role, 'name', u.name, 'team_id', u.team_id);
end $$;

create or replace function public.kt_logout(p_token text) returns jsonb
language sql security definer set search_path to 'public','pg_temp' as $$
  delete from public.kt_sessions where token = p_token;
  select jsonb_build_object('ok', true);
$$;

create or replace function public.kt_admin_user_save(p_pin text, p_id integer, p_name text, p_new_pin text, p_team integer)
returns jsonb language plpgsql security definer set search_path to 'public','pg_temp' as $$
declare u public.kt_users; old public.kt_users; changed boolean;
begin
  u := public.kt__need(p_pin, true);
  select * into old from public.kt_users where id = p_id;
  if old.id is null then raise exception 'ONBEKENDE_GEBRUIKER'; end if;
  if coalesce(p_new_pin, '') <> '' and length(p_new_pin) < 4 then raise exception 'PIN_TE_KORT'; end if;
  if coalesce(p_new_pin, '') <> '' and exists (select 1 from public.kt_users where pin = p_new_pin and id <> p_id) then
    raise exception 'PIN_BESTAAT_AL';
  end if;
  changed := coalesce(p_new_pin, '') <> '' and p_new_pin <> old.pin;
  update public.kt_users set name = left(coalesce(nullif(trim(p_name),''), old.name), 60), team_id = p_team,
    pin = case when changed then p_new_pin else pin end where id = p_id;
  if changed then delete from public.kt_sessions where user_id = p_id and token <> p_pin; end if;
  perform public.kt__log(u.name, 'gebruiker aangepast', jsonb_build_object('user_id', p_id, 'naam', p_name, 'pin_gewijzigd', changed));
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.kt_state(p_pin text default null) returns jsonb
language plpgsql stable security definer set search_path to 'public','pg_temp' as $$
declare u public.kt_users; hid boolean; strip boolean; pp int;
begin
  u := public.kt__user(p_pin);
  hid := coalesce((select (value #>> '{}')::boolean from public.kt_settings where key = 'hidden'), false);
  pp := coalesce((select (value #>> '{}')::int from public.kt_settings where key = 'puzzle_points'), 5);
  strip := hid and u.id is null;
  return jsonb_build_object(
    'hidden', strip, 'hidden_setting', hid, 'puzzle_points', pp, 'now', now(),
    'teams', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', t.id, 'name', t.name, 'color', t.color, 'members', t.members, 'arrived_at', t.arrived_at,
        'puzzle_at', case when strip then null else t.puzzle_at end,
        'puzzle_answer', case when strip then '' else t.puzzle_answer end,
        'score', case when strip then null else
          coalesce((select sum(coalesce(a.points_override, c.points)) from public.kt_assign a join public.kt_cards c on c.id = a.card_id where a.team_id = t.id and a.done), 0)
          + coalesce((select sum(e.points) from public.kt_extra e where e.team_id = t.id), 0)
          + case when t.puzzle_at is not null then pp else 0 end end
      ) order by t.id), '[]'::jsonb) from public.kt_teams t),
    'cards', (select coalesce(jsonb_agg(to_jsonb(c) order by c.points desc, c.sort), '[]'::jsonb) from public.kt_cards c),
    'assign', (select coalesce(jsonb_agg(jsonb_build_object(
        'card_id', a.card_id, 'team_id', a.team_id,
        'done', case when strip then false else a.done end,
        'proof', case when strip then false else a.proof end,
        'points_override', case when strip then null else a.points_override end,
        'note', case when strip then '' else a.note end,
        'done_at', case when strip then null else a.done_at end,
        'done_by', case when strip then null else a.done_by end)), '[]'::jsonb) from public.kt_assign a),
    'extra', (select coalesce(jsonb_agg(to_jsonb(e) order by e.id), '[]'::jsonb) from public.kt_extra e where not strip)
  );
end $$;

revoke execute on function public.kt__need(text, boolean), public.kt__log(text, text, jsonb), public.kt__user(text), public.kt__ip() from public, anon, authenticated;
grant execute on function public.kt_login(text), public.kt_whoami(text), public.kt_logout(text) to anon, authenticated;
