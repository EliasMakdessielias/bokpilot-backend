-- ARKIV v1b — granskningsfixar (2026-07-25). Spegel: supabase/arkiv_v1b.sql
-- Åtgärdar fynden från domängranskningen av arkiv_v1: synlighet ärvs inte (H1),
-- FK RESTRICT blockerade bolagsradering (H3), valideringstrigger utan definer (M1),
-- document_id/storage_path utan bolagskoppling (M2/L5), avslutade byråuppdrag (M5),
-- write-lock saknades (M6), bucketen utan gränser (M8), radering utan spår (M4),
-- klientsatt uppladdad_av (L2), delete-policy utan synlighetsguard (L3).

-- ── M5: avslutade byråuppdrag ger inte längre förvaltarskap, och bolagets egen
--        ägare låses inte ute när uppdraget avslutats (byra_klient raderas aldrig).
create or replace function public.ar_arkiv_forvaltare(p_company uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
      select 1 from byra_medlemskap bm
      where bm.byra_bolag_id = p_company and bm.anvandare_id = auth.uid() and bm.aktiv)
    or exists (
      select 1 from byra_klient bk
      join byra_medlemskap bm on bm.byra_bolag_id = bk.byra_bolag_id
      where bk.klient_bolag_id = p_company and bk.status = 'aktiv'
        and bm.anvandare_id = auth.uid() and bm.aktiv
        and (bm.roll = 'admin' or bk.kundansvarig_anvandare_id = auth.uid()))
    or (
      not exists (select 1 from byra_klient bk where bk.klient_bolag_id = p_company and bk.status = 'aktiv')
      and exists (
        select 1 from user_companies uc
        where uc.company_id = p_company and uc.user_id = auth.uid()
          and lower(coalesce(uc.role, '')) in ('admin', 'owner', 'agare', 'ägare')));
$$;

-- ── H3: RESTRICT kan inte skjutas upp och blockerade kaskadraderingen av ett bolag
--        (GDPR-raderingen i edge-funktionen admin misslyckades tyst). Regeln
--        "töm mappen först" hör hemma i en trigger, inte i en främmande nyckel.
alter table public.arkiv_filer drop constraint if exists arkiv_filer_mapp_id_fkey;
alter table public.arkiv_filer add constraint arkiv_filer_mapp_id_fkey
  foreign key (mapp_id) references public.arkiv_mappar(id) on delete cascade;

alter table public.arkiv_mappar drop constraint if exists arkiv_mappar_parent_id_fkey;
alter table public.arkiv_mappar add constraint arkiv_mappar_parent_id_fkey
  foreign key (parent_id) references public.arkiv_mappar(id) on delete cascade;

-- Töm-först-regeln: räknar ALLA filer (även mjukraderade i papperskorgen) och
-- undermappar. Släpper igenom när bolaget självt håller på att raderas — då är
-- companies-raden redan borta i samma transaktion och allt ska följa med ut.
create or replace function public.arkiv_mapp_fore_radering() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from companies where id = old.company_id) then
    return old;
  end if;
  if exists (select 1 from arkiv_filer f where f.mapp_id = old.id) then
    raise exception 'Mappen innehåller dokument (även i papperskorgen) – töm den först';
  end if;
  if exists (select 1 from arkiv_mappar m where m.parent_id = old.id) then
    raise exception 'Mappen har undermappar – ta bort dem först';
  end if;
  return old;
end $$;

drop trigger if exists arkiv_mapp_fore_radering_trg on public.arkiv_mappar;
create trigger arkiv_mapp_fore_radering_trg before delete on public.arkiv_mappar
  for each row execute function public.arkiv_mapp_fore_radering();

