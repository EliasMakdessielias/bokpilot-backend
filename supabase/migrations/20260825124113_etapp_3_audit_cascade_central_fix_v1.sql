-- Etapp 3, central fix: cascade-säkra auditloggen på ETT ställe i stället för per trigger.
--
-- Vid radering av ett bolag raderas allt som pekar på det (verifikationer, verifikationsrader,
-- hela kontoplanen, arkivfiler …). Varje sådan tabell har en audit-trigger som skriver till
-- audit_log — vars company_id har FK ON DELETE CASCADE mot companies. Under raderingen finns
-- bolaget kvar i statementets snapshot, så triggrarna loggar ändå och får foreign_key_violation,
-- vilket avbryter hela raderingen.
--
-- Att lappa varje trigger blir spretigt (accounts_audit, arkiv_*, audit_verifikation_rows …).
-- Rätt nivå är log_accounting_audit, som alla går igenom: FK-brott mot audit_log kan i praktiken
-- bara betyda "bolaget finns inte längre" och sväljs därför. Alla andra fel kastas som förut,
-- så auditloggen fortfarande inte kan tystas i drift (BFL 5 kap).
create or replace function public.log_accounting_audit(
  p_action text, p_entity text, p_entity_ref text, p_source text default null::text,
  p_metadata jsonb default null::jsonb, p_company_id uuid default null::uuid,
  p_before jsonb default null::jsonb, p_after jsonb default null::jsonb
) returns void
language plpgsql security definer set search_path to 'public'
as $$
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
end $$;
