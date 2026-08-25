-- Följdfix 3 till etapp 8. Sju främmande nycklar mot companies har RESTRICT/NO ACTION
-- och blockerar därför raderingen även med samtliga triggerundantag på plats:
--   byra_klient, byra_medlemskap, uppdrag, uppdragsuppgift (byråkopplingar),
--   aml_flags, kyc_assessments (penningtvättslagen), kivra_utskick.
-- De måste rensas uttryckligen och i rätt ordning.
--
-- Om AML/KYC: penningtvättslagen har egna bevarandetider som skiljer sig från BFL:s
-- sju år. Omfattningen loggas därför i platform_audit_log innan posterna tas bort,
-- så att det i efterhand går att visa vad som fanns. Överväg arkivexport av
-- KYC-underlaget innan ett bolag med kundkännedomsdokumentation avvecklas.

-- Byråns sista administratör: samma resonemang som forbjud_sista_admin_bort.
create or replace function public.skydda_sista_byra_admin()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $fn$
begin
  if tg_op = 'DELETE' and current_setting('app.bfl_avveckla', true) = 'on' then
    return OLD;
  end if;
  if OLD.roll = 'admin' and OLD.aktiv
     and not exists (
       select 1 from public.byra_medlemskap m
       where m.byra_bolag_id = OLD.byra_bolag_id
         and m.roll = 'admin' and m.aktiv and m.id <> OLD.id)
  then
    raise exception 'Byrån måste ha minst en aktiv administratör.';
  end if;
  return OLD;
end $fn$;

create or replace function public.avveckla_bolag(p_company uuid, p_orsak text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_namn text; v_orgnr text; v_innehall jsonb := '{}'::jsonb; r record; n bigint;
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

  -- Sammanställ omfattningen INNAN något raderas, för den permanenta loggen.
  for r in
    select * from (values
      ('verifikationer'), ('verifikation_andringar'), ('documents'), ('invoices'),
      ('supplier_invoices'), ('bank_transactions'), ('vat_reports'), ('lonekorningar'),
      ('lonebesked'), ('salaries'), ('agi_deklarationer'), ('accounts'),
      ('kyc_assessments'), ('aml_flags')
    ) as t(tabell)
  loop
    if to_regclass('public.' || r.tabell) is not null then
      execute format('select count(*) from public.%I where company_id = $1', r.tabell)
        into n using p_company;
      if n > 0 then v_innehall := v_innehall || jsonb_build_object(r.tabell, n); end if;
    end if;
  end loop;

  perform public.log_platform_audit(
    'company_decommissioned', p_company::text,
    jsonb_build_object('namn', v_namn, 'org_nr', v_orgnr,
                       'orsak', left(trim(p_orsak), 500),
                       'innehall_vid_radering', v_innehall,
                       'lagrum', 'BFL 7 kap. 2 §'));

  perform set_config('app.bfl_avveckla', 'on', true);
  perform set_config('app.periodlas_bypass', 'on', true);

  -- Relationer som inte kaskaderar. Ordningen följer beroendena:
  -- uppgifter före uppdrag, uppdrag före byråkopplingen.
  delete from public.uppdragsuppgift where klient_bolag_id = p_company or byra_bolag_id = p_company;
  delete from public.uppdrag         where klient_bolag_id = p_company or byra_bolag_id = p_company;
  delete from public.byra_klient     where klient_bolag_id = p_company or byra_bolag_id = p_company;
  delete from public.byra_medlemskap where byra_bolag_id = p_company;
  delete from public.aml_flags       where company_id = p_company;
  delete from public.kyc_assessments where company_id = p_company;
  delete from public.kivra_utskick   where company_id = p_company;

  delete from public.companies where id = p_company;

  perform set_config('app.bfl_avveckla', 'off', true);
  perform set_config('app.periodlas_bypass', 'off', true);

  return jsonb_build_object('ok', true, 'bolag', v_namn, 'org_nr', v_orgnr,
                            'raderat_innehall', v_innehall);
end $fn$;

revoke execute on function public.avveckla_bolag(uuid, text) from public, anon;
grant execute on function public.avveckla_bolag(uuid, text) to authenticated;
