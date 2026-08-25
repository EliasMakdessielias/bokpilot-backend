-- Etapp 3, följdfix: audit_verifikation_rows saknade all felhantering.
--
-- Upptäckt vid test av företagsradering. Vid cascade-radering (companies → verifikationer →
-- verifikation_rows) försöker radtriggern skriva en audit_log-rad för ett bolag som är på
-- väg bort → foreign_key_violation som avbryter hela raderingen.
--
-- Funktionens befintliga "modern är redan borta"-check räcker inte: under cascade är
-- moderverifikationen fortfarande synlig i statementets snapshot, så den loggar ändå.
--
-- OBS: detta var en pre-existerande bugg (fanns före etapp 3) — den doldes tidigare inte
-- av något, utan gjorde helt enkelt att radering av bolag med bokförd historik fallerade.
-- Samma semantik som audit_verifikation: FK-brott sväljs (kan bara betyda att bolaget
-- försvinner), alla andra fel kastas så att loggen inte kan tystas i drift.
create or replace function public.audit_verifikation_rows() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_ver uuid; v_company uuid; v_ver_nr text;
begin
  -- Enbart avstämningsmarkering: arbetsmarkering, inte bokföringsdata.
  if tg_op = 'UPDATE'
     and new.account_nr = old.account_nr
     and new.account_name is not distinct from old.account_name
     and coalesce(new.debet, 0) = coalesce(old.debet, 0)
     and coalesce(new.kredit, 0) = coalesce(old.kredit, 0)
     and new.transaction_info is not distinct from old.transaction_info
     and new.sort_order is not distinct from old.sort_order
     and new.verifikation_id is not distinct from old.verifikation_id then
    return new;
  end if;

  v_ver := case when tg_op = 'DELETE' then old.verifikation_id else new.verifikation_id end;
  select v.company_id, v.ver_nr into v_company, v_ver_nr
    from public.verifikationer v where v.id = v_ver;

  -- Moderverifikationen är redan borta (kaskadradering) – huvudets egen
  -- audit-post innehåller hela raduppsättningen, så vi loggar inte dubbelt.
  if not found then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  begin
    perform public.log_accounting_audit(
      case tg_op when 'INSERT' then 'row_created'
                 when 'UPDATE' then 'row_updated'
                 else 'row_deleted' end,
      'verifikation_rad',
      (case when tg_op = 'DELETE' then old.id else new.id end)::text,
      nullif(current_setting('app.audit_source', true), ''),
      jsonb_build_object('verifikation_id', v_ver, 'ver_nr', v_ver_nr),
      v_company,
      case when tg_op <> 'INSERT' then jsonb_build_object(
        'konto', old.account_nr, 'kontonamn', old.account_name,
        'debet', old.debet, 'kredit', old.kredit,
        'text', old.transaction_info, 'ordning', old.sort_order) end,
      case when tg_op <> 'DELETE' then jsonb_build_object(
        'konto', new.account_nr, 'kontonamn', new.account_name,
        'debet', new.debet, 'kredit', new.kredit,
        'text', new.transaction_info, 'ordning', new.sort_order) end
    );
  exception
    when foreign_key_violation then
      null;   -- bolaget raderas (cascade) – audit-raden har inget att peka på
    when others then
      raise;  -- riktigt auditfel stoppar transaktionen
  end;

  return case when tg_op = 'DELETE' then old else new end;
end $$;
