-- Rättelse i etapp 9.
--
-- 1) record_worker_health rensar last_error vid lyckad körning ("rensa fel vid
--    lyckad körning" i dess egen kod). Notisen om föräldralösa filer skickades
--    därför in för att omedelbart kastas bort — död kod som ser ut att göra något.
--
-- 2) Föräldralösa filer behöver ändå ett spår. De larmas INTE, eftersom det i dag
--    finns 21 kända sådana och ett dagligt larm om ett statiskt tillstånd bara
--    tränar bort uppmärksamheten. I stället skrivs en rad i system_error_log
--    enbart när antalet ÄNDRAS — det är förändringen som är signalen.
--
--    Raden skrivs direkt till tabellen och INTE via report_system_error, eftersom
--    den funktionen alltid eskalerar till en 'urgent'-notis till samtliga
--    plattformsadmins oavsett angiven severity.
create or replace function public.cron_lagringsintegritet()
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_res jsonb; n_saknade int; n_foraldralosa int; n_forra int;
begin
  v_res := public.kontrollera_lagringsintegritet();
  n_saknade      := (v_res #>> '{saknade_filer,antal}')::int;
  n_foraldralosa := (v_res #>> '{foraldralosa_filer,antal}')::int;

  -- Farliga riktningen: databasrad utan fil = räkenskapsinformation kan vara borta.
  if n_saknade > 0 then
    perform public.report_system_error(
      'lagringsintegritet',
      format('%s underlag saknas i Storage men finns kvar i databasen. Räkenskapsinformation kan ha gått förlorad (BFL 7 kap. 2 §).', n_saknade),
      null, 'critical', 'STORAGE_MISSING_FILES', v_res, now());
  end if;

  -- Ofarliga riktningen: fil utan databasrad. Spår endast vid förändring.
  select (metadata #>> '{foraldralosa_filer,antal}')::int into n_forra
  from public.system_error_log
  where component = 'lagringsintegritet' and error_code = 'STORAGE_ORPHANS'
  order by occurred_at desc limit 1;

  if n_foraldralosa > 0 and n_foraldralosa is distinct from n_forra then
    insert into public.system_error_log(component, message, severity, error_code, metadata, occurred_at)
    values ('lagringsintegritet',
            format('Antal föräldralösa filer i Storage ändrades från %s till %s. Ingen räkenskapsinformation förlorad, men filer utan databasrad bör gallras (GDPR art. 5.1 c och e).',
                   coalesce(n_forra::text, 'okänt'), n_foraldralosa),
            'info', 'STORAGE_ORPHANS', v_res, now());
  end if;

  perform public.record_worker_health('lagringsintegritet', true);
exception when others then
  perform public.record_worker_health('lagringsintegritet', false, left(sqlerrm, 300));
  raise;
end $fn$;

revoke execute on function public.cron_lagringsintegritet() from public, anon, authenticated;
