-- Etapp 4 forts.: log_accounting_audit kontrollerade anroparens bolagsåtkomst ENDAST i
-- grenen för p_entity = 'document'. Med ett explicit p_company_id kunde därför vilken
-- inloggad användare som helst skriva förfalskade rader i ett främmande bolags audit_log
-- (BFL 5 kap. – behandlingshistorikens tillförlitlighet).
--
-- Kontrollen läggs på DIREKTANROP (pg_trigger_depth() = 0). Triggeranrop undantas
-- eftersom den underliggande DML:en redan passerat sina egna spärrar, och systemflöden
-- (cron som postgres, edge functions med service_role) saknar auth.uid() och berörs inte.
-- Åtkomstpopulationen är densamma som bokfor_verifikation redan kräver.
create or replace function public.log_accounting_audit(
  p_action text, p_entity text, p_entity_ref text,
  p_source text default null::text, p_metadata jsonb default null::jsonb,
  p_company_id uuid default null::uuid, p_before jsonb default null::jsonb,
  p_after jsonb default null::jsonb)
 returns void
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_actor uuid := auth.uid();
  v_email text := auth.jwt() ->> 'email';
  v_company uuid := p_company_id;
begin
  if v_company is null and p_entity = 'document' and p_entity_ref is not null then
    select company_id into v_company from public.documents where id = p_entity_ref::uuid;
    if v_actor is not null and v_company is not null
       and not exists (select 1 from public.user_companies uc where uc.user_id = v_actor and uc.company_id = v_company) then
      return;
    end if;
  elsif pg_trigger_depth() = 0 and v_actor is not null and v_company is not null then
    perform public._assert_company_access(v_company);
  end if;
  if v_company is null then return; end if;

  begin
    insert into public.audit_log(company_id, entity, entity_ref, action, old_data, new_data, metadata, source, changed_by, changed_by_email)
    values (v_company, p_entity, p_entity_ref, p_action, p_before, p_after, p_metadata,
            coalesce(p_source, case when v_actor is not null then 'ui' else 'system' end), v_actor, v_email);
  exception
    when foreign_key_violation then
      null;   -- bolaget raderas (cascade) – auditraden har inget att peka på
  end;
end $function$;
