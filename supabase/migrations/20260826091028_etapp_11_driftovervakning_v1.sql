-- Etapp 11: driftövervakning som faktiskt läser de signaler systemet redan skriver.
--
-- worker_health har registrerat åtta komponenter sedan i somras, och cron.job_run_details
-- har varje körning. Ingenting har läst dem. Följden: folio-ocr har elva raka misslyckanden
-- sedan 2026-07-14 och har aldrig lyckats; stripe-webhook har aldrig lyckats och föll
-- 2026-06-08 på "Okänt Stripe price_id"; e-postimporten är tyst sedan 78 dagar. Allt
-- upptäcktes för att en människa råkade titta.
--
-- Två sorters komponenter kräver två sorters larm, och att blanda ihop dem ger antingen
-- falsklarm eller tystnad:
--   'cron'          - ska köra på schema. Tystnad ÄR felet.
--   'handelsestyrd' - kör när något händer. Tystnad kan vara normalt (inga fakturor kom
--                     in), men upprepade FEL är alltid fel.

create table if not exists public.driftkomponenter (
  namn                     text primary key,
  typ                      text not null check (typ in ('cron', 'handelsestyrd')),
  max_tyst_timmar          integer,
  max_fel_i_rad            integer not null default 3,
  beskrivning              text,
  aktiv                    boolean not null default true,
  senast_rapporterad_status text,
  created_at               timestamptz not null default now()
);

comment on column public.driftkomponenter.max_tyst_timmar is
  'Hur länge tystnad tolereras. NULL = larma aldrig på tystnad (händelsestyrd).';
comment on column public.driftkomponenter.senast_rapporterad_status is
  'Senast larmade status. Används för att bara larma vid FÖRÄNDRING, inte varje natt.';

alter table public.driftkomponenter enable row level security;
revoke all on table public.driftkomponenter from anon, authenticated;

insert into public.driftkomponenter (namn, typ, max_tyst_timmar, max_fel_i_rad, beskrivning) values
  ('bokpilot-scheduled-notifications', 'cron', 36, 1, 'Dagliga notisutskick 06:00'),
  ('bokpilot-subscription-grace',      'cron', 36, 1, 'Abonnemangsspärrar 06:15'),
  ('monthly-control-daily',            'cron', 36, 1, 'Månadskontroller 03:15'),
  ('gdpr-gallring-natt',               'cron', 36, 1, 'GDPR-gallring av loggar 03:40'),
  ('kivra-sync-10min',                 'cron',  2, 3, 'Kivra-synk var 10:e minut'),
  ('byrastod-jobb-natt',               'cron', 36, 1, 'Byråstödets deadlinejobb 04:10'),
  ('lagringsintegritet-natt',          'cron', 36, 1, 'Avstämning databas mot Storage 03:25'),
  ('stripe-webhook',   'handelsestyrd', null, 1, 'Tar emot betalhändelser från Stripe'),
  ('folio-ocr',        'handelsestyrd', null, 3, 'OCR-tolkning av underlag'),
  ('inbound-email',    'handelsestyrd', null, 3, 'Inkommande underlag via e-post'),
  ('tolka-underlag',   'handelsestyrd', null, 3, 'AI-tolkning av underlag'),
  ('email-worker',     'handelsestyrd', null, 3, 'Utgående e-post'),
  ('imap-import',      'handelsestyrd', null, 3, 'IMAP-hämtning av e-post')
on conflict (namn) do nothing;

-- Läsbar ögonblicksbild. Cronjobb bedöms mot cron.job_run_details (auktoritativt),
-- händelsestyrda mot worker_health.
create or replace function public.driftstatus()
returns table (
  namn text, typ text, status text, detalj text, senast timestamptz
)
language sql
security definer
set search_path = public
as $fn$
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
    select max(r.end_time) filter (where r.status = 'succeeded') as senaste_ok,
           (array_agg(r.status      order by r.end_time desc))[1] as senaste_status,
           (array_agg(r.return_message order by r.end_time desc))[1] as senaste_meddelande
    from cron.job_run_details r where r.jobid = j.jobid
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
$fn$;

-- Nattlig vakt. Larmar endast vid FÖRÄNDRING av status — ett dagligt larm om ett
-- konstant tillstånd tränar bort uppmärksamheten, vilket är precis hur folio-ocr
-- kunde ligga nere i sex veckor.
create or replace function public.cron_driftkontroll()
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  r record; forandringar text := ''; antal_daliga int := 0;
begin
  for r in select * from public.driftstatus() loop
    if r.status <> 'OK' then
      antal_daliga := antal_daliga + 1;
    end if;

    if r.status is distinct from (select senast_rapporterad_status
                                    from public.driftkomponenter where namn = r.namn) then
      forandringar := forandringar || format(E'%s: %s -> %s (%s)\n',
        r.namn,
        coalesce((select senast_rapporterad_status from public.driftkomponenter where namn = r.namn), 'okand'),
        r.status, r.detalj);
      update public.driftkomponenter set senast_rapporterad_status = r.status where namn = r.namn;
    end if;
  end loop;

  if forandringar <> '' then
    perform public.report_system_error(
      'driftkontroll',
      format('Driftstatus har ändrats för %s komponent(er). %s av %s är inte OK.',
             (length(forandringar) - length(replace(forandringar, chr(10), ''))),
             antal_daliga,
             (select count(*) from public.driftkomponenter where aktiv)),
      null,
      case when antal_daliga > 0 then 'error' else 'info' end,
      'DRIFT_STATUS_ANDRAD',
      jsonb_build_object('forandringar', forandringar,
                         'full_status', (select jsonb_agg(to_jsonb(d)) from public.driftstatus() d)),
      now());
  end if;

  perform public.record_worker_health('driftkontroll', true);
exception when others then
  perform public.record_worker_health('driftkontroll', false, left(sqlerrm, 300));
  raise;
end $fn$;

revoke execute on function public.cron_driftkontroll() from public, anon, authenticated;
revoke execute on function public.driftstatus() from public, anon;
grant execute on function public.driftstatus() to authenticated;

select cron.schedule('driftkontroll-natt', '50 3 * * *',
                     'select public.cron_driftkontroll()');
