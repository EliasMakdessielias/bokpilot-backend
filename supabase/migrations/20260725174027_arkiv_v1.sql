-- ARKIV v1 — dokumentarkiv med mappar, synlighet och kunduppladdning (2026-07-25)
-- Klientlogik: src/pages/Dokument.jsx + src/lib/arkiv.js. Spegel: supabase/arkiv.sql

create or replace function public.safe_uuid(t text) returns uuid
language plpgsql immutable as $$
begin
  return t::uuid;
exception when others then
  return null;
end $$;

create or replace function public.ar_arkiv_forvaltare(p_company uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
      select 1 from byra_medlemskap bm
      where bm.byra_bolag_id = p_company and bm.anvandare_id = auth.uid() and bm.aktiv)
    or exists (
      select 1 from byra_klient bk
      join byra_medlemskap bm on bm.byra_bolag_id = bk.byra_bolag_id
      where bk.klient_bolag_id = p_company
        and bm.anvandare_id = auth.uid() and bm.aktiv
        and (bm.roll = 'admin' or bk.kundansvarig_anvandare_id = auth.uid()))
    or (
      not exists (select 1 from byra_klient bk where bk.klient_bolag_id = p_company)
      and exists (
        select 1 from user_companies uc
        where uc.company_id = p_company and uc.user_id = auth.uid()
          and lower(coalesce(uc.role, '')) in ('admin', 'owner', 'agare', 'ägare')));
$$;

revoke all on function public.ar_arkiv_forvaltare(uuid) from public, anon;
grant execute on function public.ar_arkiv_forvaltare(uuid) to authenticated, service_role;

create table if not exists public.arkiv_mappar (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  parent_id uuid references public.arkiv_mappar(id) on delete restrict,
  namn text not null check (length(btrim(namn)) between 1 and 80),
  synlighet text not null default 'kund_skriv' check (synlighet in ('byra', 'kund', 'kund_skriv')),
  gallringsregel text not null default 'ingen'
    check (gallringsregel in ('ingen', 'bfl_7ar', 'ptl_5ar', 'gdpr_gallras')),
  systemnyckel text,
  sortering int not null default 100,
  skapad_av uuid default auth.uid(),
  created_at timestamptz not null default now()
);

create unique index if not exists arkiv_mappar_systemnyckel_uniq
  on public.arkiv_mappar (company_id, systemnyckel) where systemnyckel is not null;
create unique index if not exists arkiv_mappar_namn_uniq
  on public.arkiv_mappar (company_id, coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(btrim(namn)));
create index if not exists arkiv_mappar_traed_idx on public.arkiv_mappar (company_id, parent_id);

create or replace function public.arkiv_mapp_validera() returns trigger
language plpgsql set search_path = public as $$
declare v_id uuid; v_djup int := 0;
begin
  if new.parent_id is null then return new; end if;
  if new.parent_id = new.id then
    raise exception 'En mapp kan inte ligga i sig själv';
  end if;
  if exists (select 1 from arkiv_mappar p where p.id = new.parent_id and p.company_id <> new.company_id) then
    raise exception 'Mappen måste ligga i samma bolag som sin överordnade mapp';
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
  return new;
end $$;

drop trigger if exists arkiv_mapp_validera_trg on public.arkiv_mappar;
create trigger arkiv_mapp_validera_trg before insert or update on public.arkiv_mappar
  for each row execute function public.arkiv_mapp_validera();

alter table public.arkiv_mappar enable row level security;

drop policy if exists arkiv_mappar_select on public.arkiv_mappar;
create policy arkiv_mappar_select on public.arkiv_mappar for select to authenticated
  using (company_id in (select public.user_company_ids())
         and (synlighet <> 'byra' or public.ar_arkiv_forvaltare(company_id)));

drop policy if exists arkiv_mappar_insert on public.arkiv_mappar;
create policy arkiv_mappar_insert on public.arkiv_mappar for insert to authenticated
  with check (company_id in (select public.user_company_ids())
              and public.ar_arkiv_forvaltare(company_id));

drop policy if exists arkiv_mappar_update on public.arkiv_mappar;
create policy arkiv_mappar_update on public.arkiv_mappar for update to authenticated
  using (company_id in (select public.user_company_ids()) and public.ar_arkiv_forvaltare(company_id))
  with check (company_id in (select public.user_company_ids()) and public.ar_arkiv_forvaltare(company_id));

drop policy if exists arkiv_mappar_delete on public.arkiv_mappar;
create policy arkiv_mappar_delete on public.arkiv_mappar for delete to authenticated
  using (company_id in (select public.user_company_ids()) and public.ar_arkiv_forvaltare(company_id));

