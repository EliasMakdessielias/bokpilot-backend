-- Migration ai_kvot_v1 (2026-09-09): kostnadstak per användare för AI-chattfunktionerna
-- (assistent-ai, bokfor-ai, ekonomichef-ai, granska-ai, manadskontroll-ai, support-ai).
-- ai_call_log får kolumnen funktion och ett index per användare; ai_kvot_klaim räknar
-- anrop i glidande fönster och loggar anropet. Tak: 60 per användare och timme, 400 per
-- användare och dygn, 1 500 per timme för hela plattformen (kretsbrytare). Endast
-- service_role får anropa. Klientlogik: supabase/functions/_shared/aiKvot.ts.
-- OBS: raderna räknas även av ai_claim_job (tolka-underlag, 8 anrop/användare/minut) —
-- en gemensam AI-budget per användare.
alter table public.ai_call_log add column if not exists funktion text;
comment on column public.ai_call_log.funktion is 'Edge-funktion som gjorde AI-anropet (null = tolka-underlag före 2026-09-09).';
create index if not exists ai_call_log_user_recent_idx on public.ai_call_log (user_id, created_at desc);

create or replace function public.ai_kvot_klaim(p_user_id uuid, p_funktion text, p_company_id uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_now timestamptz := now();
  v_timme int; v_dygn int; v_plattform int;
  v_aldsta timestamptz;
  c_tak_timme constant int := 60;
  c_tak_dygn constant int := 400;
  c_tak_plattform_timme constant int := 1500;
begin
  if p_user_id is null or coalesce(p_funktion, '') = '' then
    raise exception 'ai_kvot_klaim: användare och funktion krävs' using errcode = '22023';
  end if;
  select count(*) filter (where user_id = p_user_id and created_at > v_now - interval '1 hour'),
         count(*) filter (where user_id = p_user_id),
         count(*) filter (where created_at > v_now - interval '1 hour')
    into v_timme, v_dygn, v_plattform
    from public.ai_call_log
   where created_at > v_now - interval '24 hours';
  if v_timme >= c_tak_timme then
    select min(created_at) into v_aldsta from public.ai_call_log
     where user_id = p_user_id and created_at > v_now - interval '1 hour';
    return jsonb_build_object('allowed', false, 'reason', 'timme', 'anvant', v_timme, 'tak', c_tak_timme,
      'retry_after_seconds', greatest(60, ceil(extract(epoch from (v_aldsta + interval '1 hour' - v_now)))::int));
  end if;
  if v_dygn >= c_tak_dygn then
    return jsonb_build_object('allowed', false, 'reason', 'dygn', 'anvant', v_dygn, 'tak', c_tak_dygn, 'retry_after_seconds', 3600);
  end if;
  if v_plattform >= c_tak_plattform_timme then
    return jsonb_build_object('allowed', false, 'reason', 'plattform', 'anvant', v_plattform, 'tak', c_tak_plattform_timme, 'retry_after_seconds', 600);
  end if;
  insert into public.ai_call_log (user_id, company_id, funktion) values (p_user_id, p_company_id, p_funktion);
  return jsonb_build_object('allowed', true, 'anvant_timme', v_timme + 1, 'tak_timme', c_tak_timme, 'anvant_dygn', v_dygn + 1, 'tak_dygn', c_tak_dygn);
end $$;

revoke all on function public.ai_kvot_klaim(uuid, text, uuid) from public, anon, authenticated;
grant execute on function public.ai_kvot_klaim(uuid, text, uuid) to service_role;
