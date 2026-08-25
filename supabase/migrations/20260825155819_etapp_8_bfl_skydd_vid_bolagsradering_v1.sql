-- Etapp 8: databasspärr mot att räkenskapsinformation förstörs vid bolagsradering.
--
-- Bakgrund: 72 tabeller har ON DELETE CASCADE mot companies(id) — däribland
-- verifikationer, verifikation_andringar, documents och audit_log. En enda
-- DELETE på companies raderar alltså hela bokföringen OCH beviskedjan.
--
-- Skyddet fanns i praktiken bara som en sidoeffekt: kaskaden träffar
-- forbjud_sista_admin_bort (kan inte ta bort siste admin) och
-- forbjud_bokford_radering (verifikationer får inte raderas). Ingen av dem är
-- en BFL-regel — de skyddar bokföringen av en slump, och ett bolag utan
-- verifikationer men med underlag, fakturor eller lönedata hade inget skydd alls.
--
-- Här införs ett uttryckligt, namngivet skydd på companies-nivå som gäller ALLA
-- vägar in, inklusive service_role och SQL-editorn.

create or replace function public.forbjud_radera_bolag_med_rakenskapsinfo()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  r record; n bigint; v_fynd text[] := '{}';
begin
  -- Sanktionerad avveckling sätter flaggan; den sätts endast av avveckla_bolag().
  if current_setting('app.bfl_avveckla', true) = 'on' then
    return old;
  end if;

  for r in
    select * from (values
      ('verifikationer',        'bokförda verifikationer'),
      ('verifikation_andringar','poster i rättelsejournalen'),
      ('documents',             'underlag'),
      ('invoices',              'kundfakturor'),
      ('supplier_invoices',     'leverantörsfakturor'),
      ('bank_transactions',     'bankhändelser'),
      ('vat_reports',           'momsrapporter'),
      ('lonekorningar',         'lönekörningar'),
      ('lonebesked',            'lönebesked'),
      ('salaries',              'löneposter'),
      ('agi_deklarationer',     'AGI-deklarationer')
    ) as t(tabell, etikett)
  loop
    if to_regclass('public.' || r.tabell) is not null then
      execute format('select count(*) from public.%I where company_id = $1', r.tabell)
        into n using old.id;
      if n > 0 then
        v_fynd := v_fynd || format('%s %s', n, r.etikett);
      end if;
    end if;
  end loop;

  if array_length(v_fynd, 1) > 0 then
    raise exception
      'BFL_SKYDD: Bolaget "%" kan inte raderas. Det innehåller räkenskapsinformation som ska bevaras i sju år efter utgången av det kalenderår då räkenskapsåret avslutades (BFL 7 kap. 2 §). Hittade: %. Ta en arkivexport först och avveckla därefter via avveckla_bolag(bolags_id, orsak), som loggar åtgärden permanent.',
      old.name, array_to_string(v_fynd, ', ');
  end if;

  return old;
end $fn$;

drop trigger if exists trg_forbjud_radera_bolag_med_rakenskapsinfo on public.companies;
create trigger trg_forbjud_radera_bolag_med_rakenskapsinfo
  before delete on public.companies
  for each row execute function public.forbjud_radera_bolag_med_rakenskapsinfo();

-- Sanktionerad väg: kräver plattformsadmin och en orsak, och loggar i
-- platform_audit_log — en av få loggar som INTE kaskaderar bort med bolaget
-- (audit_log gör det, och är alltså värdelös för just den här händelsen).
create or replace function public.avveckla_bolag(p_company uuid, p_orsak text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_namn text; v_orgnr text; v_innehall jsonb; r record; n bigint;
begin
  if not public.is_platform_admin() then
    raise exception 'ATKOMST_NEKAD: Endast plattformsadministratör kan avveckla ett bolag.';
  end if;
  if nullif(trim(coalesce(p_orsak, '')), '') is null then
    raise exception 'FEL: Ange en orsak till avvecklingen. Den loggas permanent och går inte att ändra i efterhand.';
  end if;

  select name, org_nr into v_namn, v_orgnr from public.companies where id = p_company;
  if v_namn is null then
    raise exception 'FEL: Bolaget finns inte.';
  end if;

  -- Sammanställ vad som förstörs, så loggen visar omfattningen även efteråt.
  v_innehall := '{}'::jsonb;
  for r in
    select * from (values
      ('verifikationer'), ('verifikation_andringar'), ('documents'), ('invoices'),
      ('supplier_invoices'), ('bank_transactions'), ('vat_reports'),
      ('lonekorningar'), ('lonebesked'), ('salaries'), ('agi_deklarationer'), ('accounts')
    ) as t(tabell)
  loop
    if to_regclass('public.' || r.tabell) is not null then
      execute format('select count(*) from public.%I where company_id = $1', r.tabell)
        into n using p_company;
      if n > 0 then
        v_innehall := v_innehall || jsonb_build_object(r.tabell, n);
      end if;
    end if;
  end loop;

  perform public.log_platform_audit(
    'company_decommissioned',
    p_company::text,
    jsonb_build_object('namn', v_namn, 'org_nr', v_orgnr,
                       'orsak', left(trim(p_orsak), 500),
                       'innehall_vid_radering', v_innehall,
                       'lagrum', 'BFL 7 kap. 2 §'));

  perform set_config('app.bfl_avveckla', 'on', true);
  perform set_config('app.periodlas_bypass', 'on', true);
  delete from public.companies where id = p_company;
  perform set_config('app.bfl_avveckla', 'off', true);
  perform set_config('app.periodlas_bypass', 'off', true);

  return jsonb_build_object('ok', true, 'bolag', v_namn, 'org_nr', v_orgnr,
                            'raderat_innehall', v_innehall);
end $fn$;

revoke execute on function public.forbjud_radera_bolag_med_rakenskapsinfo() from public, anon, authenticated;
revoke execute on function public.avveckla_bolag(uuid, text) from public, anon;
grant execute on function public.avveckla_bolag(uuid, text) to authenticated;