-- ── H1 + M1: synlighet ärvs nedåt, och valideringen körs som definer så att den
--        ser mappar i andra bolag (annars filtrerade RLS bort dem och kontrollen
--        blev verkningslös).
create or replace function public.arkiv_mapp_validera() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_djup int := 0; v_foralder_synlighet text;
begin
  if new.parent_id is not null then
    if new.parent_id = new.id then
      raise exception 'En mapp kan inte ligga i sig själv';
    end if;
    if not exists (select 1 from arkiv_mappar p where p.id = new.parent_id and p.company_id = new.company_id) then
      raise exception 'Mappen måste ligga i samma bolag som sin överordnade mapp';
    end if;
    -- En undermapp får ALDRIG vara synlig för kunden när föräldern är byråintern.
    select synlighet into v_foralder_synlighet from arkiv_mappar where id = new.parent_id;
    if v_foralder_synlighet = 'byra' and new.synlighet <> 'byra' then
      raise exception 'Mappen ligger i en byråintern mapp och kan därför bara vara synlig för byrån';
    end if;
    v_id := new.parent_id;
    while v_id is not null loop
      v_djup := v_djup + 1;
      if v_id = new.id then
        raise exception 'Mappen kan inte flyttas in i sin egen undermapp';
      end if;
      if v_djup > 10 then
        raise exception 'För djup mappstruktur (max 10 nivåer)';
      end if;
      select parent_id into v_id from arkiv_mappar where id = v_id;
    end loop;
  end if;
  -- Att stänga en mapp för kunden får inte lämna kvar öppna undermappar.
  if tg_op = 'UPDATE' and new.synlighet = 'byra' and old.synlighet <> 'byra'
     and exists (select 1 from arkiv_mappar m where m.parent_id = new.id and m.synlighet <> 'byra') then
    raise exception 'Mappen har undermappar som är synliga för kunden – ändra dem först';
  end if;
  return new;
end $$;

-- ── L2: uppladdad_av och created_at sätts av servern, inte av anroparen.
create or replace function public.arkiv_fil_fore_insert() returns trigger
language plpgsql set search_path = public as $$
begin
  if auth.uid() is not null then
    new.uppladdad_av := auth.uid();
    new.created_at := now();
  end if;
  return new;
end $$;

drop trigger if exists arkiv_fil_fore_insert_trg on public.arkiv_filer;
create trigger arkiv_fil_fore_insert_trg before insert on public.arkiv_filer
  for each row execute function public.arkiv_fil_fore_insert();

-- ── M4: spårbarhet vid radering (mapparna bfl_7ar/ptl_5ar kräver det).
alter table public.arkiv_filer add column if not exists raderad_av uuid;

create or replace function public.arkiv_fil_logga_radering() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_rad record; v_action text;
begin
  if tg_op = 'DELETE' then
    v_rad := old; v_action := 'radera_permanent';
  else
    if new.raderad_at is null or old.raderad_at is not null then return new; end if;
    v_rad := new; v_action := 'radera';
    new.raderad_av := auth.uid();
  end if;
  insert into audit_log (company_id, entity, entity_ref, action, old_data, changed_by, source)
  values (v_rad.company_id, 'arkiv_fil', v_rad.id::text, v_action,
          jsonb_build_object('file_name', v_rad.file_name, 'mapp_id', v_rad.mapp_id,
                             'document_id', v_rad.document_id, 'kalla', v_rad.kalla),
          auth.uid(), 'ui');
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;

drop trigger if exists arkiv_fil_logga_mjukradering_trg on public.arkiv_filer;
create trigger arkiv_fil_logga_mjukradering_trg before update on public.arkiv_filer
  for each row execute function public.arkiv_fil_logga_radering();

drop trigger if exists arkiv_fil_logga_radering_trg on public.arkiv_filer;
create trigger arkiv_fil_logga_radering_trg after delete on public.arkiv_filer
  for each row execute function public.arkiv_fil_logga_radering();

-- ── L5: storage_path måste ligga under bolagets och mappens egen prefix, annars
--        kunde en permanent radering ta bort en fil i ett annat bolags arkiv.
alter table public.arkiv_filer drop constraint if exists arkiv_filer_sokvag_ck;
alter table public.arkiv_filer add constraint arkiv_filer_sokvag_ck
  check (storage_path is null or storage_path like company_id::text || '/' || mapp_id::text || '/%');

