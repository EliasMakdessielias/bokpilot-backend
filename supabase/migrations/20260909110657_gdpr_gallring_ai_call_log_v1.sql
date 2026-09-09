-- gdpr_gallring_ai_call_log_v1 (2026-09-09): bevarandetid för ai_call_log.
--
-- ai_call_log är räknaren bakom AI-kvoterna (ai_kvot_klaim, ai_claim_job) och behöver bara
-- det senaste dygnet för sitt ändamål. Tolv månader bevaras för missbruksutredning och
-- kostnadsuppföljning (intresseavvägning, art. 6.1 f; lagringsminimering, art. 5.1 e) —
-- Elias beslut 2026-09-09 efter granskningsagenternas fynd. Raderna är pseudonyma (user_id,
-- company_id, document_id, funktion, tidpunkt) och innehåller ingen prompt eller text.
-- Gallras av det nattliga jobbet gdpr-gallring-natt (03:40) via gallra_gdpr_loggar(),
-- som får en sjätte tabell. Övriga bevarandetider är oförändrade.
create or replace function public.gallra_gdpr_loggar()
 returns table(tabell text, raderade bigint)
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
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

  -- 2026-09-09: ai_call_log (räknaren bakom AI-kvoterna) bevaras tolv månader.
  delete from public.ai_call_log where created_at < now() - interval '12 months';
  get diagnostics n = row_count;
  tabell := 'ai_call_log'; raderade := n; return next;
end $function$;
