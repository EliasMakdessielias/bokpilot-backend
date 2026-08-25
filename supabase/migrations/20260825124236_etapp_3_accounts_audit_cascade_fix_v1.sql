-- Etapp 3, sista cascade-fixen: accounts_audit skriver direkt till audit_log (går inte via
-- log_accounting_audit) och saknade felhantering. Vid radering av ett bolag raderas hela
-- kontoplanen (~1367 konton) via cascade, och varje konto triggade en auditskrivning mot ett
-- bolag som är på väg bort → foreign_key_violation som avbröt hela raderingen.
--
-- Pre-existerande bugg (inte införd av etapp 3). Samma semantik som övriga audit-vägar:
-- FK-brott sväljs (kan bara betyda att bolaget försvinner), alla andra fel kastas.
-- search_path sätts explicit (saknades helt) enligt samma mönster som övriga SECURITY DEFINER.
create or replace function public.accounts_audit() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_email text := auth.jwt() ->> 'email';
  v_uid uuid := auth.uid();
begin
  if current_setting('app.bulk_import', true) = 'on' then
    return coalesce(new, old);
  end if;

  begin
    if (tg_op = 'DELETE') then
      insert into public.audit_log(company_id, entity, entity_ref, action, old_data, changed_by, changed_by_email)
      values (old.company_id, 'account', old.account_nr, 'delete', to_jsonb(old), v_uid, v_email);
    elsif (tg_op = 'UPDATE') then
      insert into public.audit_log(company_id, entity, entity_ref, action, old_data, new_data, changed_by, changed_by_email)
      values (new.company_id, 'account', new.account_nr, 'update', to_jsonb(old), to_jsonb(new), v_uid, v_email);
    else
      insert into public.audit_log(company_id, entity, entity_ref, action, new_data, changed_by, changed_by_email)
      values (new.company_id, 'account', new.account_nr, 'create', to_jsonb(new), v_uid, v_email);
    end if;
  exception
    when foreign_key_violation then
      null;   -- bolaget raderas (cascade) – auditraden har inget att peka på
    when others then
      raise;  -- riktigt auditfel stoppar transaktionen
  end;

  return case when tg_op = 'DELETE' then old else new end;
end $$;
