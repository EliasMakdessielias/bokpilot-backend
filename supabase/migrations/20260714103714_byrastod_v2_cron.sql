-- Byråstöd etapp B: nattlig schemaläggning av byrastod-jobb (kivra-sync-mönstret).
-- Nyckeln genereras i databasen och hanteras aldrig utanför den.

insert into public.interna_nycklar (namn, varde)
values ('byrastod_cron', encode(extensions.gen_random_bytes(24), 'hex'))
on conflict (namn) do nothing;

do $$
begin
  perform cron.unschedule('byrastod-jobb-natt');
exception when others then null;
end $$;

do $$
begin
  perform cron.schedule('byrastod-jobb-natt', '10 4 * * *', $cron$
  select net.http_post(
    url := 'https://vzeqvapebkbapwflozbi.supabase.co/functions/v1/byrastod-jobb',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ6ZXF2YXBlYmtiYXB3ZmxvemJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM2ODQ0NzAsImV4cCI6MjA5OTI2MDQ3MH0.uI-gF2q7SIK57rJIglczsfSiDIYN3aQm6a-Vz1yZiqQ',
      'x-byrastod-cron-secret', (select varde from public.interna_nycklar where namn = 'byrastod_cron')
    ),
    body := '{"cron": true}'::jsonb
  );
  $cron$);
exception when others then
  raise notice 'pg_cron ej tillgänglig — schemalägg byrastod-jobb-natt manuellt: %', sqlerrm;
end $$;
