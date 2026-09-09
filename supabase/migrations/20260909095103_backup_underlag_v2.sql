-- backup_underlag_v2: uttrycklig timeout i cronjobbets http-anrop (2026-09-09).
-- pg_net väntar annars bara 5 000 ms på svar. Provkörningen 2026-09-09 tog 18,5 s för
-- 29 objekt och en full körning får ta upp till 110 s (TIDSBUDGET_MS i backup-underlag),
-- så svaret ska kunna läsas ur net._http_response i efterhand i stället för att loggas
-- som timed_out. Kommandot är i övrigt identiskt med backup_underlag_v1.
select cron.alter_job(
  job_id := (select jobid from cron.job where jobname = 'backup-underlag-natt'),
  command := $job$
  select net.http_post(
    url := 'https://vzeqvapebkbapwflozbi.supabase.co/functions/v1/backup-underlag',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_vyR02gFIVZH9zY7RBRvX7Q_mBogzd00',
      'apikey', 'sb_publishable_vyR02gFIVZH9zY7RBRvX7Q_mBogzd00',
      'x-backup-cron-secret', (select varde from public.interna_nycklar where namn = 'backup_cron')
    ),
    body := '{"cron": true}'::jsonb,
    timeout_milliseconds := 150000
  );
  $job$
);