create table if not exists public.arkiv_filer (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  mapp_id uuid not null references public.arkiv_mappar(id) on delete restrict,
  document_id uuid references public.documents(id) on delete cascade,
  storage_path text,
  file_name text not null,
  mime_type text,
  file_size bigint,
  beskrivning text,
  kalla text not null default 'uppladdad'
    check (kalla in ('uppladdad', 'underlag', 'moms', 'agi', 'sie', 'arsredovisning', 'arkivexport')),
  uppladdad_av uuid default auth.uid(),
  raderad_at timestamptz,
  created_at timestamptz not null default now(),
  constraint arkiv_filer_kalla_ck check (document_id is not null or storage_path is not null)
);

create index if not exists arkiv_filer_mapp_idx on public.arkiv_filer (company_id, mapp_id, raderad_at);
create index if not exists arkiv_filer_document_idx on public.arkiv_filer (document_id) where document_id is not null;
create unique index if not exists arkiv_filer_doc_uniq
  on public.arkiv_filer (mapp_id, document_id) where document_id is not null and raderad_at is null;

alter table public.arkiv_filer enable row level security;

drop policy if exists arkiv_filer_select on public.arkiv_filer;
create policy arkiv_filer_select on public.arkiv_filer for select to authenticated
  using (exists (
    select 1 from public.arkiv_mappar m
    where m.id = arkiv_filer.mapp_id
      and m.company_id in (select public.user_company_ids())
      and (m.synlighet <> 'byra' or public.ar_arkiv_forvaltare(m.company_id))));

drop policy if exists arkiv_filer_insert on public.arkiv_filer;
create policy arkiv_filer_insert on public.arkiv_filer for insert to authenticated
  with check (exists (
    select 1 from public.arkiv_mappar m
    where m.id = arkiv_filer.mapp_id
      and m.company_id = arkiv_filer.company_id
      and m.company_id in (select public.user_company_ids())
      and (public.ar_arkiv_forvaltare(m.company_id) or m.synlighet = 'kund_skriv')));

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
      and (public.ar_arkiv_forvaltare(m.company_id) or m.synlighet = 'kund_skriv')));

drop policy if exists arkiv_filer_delete on public.arkiv_filer;
create policy arkiv_filer_delete on public.arkiv_filer for delete to authenticated
  using (exists (
    select 1 from public.arkiv_mappar m
    where m.id = arkiv_filer.mapp_id
      and m.company_id in (select public.user_company_ids())
      and (public.ar_arkiv_forvaltare(m.company_id) or arkiv_filer.uppladdad_av = auth.uid())));

insert into storage.buckets (id, name, public) values ('arkiv', 'arkiv', false)
  on conflict (id) do nothing;

drop policy if exists "arkiv_select" on storage.objects;
create policy "arkiv_select" on storage.objects for select to authenticated
  using (bucket_id = 'arkiv' and exists (
    select 1 from public.arkiv_mappar m
    where m.id = public.safe_uuid((storage.foldername(name))[2])
      and m.company_id::text = (storage.foldername(name))[1]
      and m.company_id in (select public.user_company_ids())
      and (m.synlighet <> 'byra' or public.ar_arkiv_forvaltare(m.company_id))));

drop policy if exists "arkiv_insert" on storage.objects;
create policy "arkiv_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'arkiv' and exists (
    select 1 from public.arkiv_mappar m
    where m.id = public.safe_uuid((storage.foldername(name))[2])
      and m.company_id::text = (storage.foldername(name))[1]
      and m.company_id in (select public.user_company_ids())
      and (public.ar_arkiv_forvaltare(m.company_id) or m.synlighet = 'kund_skriv')));

drop policy if exists "arkiv_delete" on storage.objects;
create policy "arkiv_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'arkiv' and exists (
    select 1 from public.arkiv_mappar m
    where m.id = public.safe_uuid((storage.foldername(name))[2])
      and m.company_id::text = (storage.foldername(name))[1]
      and m.company_id in (select public.user_company_ids())
      and (public.ar_arkiv_forvaltare(m.company_id) or storage.objects.owner = auth.uid())));

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
      ('avtal',           'Avtal',                      'kund_skriv', 'ingen',        30),
      ('bank_forsakring', 'Bank och försäkring',        'kund_skriv', 'ingen',        40),
      ('personal',        'Personal',                   'byra',       'gdpr_gallras', 50),
      ('uppdrag_kyc',     'Uppdrag och kundkännedom',   'byra',       'ptl_5ar',      60),
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

revoke all on function public.arkiv_skapa_standardmappar(uuid) from public, anon;
grant execute on function public.arkiv_skapa_standardmappar(uuid) to authenticated, service_role;
