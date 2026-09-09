-- Migration ai_kvot_v2 (2026-09-09): separata räknefönster för chatt och tolkning.
-- Granskningsfynd samma dag: ai_kvot_klaim räknade även tolka-underlags rader (document_id)
-- och ai_claim_job räknade även chattens rader (funktion). En byrå som bulk-tolkar 60 underlag
-- fick chatten spärrad för timmen utan ett enda chattanrop, och åtta chattfrågor på en minut
-- gav tolkningen 60 sekunders cooldown. Nu räknar ai_kvot_klaim per användare bara rader med
-- funktion satt (chattanropen) och ai_claim_job bara rader med document_id satt (tolkningarna).
-- Plattformstaket i ai_kvot_klaim räknar fortfarande alla AI-anrop (kretsbrytare).
-- Rättigheter oförändrade (create or replace behåller ACL: ai_kvot_klaim endast service_role,
-- ai_claim_job som tidigare). Klientlogik oförändrad: _shared/aiKvot.ts, tolka-underlag.
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
  -- Användartaken räknar bara chattanrop (funktion satt); plattformstaket räknar alla AI-anrop.
  select count(*) filter (where user_id = p_user_id and funktion is not null and created_at > v_now - interval '1 hour'),
         count(*) filter (where user_id = p_user_id and funktion is not null),
         count(*) filter (where created_at > v_now - interval '1 hour')
    into v_timme, v_dygn, v_plattform
    from public.ai_call_log
   where created_at > v_now - interval '24 hours';
  if v_timme >= c_tak_timme then
    select min(created_at) into v_aldsta from public.ai_call_log
     where user_id = p_user_id and funktion is not null and created_at > v_now - interval '1 hour';
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

create or replace function public.ai_claim_job(p_document_id uuid, p_company_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = 'public'
as $$
declare
  v_now timestamptz := now();
  v_scope text; v_until timestamptz;
  v_doc record; v_job uuid;
  v_user_calls int; v_company_calls int;
begin
  select scope, cooldown_until into v_scope, v_until from public.ai_cooldowns
   where cooldown_until > v_now
     and ((scope = 'document' and scope_key = p_document_id::text)
       or (scope = 'user' and scope_key = p_user_id::text)
       or (scope = 'company' and scope_key = p_company_id::text))
   order by cooldown_until desc limit 1;
  if v_until is not null then
    return jsonb_build_object('allowed', false, 'reason', 'cooldown', 'scope', v_scope,
      'retry_after_seconds', greatest(1, ceil(extract(epoch from (v_until - v_now)))::int));
  end if;

  select id, ai_status, ai_job_id, ai_job_started_at into v_doc
    from public.documents where id = p_document_id and company_id = p_company_id;
  if v_doc.id is null then
    return jsonb_build_object('allowed', false, 'reason', 'not_found');
  end if;

  if v_doc.ai_status = 'processing' and v_doc.ai_job_started_at > v_now - interval '90 seconds' then
    return jsonb_build_object('allowed', false, 'reason', 'in_progress', 'job_id', v_doc.ai_job_id);
  end if;

  -- Bara tolkningar (document_id satt) räknas här; chattanropen har eget tak i ai_kvot_klaim.
  select count(*) filter (where user_id = p_user_id),
         count(*) filter (where company_id = p_company_id)
    into v_user_calls, v_company_calls
    from public.ai_call_log where created_at > v_now - interval '60 seconds' and document_id is not null;
  if v_user_calls >= 8 or v_company_calls >= 20 then
    insert into public.ai_cooldowns(scope, scope_key, cooldown_until, reason)
      values (case when v_user_calls >= 8 then 'user' else 'company' end,
              case when v_user_calls >= 8 then p_user_id::text else p_company_id::text end,
              v_now + interval '60 seconds', 'rate_limit')
      on conflict (scope, scope_key) do update set cooldown_until = excluded.cooldown_until, reason = excluded.reason, updated_at = v_now;
    return jsonb_build_object('allowed', false, 'reason', 'rate_limited',
      'scope', case when v_user_calls >= 8 then 'user' else 'company' end, 'retry_after_seconds', 60);
  end if;

  v_job := gen_random_uuid();
  update public.documents
     set ai_status = 'processing', ai_job_id = v_job, ai_job_started_at = v_now,
         ai_attempts = coalesce(ai_attempts, 0) + 1
   where id = p_document_id and company_id = p_company_id;
  insert into public.ai_call_log(user_id, company_id, document_id) values (p_user_id, p_company_id, p_document_id);
  return jsonb_build_object('allowed', true, 'job_id', v_job);
end $$;
