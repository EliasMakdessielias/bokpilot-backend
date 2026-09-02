-- pg_cron-jobb i bokpilot-sverige (vzeqvapebkbapwflozbi), dumpade 2026-09-02.
-- Referens — körs redan i databasen. Authorization- och apikey-headern i jobb 4
-- och 5 är projektets publicerbara nyckel (sb_publishable_...), som ersatte den
-- tidigare anon-JWT:n vid nyckelrotationen; båda är publika till sin natur. De
-- hemliga cron-nycklarna läses ur public.interna_nycklar vid körning och ingår
-- inte i dumpen.

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
      'Authorization', 'Bearer sb_publishable_vyR02gFIVZH9zY7RBRvX7Q_mBogzd00',
      'apikey', 'sb_publishable_vyR02gFIVZH9zY7RBRvX7Q_mBogzd00',
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
      'Authorization', 'Bearer sb_publishable_vyR02gFIVZH9zY7RBRvX7Q_mBogzd00',
      'apikey', 'sb_publishable_vyR02gFIVZH9zY7RBRvX7Q_mBogzd00',
      'x-byrastod-cron-secret', (select varde from public.interna_nycklar where namn = 'byrastod_cron')
    ),
    body := '{"cron": true}'::jsonb
  );
$job$);

-- jobid 6: gdpr-gallring-natt, schema '40 3 * * *', aktiv
select cron.schedule('gdpr-gallring-natt', '40 3 * * *',
  $job$ select public.gallra_gdpr_loggar() $job$);

-- jobid 7: lagringsintegritet-natt, schema '25 3 * * *', aktiv
-- Etapp 9: jämför documents/arkiv_filer mot storage.objects åt båda hållen och
-- larmar när en databasrad saknar sin fil i Storage.
select cron.schedule('lagringsintegritet-natt', '25 3 * * *',
  $job$ select public.cron_lagringsintegritet() $job$);

-- jobid 8: driftkontroll-natt, schema '50 3 * * *', aktiv
-- Etapp 11: nattlig driftvakt. Läser driftstatus() för komponenterna i
-- public.driftkomponenter och larmar bara när en komponents status har ändrats.
select cron.schedule('driftkontroll-natt', '50 3 * * *',
  $job$ select public.cron_driftkontroll() $job$);

-- jobid 10: kyc-bevakning-natt, schema '30 3 * * *', aktiv
-- Etapp 14: bevakar kundkännedomens giltighet per aktiv byråklient och skriver
-- aml_flags av typ kyc_saknas. Schemalades i etapp 14 som jobid 9 (04:35) och
-- flyttades i etapp 14b till 03:30, före driftvakten; jobid 9 är avregistrerat
-- och finns inte längre i cron.job.
select cron.schedule('kyc-bevakning-natt', '30 3 * * *',
  $job$ select public.cron_kyc_bevakning() $job$);