-- ── M2: arkivposten måste peka på ett underlag i SAMMA bolag.
drop policy if exists arkiv_filer_insert on public.arkiv_filer;
create policy arkiv_filer_insert on public.arkiv_filer for insert to authenticated
  with check (exists (
      select 1 from public.arkiv_mappar m
      where m.id = arkiv_filer.mapp_id
        and m.company_id = arkiv_filer.company_id
        and m.company_id in (select public.user_company_ids())
        and (public.ar_arkiv_forvaltare(m.company_id) or m.synlighet = 'kund_skriv'))
    and (document_id is null or exists (
      select 1 from public.documents d
      where d.id = arkiv_filer.document_id and d.company_id = arkiv_filer.company_id)));

drop policy if exists arkiv_filer_update on public.arkiv_filer;
create policy arkiv_filer_update on public.arkiv_filer for update to authenticated
  using (exists (
    select 1 from public.arkiv_mappar m
    where m.id = arkiv_filer.mapp_id
      and m.company_id in (select public.user_company_ids())
      and (m.synlighet <> 'byra' or public.ar_arkiv_forvaltare(m.company_id))
      and (public.ar_arkiv_forvaltare(m.company_id) or arkiv_filer.uppladdad_av = auth.uid())))
  with check (exists (
      select 1 from public.arkiv_mappar m
      where m.id = arkiv_filer.mapp_id
        and m.company_id = arkiv_filer.company_id
        and m.company_id in (select public.user_company_ids())
        and (public.ar_arkiv_forvaltare(m.company_id) or m.synlighet = 'kund_skriv'))
    and (document_id is null or exists (
      select 1 from public.documents d
      where d.id = arkiv_filer.document_id and d.company_id = arkiv_filer.company_id)));

-- ── L3: delete-policyerna får samma synlighetsguard som select/update, så skyddet
--        inte enbart vilar på att arkiv_mappar-RLS filtrerar inuti subqueryn.
drop policy if exists arkiv_filer_delete on public.arkiv_filer;
create policy arkiv_filer_delete on public.arkiv_filer for delete to authenticated
  using (exists (
    select 1 from public.arkiv_mappar m
    where m.id = arkiv_filer.mapp_id
      and m.company_id in (select public.user_company_ids())
      and (m.synlighet <> 'byra' or public.ar_arkiv_forvaltare(m.company_id))
      and (public.ar_arkiv_forvaltare(m.company_id) or arkiv_filer.uppladdad_av = auth.uid())));

drop policy if exists "arkiv_delete" on storage.objects;
create policy "arkiv_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'arkiv' and exists (
    select 1 from public.arkiv_mappar m
    where m.id = public.safe_uuid((storage.foldername(name))[2])
      and m.company_id::text = (storage.foldername(name))[1]
      and m.company_id in (select public.user_company_ids())
      and (m.synlighet <> 'byra' or public.ar_arkiv_forvaltare(m.company_id))
      and (public.ar_arkiv_forvaltare(m.company_id) or storage.objects.owner = auth.uid())));

-- ── M6: pausat/blockerat bolag ska inte kunna fylla arkivet heller.
drop trigger if exists trg_write_lock on public.arkiv_mappar;
create trigger trg_write_lock before insert or update or delete on public.arkiv_mappar
  for each row execute function public.enforce_company_write_lock();

drop trigger if exists trg_write_lock on public.arkiv_filer;
create trigger trg_write_lock before insert or update or delete on public.arkiv_filer
  for each row execute function public.enforce_company_write_lock();

drop policy if exists "arkiv_insert" on storage.objects;
create policy "arkiv_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'arkiv' and exists (
    select 1 from public.arkiv_mappar m
    where m.id = public.safe_uuid((storage.foldername(name))[2])
      and m.company_id::text = (storage.foldername(name))[1]
      and m.company_id in (select public.user_company_ids())
      and public.can_company_write(m.company_id)
      and (public.ar_arkiv_forvaltare(m.company_id) or m.synlighet = 'kund_skriv')));

