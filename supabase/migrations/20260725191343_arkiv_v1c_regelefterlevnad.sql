-- ARKIV v1c — laggranskningens måste-punkter (2026-07-25). Spegel: supabase/arkiv_v1c.sql
--
-- F1 (BFL 7:2): systemgenererad räkenskapsinformation kunde raderas permanent ur arkivet,
--   även av kunden själv via API (RLS tillät det UI:t dolde). Nu spärrad i databasen.
-- F4/F5 (PTL): standardmappen "Uppdrag och kundkännedom" utgår helt — KYC-material hör
--   hemma i KYC-lagret (kyc_aml.sql) som redan har rätt behörighetsgrind (ar_byra_medlem),
--   rätt bevarandetid och rätt koppling till affärsförbindelsens slut. Två parallella
--   platser för PTL-material vore fel oavsett hur väl den ena skyddas.
-- F4:3: systemmappen Personal kan inte längre öppnas för kunden i ett klick.
-- F9 (BFL 1:2 p8b): avtal och försäkringshandlingar är räkenskapsinformation → 7 år.
-- F6 (BFL 5:11): synlighetsändring på en mapp skrivs till behandlingshistoriken.

-- ── F1: raderingsskydd för appens egna handlingar ───────────────────────────
-- Avgränsat till `kalla` (moms/agi/sie/årsredovisning/arkivexport) i stället för hela
-- bfl_7ar-mappen: en kund som råkar ladda upp ett privat foto i Skatteverket-mappen
-- måste fortfarande kunna ta bort det (GDPR art. 17 — se F3 i laggranskningen).
create or replace function public.arkiv_skydda_rakenskapsinfo() returns trigger
language plpgsql set search_path = public as $$
declare v_kalla text; v_namn text;
begin
  if tg_op = 'DELETE' then
    v_kalla := old.kalla; v_namn := old.file_name;
  else
    -- Endast övergången till raderad räknas; övriga uppdateringar är fria.
    if new.raderad_at is null or old.raderad_at is not null then return new; end if;
    v_kalla := new.kalla; v_namn := new.file_name;
  end if;
  if v_kalla in ('moms', 'agi', 'sie', 'arsredovisning', 'arkivexport') then
    raise exception '% är räkenskapsinformation och måste bevaras i sju år (bokföringslagen 7 kap. 2 §)', v_namn;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;

drop trigger if exists arkiv_skydda_rakenskapsinfo_del on public.arkiv_filer;
create trigger arkiv_skydda_rakenskapsinfo_del before delete on public.arkiv_filer
  for each row execute function public.arkiv_skydda_rakenskapsinfo();

drop trigger if exists arkiv_skydda_rakenskapsinfo_upd on public.arkiv_filer;
create trigger arkiv_skydda_rakenskapsinfo_upd before update on public.arkiv_filer
  for each row execute function public.arkiv_skydda_rakenskapsinfo();

-- ── F4:3: systemmappar med känsligt innehåll låses till byrån ───────────────
create or replace function public.arkiv_mapp_skydda_systemmapp() returns trigger
language plpgsql set search_path = public as $$
begin
  if old.systemnyckel is not null then
    if new.systemnyckel is distinct from old.systemnyckel then
      raise exception 'Standardmappens systemnyckel kan inte ändras';
    end if;
    if old.systemnyckel = 'personal' and new.synlighet <> 'byra' then
      raise exception 'Personalmappen innehåller personuppgifter om anställda och kan inte öppnas för alla användare i bolaget';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists arkiv_mapp_skydda_systemmapp_trg on public.arkiv_mappar;
create trigger arkiv_mapp_skydda_systemmapp_trg before update on public.arkiv_mappar
  for each row execute function public.arkiv_mapp_skydda_systemmapp();

-- ── F6: synlighetsändring i behandlingshistoriken ───────────────────────────
create or replace function public.arkiv_mapp_logga_synlighet() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.synlighet is distinct from old.synlighet then
    insert into audit_log (company_id, entity, entity_ref, action, old_data, new_data, changed_by, source)
    values (new.company_id, 'arkiv_mapp', new.id::text, 'andra_synlighet',
            jsonb_build_object('namn', old.namn, 'synlighet', old.synlighet),
            jsonb_build_object('namn', new.namn, 'synlighet', new.synlighet),
            auth.uid(), 'ui');
  end if;
  return new;
end $$;

drop trigger if exists arkiv_mapp_logga_synlighet_trg on public.arkiv_mappar;
create trigger arkiv_mapp_logga_synlighet_trg after update on public.arkiv_mappar
  for each row execute function public.arkiv_mapp_logga_synlighet();

-- ── F4/F5 + F9: standarduppsättningen görs om ───────────────────────────────
create or replace function public.arkiv_skapa_standardmappar(p_company uuid)
returns int language plpgsql security definer set search_path = public as $$
declare v_antal int := 0; r record;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from user_companies where user_id = auth.uid() and company_id = p_company) then
    raise exception 'forbidden';
  end if;
  for r in select * from (values
      ('skatteverket',    'Skatteverket',               'kund',       'bfl_7ar',      10),
      ('bokslut',         'Bokslut och årsredovisning', 'kund',       'bfl_7ar',      20),
      -- Avtal och försäkringshandlingar är räkenskapsinformation (BFL 1 kap. 2 § p 8 b).
      ('avtal',           'Avtal',                      'kund_skriv', 'bfl_7ar',      30),
      ('bank_forsakring', 'Bank och försäkring',        'kund_skriv', 'bfl_7ar',      40),
      ('personal',        'Personal',                   'byra',       'gdpr_gallras', 50),
      ('ovrigt',          'Övrigt',                     'kund_skriv', 'ingen',        70)
    ) as t(nyckel, namn, synlighet, gallring, sort)
  loop
    if not exists (select 1 from arkiv_mappar where company_id = p_company and systemnyckel = r.nyckel) then
      insert into arkiv_mappar (company_id, namn, synlighet, gallringsregel, systemnyckel, sortering)
      values (p_company, r.namn, r.synlighet, r.gallring, r.nyckel, r.sort);
      v_antal := v_antal + 1;
    end if;
  end loop;
  return v_antal;
end $$;

-- Rätta befintliga bolag: avtal/bank får rätt bevarandetid, och den tomma
-- KYC-mappen tas bort (PTL-materialet hör hemma i KYC-modulen).
update public.arkiv_mappar set gallringsregel = 'bfl_7ar'
where systemnyckel in ('avtal', 'bank_forsakring') and gallringsregel = 'ingen';

delete from public.arkiv_mappar m
where m.systemnyckel = 'uppdrag_kyc'
  and not exists (select 1 from arkiv_filer f where f.mapp_id = m.id)
  and not exists (select 1 from arkiv_mappar b where b.parent_id = m.id);
