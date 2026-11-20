-- Verwijdert ALLE kroegentocht-tabellen en -functies (kt_...) uit het Supabase-project HHCdatabase.
-- Andere tabellen blijven onaangeroerd. Plak dit in de Supabase SQL-editor.
do $$ declare f record; begin
  for f in select p.oid::regprocedure s from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.proname like 'kt\_%' loop
    execute 'drop function ' || f.s;
  end loop;
end $$;
drop table if exists public.kt_sessions, public.kt_login_fail, public.kt_log, public.kt_extra, public.kt_assign,
  public.kt_cards, public.kt_teams, public.kt_users, public.kt_settings cascade;
