-- Etapp 10: underlag för säkerhetskopiering utanför Supabase.
--
-- Storage-API:ts list() är inte rekursiv — undermappar måste traverseras manuellt,
-- vilket gör en extern backup onödigt bräcklig. Den här funktionen läser i stället
-- storage.objects direkt och returnerar hela beståndet i ett svep.
--
-- `shimo-audio` utesluts: den bucketen tillhör ett annat projekt (böneappen), är
-- publik, och står för 40 MB av 46. Backupen ska omfatta räkenskapsinformation och
-- klientdata, inget annat.
create or replace function public.lista_lagringsobjekt()
returns table (
  bucket text,
  sokvag text,
  storlek bigint,
  mimetyp text,
  etag text,
  andrad timestamptz
)
language sql
security definer
set search_path = public
as $fn$
  select o.bucket_id::text,
         o.name::text,
         (o.metadata->>'size')::bigint,
         o.metadata->>'mimetype',
         coalesce(o.metadata->>'eTag', o.version::text),
         o.updated_at
  from storage.objects o
  where o.bucket_id in ('underlag', 'arkiv', 'annual-report-exports', 'support')
  order by o.bucket_id, o.name;
$fn$;

-- Endast service_role (backupskriptet). Varken anon eller authenticated behöver
-- se hela beståndet tvärs bolagsgränser.
revoke execute on function public.lista_lagringsobjekt() from public, anon, authenticated;
