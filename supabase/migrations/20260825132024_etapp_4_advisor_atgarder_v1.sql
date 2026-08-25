-- Etapp 4: åtgärder från Supabase security advisors 2026-08-25.
-- Empiriskt underlag: frontendbundeln gör inga anon-anrop alls (alla RPC:er sessionsgrindade),
-- cronjobb kör som postgres, edge functions som service_role — ingen påverkas av anon-indragning.

-- 1) Lås search_path på de 36 funktioner som saknade den (advisor: function_search_path_mutable).
--    Alla kroppar refererar endast public/pg_catalog (auth.* alltid schemakvalificerat) — verifierat mot dumpen.
alter function public._assert_company_access(uuid) set search_path = public;
alter function public._support_snip(text) set search_path = public;
alter function public.assign_archive_number() set search_path = public;
alter function public.bas_class(text) set search_path = public;
alter function public.bas_type(text) set search_path = public;
alter function public.clear_chart_of_accounts(uuid) set search_path = public;
alter function public.delete_account_safe(uuid,text) set search_path = public;
alter function public.forbjud_andring_bokford_levfaktura() set search_path = public;
alter function public.forbjud_bokford_faktura_radering() set search_path = public;
alter function public.forbjud_bokford_lonekorning_radering() set search_path = public;
alter function public.forbjud_bokford_radering() set search_path = public;
alter function public.import_chart_of_accounts(uuid,text,text,jsonb) set search_path = public;
alter function public.inbox_addr_guard() set search_path = public;
alter function public.is_platform_admin() set search_path = public;
alter function public.lager_handelser_appendonly() set search_path = public;
alter function public.lager_inventering_last() set search_path = public;
alter function public.map_stripe_status(text) set search_path = public;
alter function public.next_ver_nr(uuid,text) set search_path = public;
alter function public.notify_event(uuid,text,jsonb,text,uuid,text,uuid[],uuid,text,text,text[]) set search_path = public;
alter function public.notify_on_bookkeeping_suggestion() set search_path = public;
alter function public.notify_on_import_failed() set search_path = public;
alter function public.notify_on_inbound_document() set search_path = public;
alter function public.notify_on_verifikation_created() set search_path = public;
alter function public.on_verifikation_delete() set search_path = public;
alter function public.protect_archive_number() set search_path = public;
alter function public.protect_locked_account() set search_path = public;
alter function public.provision_company_inboxes() set search_path = public;
alter function public.purge_test_data(uuid) set search_path = public;
alter function public.render_template(text,jsonb) set search_path = public;
alter function public.reset_company(uuid,jsonb) set search_path = public;
alter function public.safe_uuid(text) set search_path = public;
alter function public.seed_bas_accounts(uuid) set search_path = public;
alter function public.seed_new_company() set search_path = public;
alter function public.set_updated_at() set search_path = public;
alter function public.skydda_bokfort_underlag() set search_path = public;
alter function public.verifikation_andringar_appendonly() set search_path = public;

-- 2) anon (och implicit PUBLIC) förlorar EXECUTE på samtliga egna funktioner i public.
--    Extensionfunktioner (btree_gist m.fl.) undantas — de är inte SECURITY DEFINER och
--    indexmaskineriet privilegiekontrolleras inte per anrop, men vi rör dem inte.
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as fn
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prokind in ('f','p')
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('revoke execute on function %s from public, anon', r.fn);
  end loop;
end$$;

-- 3) Triggerfunktioner ska inte kunna exekveras av API-rollerna alls.
--    (Triggrar avfyras oberoende av anroparens EXECUTE-rättighet — privilegiet
--    kontrolleras vid CREATE TRIGGER, inte vid DML. Verifieras i efterföljande test.)
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as fn
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prorettype = 'trigger'::regtype
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('revoke execute on function %s from authenticated, service_role', r.fn);
  end loop;
end$$;

-- 4) Framtida funktioner som skapas av postgres ska inte automatiskt bli anropbara av anon/PUBLIC.
alter default privileges for role postgres in schema public revoke execute on functions from public;
alter default privileges for role postgres in schema public revoke execute on functions from anon;

-- 5) Interna tabeller med RLS på men utan policies (avsiktlig deny-all): ta även bort de
--    verkningslösa DML-grants som låg kvar, samma mönster som konsol_-tabellerna och etapp 3.
revoke all on table
  public.ai_call_log, public.ai_cooldowns, public.bas_accounts,
  public.bokslut_sync_operations, public.company_lookup_cache, public.company_lookup_rate,
  public.interna_nycklar, public.konsol_audit_logg, public.ocr_provider_config,
  public.stripe_event_log, public.system_error_log
from anon, authenticated;
