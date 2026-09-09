-- Migration backup_underlag_v1 (2026-09-09): extern säkerhetskopia av Storage-underlagen.
-- Supabases databasbackuper omfattar inte Storage (etapp 9): filerna i bucketarna underlag,
-- arkiv, annual-report-exports och support har hittills saknat kopia. Edge-funktionen
-- backup-underlag (cron 02:30, service_role) kopierar nya och ändrade objekt till Azure Blob
-- Storage i Sweden Central (oföränderlig container, se docs/BACKUP-UNDERLAG.md) och bokför
-- varje kopia i manifestet backup_objekt. Aktiveras först när edge-secreten AZURE_BLOB_SAS_URL
-- finns — tills dess rapporterar funktionen fel till driftvakten (ett larm, sedan tyst).
-- Klientlogik: supabase/functions/backup-underlag/index.ts + _shared/backup.ts.

-- Manifest: en rad per kopierad objektversion (etag). Endast service_role.
create table if not exists public.backup_objekt (
  bucket text not null,
  sokvag text not null,
  etag text not null,
  storlek bigint,
  blobnamn text not null,
  kopierad_at timestamptz not null default now(),
  primary key (bucket, sokvag, etag)
);
comment on table public.backup_objekt is 'Manifest över Storage-objekt som kopierats till det externa arkivet (Azure Blob, Sweden Central): en rad per objektversion (etag) med blobnamnet i arkivet. Endast service_role.';
alter table public.backup_objekt enable row level security;
revoke all on table public.backup_objekt from public, anon, authenticated;
grant all on table public.backup_objekt to service_role;
create index if not exists backup_objekt_kopierad_idx on public.backup_objekt (kopierad_at desc);

-- Objekt vars aktuella etag saknar kopia, äldst först. tidigare_kopior styr blobnamnet
-- (en ändrad fil får ett nytt blobnamn eftersom arkivet aldrig skriver över).
create or replace function public.backup_att_kopiera(p_max integer default 100)
returns table (bucket text, sokvag text, storlek bigint, mimetyp text, etag text, andrad timestamptz, tidigare_kopior integer)
language sql
security definer
set search_path = 'public'
as $$
  select l.bucket, l.sokvag, l.storlek, l.mimetyp, l.etag, l.andrad,
         (select count(*)::int from public.backup_objekt b where b.bucket = l.bucket and b.sokvag = l.sokvag) as tidigare_kopior
  from public.lista_lagringsobjekt() l
  where not exists (
    select 1 from public.backup_objekt b
    where b.bucket = l.bucket and b.sokvag = l.sokvag and b.etag = l.etag)
  order by l.andrad asc nulls first
  limit greatest(1, least(coalesce(p_max, 100), 500));
$$;
revoke all on function public.backup_att_kopiera(integer) from public, anon, authenticated;
grant execute on function public.backup_att_kopiera(integer) to service_role;

-- Läsbar status för drift och revision (bara antal och tidpunkter, inga sökvägar).
create or replace function public.backup_status()
returns jsonb
language sql
stable
security definer
set search_path = 'public'
as $$
  select jsonb_build_object(
    'objekt_i_storage', (select count(*) from public.lista_lagringsobjekt()),
    'saknar_kopia', (select count(*) from public.lista_lagringsobjekt() l
                       where not exists (select 1 from public.backup_objekt b
                                         where b.bucket = l.bucket and b.sokvag = l.sokvag and b.etag = l.etag)),
    'kopior_totalt', (select count(*) from public.backup_objekt),
    'senaste_kopia', (select max(kopierad_at) from public.backup_objekt)
  );
$$;
revoke all on function public.backup_status() from public, anon;
grant execute on function public.backup_status() to authenticated, service_role;

-- Cron-nyckeln som edge-funktionen kräver (läses bara av service_role; interna_nycklar har
-- RLS utan policies). Skapas slumpmässigt här och lämnar aldrig databasen utom i cron-headern.
insert into public.interna_nycklar (namn, varde)
values ('backup_cron', encode(extensions.gen_random_bytes(24), 'hex'))
on conflict (namn) do nothing;

-- Nattjobbet 02:30 (före lagringsintegriteten 03:25 och driftvakten 03:50). Publishable-
-- nyckeln är offentlig (ligger i frontend-bundeln); åtkomsten styrs av x-backup-cron-secret.
do $$
begin
  perform cron.unschedule('backup-underlag-natt');
exception when others then null;  -- fanns inte — ok
end $$;

do $$
begin
  perform cron.schedule('backup-underlag-natt', '30 2 * * *', $cron$
  select net.http_post(
    url := 'https://vzeqvapebkbapwflozbi.supabase.co/functions/v1/backup-underlag',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_vyR02gFIVZH9zY7RBRvX7Q_mBogzd00',
      'apikey', 'sb_publishable_vyR02gFIVZH9zY7RBRvX7Q_mBogzd00',
      'x-backup-cron-secret', (select varde from public.interna_nycklar where namn = 'backup_cron')
    ),
    body := '{"cron": true}'::jsonb
  );
  $cron$);
exception when others then
  raise notice 'pg_cron ej tillgänglig — schemalägg backup-underlag-natt manuellt: %', sqlerrm;
end $$;

-- Driftvakten: cronjobbet (tystnad = fel) och funktionens egen rapportering (fel = kopia
-- saknas eller AZURE_BLOB_SAS_URL saknas/duger inte). Baslinjen lämnas tom så att första
-- nattens verkliga status larmas en gång.
insert into public.driftkomponenter (namn, typ, max_tyst_timmar, max_fel_i_rad, beskrivning) values
  ('backup-underlag-natt', 'cron', 36, 1, 'Extern säkerhetskopia av Storage-underlagen till Azure Blob (Sweden Central) 02:30 — cronjobbet'),
  ('backup-underlag', 'handelsestyrd', null, 1, 'Backupjobbets egen rapportering: FEL = objekt kunde inte kopieras eller AZURE_BLOB_SAS_URL saknas/duger inte')
on conflict (namn) do nothing;
