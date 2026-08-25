revoke execute on function public.stripe_handle_event(text, text, text, text, text, text, timestamptz, timestamptz, text, text, timestamptz) from public, anon, authenticated;
grant  execute on function public.stripe_handle_event(text, text, text, text, text, text, timestamptz, timestamptz, text, text, timestamptz) to service_role;

revoke execute on function public.sync_company_service_state_from_billing(uuid) from public, anon, authenticated;
grant  execute on function public.sync_company_service_state_from_billing(uuid) to service_role;

revoke execute on function public.next_ver_nr(uuid, text) from public, anon, authenticated;
grant  execute on function public.next_ver_nr(uuid, text) to service_role;

revoke execute on function public.cron_run_monthly_controls() from public, anon, authenticated;
grant  execute on function public.cron_run_monthly_controls() to service_role;
revoke execute on function public.run_scheduled_plan_enforcement() from public, anon, authenticated;
grant  execute on function public.run_scheduled_plan_enforcement() to service_role;
revoke execute on function public.run_subscription_grace_enforcement() from public, anon, authenticated;
grant  execute on function public.run_subscription_grace_enforcement() to service_role;
revoke execute on function public.notify_subscription_lifecycle() from public, anon, authenticated;
grant  execute on function public.notify_subscription_lifecycle() to service_role;

revoke execute on function public.record_ai_usage(uuid, text) from public, anon, authenticated;
grant  execute on function public.record_ai_usage(uuid, text) to service_role;
revoke execute on function public.ai_claim_job(uuid, uuid, uuid) from public, anon, authenticated;
grant  execute on function public.ai_claim_job(uuid, uuid, uuid) to service_role;
revoke execute on function public.ai_finish_job(uuid, uuid, text, integer, uuid, text) from public, anon, authenticated;
grant  execute on function public.ai_finish_job(uuid, uuid, text, integer, uuid, text) to service_role;

revoke execute on function public.log_ai_error(text, text, integer, text, text, text, integer, text, uuid, uuid, uuid) from public, anon, authenticated;
grant  execute on function public.log_ai_error(text, text, integer, text, text, text, integer, text, uuid, uuid, uuid) to service_role;
revoke execute on function public.log_platform_audit(text, text, jsonb) from public, anon, authenticated;
grant  execute on function public.log_platform_audit(text, text, jsonb) to service_role;

revoke execute on function public.apply_email_unsubscribe(uuid, text) from public, anon;

revoke execute on function public.run_monthly_control(uuid, integer, integer) from public, anon;
revoke execute on function public.run_scheduled_notifications() from public, anon;
revoke execute on function public.log_accounting_audit(text, text, text, text, jsonb, uuid, jsonb, jsonb) from public, anon;
revoke execute on function public.report_system_error(text, text, uuid) from public, anon;
revoke execute on function public.report_system_error(text, text, uuid, text, text, jsonb, timestamptz) from public, anon;

create or replace function public.bokslut_get_or_create(p_company uuid, p_fiscal_year_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_id uuid; v_existed boolean;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  perform public._assert_company_access(p_company);
  if not public.has_ai_feature(p_company, 'ai_bokslut_arsredovisning') then raise exception 'feature_not_licensed' using errcode='42501'; end if;
  if not exists (select 1 from fiscal_years fy where fy.id=p_fiscal_year_id and fy.company_id=p_company) then
    raise exception 'fiscal year mismatch' using errcode='22023'; end if;

  select id into v_id from bokslut_engagements where company_id=p_company and fiscal_year_id=p_fiscal_year_id;
  v_existed := v_id is not null;

  if not v_existed then
    insert into bokslut_engagements (company_id, fiscal_year_id, ansvarig_user_id)
    values (p_company, p_fiscal_year_id, auth.uid())
    on conflict (company_id, fiscal_year_id) do update set updated_at=now()
    returning id into v_id;
    insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
    values (v_id, p_company, auth.uid(), 'engagement_created', jsonb_build_object('fiscal_year_id', p_fiscal_year_id));
  else
    update bokslut_engagements set updated_at=now() where id=v_id;
    if not exists (
      select 1 from bokslut_audit_log
      where engagement_id=v_id and user_id=auth.uid() and action='engagement_opened' and created_at > now() - interval '1 hour'
    ) then
      insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
      values (v_id, p_company, auth.uid(), 'engagement_opened', jsonb_build_object('fiscal_year_id', p_fiscal_year_id));
    end if;
  end if;

  return (select to_jsonb(e) from bokslut_engagements e where e.id=v_id);
end $function$;

revoke execute on function public.bokslut_get_or_create(uuid, uuid) from public, anon;
