-- Etapp 11b: driftstatus() bedömer bara AVSLUTADE körningar.
--
-- Fyndet (2026-09-09): sedan driftvakten registrerades i sitt eget register (etapp 14b)
-- har den varje natt dömt sig själv som FEL med detaljen "Senaste körning: running", och
-- kivra-sync-10min har växlat OK -> FEL -> OK sex gånger på tolv dygn (29/8, 31/8, 1/9,
-- 5/9, 6/9, 9/9). Orsak: lateral-frågan väljer senaste status med
-- array_agg(... order by end_time desc). En pågående körning har end_time = null, och null
-- sorteras FÖRST vid desc — så när vakten kör 03:50 ser den sin egen rad (running) och
-- kivra-syncens rad som startar samma sekund (running/sending) som "senaste körning".
-- Varje sådant larm går som urgent-notis till samtliga plattformsadmins — precis den sortens
-- tomma larm som vakten byggdes för att slippa.
--
-- Rättning: bara körningar med end_time satt räknas. Ett jobb som hänger fångas i stället
-- av max_tyst_timmar (TYST) när dess senaste lyckade körning blir för gammal.
-- Baslinjen för driftkontroll-natt sätts till OK — den var FEL enbart på grund av felet,
-- och vakten ska larma om förändringar, inte om nuläget (samma princip som etapp 11 och 14b).
-- Rättigheterna är oförändrade (create or replace behåller ACL) men upprepas för tydlighet.

create or replace function public.driftstatus()
returns table (
  namn text, typ text, status text, detalj text, senast timestamptz
)
language sql
security definer
set search_path = public
as $$
  -- Schemalagda jobb
  select k.namn, k.typ,
         case
           when j.jobid is null then 'SAKNAS'
           when not j.active   then 'AVSTANGD'
           when d.senaste_ok is null then 'ALDRIG_LYCKATS'
           when d.senaste_status <> 'succeeded' then 'FEL'
           when k.max_tyst_timmar is not null
                and d.senaste_ok < now() - make_interval(hours => k.max_tyst_timmar) then 'TYST'
           else 'OK'
         end,
         case
           when j.jobid is null then 'Cronjobbet finns inte i cron.job'
           when not j.active then 'Jobbet är avstängt'
           when d.senaste_ok is null then 'Har aldrig lyckats'
           when d.senaste_status <> 'succeeded' then 'Senaste körning: ' || d.senaste_status
                || coalesce(' - ' || left(d.senaste_meddelande, 120), '')
           else 'Senaste lyckade körning för ' || (now() - d.senaste_ok)::interval(0)::text || ' sedan'
         end,
         d.senaste_ok
  from public.driftkomponenter k
  left join cron.job j on j.jobname = k.namn
  left join lateral (
    -- Bara avslutade körningar (end_time satt). En pågående körning har end_time = null,
    -- som sorteras först vid desc — då dömde vakten sig själv och jobb som startar samma
    -- sekund (kivra-sync 03:50) som FEL med "Senaste körning: running". Rättat i etapp 11b.
    select max(r.end_time) filter (where r.status = 'succeeded') as senaste_ok,
           (array_agg(r.status      order by r.end_time desc))[1] as senaste_status,
           (array_agg(r.return_message order by r.end_time desc))[1] as senaste_meddelande
    from cron.job_run_details r where r.jobid = j.jobid and r.end_time is not null
  ) d on true
  where k.aktiv and k.typ = 'cron'

  union all

  -- Händelsestyrda komponenter
  select k.namn, k.typ,
         case
           when w.component is null then 'OKAND'
           when w.consecutive_failures >= k.max_fel_i_rad then 'FEL'
           when w.last_success_at is null then 'ALDRIG_LYCKATS'
           else 'OK'
         end,
         case
           when w.component is null then 'Har aldrig rapporterat status'
           when w.consecutive_failures >= k.max_fel_i_rad then
             w.consecutive_failures || ' fel i rad' || coalesce(' - ' || left(w.last_error, 120), '')
           when w.last_success_at is null then
             'Har aldrig lyckats' || coalesce('. Senaste fel: ' || left(w.last_error, 100), '')
           else 'Senast OK för ' || (now() - w.last_success_at)::interval(0)::text || ' sedan'
         end,
         w.last_success_at
  from public.driftkomponenter k
  left join public.worker_health w on w.component = k.namn
  where k.aktiv and k.typ = 'handelsestyrd'
$$;

revoke all on function public.driftstatus() from public, anon;
grant execute on function public.driftstatus() to authenticated;

update public.driftkomponenter
set senast_rapporterad_status = 'OK'
where namn = 'driftkontroll-natt' and senast_rapporterad_status = 'FEL';
