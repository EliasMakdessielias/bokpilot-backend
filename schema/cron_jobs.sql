-- pg_cron-jobb i bokpilot-sverige (vzeqvapebkbapwflozbi), dumpade 2026-08-20.
-- Referens — körs redan i databasen. Authorization-headern i jobb 4 och 5 är
-- projektets publika anon-nyckel; de hemliga cron-nycklarna läses ur
-- public.interna_nycklar vid körning och ingår inte i dumpen.

-- jobid 1: bokpilot-scheduled-notifications, schema '0 6 * * *', aktiv
select cron.schedule('bokpilot-scheduled-notifications', '0 6 * * *', $job$
  select public.run_scheduled_notifications();
  select public.notify_subscription_lifecycle();
  select public.run_scheduled_plan_enforcement();
  select public.record_worker_health('scheduled-notifications', true, null);
$job$);

-- jobid 2: bokpilot-subscription-grace, schema '15 6 * * *', aktiv
select cron.schedule('bokpilot-subscription-grace', '15 6 * * *',
  $job$ select public.run_subscription_grace_enforcement() $job$);

-- jobid 3: monthly-control-daily, schema '15 3 * * *', aktiv
select cron.schedule('monthly-control-daily', '15 3 * * *',
  $job$ select public.cron_run_monthly_controls(); $job$);

-- jobid 4: kivra-sync-10min, schema '*/10 * * * *', aktiv
select cron.schedule('kivra-sync-10min', '*/10 * * * *', $job$
  select net.http_post(
    url := 'https://vzeqvapebkbapwflozbi.supabase.co/functions/v1/kivra-sync',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6ZXF2YXBlYmtiYXB3ZmxvemJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2ODQ0NzAsImV4cCI6MjA5OTI2MDQ3MH0.uI-gF2q7SIK57rJIglczsfSiDIYN3aQm6a-Vz1yZiqQ',
      'x-kivra-cron-secret', (select varde from public.interna_nycklar where namn='kivra_cron')
    ),
    body := '{"cron": true}'::jsonb
  );
$job$);

-- jobid 5: byrastod-jobb-natt, schema '10 4 * * *', aktiv
select cron.schedule('byrastod-jobb-natt', '10 4 * * *', $job$
  select net.http_post(
    url := 'https://vzeqvapebkbapwflozbi.supabase.co/functions/v1/byrastod-jobb',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6ZXF2YXBlYmtiYXB3ZmxvemJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2ODQ0NzAsImV4cCI6MjA5OTI2MDQ3MH0.uI-gF2q7SIK57rJIglczsfSiDIYN3aQm6a-Vz1yZiqQ',
      'x-byrastod-cron-secret', (select varde from public.interna_nycklar where namn = 'byrastod_cron')
    ),
    body := '{"cron": true}'::jsonb
  );
$job$);

-- jobid 6: gdpr-gallring-natt, schema '40 3 * * *', aktiv
select cron.schedule('gdpr-gallring-natt', '40 3 * * *',
  $job$ select public.gallra_gdpr_loggar() $job$);
