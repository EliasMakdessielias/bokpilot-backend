-- GDPR-gallring av drift- och AI-loggar (registerförteckningen B4b/B7, art 5.1 e).
-- Bevarandetider fastställda av Elias 2026-08-17:
--   assistent_logg      24 mån  (created_at)
--   robo_bp_messages    24 mån  (created_at)
--   support_ai_events   24 mån  (created_at)
--   kivra_utskick       24 mån  (skickad_at)
--   inbound_email_log   12 mån  (created_at)
-- Spårbarhetsloggarna (audit_log, ai_bokforing_logg, download_audit_log) gallras
-- ALDRIG här — de ingår i verifieringskedjan enligt BFL och bevaras med bokföringen.

create or replace function public.gallra_gdpr_loggar()
returns table(tabell text, raderade bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  n bigint;
begin
  delete from public.assistent_logg where created_at < now() - interval '24 months';
  get diagnostics n = row_count;
  tabell := 'assistent_logg'; raderade := n; return next;

  delete from public.robo_bp_messages where created_at < now() - interval '24 months';
  get diagnostics n = row_count;
  tabell := 'robo_bp_messages'; raderade := n; return next;

  delete from public.support_ai_events where created_at < now() - interval '24 months';
  get diagnostics n = row_count;
  tabell := 'support_ai_events'; raderade := n; return next;

  delete from public.kivra_utskick where skickad_at < now() - interval '24 months';
  get diagnostics n = row_count;
  tabell := 'kivra_utskick'; raderade := n; return next;

  delete from public.inbound_email_log where created_at < now() - interval '12 months';
  get diagnostics n = row_count;
  tabell := 'inbound_email_log'; raderade := n; return next;
end $$;

comment on function public.gallra_gdpr_loggar() is
  'Nattlig GDPR-gallring (art 5.1 e). Bevarandetider enligt GDPR-REGISTERFORTECKNING.md B7. Körs av pg_cron-jobbet gdpr-gallring-natt.';

-- Endast driftjobbet (och service role) får köra gallringen — inte klienter.
revoke execute on function public.gallra_gdpr_loggar() from public, anon, authenticated;

-- Schemalagd nattlig körning 03:40 (krockar inte med monthly-control 03:15,
-- byrastod-jobb-natt 04:10, notiser 06:00, subscription-grace 06:15).
-- Exception-säker enligt husmönstret (bryter inte migrationen om pg_cron saknas).
do $$
begin
  perform cron.unschedule('gdpr-gallring-natt');
exception when others then null;  -- fanns inte — ok
end $$;

do $$
begin
  perform cron.schedule('gdpr-gallring-natt', '40 3 * * *',
    $cron$select public.gallra_gdpr_loggar()$cron$);
exception when others then
  raise notice 'pg_cron ej tillgänglig — schemalägg gallra_gdpr_loggar() manuellt: %', sqlerrm;
end $$;
