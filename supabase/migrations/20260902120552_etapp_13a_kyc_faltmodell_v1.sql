-- Etapp 13a: kundkännedomen får den datamodell penningtvättslagen kräver.
--
-- kyc_assessments registrerade ATT en kontroll skett (tidsstämplar och booleaner),
-- inte VAD den bestod av. Ordet "huvudman" förekom i hela schemat bara som en
-- tidsstämpelkolumn. Vid tillsyn kan byrån då inte visa upp de handlingar
-- 5 kap. 3 § PTL kräver att den bevarar i fem år — eftersom de aldrig samlats in.
-- 3 kap. 8 §: verklig huvudmans identitet ska kontrolleras, vilket förutsätter att
-- man vet vem det är. Den uppgiften saknades i modellen.

-- Krävs för sammansatta FK:er från barn-tabellerna (id + company_id ihop).
alter table public.kyc_assessments
  add constraint kyc_assessments_id_company_uniq unique (id, company_id);

alter table public.kyc_assessments
  add column if not exists identitetshandling_typ text
    check (identitetshandling_typ is null or identitetshandling_typ in
           ('pass','nationellt_id','korkort','bankid','annat')),
  add column if not exists identitetshandling_referens text,
  add column if not exists identitetshandling_utfardare text,
  add column if not exists identitetshandling_giltig_till date,
  add column if not exists sanktionslista_kalla text,
  add column if not exists sanktionslista_datum date,
  add column if not exists pep_kalla text,
  add column if not exists pep_datum date;

comment on column public.kyc_assessments.identitetshandling_referens is
  'Handlingens nummer/referens. Kopia arkiveras som kyc_bilagor med typ identitetshandling.';
comment on column public.kyc_assessments.sanktionslista_kalla is
  'Vilken lista som slagits (t.ex. EU:s konsoliderade sanktionslista, OFAC) och per vilket datum.';

-- Verklig huvudman: en rad per person. Personnummer ELLER födelsedatum krävs.
create table if not exists public.kyc_huvudman (
  id              uuid primary key default gen_random_uuid(),
  kyc_id          uuid not null,
  company_id      uuid not null,
  namn            text not null,
  personnummer    text,
  fodelsedatum    date,
  agarandel       numeric(5,2) check (agarandel is null or (agarandel >= 0 and agarandel <= 100)),
  kontrollsatt    text not null check (kontrollsatt in
                    ('bolagsverket','registerutdrag','agarforteckning','intyg','annat')),
  kalla           text,
  kontrollerad_at timestamptz not null default now(),
  kontrollerad_av uuid default auth.uid(),
  created_at      timestamptz not null default now(),
  constraint kyc_huvudman_kyc_fkey
    foreign key (kyc_id, company_id) references public.kyc_assessments(id, company_id) on delete cascade,
  constraint kyc_huvudman_identitet_chk check (personnummer is not null or fodelsedatum is not null)
);
create index if not exists idx_kyc_huvudman_kyc_id on public.kyc_huvudman (kyc_id);
create index if not exists idx_kyc_huvudman_company_id on public.kyc_huvudman (company_id);

-- Bilagor: registerutdrag, kopia av identitetshandling, utskrift av sanktionskontroll.
-- Filerna ligger i den privata bucketen 'kyc' (etapp 13b), sökväg <company_id>/<kyc_id>/<uuid>.<ext>.
create table if not exists public.kyc_bilagor (
  id            uuid primary key default gen_random_uuid(),
  kyc_id        uuid not null,
  company_id    uuid not null,
  typ           text not null check (typ in
                  ('identitetshandling','huvudman','registerutdrag','sanktionskontroll','pep_kontroll','ovrigt')),
  storage_path  text not null unique,
  file_name     text not null,
  mime_type     text,
  file_size     bigint,
  beskrivning   text,
  uppladdad_av  uuid default auth.uid(),
  created_at    timestamptz not null default now(),
  constraint kyc_bilagor_kyc_fkey
    foreign key (kyc_id, company_id) references public.kyc_assessments(id, company_id) on delete cascade
);
create index if not exists idx_kyc_bilagor_kyc_id on public.kyc_bilagor (kyc_id);
create index if not exists idx_kyc_bilagor_company_id on public.kyc_bilagor (company_id);

-- RLS: samma scope som kyc_assessments (byråns klientbolag). Ingen DELETE-policy —
-- underlaget ska bevaras i fem år (5 kap. 3 § PTL).
alter table public.kyc_huvudman enable row level security;
alter table public.kyc_bilagor  enable row level security;

create policy kyc_huvudman_select on public.kyc_huvudman for select to authenticated
  using (company_id in (select public.mina_klientbolag()));
create policy kyc_huvudman_insert on public.kyc_huvudman for insert to authenticated
  with check (company_id in (select public.mina_klientbolag()));
create policy kyc_huvudman_update on public.kyc_huvudman for update to authenticated
  using (company_id in (select public.mina_klientbolag()))
  with check (company_id in (select public.mina_klientbolag()));

create policy kyc_bilagor_select on public.kyc_bilagor for select to authenticated
  using (company_id in (select public.mina_klientbolag()));
create policy kyc_bilagor_insert on public.kyc_bilagor for insert to authenticated
  with check (company_id in (select public.mina_klientbolag()));

revoke all on table public.kyc_huvudman, public.kyc_bilagor from public, anon;
grant select, insert, update on table public.kyc_huvudman to authenticated;
grant select, insert         on table public.kyc_bilagor  to authenticated;

-- Behandlingshistorik. kyc_assessments var fritt redigerbar utan spår (policyn
-- kyc_update_byra); nu loggas varje ändring med ändrade kolumner, aldrig värden.
drop trigger if exists trg_audit_personuppgifter on public.kyc_assessments;
create trigger trg_audit_personuppgifter
  after insert or update or delete on public.kyc_assessments
  for each row execute function public.audit_personuppgifter();
create trigger trg_audit_personuppgifter
  after insert or update or delete on public.kyc_huvudman
  for each row execute function public.audit_personuppgifter();
create trigger trg_audit_personuppgifter
  after insert or update or delete on public.kyc_bilagor
  for each row execute function public.audit_personuppgifter();
