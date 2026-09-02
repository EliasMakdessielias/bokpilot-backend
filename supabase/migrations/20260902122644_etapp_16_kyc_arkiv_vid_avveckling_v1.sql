-- Etapp 16: kundkännedom bevaras när ett bolag avvecklas (PTL 5 kap. 3–4 §§).
--
-- avveckla_bolag() (etapp 8) skyddar räkenskapsinformationen enligt BFL men raderar
-- kyc_assessments och aml_flags uttryckligen — de har RESTRICT-nycklar mot companies
-- och måste bort för att bolaget ska kunna raderas. Sedan etapp 13 kaskaderar även
-- kyc_huvudman och kyc_bilagor med. Penningtvättslagen kräver dock att handlingar
-- och uppgifter om kundkännedom bevaras i fem år efter att affärsförbindelsen
-- upphörde (5 kap. 3 §), upp till tio år på begäran av myndighet (5 kap. 4 §).
--
-- Lösning: en fryst kopia (jsonb) av alla KYC-rader, huvudmän, bilagereferenser och
-- AML-flaggor tas INNAN raderingen och läggs i kyc_arkiv. Tabellen är append-only:
-- ingen ändring, ingen radering före bevaras_till; enda tillåtna uppdatering är att
-- förlänga bevarandetiden. Filerna i bucketen 'kyc' rörs inte av avvecklingen
-- (stadning-underlag tömmer bara 'underlag'), så bilagorna finns kvar under
-- <bolags-id>/ och läspolicyn utökas så byrån når dem via arkivet.
--
-- Personuppgifter (personnummer på verkliga huvudmän) hamnar i arkivet — rättslig
-- grund är den lagstadgade bevarandeskyldigheten (GDPR art. 6.1 c, PTL 5 kap. 3 §).

create table public.kyc_arkiv (
  id                              uuid primary key default gen_random_uuid(),
  bolag_id_ursprung               uuid not null,
  bolag_namn                      text not null,
  org_nr                          text,
  byra_bolag_ids                  uuid[] not null default '{}',
  affarsforbindelse_avslutad_at   timestamptz not null default now(),
  bevaras_till                    date not null,
  avvecklad_av                    uuid,
  orsak                           text,
  kyc_assessments                 jsonb not null,
  kyc_huvudman                    jsonb not null default '[]'::jsonb,
  kyc_bilagor                     jsonb not null default '[]'::jsonb,
  aml_flags                       jsonb not null default '[]'::jsonb,
  created_at                      timestamptz not null default now()
);
comment on table public.kyc_arkiv is
  'Fryst kopia av kundkännedom för avvecklade bolag. Bevaras enligt PTL 5 kap. 3 § (5 år) / 4 § (10 år). Append-only.';
create index kyc_arkiv_byra_idx on public.kyc_arkiv using gin (byra_bolag_ids);
create index kyc_arkiv_bevaras_idx on public.kyc_arkiv (bevaras_till);

alter table public.kyc_arkiv enable row level security;
revoke all on public.kyc_arkiv from anon, authenticated;
grant select on public.kyc_arkiv to authenticated;
create policy kyc_arkiv_select on public.kyc_arkiv for select to authenticated
  using (public.is_platform_admin() or byra_bolag_ids && array(select public.mina_byraer()));

-- Append-only: ändring nekas utom förlängd bevarandetid; radering nekas före bevaras_till.
create or replace function public.kyc_arkiv_skydd()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op = 'UPDATE' then
    if new.bevaras_till > old.bevaras_till
       and (to_jsonb(new) - 'bevaras_till') = (to_jsonb(old) - 'bevaras_till') then
      return new;
    end if;
    raise exception 'KYC_ARKIV_SKYDD: arkiverad kundkännedom kan inte ändras — endast bevarandetiden får förlängas (PTL 5 kap. 3–4 §§).';
  elsif tg_op = 'DELETE' then
    if old.bevaras_till < current_date then
      return old;
    end if;
    raise exception 'KYC_ARKIV_SKYDD: bevarandetiden löper till % — radering nekad (PTL 5 kap. 3 §).', old.bevaras_till;
  end if;
  raise exception 'KYC_ARKIV_SKYDD: % nekad.', tg_op;
end $fn$;
revoke execute on function public.kyc_arkiv_skydd() from public, anon, authenticated;

create trigger trg_kyc_arkiv_skydd
  before update or delete on public.kyc_arkiv
  for each row execute function public.kyc_arkiv_skydd();
create trigger trg_kyc_arkiv_no_truncate
  before truncate on public.kyc_arkiv
  for each statement execute function public.kyc_arkiv_skydd();

-- Byrån får läsa bilagor i bucketen 'kyc' även för avvecklade bolag den haft som klient.
alter policy kyc_obj_select on storage.objects using (
  bucket_id = 'kyc' and (
    (storage.foldername(name))[1] in (select k::text from public.mina_klientbolag() k)
    or (storage.foldername(name))[1] in (
      select a.bolag_id_ursprung::text from public.kyc_arkiv a
      where a.byra_bolag_ids && array(select public.mina_byraer()))
  )
);

-- avveckla_bolag: identisk med etapp 8 utom arkiveringsblocket före KYC-raderingen.
create or replace function public.avveckla_bolag(p_company uuid, p_orsak text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_namn text; v_orgnr text; v_innehall jsonb := '{}'::jsonb; r record; n bigint;
  v_arkiv uuid; v_bevaras date;
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

  -- PTL 5 kap. 3 §: kundkännedomen fryses i kyc_arkiv innan raderna måste bort.
  if exists (select 1 from public.kyc_assessments where company_id = p_company) then
    v_bevaras := (current_date + interval '5 years')::date;
    insert into public.kyc_arkiv (
      bolag_id_ursprung, bolag_namn, org_nr, byra_bolag_ids,
      affarsforbindelse_avslutad_at, bevaras_till, avvecklad_av, orsak,
      kyc_assessments, kyc_huvudman, kyc_bilagor, aml_flags)
    values (
      p_company, v_namn, v_orgnr,
      coalesce((select array_agg(distinct bk.byra_bolag_id) from public.byra_klient bk where bk.klient_bolag_id = p_company), '{}'),
      now(), v_bevaras, auth.uid(), left(trim(p_orsak), 500),
      (select coalesce(jsonb_agg(to_jsonb(k) order by k.created_at), '[]'::jsonb) from public.kyc_assessments k where k.company_id = p_company),
      (select coalesce(jsonb_agg(to_jsonb(h) order by h.created_at), '[]'::jsonb) from public.kyc_huvudman h where h.company_id = p_company),
      (select coalesce(jsonb_agg(to_jsonb(b) order by b.created_at), '[]'::jsonb) from public.kyc_bilagor b where b.company_id = p_company),
      (select coalesce(jsonb_agg(to_jsonb(f) order by f.created_at), '[]'::jsonb) from public.aml_flags f where f.company_id = p_company))
    returning id into v_arkiv;

    perform public.log_platform_audit(
      'kyc_archived', p_company::text,
      jsonb_build_object('kyc_arkiv_id', v_arkiv, 'bevaras_till', v_bevaras,
                         'lagrum', 'PTL 5 kap. 3 §'));
  end if;

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
                            'raderat_innehall', v_innehall,
                            'kyc_arkiv_id', v_arkiv, 'kyc_bevaras_till', v_bevaras);
end $function$;
