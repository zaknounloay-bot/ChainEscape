-- Chain Escape - real-player results (Phase 3B-B), follow-up to
-- 20261014120000_ce_competition_results.sql. ADDITIVE ONLY: table grants
-- for service_role, nothing else.
--
-- Why: on this project new tables in public give service_role only
-- TRUNCATE/REFERENCES/TRIGGER/MAINTAIN by default (no SELECT/INSERT/UPDATE/
-- DELETE), unlike Supabase's older "grant all" default. ce_submit_result and
-- ce_level_standing are SECURITY INVOKER, so the Edge Function (service_role)
-- needs these table privileges to run them. Bypassing RLS does not replace
-- table privileges.
--
-- Exactly what the two functions do, no more:
--   ce_level_fingerprints  SELECT                  (active level check)
--   ce_comp_players        SELECT, INSERT          (read / claim a player;
--                                                   ON CONFLICT DO NOTHING)
--   ce_level_results       SELECT, INSERT, UPDATE  (upsert ON CONFLICT DO
--                                                   UPDATE ... WHERE, ranking)
-- No DELETE. anon and authenticated stay without any access (RLS on, no
-- policies, privileges revoked by the first migration).

grant select on public.ce_level_fingerprints to service_role;
grant select, insert on public.ce_comp_players to service_role;
grant select, insert, update on public.ce_level_results to service_role;
