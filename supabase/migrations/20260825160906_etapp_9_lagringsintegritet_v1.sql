-- Etapp 9: avstämning mellan databas och Storage.
--
-- Bakgrund: Supabases databasbackuper omfattar INTE objekt i Storage — databasen
-- innehåller bara metadata (documents.storage_path, arkiv_filer.storage_path).
-- Den farliga felmoden är därför tyst: en återställning ger en databas som ser
-- komplett ut — verifikationer, konteringsrader, dokumentrader — medan varje
-- storage_path pekar på en fil som inte finns. Ingenting i systemet upptäcker det.
--
-- Den här funktionen jämför båda hållen:
--   SAKNADE FILER   - databasrad finns, filen är borta. Räkenskapsinformation
--                     förlorad. Larmas som critical.
--   FÖRÄLDRALÖSA    - filen finns, ingen databasrad pekar på den. Ingen förlust,
--                     men en lagringsminimeringsfråga (GDPR art. 5.1 c och e).
--                     Rapporteras utan larm.

create or replace function public.kontrollera_lagringsintegritet()
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_saknade jsonb; v_foraldralosa jsonb;
  n_saknade int; n_foraldralosa int;
begin
  -- 1) Databasrader vars fil saknas i Storage
  select coalesce(jsonb_agg(x), '[]'::jsonb), count(*)
    into v_saknade, n_saknade
  from (
    select 'documents' as tabell, d.id::text as rad_id, d.company_id::text as bolag,
           d.storage_path, d.verifikation_id is not null as ar_bokfort
    from public.documents d
    where d.storage_path is not null
      and not exists (select 1 from storage.objects o
                      where o.bucket_id = 'underlag' and o.name = d.storage_path)
    union all
    select 'arkiv_filer', f.id::text, f.company_id::text, f.storage_path, false
    from public.arkiv_filer f
    where f.storage_path is not null
      and f.raderad_at is null
      and not exists (select 1 from storage.objects o
                      where o.bucket_id = 'arkiv' and o.name = f.storage_path)
    limit 100
  ) x;

  -- 2) Filer i Storage utan databasrad
  select coalesce(jsonb_agg(y), '[]'::jsonb), count(*)
    into v_foraldralosa, n_foraldralosa
  from (
    select o.bucket_id, o.name as storage_path,
           (storage.foldername(o.name))[1] as bolagsmapp,
           exists (select 1 from public.companies c
                   where c.id::text = (storage.foldername(o.name))[1]) as bolaget_finns
    from storage.objects o
    where o.bucket_id = 'underlag'
      and not exists (select 1 from public.documents d where d.storage_path = o.name)
    union all
    select o.bucket_id, o.name, (storage.foldername(o.name))[1],
           exists (select 1 from public.companies c where c.id::text = (storage.foldername(o.name))[1])
    from storage.objects o
    where o.bucket_id = 'arkiv'
      and not exists (select 1 from public.arkiv_filer f where f.storage_path = o.name)
    limit 100
  ) y;

  return jsonb_build_object(
    'kontrollerad_at', now(),
    'saknade_filer', jsonb_build_object('antal', n_saknade, 'poster', v_saknade),
    'foraldralosa_filer', jsonb_build_object('antal', n_foraldralosa, 'poster', v_foraldralosa),
    'summering', jsonb_build_object(
      'documents', (select count(*) from public.documents where storage_path is not null),
      'underlag_objekt', (select count(*) from storage.objects where bucket_id = 'underlag'),
      'arkiv_filer', (select count(*) from public.arkiv_filer where storage_path is not null and raderad_at is null),
      'arkiv_objekt', (select count(*) from storage.objects where bucket_id = 'arkiv')));
end $fn$;

-- Nattlig körning. Larmar bara åt det farliga hållet, och registrerar hjärtslag
-- så att en funktion som slutar köra inte kan se ut som en frisk (jfr att
-- stripe-webhook och folio-ocr varit trasiga i veckor utan att någon märkt det).
create or replace function public.cron_lagringsintegritet()
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare v_res jsonb; n_saknade int; n_foraldralosa int;
begin
  v_res := public.kontrollera_lagringsintegritet();
  n_saknade := (v_res #>> '{saknade_filer,antal}')::int;
  n_foraldralosa := (v_res #>> '{foraldralosa_filer,antal}')::int;

  if n_saknade > 0 then
    perform public.report_system_error(
      'lagringsintegritet',
      format('%s underlag saknas i Storage men finns kvar i databasen. Räkenskapsinformation kan ha gått förlorad (BFL 7 kap. 2 §).', n_saknade),
      null, 'critical', 'STORAGE_MISSING_FILES',
      v_res, now());
  end if;

  perform public.record_worker_health('lagringsintegritet', true,
    case when n_foraldralosa > 0
         then format('%s föräldralösa filer utan databasrad', n_foraldralosa)
         else null end);
exception when others then
  perform public.record_worker_health('lagringsintegritet', false, left(sqlerrm, 300));
  raise;
end $fn$;

revoke execute on function public.kontrollera_lagringsintegritet() from public, anon;
revoke execute on function public.cron_lagringsintegritet() from public, anon, authenticated;
grant execute on function public.kontrollera_lagringsintegritet() to authenticated;

select cron.schedule('lagringsintegritet-natt', '25 3 * * *',
                     'select public.cron_lagringsintegritet()');
