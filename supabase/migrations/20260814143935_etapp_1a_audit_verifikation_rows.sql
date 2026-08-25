-- Etapp 1a: behandlingshistorik på verifikationsrader.
-- Rent additiv: loggar INSERT/UPDATE/DELETE på verifikation_rows till audit_log.
-- Spärrar ingenting och ändrar ingen befintlig data.

create or replace function public.audit_verifikation_rows()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
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

  return case when tg_op = 'DELETE' then old else new end;
end $$;

drop trigger if exists trg_audit_ver_rows on public.verifikation_rows;
create trigger trg_audit_ver_rows
after insert or update or delete on public.verifikation_rows
for each row execute function public.audit_verifikation_rows();