-- ── M8: gränser på bucketen (underlag har dem sedan tidigare). Kontors- och
--        deklarationsformat tillkommer; text/html blockeras medvetet.
update storage.buckets set
  file_size_limit = 52428800,
  allowed_mime_types = array[
    'application/pdf',
    'image/png','image/jpeg','image/jpg','image/webp','image/gif','image/heic','image/heif',
    'image/svg+xml','image/bmp','image/avif','image/tiff',
    'application/xml','text/xml','text/plain','text/csv','application/zip',
    'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint','application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/octet-stream'
  ]
where id = 'arkiv';

-- ── H2: systemgenererade filer (momsdeklaration, AGI, SIE, årsredovisning) ska
--        arkiveras oavsett om den inloggade är förvaltare eller kundanvändare —
--        de är inte kunduppladdningar utan appens egna handlingar. Definer-RPC
--        med medlemskapskontroll; skriver aldrig i en mapp utanför bolaget.
create or replace function public.arkiv_arkivera_systemfil(
  p_company uuid, p_systemnyckel text, p_storage_path text, p_file_name text,
  p_mime_type text, p_file_size bigint, p_kalla text, p_beskrivning text, p_hoppa_om_finns boolean default false)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_mapp uuid; v_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from user_companies where user_id = auth.uid() and company_id = p_company) then
    raise exception 'forbidden';
  end if;
  if not public.can_company_write(p_company) then
    raise exception 'Tjänsten är pausad för det här företaget';
  end if;
  select id into v_mapp from arkiv_mappar where company_id = p_company and systemnyckel = p_systemnyckel;
  if v_mapp is null then
    perform public.arkiv_skapa_standardmappar(p_company);
    select id into v_mapp from arkiv_mappar where company_id = p_company and systemnyckel = p_systemnyckel;
  end if;
  if v_mapp is null then raise exception 'Mappen % saknas', p_systemnyckel; end if;
  if p_storage_path is null or p_storage_path not like p_company::text || '/' || v_mapp::text || '/%' then
    raise exception 'Ogiltig sökväg för arkivfilen';
  end if;
  if p_hoppa_om_finns then
    select id into v_id from arkiv_filer
    where mapp_id = v_mapp and file_name = p_file_name and raderad_at is null limit 1;
    if v_id is not null then return v_id; end if;
  end if;
  insert into arkiv_filer (company_id, mapp_id, storage_path, file_name, mime_type, file_size, kalla, beskrivning)
  values (p_company, v_mapp, p_storage_path, p_file_name, p_mime_type, p_file_size,
          coalesce(p_kalla, 'uppladdad'), p_beskrivning)
  returning id into v_id;
  return v_id;
end $$;

revoke all on function public.arkiv_arkivera_systemfil(uuid, text, text, text, text, bigint, text, text, boolean) from public, anon;
grant execute on function public.arkiv_arkivera_systemfil(uuid, text, text, text, text, bigint, text, text, boolean) to authenticated, service_role;

-- Systemfilen måste också kunna LADDAS UPP till bucketen av en kundanvändare i en
-- 'kund'-mapp. Uppladdningen sker före insert:en ovan, därför en egen väg: mappar
-- med systemnyckel tillåter uppladdning för alla bolagsmedlemmar.
drop policy if exists "arkiv_insert" on storage.objects;
create policy "arkiv_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'arkiv' and exists (
    select 1 from public.arkiv_mappar m
    where m.id = public.safe_uuid((storage.foldername(name))[2])
      and m.company_id::text = (storage.foldername(name))[1]
      and m.company_id in (select public.user_company_ids())
      and public.can_company_write(m.company_id)
      and (public.ar_arkiv_forvaltare(m.company_id)
           or m.synlighet = 'kund_skriv'
           or (m.systemnyckel is not null and m.synlighet <> 'byra'))));
