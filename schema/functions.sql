CREATE OR REPLACE FUNCTION public._ar_betrodd_backend()
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v text;
begin
  v := nullif(current_setting('request.jwt.claims', true), '');
  if v is null then
    return true;    -- ingen PostgREST-kontext alls: cron, migrationer, psql
  end if;
  return (v::jsonb ->> 'role') = 'service_role';
exception when others then
  return false;     -- fail-closed: går kontexten inte att avgöra, kräv behörighet
end $function$
;

CREATE OR REPLACE FUNCTION public._assert_company_access(p_company uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not (p_company in (select user_company_ids()) or public.is_platform_admin()) then
    raise exception 'ATKOMST_NEKAD: Du har inte behörighet till detta företag.';
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public._bokslut_attachment_guard(p_attachment uuid)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;
begin
  select a.id, a.company_id, a.engagement_id, e.status as eng_status into r
  from bokslut_attachments a join bokslut_engagements e on e.id = a.engagement_id where a.id = p_attachment;
  if r.id is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id = auth.uid() and uc.company_id = r.company_id) then raise exception 'forbidden' using errcode='42501'; end if;
  if r.eng_status = 'last' then raise exception 'engagemanget är låst' using errcode='42501'; end if;
  return r;
end $function$
;

CREATE OR REPLACE FUNCTION public._bokslut_check_guard(p_check uuid)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;
begin
  select c.id, c.company_id, c.engagement_id into r from bokslut_checks c where c.id=p_check;
  if r.id is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=r.company_id) then raise exception 'forbidden' using errcode='42501'; end if;
  if exists (select 1 from bokslut_engagements e where e.id=r.engagement_id and e.status='last') then raise exception 'engagemanget är låst' using errcode='42501'; end if;
  return r;
end $function$
;

CREATE OR REPLACE FUNCTION public._bokslut_checks_comment_revision()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.comment is distinct from old.comment then
    new.comment_revision := old.comment_revision + 1;
    new.comment_updated_at := pg_catalog.statement_timestamp();
    new.comment_updated_by := auth.uid();
  else
    new.comment_revision := old.comment_revision;
    new.comment_updated_at := old.comment_updated_at;
    new.comment_updated_by := old.comment_updated_by;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public._bokslut_recount(p_eng uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_open int; v_crit int; v_high int; v_locked text;
begin
  select count(*) filter (where status in ('open','in_progress','needs_review')),
         count(*) filter (where status in ('open','in_progress','needs_review') and risk_level='critical'),
         count(*) filter (where status in ('open','in_progress','needs_review') and risk_level='high')
  into v_open, v_crit, v_high from bokslut_checks where engagement_id=p_eng;
  select status into v_locked from bokslut_engagements where id=p_eng;
  update bokslut_engagements set open_count=v_open, critical_count=v_crit, high_count=v_high, updated_at=now(),
    status = case when v_locked in ('klar_for_konsult','godkand','avvisad','last') then v_locked
      when (v_crit+v_high) > 0 then 'kraver_granskning'
      when v_open > 0 then 'pagar'
      when v_open = 0 then 'klar_for_konsult' else v_locked end
  where id=p_eng;
end $function$
;

CREATE OR REPLACE FUNCTION public._limit_for(p_company_id uuid, p_metric text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case p_metric
    when 'users' then p.max_users when 'companies' then p.max_companies
    when 'invoices' then p.max_invoices_per_month when 'documents' then p.max_documents_per_month
    when 'storage' then p.max_storage_mb when 'ai' then p.max_ai_operations_per_month end
  from company_subscriptions s join subscription_plans p on p.id=s.plan_id where s.company_id=p_company_id
$function$
;

CREATE OR REPLACE FUNCTION public._mc_item_guard(p_item uuid)
 RETURNS record
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;
begin
  select i.id, i.company_id, i.monthly_control_id into r from monthly_control_items i where i.id=p_item;
  if r.id is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=r.company_id) then
    raise exception 'forbidden' using errcode='42501'; end if;
  return r;
end $function$
;

CREATE OR REPLACE FUNCTION public._mc_recount(p_control uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_total int; v_open int; v_crit int; v_high int; v_norm int; v_low int; v_res int; v_closed boolean;
begin
  select count(*),
    count(*) filter (where status in ('open','in_progress','waiting_for_user','waiting_for_support','blocked')),
    count(*) filter (where priority='critical' and status in ('open','in_progress','waiting_for_user','waiting_for_support','blocked')),
    count(*) filter (where priority='high' and status in ('open','in_progress','waiting_for_user','waiting_for_support','blocked')),
    count(*) filter (where priority='normal' and status in ('open','in_progress','waiting_for_user','waiting_for_support','blocked')),
    count(*) filter (where priority='low' and status in ('open','in_progress','waiting_for_user','waiting_for_support','blocked')),
    count(*) filter (where status='resolved')
  into v_total, v_open, v_crit, v_high, v_norm, v_low, v_res
  from monthly_control_items where monthly_control_id=p_control;
  select status='closed' into v_closed from monthly_controls where id=p_control;
  update monthly_controls set
    critical_count=v_crit, high_count=v_high, normal_count=v_norm, low_count=v_low, resolved_count=v_res,
    progress_percent = case when v_total=0 then 100 else round((v_total - v_open)::numeric * 100 / v_total) end,
    status = case
      when v_closed then 'closed'
      when v_total=0 then 'ready_for_review'
      when (v_crit + v_high) > 0 then 'needs_action'
      when v_open > 0 then 'in_progress'
      else 'ready_for_review' end,
    updated_at = now()
  where id=p_control;
end $function$
;

CREATE OR REPLACE FUNCTION public._notify_plan_limit(p_company_id uuid, p_metric text, v jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_status text := v->>'status'; v_label text; v_event text; v_channels text[]; v_company text; v_plan text;
begin
  if v_status not in ('warning','exceeded') then return; end if;
  v_label := case p_metric when 'users' then 'Användare' when 'companies' then 'Företag'
    when 'invoices' then 'Fakturor denna månad' when 'documents' then 'Underlag denna månad'
    when 'storage' then 'Lagring (MB)' when 'ai' then 'AI-operationer denna månad' else p_metric end;
  select c.name, p.name into v_company, v_plan from companies c
    left join company_subscriptions s on s.company_id=c.id left join subscription_plans p on p.id=s.plan_id where c.id=p_company_id;
  v_event := case when v_status='exceeded' then 'plan_limit_exceeded' else 'plan_limit_warning' end;
  v_channels := case when v_status='exceeded' then array['in_app','email'] else array['in_app'] end;
  perform public.notify_event(p_company_id, v_event,
    jsonb_build_object('metricLabel',v_label,'companyName',coalesce(v_company,''),'planName',coalesce(v_plan,''),
      'limitType',p_metric,'used',v->>'used','limit',v->>'limit','percent',v->>'percentUsed',
      'actionUrl','https://app.bokpilot.se/installningar/abonnemang'),
    'plan_limit', null, '/installningar/abonnemang', null, null,
    case when v_status='exceeded' then 'high' else 'normal' end,
    -- dedupe: event (warning/exceeded) i nyckeln -> warning->exceeded samma dag tillåts; max 1/metric/dag
    v_event||':'||p_company_id::text||':'||p_metric||':'||to_char(now(),'YYYYMMDD'), v_channels);
end $function$
;

CREATE OR REPLACE FUNCTION public._plan_limit_status(p_company_id uuid, p_metric text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_limit int; v_used int; v_pct int; v_status text;
begin
  if p_metric not in ('users','companies','invoices','documents','storage','ai') then
    raise exception 'ogiltig metric' using errcode='22023'; end if;
  v_limit := public._limit_for(p_company_id, p_metric);
  v_used := public._plan_used(p_company_id, p_metric);
  if v_limit is null or v_limit < 0 then
    return jsonb_build_object('metric',p_metric,'limit',null,'used',v_used,'remaining',null,'percentUsed',null,'status','unlimited');
  end if;
  v_pct := case when v_limit=0 then 100 else round(v_used*100.0/v_limit) end;
  v_status := case when v_used >= v_limit then 'exceeded' when v_pct >= 80 then 'warning' else 'ok' end;
  return jsonb_build_object('metric',p_metric,'limit',v_limit,'used',v_used,
    'remaining', greatest(0, v_limit-v_used), 'percentUsed', v_pct, 'status', v_status);
end $function$
;

CREATE OR REPLACE FUNCTION public._plan_used(p_company_id uuid, p_metric text)
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case p_metric
    when 'users' then (select count(*) from user_companies where company_id=p_company_id)
    when 'companies' then (select count(distinct uc2.company_id) from user_companies uc2
                           where uc2.user_id in (select user_id from user_companies where company_id=p_company_id))
    when 'invoices' then (select count(*) from invoices where company_id=p_company_id and created_at >= date_trunc('month', now()))
    when 'documents' then (select count(*) from documents where company_id=p_company_id and created_at >= date_trunc('month', now()))
    when 'storage' then (select coalesce(round(sum(file_size)/1048576.0)::int,0) from documents where company_id=p_company_id)
    when 'ai' then (select count(*) from ai_usage_log where company_id=p_company_id and created_at >= date_trunc('month', now()))
    else 0 end::int
$function$
;

CREATE OR REPLACE FUNCTION public._support_snip(p text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$ select left(coalesce(p,''),140) $function$
;

CREATE OR REPLACE FUNCTION public.acceptera_inbjudningar()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid   uuid := auth.uid();
  v_email text := auth.jwt() ->> 'email';
  v_antal int  := 0;
  r record;
begin
  if v_uid is null or v_email is null then
    raise exception 'ATKOMST_NEKAD: Du måste vara inloggad.';
  end if;

  for r in
    select id, company_id, coalesce(role, 'member') as role
    from public.company_invites
    where status = 'pending'
      and lower(email) = lower(v_email)
  loop
    insert into public.user_companies (user_id, company_id, role, email)
    values (v_uid, r.company_id,
            case when r.role = 'admin' then 'admin' else 'member' end,
            v_email)
    on conflict (user_id, company_id) do nothing;

    update public.company_invites
       set status = 'accepted'
     where id = r.id;

    v_antal := v_antal + 1;
  end loop;

  return jsonb_build_object('accepterade', v_antal);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.accounts_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_email text := auth.jwt() ->> 'email';
  v_uid uuid := auth.uid();
begin
  if current_setting('app.bulk_import', true) = 'on' then
    return coalesce(new, old);
  end if;

  begin
    if (tg_op = 'DELETE') then
      insert into public.audit_log(company_id, entity, entity_ref, action, old_data, changed_by, changed_by_email)
      values (old.company_id, 'account', old.account_nr, 'delete', to_jsonb(old), v_uid, v_email);
    elsif (tg_op = 'UPDATE') then
      insert into public.audit_log(company_id, entity, entity_ref, action, old_data, new_data, changed_by, changed_by_email)
      values (new.company_id, 'account', new.account_nr, 'update', to_jsonb(old), to_jsonb(new), v_uid, v_email);
    else
      insert into public.audit_log(company_id, entity, entity_ref, action, new_data, changed_by, changed_by_email)
      values (new.company_id, 'account', new.account_nr, 'create', to_jsonb(new), v_uid, v_email);
    end if;
  exception
    when foreign_key_violation then
      null;   -- bolaget raderas (cascade) – auditraden har inget att peka på
    when others then
      raise;  -- riktigt auditfel stoppar transaktionen
  end;

  return case when tg_op = 'DELETE' then old else new end;
end $function$
;

CREATE OR REPLACE FUNCTION public.add_internal_note(p_ticket_id uuid, p_body text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_note uuid;
begin
  if not public.can_view_support() then raise exception 'forbidden' using errcode='42501'; end if;
  insert into support_internal_notes(ticket_id, author_admin_id, body) values (p_ticket_id, auth.uid(), p_body) returning id into v_note;
  perform public.log_platform_audit('support_internal_note', p_ticket_id::text, '{}'::jsonb);
  return v_note;
end $function$
;

CREATE OR REPLACE FUNCTION public.add_support_attachment(p_message_id uuid, p_note_id uuid, p_file_name text, p_mime text, p_size bigint, p_storage_path text, p_visibility text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); t record; v_ext text; v_vis text; v_att uuid; v_is_admin boolean;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if p_message_id is not null then
    select tk.* into t from support_messages m join support_tickets tk on tk.id=m.ticket_id where m.id=p_message_id;
  elsif p_note_id is not null then
    select tk.* into t from support_internal_notes n join support_tickets tk on tk.id=n.ticket_id where n.id=p_note_id;
  else raise exception 'message_id eller note_id krävs' using errcode='22023'; end if;
  if t is null then raise exception 'not found' using errcode='P0002'; end if;
  v_is_admin := public.can_view_support();
  if p_note_id is not null and not v_is_admin then raise exception 'forbidden' using errcode='42501'; end if;
  if not (v_is_admin or t.created_by_user_id=v_uid or t.company_id in (select user_company_ids())) then raise exception 'forbidden' using errcode='42501'; end if;
  v_ext := lower(substring(p_file_name from '\.([A-Za-z0-9]+)$'));
  if v_ext = any (array['exe','bat','cmd','com','scr','js','jar','msi','sh','ps1','vbs','dll','app','html','htm','svg','zip']) then
    raise exception 'blockerad filtyp: %', v_ext using errcode='22023'; end if;
  if v_ext is null or not (v_ext = any (array['pdf','png','jpg','jpeg','webp','txt','csv','xlsx','docx','json','webm','m4a','mp3','ogg','wav'])) then
    raise exception 'ej tillåten filtyp' using errcode='22023'; end if;
  if coalesce(p_size,0) > 10485760 then raise exception 'för stor fil (max 10 MB)' using errcode='22023'; end if;
  if position('..' in p_storage_path) > 0 then raise exception 'ogiltig sökväg' using errcode='22023'; end if;
  if p_storage_path not like t.company_id::text||'/'||t.id::text||'/%' then raise exception 'sökväg matchar inte ärendet' using errcode='22023'; end if;
  v_vis := case when p_note_id is not null then 'internal_only' else 'customer_visible' end;
  insert into support_attachments(ticket_id, message_id, note_id, company_id, uploaded_by_user_id, file_name, mime_type, file_size, storage_path, visibility)
  values (t.id, p_message_id, p_note_id, t.company_id, v_uid, left(p_file_name,255), p_mime, p_size, p_storage_path, v_vis) returning id into v_att;
  perform public.log_platform_audit('support_attachment_uploaded', t.id::text, jsonb_build_object('file_name',left(p_file_name,255),'visibility',v_vis,'attachment_id',v_att));
  return v_att;
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_acknowledge_system_error(p_event_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_manage_operations() then raise exception 'forbidden' using errcode='42501'; end if;
  update public.notification_events set acknowledged_at=now(), acknowledged_by=auth.uid()
    where id=p_event_id and event_type='system_error';
  perform public.log_platform_audit('system_error_acknowledged', p_event_id::text, '{}'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_cancel_notification(p_queue_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_manage_operations() then raise exception 'forbidden' using errcode='42501'; end if;
  update public.notification_queue set status='cancelled', updated_at=now()
    where id=p_queue_id and status in ('pending','failed','processing');
  perform public.log_platform_audit('notification_cancel', p_queue_id::text, '{}'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_company_usage_detail(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  return jsonb_build_object(
    'company', (select jsonb_build_object('id',id,'name',name,'org_nr',org_nr) from companies where id=p_company_id),
    'subscription', (select row_to_json(s) from company_subscriptions s where s.company_id=p_company_id),
    'plan', (select row_to_json(p) from subscription_plans p where p.id=(select plan_id from company_subscriptions where company_id=p_company_id)),
    'limits', public.check_all_plan_limits(p_company_id),
    'recent_alerts', coalesce((select jsonb_agg(row_to_json(a) order by a.created_at desc) from (
        select event_type, created_at, payload->>'metricLabel' metric, payload->>'used' used, payload->>'limit' lim
        from notification_events where company_id=p_company_id and event_type in ('plan_limit_warning','plan_limit_exceeded')
        order by created_at desc limit 10) a), '[]'::jsonb),
    'billing_tickets', coalesce((select jsonb_agg(row_to_json(t) order by t.created_at desc) from (
        select id, subject, status, priority, created_at from support_tickets
        where company_id=p_company_id and category='billing' order by created_at desc limit 10) t), '[]'::jsonb));
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_get_company(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v jsonb;
begin
  if not public.can_view_operations() then raise exception 'forbidden' using errcode='42501'; end if;
  select jsonb_build_object(
    'company', (select to_jsonb(x) from (
      select id, name, org_nr, vat_nr, email, phone, address, postnr, postort, archive_number::text archive_number,
        company_number, foretagsform, momsperiod, valuta, created_at, onboarded,
        coalesce(service_state,'active') service_state, service_reason, service_note, service_changed_at, service_changed_by, suspended
      from companies where id = p_company_id) x),
    'users', (select coalesce(jsonb_agg(jsonb_build_object(
        'user_id', uc.user_id, 'email', coalesce(uc.email, uu.email), 'role', uc.role, 'last_sign_in_at', uu.last_sign_in_at)
        order by uc.role), '[]'::jsonb)
      from user_companies uc left join auth.users uu on uu.id = uc.user_id where uc.company_id = p_company_id),
    'subscription', (select to_jsonb(x) from (
      select s.status, s.billing_period, p.name plan_name, s.trial_ends_at, s.current_period_start, s.current_period_end,
        s.cancelled_at, s.suspended_at, s.payment_provider, s.payment_status, s.last_payment_at, s.next_billing_at
      from company_subscriptions s left join subscription_plans p on p.id = s.plan_id where s.company_id = p_company_id) x),
    'usage', jsonb_build_object(
      'users', (select count(*) from user_companies where company_id = p_company_id),
      'documents', (select count(*) from documents where company_id = p_company_id),
      'verifikationer', (select count(*) from verifikationer where company_id = p_company_id),
      'inbound', (select count(*) from documents where company_id = p_company_id and source = 'email'),
      'open_tickets', (select count(*) from support_tickets where company_id = p_company_id and status not in ('resolved','closed'))),
    'recent_inbound', (select coalesce(jsonb_agg(jsonb_build_object(
        'file_name', file_name, 'kategori', kategori, 'created_at', created_at) order by created_at desc), '[]'::jsonb)
      from (select file_name, kategori, created_at from documents where company_id = p_company_id and source = 'email' order by created_at desc limit 5) d),
    'support', (select coalesce(jsonb_agg(jsonb_build_object(
        'id', id, 'subject', subject, 'status', status, 'priority', priority, 'created_at', created_at) order by created_at desc), '[]'::jsonb)
      from (select id, subject, status, priority, created_at from support_tickets where company_id = p_company_id order by created_at desc limit 8) t),
    'audit', (select coalesce(jsonb_agg(jsonb_build_object(
        'action', action, 'actor_email', actor_email, 'detail', detail, 'created_at', created_at) order by created_at desc), '[]'::jsonb)
      from (select action, actor_email, detail, created_at from platform_audit_log where target = p_company_id::text order by created_at desc limit 20) a)
  ) into v;
  if (v->'company') is null then raise exception 'företag saknas' using errcode='P0002'; end if;
  return v;
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_get_subscription(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v jsonb;
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  select jsonb_build_object(
    'company', (select jsonb_build_object('id',id,'name',name,'org_nr',org_nr,
        'service_state',coalesce(service_state,'active'),'service_state_manual',coalesce(service_state_manual,false)) from companies where id=p_company_id),
    'subscription', (select row_to_json(s) from company_subscriptions s where s.company_id=p_company_id),
    'plan', (select row_to_json(p) from subscription_plans p where p.id=(select plan_id from company_subscriptions where company_id=p_company_id))
  ) into v;
  return v;
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_grant_platform_role(p_email text, p_role text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_superadmin() then raise exception 'forbidden' using errcode='42501'; end if;
  if p_role not in ('operations_admin','support_admin','billing_admin') then
    raise exception 'ogiltig roll (superadmin hanteras via platform_admins)' using errcode='22023'; end if;
  insert into public.platform_user_roles(email, role, granted_by) values (lower(p_email), p_role, auth.uid())
    on conflict (email, role) do nothing;
  perform public.log_platform_audit('role_granted', lower(p_email), jsonb_build_object('role', p_role));
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_list_companies(p_search text DEFAULT NULL::text, p_state text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_view_operations() then raise exception 'forbidden' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(row_to_json(r)) from (
    select c.id company_id, c.name, c.org_nr, c.email, c.archive_number::text archive_number,
      coalesce(c.service_state,'active') service_state, c.service_reason, c.service_changed_at,
      s.status sub_status, p.name plan_name, s.billing_period,
      (select count(*) from user_companies uc where uc.company_id = c.id) user_count,
      (select count(*) from documents d where d.company_id = c.id) document_count,
      (select count(*) from support_tickets t where t.company_id = c.id and t.status not in ('resolved','closed')) open_tickets,
      greatest(
        (select max(created_at) from documents d where d.company_id = c.id),
        (select max(created_at) from verifikationer v where v.company_id = c.id)) last_activity,
      (select max(uu.last_sign_in_at) from auth.users uu
         join user_companies uc2 on uc2.user_id = uu.id where uc2.company_id = c.id) last_login,
      case
        when coalesce(c.service_state,'active') in ('paused','blocked') then 'blocked'
        when s.status = 'past_due' then 'at_risk'
        when (select count(*) from support_tickets t where t.company_id = c.id and t.status not in ('resolved','closed')) > 3 then 'warning'
        else 'healthy'
      end risk
    from companies c
    left join company_subscriptions s on s.company_id = c.id
    left join subscription_plans p on p.id = s.plan_id
    where (p_search is null
        or c.name ilike '%'||p_search||'%' or c.org_nr ilike '%'||p_search||'%'
        or c.email ilike '%'||p_search||'%' or coalesce(c.archive_number::text,'') ilike '%'||p_search||'%')
      and (p_state is null
        or (p_state in ('active','paused','blocked') and coalesce(c.service_state,'active') = p_state)
        or (p_state in ('trial','past_due','cancelled','expired','suspended') and s.status = p_state))
    order by c.name limit 500) r), '[]'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_list_plans()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(row_to_json(p) order by p.sort_order, p.name) from subscription_plans p), '[]'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_list_platform_roles()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when public.is_superadmin() then coalesce(
    (select jsonb_agg(jsonb_build_object('email',email,'role',role,'granted_at',granted_at) order by email) from public.platform_user_roles),
    '[]'::jsonb) else null end
$function$
;

CREATE OR REPLACE FUNCTION public.admin_list_subscriptions(p_status text DEFAULT NULL::text, p_plan_id uuid DEFAULT NULL::uuid, p_search text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_view_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(row_to_json(r)) from (
    select c.id company_id, c.name company_name, c.org_nr,
      s.id subscription_id, s.plan_id, p.name plan_name, s.status, s.billing_period,
      s.trial_ends_at, s.current_period_start, s.current_period_end, s.cancelled_at, s.suspended_at,
      s.payment_provider, s.payment_customer_id, s.payment_subscription_id,
      s.payment_status, s.grace_until, s.last_payment_failed_at, s.next_payment_attempt_at, s.discount_percent
    from companies c
    left join company_subscriptions s on s.company_id=c.id
    left join subscription_plans p on p.id=s.plan_id
    where (p_status is null or s.status=p_status) and (p_plan_id is null or s.plan_id=p_plan_id)
      and (p_search is null or c.name ilike '%'||p_search||'%' or c.org_nr ilike '%'||p_search||'%')
    order by c.name limit 500) r), '[]'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_plan_usage_overview(p_search text DEFAULT NULL::text, p_plan_id uuid DEFAULT NULL::uuid, p_sub_status text DEFAULT NULL::text, p_status text DEFAULT NULL::text, p_limit_type text DEFAULT NULL::text, p_sort text DEFAULT 'percent_desc'::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rows jsonb; v_total int;
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  drop table if exists _scored;
  create temp table _scored on commit drop as
  with base as (
    select c.id, c.name, c.org_nr, c.created_at, s.plan_id, p.name plan_name, s.status sub_status, s.billing_period,
      (select max(created_at) from documents d where d.company_id=c.id) last_activity
    from companies c
    left join company_subscriptions s on s.company_id=c.id
    left join subscription_plans p on p.id=s.plan_id
    where (p_plan_id is null or s.plan_id=p_plan_id)
      and (p_sub_status is null or s.status=p_sub_status)
      and (p_search is null or c.name ilike '%'||p_search||'%' or coalesce(c.org_nr,'') ilike '%'||p_search||'%')
  ),
  lim as (
    select b.*, (select jsonb_agg(public.check_plan_limit(b.id, t.m) order by t.ord)
                 from unnest(array['users','companies','invoices','documents','storage','ai']) with ordinality as t(m, ord)) limits
    from base b
  )
  select l.id, l.name, l.org_nr, l.created_at, l.plan_id, l.plan_name, l.sub_status, l.billing_period, l.last_activity, l.limits,
    coalesce((select max((x->>'percentUsed')::int) from jsonb_array_elements(l.limits) x where (x->>'percentUsed') is not null),0) max_pct,
    (select count(*)::int from jsonb_array_elements(l.limits) x where x->>'status'='exceeded') exceeded_count,
    coalesce((select (x->>'used')::int from jsonb_array_elements(l.limits) x where x->>'metric'='storage'),0) storage_used,
    coalesce((select (x->>'used')::int from jsonb_array_elements(l.limits) x where x->>'metric'='ai'),0) ai_used,
    case
      when p_limit_type is not null then (select x->>'status' from jsonb_array_elements(l.limits) x where x->>'metric'=p_limit_type)
      when exists(select 1 from jsonb_array_elements(l.limits) x where x->>'status'='exceeded') then 'exceeded'
      when exists(select 1 from jsonb_array_elements(l.limits) x where x->>'status'='warning') then 'warning'
      else 'ok' end overall
  from lim l;
  select count(*) into v_total from _scored where (p_status is null or overall=p_status);
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb) into v_rows from (
    select id company_id, name company_name, org_nr, plan_id, plan_name, sub_status, billing_period, last_activity,
      limits, overall, max_pct, exceeded_count, storage_used, ai_used
    from _scored where (p_status is null or overall=p_status)
    order by
      case when p_sort='percent_desc' then max_pct when p_sort='exceeded' then exceeded_count
           when p_sort='storage' then storage_used when p_sort='ai' then ai_used end desc nulls last,
      case when p_sort='newest' then created_at end desc nulls last,
      case when p_sort='oldest_active' then created_at end asc nulls last,
      name
    limit greatest(1, least(p_limit, 200)) offset greatest(0, p_offset)) r;
  return jsonb_build_object('total', v_total, 'rows', v_rows);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_retry_notification(p_queue_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_manage_operations() then raise exception 'forbidden' using errcode='42501'; end if;
  update public.notification_queue set status='pending', next_retry_at=null, attempt_count=0, error_message=null, updated_at=now()
    where id=p_queue_id and channel='email' and status in ('failed','pending','skipped');
  perform public.log_platform_audit('notification_retry', p_queue_id::text, '{}'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_revoke_platform_role(p_email text, p_role text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.is_superadmin() then raise exception 'forbidden' using errcode='42501'; end if;
  delete from public.platform_user_roles where lower(email)=lower(p_email) and role=p_role;
  perform public.log_platform_audit('role_revoked', lower(p_email), jsonb_build_object('role', p_role));
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_send_upgrade_suggestion(p_company_id uuid, p_plan_id uuid, p_message text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_plan text;
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  select name into v_plan from subscription_plans where id=p_plan_id;
  perform public.notify_event(p_company_id, 'upgrade_suggestion',
    jsonb_build_object('planName', coalesce(v_plan,'en högre plan'),
      'message', coalesce(nullif(trim(p_message),''), 'Hör av dig om du vill veta mer om uppgradering.'),
      'actionUrl','https://app.bokpilot.se/installningar/abonnemang'),
    'subscription', null, '/installningar/abonnemang', null, null, 'normal');
  perform public.log_platform_audit('upgrade_suggestion_sent', p_company_id::text, jsonb_build_object('plan_id', p_plan_id));
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_set_company_plan(p_company_id uuid, p_plan_id uuid, p_billing_period text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  if p_billing_period not in ('monthly','yearly','trial') then raise exception 'ogiltig billing-period' using errcode='22023'; end if;
  if not exists (select 1 from subscription_plans where id=p_plan_id and is_active) then
    raise exception 'planen finns inte eller är inaktiv' using errcode='22023'; end if;
  insert into company_subscriptions(company_id, plan_id, billing_period, status, current_period_start)
  values (p_company_id, p_plan_id, p_billing_period, 'active', now())
  on conflict (company_id) do update set plan_id=excluded.plan_id, billing_period=excluded.billing_period, updated_at=now();
  perform public.log_platform_audit('subscription_plan_changed', p_company_id::text, jsonb_build_object('plan_id',p_plan_id,'billing_period',p_billing_period));
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_set_company_service_state(p_company_id uuid, p_state text, p_reason text DEFAULT NULL::text, p_note text DEFAULT NULL::text, p_notify boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_prev text; v_name text; v_admins uuid[]; v_label text; v_event text;
begin
  if not public.can_manage_operations() then raise exception 'forbidden' using errcode='42501'; end if;
  if p_state not in ('active','paused','blocked') then raise exception 'ogiltigt service-state' using errcode='22023'; end if;
  select service_state, name into v_prev, v_name from public.companies where id = p_company_id;
  if v_prev is null then raise exception 'företag saknas' using errcode='P0002'; end if;
  update public.companies set
    service_state = p_state,
    service_reason = case when p_state = 'active' then null else p_reason end,
    service_note = case when p_state = 'active' then null else p_note end,
    service_changed_at = now(), service_changed_by = auth.uid(),
    service_state_manual = (p_state <> 'active'), suspended = (p_state <> 'active')
  where id = p_company_id;
  perform public.log_platform_audit('company_service_state_changed', p_company_id::text,
    jsonb_build_object('previous_state', v_prev, 'new_state', p_state, 'reason', p_reason, 'notified', p_notify, 'source','admin'));
  if p_notify then
    v_label := case p_state when 'paused' then 'tillfälligt pausat' when 'blocked' then 'blockerat' else 'återaktiverat' end;
    v_event := case p_state when 'active' then 'service_reactivated' when 'blocked' then 'service_blocked' else 'service_paused' end;
    select array_agg(user_id) into v_admins from public.user_companies where company_id = p_company_id and role = 'admin';
    perform public.notify_event(p_company_id, v_event,
      jsonb_build_object('companyName', v_name, 'stateLabel', v_label, 'reason', coalesce(nullif(p_reason,''),'—'),
        'date', to_char(now(),'YYYY-MM-DD'), 'actionUrl', 'https://app.bokpilot.se/support'),
      'company', p_company_id, 'https://app.bokpilot.se/support',
      v_admins, auth.uid(), case when p_state = 'blocked' then 'high' else 'normal' end, null, array['in_app','email']);
  end if;
  return jsonb_build_object('company_id', p_company_id, 'previous_state', v_prev, 'new_state', p_state);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_set_plan_active(p_id uuid, p_active boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  update subscription_plans set is_active=p_active, updated_at=now() where id=p_id;
  perform public.log_platform_audit(case when p_active then 'plan_activated' else 'plan_deactivated' end, p_id::text, '{}'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_set_subscription_dates(p_company_id uuid, p_trial_ends_at timestamp with time zone, p_current_period_end timestamp with time zone)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_old record;
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  select trial_ends_at, current_period_end into v_old from company_subscriptions where company_id=p_company_id;
  insert into company_subscriptions(company_id, trial_ends_at, current_period_end) values (p_company_id, p_trial_ends_at, p_current_period_end)
  on conflict (company_id) do update set trial_ends_at=p_trial_ends_at, current_period_end=p_current_period_end, updated_at=now();
  if v_old is null or v_old.trial_ends_at is distinct from p_trial_ends_at then
    perform public.log_platform_audit('subscription_trial_changed', p_company_id::text, jsonb_build_object('trial_ends_at',p_trial_ends_at)); end if;
  if v_old is null or v_old.current_period_end is distinct from p_current_period_end then
    perform public.log_platform_audit('subscription_period_changed', p_company_id::text, jsonb_build_object('current_period_end',p_current_period_end)); end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_set_subscription_discount(p_company_id uuid, p_percent numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  if p_percent is null or p_percent < 0 or p_percent > 100 then raise exception 'ogiltig rabatt (0-100)' using errcode='22023'; end if;
  update public.company_subscriptions set discount_percent = p_percent, updated_at = now() where company_id = p_company_id;
  perform public.log_platform_audit('admin_set_discount', p_company_id::text, jsonb_build_object('percent', p_percent));
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_set_subscription_grace(p_company_id uuid, p_grace_until timestamp with time zone)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  update public.company_subscriptions set grace_until = p_grace_until, updated_at = now() where company_id = p_company_id;
  perform public.log_platform_audit('admin_set_grace', p_company_id::text, jsonb_build_object('grace_until', p_grace_until));
  return public.sync_company_service_state_from_billing(p_company_id);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_set_subscription_status(p_company_id uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_label text; v_msg text; v_action text;
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  if p_status not in ('trial','active','past_due','suspended','cancelled','expired') then raise exception 'ogiltig status' using errcode='22023'; end if;
  insert into company_subscriptions(company_id, status) values (p_company_id, p_status)
  on conflict (company_id) do update set status=p_status,
    suspended_at = case when p_status='suspended' then now() when company_subscriptions.status='suspended' and p_status<>'suspended' then null else company_subscriptions.suspended_at end,
    cancelled_at = case when p_status='cancelled' then now() else company_subscriptions.cancelled_at end,
    updated_at=now();
  v_action := case p_status when 'suspended' then 'subscription_suspended' when 'cancelled' then 'subscription_cancelled'
    when 'active' then 'subscription_reactivated' else 'subscription_status_changed' end;
  perform public.log_platform_audit(v_action, p_company_id::text, jsonb_build_object('status',p_status));
  -- Notis till kund vid kritiska statusbyten (stabil källa: statusändringen).
  if p_status in ('past_due','suspended','cancelled') then
    v_label := case p_status when 'past_due' then 'Förfallen betalning' when 'suspended' then 'Pausat' when 'cancelled' then 'Avslutat' end;
    v_msg := case p_status
      when 'past_due' then 'Ditt abonnemang har en förfallen betalning. Uppdatera betalningen för att undvika avbrott.'
      when 'suspended' then 'Ditt abonnemang är pausat. Kontakta oss för att återaktivera.'
      else 'Ditt abonnemang har avslutats.' end;
    perform public.notify_event(p_company_id, 'subscription_status_changed',
      jsonb_build_object('statusLabel',v_label,'message',v_msg,'actionUrl','https://app.bokpilot.se/installningar'),
      'subscription', null, '/installningar', null, null,
      case when p_status='past_due' then 'high' else 'normal' end);
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_sync_service_state(p_company_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  return public.sync_company_service_state_from_billing(p_company_id);
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_system_overview()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_workers jsonb; v_queue jsonb; v_errors jsonb; v_deliv jsonb;
  v_components text[] := array['imap-import','inbound-email','tolka-underlag','email-worker','scheduled-notifications'];
begin
  if not public.can_view_operations() then raise exception 'forbidden' using errcode = '42501'; end if;
  select jsonb_agg(jsonb_build_object('component', comp,
    'last_success_at', wh.last_success_at, 'last_failure_at', wh.last_failure_at,
    'consecutive_failures', coalesce(wh.consecutive_failures,0), 'last_error', wh.last_error,
    'last_severity', sev.severity, 'has_record', (wh.component is not null),
    'status', case when wh.component is null then 'unknown'
      when coalesce(wh.consecutive_failures,0) > 0 then 'failing'
      when sev.severity in ('error','critical') and sev.created_at > now() - interval '24 hours' then 'failing'
      when sev.severity = 'warning' and sev.created_at > now() - interval '24 hours' then 'warning'
      when wh.last_success_at is null or wh.last_success_at < now() - interval '24 hours' then 'warning'
      else 'healthy' end) order by comp) into v_workers
  from unnest(v_components) comp
  left join worker_health wh on wh.component = comp
  left join lateral (select e.payload->>'severity' severity, e.created_at from notification_events e
    where e.event_type='system_error' and e.payload->>'component'=comp order by e.created_at desc limit 1) sev on true;
  select jsonb_build_object('pending', count(*) filter (where status='pending'),
    'processing', count(*) filter (where status='processing'),
    'sent_today', count(*) filter (where status='sent' and updated_at >= date_trunc('day', now())),
    'failed', count(*) filter (where status='failed'), 'skipped', count(*) filter (where status='skipped'),
    'cancelled', count(*) filter (where status='cancelled'),
    'retries_scheduled', count(*) filter (where status='pending' and next_retry_at is not null and next_retry_at > now()),
    'oldest_pending_age_seconds', coalesce(extract(epoch from (now() - min(scheduled_at) filter (where status='pending')))::int, 0)
  ) into v_queue from notification_queue where channel='email';
  select jsonb_agg(row_to_json(t)) into v_errors from (
    select e.id, e.created_at, e.payload->>'component' component, e.payload->>'severity' severity,
      e.payload->>'errorCode' error_code, e.payload->>'message' message, e.dedupe_key,
      e.acknowledged_at, (e.acknowledged_by is not null) acknowledged,
      exists(select 1 from notification_queue q where q.event_id=e.id and q.channel='email') has_email_queue
    from notification_events e where e.event_type='system_error' order by e.created_at desc limit 50) t;
  select jsonb_agg(row_to_json(t)) into v_deliv from (
    select q.id queue_id, q.subject, q.status, q.attempt_count, q.max_attempts, q.next_retry_at, q.event_id,
      d.failure_reason, d.failed_at, d.last_attempt_at, u.email recipient
    from notification_queue q left join notification_deliveries d on d.queue_id = q.id
    left join auth.users u on u.id = q.user_id
    where q.channel='email' and (q.status='failed' or (q.status='pending' and q.attempt_count > 0))
    order by coalesce(d.last_attempt_at, q.updated_at) desc limit 30) t;
  return jsonb_build_object('workers', coalesce(v_workers,'[]'::jsonb), 'queue', v_queue,
    'systemErrors', coalesce(v_errors,'[]'::jsonb), 'failedDeliveries', coalesce(v_deliv,'[]'::jsonb),
    'generatedAt', now());
end $function$
;

CREATE OR REPLACE FUNCTION public.admin_upsert_plan(p_id uuid, p_name text, p_description text, p_monthly numeric, p_yearly numeric, p_max_users integer, p_max_companies integer, p_max_invoices integer, p_max_documents integer, p_max_storage_mb integer, p_max_ai integer, p_support_level text, p_features jsonb, p_stripe_product_id text DEFAULT NULL::text, p_stripe_price_monthly text DEFAULT NULL::text, p_stripe_price_yearly text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid; v_prod text; v_pm text; v_py text;
begin
  if not public.can_manage_billing() then raise exception 'forbidden' using errcode='42501'; end if;
  if coalesce(trim(p_name),'')='' then raise exception 'namn krävs' using errcode='22023'; end if;
  v_prod := nullif(trim(coalesce(p_stripe_product_id,'')),'');
  v_pm := nullif(trim(coalesce(p_stripe_price_monthly,'')),'');
  v_py := nullif(trim(coalesce(p_stripe_price_yearly,'')),'');
  if v_prod is not null and v_prod not like 'prod_%' then raise exception 'Stripe product id måste börja med prod_' using errcode='22023'; end if;
  if v_pm is not null and v_pm not like 'price_%' then raise exception 'Stripe monthly price id måste börja med price_' using errcode='22023'; end if;
  if v_py is not null and v_py not like 'price_%' then raise exception 'Stripe yearly price id måste börja med price_' using errcode='22023'; end if;
  if p_id is null then
    insert into subscription_plans(name,description,monthly_price,yearly_price,max_users,max_companies,max_invoices_per_month,max_documents_per_month,max_storage_mb,max_ai_operations_per_month,support_level,features,stripe_product_id,stripe_price_monthly,stripe_price_yearly)
    values (p_name,p_description,coalesce(p_monthly,0),coalesce(p_yearly,0),p_max_users,p_max_companies,p_max_invoices,p_max_documents,p_max_storage_mb,p_max_ai,p_support_level,coalesce(p_features,'[]'::jsonb),v_prod,v_pm,v_py)
    returning id into v_id;
    perform public.log_platform_audit('plan_created', v_id::text, jsonb_build_object('name',p_name,'stripe', (v_pm is not null or v_py is not null)));
  else
    update subscription_plans set name=p_name, description=p_description, monthly_price=coalesce(p_monthly,0), yearly_price=coalesce(p_yearly,0),
      max_users=p_max_users, max_companies=p_max_companies, max_invoices_per_month=p_max_invoices, max_documents_per_month=p_max_documents,
      max_storage_mb=p_max_storage_mb, max_ai_operations_per_month=p_max_ai, support_level=p_support_level, features=coalesce(p_features,'[]'::jsonb),
      stripe_product_id=v_prod, stripe_price_monthly=v_pm, stripe_price_yearly=v_py, updated_at=now()
    where id=p_id returning id into v_id;
    perform public.log_platform_audit('plan_updated', v_id::text, jsonb_build_object('name',p_name,'stripe', (v_pm is not null or v_py is not null)));
  end if;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.ai_claim_job(p_document_id uuid, p_company_id uuid, p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  select count(*) filter (where user_id = p_user_id),
         count(*) filter (where company_id = p_company_id)
    into v_user_calls, v_company_calls
    from public.ai_call_log where created_at > v_now - interval '60 seconds';
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
end $function$
;

CREATE OR REPLACE FUNCTION public.ai_finish_job(p_document_id uuid, p_company_id uuid, p_status text, p_cooldown_seconds integer DEFAULT 0, p_user_id uuid DEFAULT NULL::uuid, p_error text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_until timestamptz := now() + make_interval(secs => greatest(0, p_cooldown_seconds));
begin
  update public.documents
     set ai_status = p_status,
         ai_cooldown_until = case when p_cooldown_seconds > 0 then v_until else ai_cooldown_until end,
         ai_last_error = left(coalesce(p_error, ai_last_error), 1000),
         ai_job_started_at = null
   where id = p_document_id and company_id = p_company_id;
  if p_cooldown_seconds > 0 then
    insert into public.ai_cooldowns(scope, scope_key, cooldown_until, reason) values
      ('document', p_document_id::text, v_until, p_status),
      ('company', p_company_id::text, v_until, p_status)
      on conflict (scope, scope_key) do update set cooldown_until = excluded.cooldown_until, reason = excluded.reason, updated_at = now();
    if p_user_id is not null then
      insert into public.ai_cooldowns(scope, scope_key, cooldown_until, reason)
        values ('user', p_user_id::text, v_until, p_status)
        on conflict (scope, scope_key) do update set cooldown_until = excluded.cooldown_until, reason = excluded.reason, updated_at = now();
    end if;
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.aml_run_checks(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_installningar aml_installningar%rowtype; v_byra uuid;
  v_nya int := 0;
  v_rad record;
begin
  if not public.ar_min_klient(p_company_id) then
    raise exception 'ATKOMST_NEKAD: bolaget är inte klient hos din byrå';
  end if;
  select bk.byra_bolag_id into v_byra from byra_klient bk where bk.klient_bolag_id = p_company_id and bk.status = 'aktiv' and bk.byra_bolag_id in (select public.mina_byraer()) limit 1; insert into aml_installningar (byra_bolag_id) values (v_byra) on conflict (byra_bolag_id) do nothing; select * into v_installningar from aml_installningar where byra_bolag_id = v_byra;

  for v_rad in
    select v.id as verifikation_id, v.ver_serie, v.ver_nr, v.datum,
           greatest(coalesce(sum(vr.debet) filter (where vr.account_nr between '1910' and '1919'), 0),
                    coalesce(sum(vr.kredit) filter (where vr.account_nr between '1910' and '1919'), 0)) as kontantbelopp
    from verifikationer v
    join verifikation_rows vr on vr.verifikation_id = v.id
    where v.company_id = p_company_id
      and vr.account_nr between '1910' and '1919'
    group by v.id, v.ver_serie, v.ver_nr, v.datum
    having greatest(coalesce(sum(vr.debet) filter (where vr.account_nr between '1910' and '1919'), 0),
                    coalesce(sum(vr.kredit) filter (where vr.account_nr between '1910' and '1919'), 0))
           >= v_installningar.kontantgrans_kr
  loop
    insert into aml_flags (company_id, typ, allvarlighet, verifikation_id, beskrivning, dedup_nyckel)
    values (p_company_id, 'kontantgrans', 'normal', v_rad.verifikation_id,
            format('Kontantrörelse %s kr i %s%s (%s) är minst gränsen %s kr',
                   round(v_rad.kontantbelopp, 2), v_rad.ver_serie, v_rad.ver_nr, v_rad.datum,
                   v_installningar.kontantgrans_kr),
            'kontantgrans:' || v_rad.verifikation_id)
    on conflict (company_id, dedup_nyckel) do nothing;
    if found then v_nya := v_nya + 1; end if;
  end loop;

  for v_rad in
    select min(x.datum) as fran, max(x.datum) as till, count(*) as antal, sum(x.belopp) as summa
    from (
      select v2.id, v2.datum,
             greatest(coalesce(sum(vr.debet) filter (where vr.account_nr between '1910' and '1919'), 0),
                      coalesce(sum(vr.kredit) filter (where vr.account_nr between '1910' and '1919'), 0)) as belopp
      from verifikationer v2
      join verifikation_rows vr on vr.verifikation_id = v2.id
      where v2.company_id = p_company_id and vr.account_nr between '1910' and '1919'
      group by v2.id, v2.datum
    ) x
    where x.belopp >= v_installningar.kontantgrans_kr * v_installningar.strukturering_andel_av_grans
      and x.belopp <  v_installningar.kontantgrans_kr
    group by div((x.datum - date '2020-01-01'), v_installningar.strukturering_fonster_dagar)
    having count(*) >= v_installningar.strukturering_min_antal
  loop
    insert into aml_flags (company_id, typ, allvarlighet, beskrivning, dedup_nyckel)
    values (p_company_id, 'strukturering', 'hog',
            format('%s kontantrörelser à 70 till 100 procent av gränsen (%s till %s, totalt %s kr) - möjligt struktureringsmönster',
                   v_rad.antal, v_rad.fran, v_rad.till, round(v_rad.summa, 2)),
            'strukturering:' || v_rad.fran || ':' || v_rad.till || ':' || v_rad.antal)
    on conflict (company_id, dedup_nyckel) do nothing;
    if found then v_nya := v_nya + 1; end if;
  end loop;

  if exists (select 1 from verifikationer where company_id = p_company_id)
     and not public.has_kyc_clearance(p_company_id) then
    insert into aml_flags (company_id, typ, allvarlighet, beskrivning, dedup_nyckel)
    values (p_company_id, 'kyc_saknas', 'hog',
            'Bolaget har bokförd aktivitet men saknar giltig godkänd kundkännedom (KYC) - automation spärrad',
            'kyc_saknas:' || to_char(current_date, 'YYYY-MM'))
    on conflict (company_id, dedup_nyckel) do nothing;
    if found then v_nya := v_nya + 1; end if;
  end if;

  return jsonb_build_object(
    'company_id', p_company_id,
    'nya_flaggor', v_nya,
    'oppna_flaggor', (select count(*) from aml_flags where company_id = p_company_id and status = 'oppen'),
    'kyc_clearance', public.has_kyc_clearance(p_company_id)
  );
end;
$function$
;

CREATE OR REPLACE FUNCTION public.annual_report_ai_context(p_draft uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_eng uuid; v_estatus text; v_dstatus text; v_ctx jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, engagement_id, status into v_company, v_eng, v_dstatus from annual_report_drafts where id=p_draft;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then
    perform log_bokslut_denied('annual_report_ai_context','ej medlem',v_company,v_eng); raise exception 'forbidden' using errcode='42501'; end if;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_ai_context','roll saknar behörighet',v_company,v_eng);
    raise exception 'Behörighet saknas: din roll får inte generera årsredovisningstext.' using errcode='42501'; end if;
  select status into v_estatus from bokslut_engagements where id=v_eng;

  select jsonb_build_object(
    'company', (select jsonb_build_object('name',name,'org_nr',org_nr,'sate',sate,'foretagsform',foretagsform) from companies where id=v_company),
    'regelverk', (select regelverk from annual_report_drafts where id=p_draft),
    'period', (select jsonb_build_object('start',period_start,'end',period_end) from annual_report_drafts where id=p_draft),
    'engagement_locked', (v_estatus='last'),
    'resultatrakning', (select structured_data from annual_report_draft_sections where draft_id=p_draft and section_key='resultatrakning'),
    'balansrakning', (select structured_data from annual_report_draft_sections where draft_id=p_draft and section_key='balansrakning'),
    'checks_summary', (select jsonb_build_object(
        'critical', count(*) filter (where risk_level='critical' and status in ('open','in_progress','needs_review')),
        'high', count(*) filter (where risk_level='high' and status in ('open','in_progress','needs_review')))
      from bokslut_checks where engagement_id=v_eng),
    'attachments', coalesce((select jsonb_agg(jsonb_build_object('type',type,'title',title,'differens',differens))
      from bokslut_attachments where engagement_id=v_eng and differens is not null and abs(differens)>0.5), '[]'::jsonb),
    'validation_open', coalesce((select jsonb_object_agg(severity, n) from (
        select severity, count(*) n from annual_report_validation_items where draft_id=p_draft and status='open' group by severity) s), '{}'::jsonb),
    'current_texts', jsonb_build_object(
      'forvaltningsberattelse', (select left(content,4000) from annual_report_draft_sections where draft_id=p_draft and section_key='forvaltningsberattelse'),
      'noter', (select left(content,4000) from annual_report_draft_sections where draft_id=p_draft and section_key='noter'))
  ) into v_ctx;
  return v_ctx;
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_finalize_server_pdf(p_export uuid, p_storage_path text, p_file_name text, p_file_size bigint, p_checksum text, p_render_engine text DEFAULT 'pdf-lib'::text, p_quality_status text DEFAULT 'not_checked'::text, p_quality_report jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_eng uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if p_quality_status not in ('not_checked','passed','failed','warning') then raise exception 'ogiltig quality_status' using errcode='22023'; end if;
  select company_id, engagement_id into v_company, v_eng from annual_report_exports where id=p_export;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_pdf_finalize','roll saknar behörighet',v_company,v_eng); raise exception 'Behörighet saknas.' using errcode='42501'; end if;
  update annual_report_exports set
    status='ready', storage_bucket='annual-report-exports', storage_path=p_storage_path,
    file_path=p_storage_path, file_name=p_file_name, file_size=p_file_size, checksum=p_checksum,
    render_engine=p_render_engine, quality_status=p_quality_status, quality_report=coalesce(p_quality_report,'{}'::jsonb), error=null
  where id=p_export;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_export_ready', jsonb_build_object('export_id',p_export,'file_name',p_file_name,'file_size',p_file_size,'quality_status',p_quality_status,'render_engine',p_render_engine));
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_generate_ai_texts(p_draft uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_company uuid; v_eng uuid; v_estatus text; v_dstatus text;
  v_cname text; v_corg text; v_sate text; v_start date; v_end date; v_res text;
  v_forv text; v_noter text; v_payload jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, engagement_id, status, period_start, period_end into v_company, v_eng, v_dstatus, v_start, v_end from annual_report_drafts where id=p_draft;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then
    perform log_bokslut_denied('annual_report_generate_ai_texts','ej medlem',v_company,v_eng); raise exception 'forbidden' using errcode='42501'; end if;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_generate_ai_texts','roll saknar behörighet',v_company,v_eng);
    raise exception 'Behörighet saknas: din roll får inte generera årsredovisningstext.' using errcode='42501'; end if;
  select status into v_estatus from bokslut_engagements where id=v_eng;
  if v_estatus='last' or v_dstatus='locked' then
    perform log_bokslut_denied('annual_report_generate_ai_texts','låst (read-only)',v_company,v_eng);
    raise exception 'Låst – endast läsläge.' using errcode='42501'; end if;

  select name, org_nr, sate into v_cname, v_corg, v_sate from companies where id=v_company;
  select coalesce(structured_data->>'arets_resultat','0') into v_res from annual_report_draft_sections where draft_id=p_draft and section_key='balansrakning';

  v_forv := format(E'Allmänt om verksamheten\n%s (org.nr %s)%s bedriver verksamhet enligt bolagsordningen. Räkenskapsåret omfattar %s–%s. Närmare beskrivning av verksamheten: Uppgift saknas. Kräver manuell granskning.\n\nVäsentliga händelser under räkenskapsåret\nUppgift saknas. Kräver manuell granskning.\n\nFlerårsöversikt\nJämförelsetal saknas eller kunde inte beräknas. Kräver manuell granskning.\n\nResultatdisposition\nÅrets resultat enligt bokföringen uppgår till %s kr. Förslag till disposition kräver manuell granskning och beslut av bolagsstämman.',
    coalesce(v_cname,'—'), coalesce(v_corg,'—'), case when coalesce(v_sate,'')<>'' then ' med säte i '||v_sate else '' end, v_start::text, v_end::text, v_res);
  v_noter := E'Not 1 – Redovisnings- och värderingsprinciper\nÅrsredovisningen är upprättad enligt årsredovisningslagen (1995:1554) och Bokföringsnämndens allmänna råd BFNAR 2016:10 (K2). Tillgångar, avsättningar och skulder har värderats till anskaffningsvärden om inget annat anges nedan.\n\nNot 2 – Medelantal anställda\nUppgift saknas. Kräver manuell granskning.\n\nNot 3 – Ställda säkerheter och eventualförpliktelser\nUppgift saknas. Kräver manuell granskning. (Får inte anges utan underlag.)\n\nÖvriga noter\nUppgift saknas. Kräver manuell granskning.';

  v_payload := jsonb_build_object('model','rule-based','prompt_version','rule-text-1','sections', jsonb_build_array(
    jsonb_build_object('section_key','forvaltningsberattelse','content',v_forv,'source_summary',jsonb_build_object('kalla','rule-based','baserat_pa',jsonb_build_array('companies','structured_data'),'note','Endast kända uppgifter; saknad data markerad "Uppgift saknas".')),
    jsonb_build_object('section_key','noter','content',v_noter,'source_summary',jsonb_build_object('kalla','rule-based','baserat_pa',jsonb_build_array('K2-principer'),'note','Endast principnot ifylld; övriga noter kräver manuell granskning.'))
  ));
  return public.annual_report_save_ai_texts(p_draft, v_payload);
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_generate_k2_draft(p_engagement uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_company uuid; v_status text; v_fy uuid; v_start date; v_end date; v_year int;
  v_cname text; v_corg text; v_sate text; v_draft uuid;
  v_intakter numeric; v_kostnader numeric; v_fin numeric; v_resultat numeric; v_tillg numeric; v_ek_skuld numeric; v_baldiff numeric; v_bal boolean;
  v_checks int; v_att int; v_sugg int; v_res_txt text;
  v_rr jsonb; v_br jsonb; v_refs jsonb;
  v_forv text; v_rr_txt text; v_br_txt text; v_noter text; v_fast text; v_under text;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, status, fiscal_year_id into v_company, v_status, v_fy from bokslut_engagements where id=p_engagement;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then
    perform log_bokslut_denied('annual_report_generate','ej medlem',v_company,p_engagement); raise exception 'forbidden' using errcode='42501'; end if;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_generate','roll saknar behörighet',v_company,p_engagement);
    raise exception 'Behörighet saknas: din roll får inte skapa årsredovisningsutkast.' using errcode='42501'; end if;
  if v_status='last' then
    perform log_bokslut_denied('annual_report_generate','engagemang låst',v_company,p_engagement);
    raise exception 'Engagemanget är låst.' using errcode='42501'; end if;

  select year, start_date, end_date into v_year, v_start, v_end from fiscal_years where id=v_fy;
  select name, org_nr, sate into v_cname, v_corg, v_sate from companies where id=v_company;

  insert into annual_report_drafts (engagement_id, company_id, fiscal_year_id, regelverk, status, title, period_start, period_end, generated_by, generated_at)
  values (p_engagement, v_company, v_fy, 'K2', 'needs_review', 'Årsredovisning '||coalesce(v_year::text,''), v_start, v_end, auth.uid(), now())
  on conflict (engagement_id) do update set period_start=excluded.period_start, period_end=excluded.period_end, generated_by=auth.uid(), generated_at=now(), updated_at=now()
  returning id into v_draft;

  if exists (select 1 from annual_report_drafts where id=v_draft and status='locked') then
    perform log_bokslut_denied('annual_report_generate','utkast låst',v_company,p_engagement);
    raise exception 'Utkastet är låst.' using errcode='42501'; end if;

  with mov as (
    select r.account_nr, sum(coalesce(r.debet,0)-coalesce(r.kredit,0)) m
    from verifikation_rows r join verifikationer v on v.id=r.verifikation_id
    where v.company_id=v_company and v.makulerad_av is null and v.datum between v_start and v_end
    group by r.account_nr
  ), bal as (
    select a.account_class ac, coalesce(a.opening_balance,0)+coalesce(mv.m,0) closing, coalesce(mv.m,0) movv
    from accounts a left join mov mv on mv.account_nr=a.account_nr
    where a.company_id=v_company
  )
  select
    coalesce(-sum(movv) filter (where ac=3),0),
    coalesce(sum(movv) filter (where ac between 4 and 7),0),
    coalesce(sum(movv) filter (where ac=8),0),
    coalesce(-sum(movv) filter (where ac between 3 and 8),0),
    coalesce(sum(closing) filter (where ac=1),0),
    coalesce(-sum(closing) filter (where ac=2),0)
  into v_intakter, v_kostnader, v_fin, v_resultat, v_tillg, v_ek_skuld
  from bal;

  v_baldiff := round(v_tillg - (v_ek_skuld + v_resultat),2);
  v_bal := abs(v_baldiff) < 0.5;
  v_res_txt := round(v_resultat,2)::text;

  select count(*) into v_checks from bokslut_checks where engagement_id=p_engagement and status not in ('resolved','ignored');
  select count(*) into v_att from bokslut_attachments where engagement_id=p_engagement;
  select count(*) into v_sugg from bokslut_ai_suggestions where engagement_id=p_engagement;

  v_rr := jsonb_build_object('rorelsens_intakter',round(v_intakter,2),'rorelsens_kostnader',round(v_kostnader,2),'finansiella_poster_och_skatt',round(v_fin,2),'arets_resultat',round(v_resultat,2),'jamforelsetal','Jämförelsetal saknas eller kunde inte beräknas.','kalla','verifikation_rows + accounts (huvudbok)');
  v_br := jsonb_build_object('summa_tillgangar',round(v_tillg,2),'eget_kapital_och_skulder',round(v_ek_skuld,2),'arets_resultat',round(v_resultat,2),'balanskontroll_differens',v_baldiff,'balanserar',v_bal,'jamforelsetal','Jämförelsetal saknas eller kunde inte beräknas.','kalla','verifikation_rows + accounts (huvudbok)');
  v_refs := jsonb_build_object('kalla','bokslut_engagement','checks_oppna',v_checks,'bilagor',v_att,'ai_forslag',v_sugg);

  v_forv := format(E'Allmänt om verksamheten\n%s (org.nr %s). Säte: %s. Räkenskapsår: %s–%s.\nBeskrivning av verksamheten: Uppgift saknas. Kräver manuell granskning.\n\nVäsentliga händelser under räkenskapsåret\nUppgift saknas. Kräver manuell granskning.\n\nFlerårsöversikt\nJämförelsetal saknas eller kunde inte beräknas.\n\nFörslag till resultatdisposition\nÅrets resultat: %s kr. Förslag till disposition kräver manuell granskning.',
    coalesce(v_cname,'—'), coalesce(v_corg,'—'), coalesce(v_sate,'—'), v_start::text, v_end::text, v_res_txt);
  v_rr_txt := format(E'Resultaträkning %s–%s.\nBeloppen är beräknade från bokföringen (huvudbok) och får inte ändras av AI. Jämförelsetal saknas eller kunde inte beräknas.', v_start::text, v_end::text);
  v_br_txt := format(E'Balansräkning per %s. Beloppen är beräknade från bokföringen (huvudbok).%s', v_end::text,
    case when v_bal then '' else E'\nOBS: Tillgångar och Eget kapital + skulder balanserar inte. Kräver manuell granskning.' end);
  v_noter := E'Not 1 – Redovisnings- och värderingsprinciper\nÅrsredovisningen är upprättad enligt årsredovisningslagen och Bokföringsnämndens allmänna råd BFNAR 2016:10 (K2).\n\nÖvriga noter (eventualförpliktelser, ställda säkerheter, medelantal anställda m.m.)\nUppgift saknas. Kräver manuell granskning.';
  v_fast := E'Fastställelseintyg\nUndertecknad intygar att resultaträkningen och balansräkningen har fastställts på årsstämma den [datum]. Uppgift saknas. Kräver manuell granskning.';
  v_under := E'Underskrifter\nOrt och datum: ____________________\n\nStyrelsens ledamöter: Uppgift saknas. Kräver manuell granskning.\n\nRevisorspåteckning (i förekommande fall): Uppgift saknas. Kräver manuell granskning.';

  insert into annual_report_draft_sections (draft_id, company_id, section_key, title, content, structured_data, source_references, ai_generated, requires_review, review_status, sort_order) values
    (v_draft, v_company, 'forvaltningsberattelse','Förvaltningsberättelse', v_forv, '{}'::jsonb, v_refs, false, true, 'needs_review', 1),
    (v_draft, v_company, 'resultatrakning','Resultaträkning', v_rr_txt, v_rr, v_refs, false, true, 'needs_review', 2),
    (v_draft, v_company, 'balansrakning','Balansräkning', v_br_txt, v_br, v_refs, false, true, 'needs_review', 3),
    (v_draft, v_company, 'noter','Noter', v_noter, '{}'::jsonb, v_refs, false, true, 'needs_review', 4),
    (v_draft, v_company, 'faststallelseintyg','Fastställelseintyg', v_fast, '{}'::jsonb, v_refs, false, true, 'needs_review', 5),
    (v_draft, v_company, 'underskriftssida','Underskriftssida', v_under, '{}'::jsonb, v_refs, false, true, 'needs_review', 6)
  on conflict (draft_id, section_key) do update
    set content=excluded.content, structured_data=excluded.structured_data, source_references=excluded.source_references, title=excluded.title, sort_order=excluded.sort_order, updated_at=now();

  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, model, detail)
  values (p_engagement, v_company, auth.uid(), 'annual_report_generated', 'rule-based', jsonb_build_object('draft_id',v_draft,'arets_resultat',round(v_resultat,2),'balanserar',v_bal,'sections',6));

  return jsonb_build_object('ok',true,'draft_id',v_draft,'arets_resultat',round(v_resultat,2),'balanserar',v_bal,'sections',6);
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_get_export_download_url(p_export uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_eng uuid; v_status text; v_bucket text; v_path text; v_name text;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, engagement_id, status, storage_bucket, storage_path, file_name into v_company, v_eng, v_status, v_bucket, v_path, v_name
  from annual_report_exports where id=p_export;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not (public.has_ai_feature(v_company,'ai_bokslut_arsredovisning') and exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company)) then
    perform log_bokslut_denied('annual_report_pdf_download','licens/medlemskap saknas',v_company,v_eng); raise exception 'forbidden' using errcode='42501'; end if;
  if v_status <> 'ready' or v_path is null then raise exception 'Ingen färdig PDF att ladda ner.' using errcode='P0002'; end if;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_export_opened', jsonb_build_object('export_id',p_export));
  return jsonb_build_object('bucket', v_bucket, 'path', v_path, 'file_name', v_name);
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_get_or_create_draft(p_engagement uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_status text; v_fy uuid; v_start date; v_end date; v_year int; v_draft public.annual_report_drafts;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, status, fiscal_year_id into v_company, v_status, v_fy from bokslut_engagements where id=p_engagement;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not public.has_ai_feature(v_company,'ai_bokslut_arsredovisning')
     or not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then
    perform log_bokslut_denied('annual_report_read','licens/medlemskap saknas',v_company,p_engagement);
    raise exception 'forbidden' using errcode='42501';
  end if;

  select * into v_draft from annual_report_drafts where engagement_id=p_engagement;
  if found then return to_jsonb(v_draft); end if;

  -- inget utkast finns: endast admin får skapa
  if not public.bokslut_can(v_company,'annual_report_write') then return null; end if;
  if v_status='last' then return null; end if;

  select year, start_date, end_date into v_year, v_start, v_end from fiscal_years where id=v_fy;
  insert into annual_report_drafts (engagement_id, company_id, fiscal_year_id, regelverk, status, title, period_start, period_end, generated_by, generated_at)
  values (p_engagement, v_company, v_fy, 'K2', 'draft', 'Årsredovisning '||coalesce(v_year::text,''), v_start, v_end, auth.uid(), now())
  returning * into v_draft;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (p_engagement, v_company, auth.uid(), 'annual_report_draft_created', jsonb_build_object('draft_id', v_draft.id));
  return to_jsonb(v_draft);
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_list_exports(p_draft uuid)
 RETURNS SETOF annual_report_exports
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select * from public.annual_report_exports
  where draft_id=p_draft and company_id in (select public.user_company_ids())
  order by created_at desc;
$function$
;

CREATE OR REPLACE FUNCTION public.annual_report_list_sections(p_draft uuid)
 RETURNS SETOF annual_report_draft_sections
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select * from public.annual_report_draft_sections
  where draft_id=p_draft and company_id in (select public.user_company_ids())
  order by sort_order;
$function$
;

CREATE OR REPLACE FUNCTION public.annual_report_list_validation_items(p_draft uuid)
 RETURNS SETOF annual_report_validation_items
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select * from public.annual_report_validation_items
  where draft_id=p_draft and company_id in (select public.user_company_ids())
  order by case severity when 'critical' then 0 when 'high' then 1 when 'warning' then 2 else 3 end,
           case status when 'open' then 0 when 'ignored' then 1 else 2 end, created_at;
$function$
;

CREATE OR REPLACE FUNCTION public.annual_report_mark_export_failed(p_export uuid, p_error text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_eng uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, engagement_id into v_company, v_eng from annual_report_exports where id=p_export;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_export_failed','roll saknar behörighet',v_company,v_eng); raise exception 'Behörighet saknas.' using errcode='42501'; end if;
  update annual_report_exports set status='failed', error=left(coalesce(p_error,''),500) where id=p_export;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_export_failed', jsonb_build_object('export_id',p_export,'error',left(coalesce(p_error,''),300)));
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_mark_export_ready(p_export uuid, p_file_path text DEFAULT NULL::text, p_file_name text DEFAULT NULL::text, p_file_size bigint DEFAULT NULL::bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_eng uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, engagement_id into v_company, v_eng from annual_report_exports where id=p_export;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_export_ready','roll saknar behörighet',v_company,v_eng); raise exception 'Behörighet saknas.' using errcode='42501'; end if;
  update annual_report_exports set status='ready', file_path=p_file_path, file_name=p_file_name, file_size=p_file_size, error=null where id=p_export;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_export_ready', jsonb_build_object('export_id',p_export,'file_name',p_file_name,'file_size',p_file_size));
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_prepare_export(p_draft uuid, p_export_type text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_eng uuid; v_export uuid; v_vsum jsonb; v_open_hc int;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if p_export_type not in ('review_pdf','html_preview') then raise exception 'ogiltig exporttyp' using errcode='22023'; end if;
  select company_id, engagement_id into v_company, v_eng from annual_report_drafts where id=p_draft;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then
    perform log_bokslut_denied('annual_report_export','ej medlem',v_company,v_eng); raise exception 'forbidden' using errcode='42501'; end if;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_export','roll saknar behörighet',v_company,v_eng);
    raise exception 'Behörighet saknas: din roll får inte exportera årsredovisningsutkast.' using errcode='42501'; end if;
  if not exists (select 1 from annual_report_draft_sections where draft_id=p_draft) then
    raise exception 'Skapa årsredovisningsutkast först.' using errcode='P0002'; end if;

  select jsonb_build_object(
    'open', count(*) filter (where status='open'),
    'critical', count(*) filter (where status='open' and severity='critical'),
    'high', count(*) filter (where status='open' and severity='high'),
    'warning', count(*) filter (where status='open' and severity='warning'),
    'info', count(*) filter (where status='open' and severity='info'),
    'ai_generated_sections', (select count(*) from annual_report_draft_sections where draft_id=p_draft and ai_generated),
    'draft_status', (select status from annual_report_drafts where id=p_draft)
  ) into v_vsum from annual_report_validation_items where draft_id=p_draft;
  v_open_hc := coalesce((v_vsum->>'critical')::int,0) + coalesce((v_vsum->>'high')::int,0);

  insert into annual_report_exports (draft_id, engagement_id, company_id, export_type, status, validation_summary, generated_by, generated_at)
  values (p_draft, v_eng, v_company, p_export_type, 'generating', v_vsum, auth.uid(), now())
  returning id into v_export;

  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_export_prepared', jsonb_build_object('export_id',v_export,'type',p_export_type,'validation',v_vsum));

  return jsonb_build_object('export_id', v_export, 'export_type', p_export_type, 'validation_summary', v_vsum, 'not_ready_for_use', (v_open_hc > 0));
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_request_server_pdf(p_draft uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_eng uuid; v_export uuid; v_vsum jsonb; v_ctx jsonb; v_is_draft bool; v_hc bool; v_ai bool;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, engagement_id into v_company, v_eng from annual_report_drafts where id=p_draft;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then
    perform log_bokslut_denied('annual_report_server_pdf','ej medlem',v_company,v_eng); raise exception 'forbidden' using errcode='42501'; end if;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_server_pdf','roll saknar behörighet',v_company,v_eng);
    raise exception 'Behörighet saknas: din roll får inte skapa arkiv-PDF.' using errcode='42501'; end if;
  if not exists (select 1 from annual_report_draft_sections where draft_id=p_draft) then
    raise exception 'Skapa årsredovisningsutkast först.' using errcode='P0002'; end if;

  select jsonb_build_object(
    'open', count(*) filter (where status='open'),
    'critical', count(*) filter (where status='open' and severity='critical'),
    'high', count(*) filter (where status='open' and severity='high'),
    'warning', count(*) filter (where status='open' and severity='warning'),
    'info', count(*) filter (where status='open' and severity='info')
  ) into v_vsum from annual_report_validation_items where draft_id=p_draft;

  v_is_draft := (select status from annual_report_drafts where id=p_draft) <> 'approved';
  v_hc := coalesce((v_vsum->>'critical')::int,0) + coalesce((v_vsum->>'high')::int,0) > 0;
  v_ai := exists (select 1 from annual_report_draft_sections where draft_id=p_draft and ai_generated);

  insert into annual_report_exports (draft_id, engagement_id, company_id, export_type, status, render_engine, validation_summary, quality_status, generated_by, generated_at)
  values (p_draft, v_eng, v_company, 'archive_pdf', 'generating', 'pdf-lib', v_vsum, 'not_checked', auth.uid(), now())
  returning id into v_export;

  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_export_prepared', jsonb_build_object('export_id',v_export,'type','archive_pdf','validation',v_vsum));

  v_ctx := jsonb_build_object(
    'export_id', v_export,
    'company', (select jsonb_build_object('name',name,'org_nr',org_nr) from companies where id=v_company),
    'draft', (select jsonb_build_object('regelverk',regelverk,'period_start',period_start,'period_end',period_end,'status',status) from annual_report_drafts where id=p_draft),
    'sections', coalesce((select jsonb_agg(jsonb_build_object('section_key',section_key,'title',title,'content',content,'structured_data',structured_data,'ai_generated',ai_generated) order by sort_order)
       from annual_report_draft_sections where draft_id=p_draft), '[]'::jsonb),
    'validation_summary', v_vsum,
    'warnings', jsonb_build_object('is_draft',v_is_draft,'has_high_critical',v_hc,'has_ai',v_ai),
    'storage_path', v_company::text || '/' || p_draft::text || '/' || v_export::text || '.pdf',
    'storage_bucket', 'annual-report-exports'
  );
  return v_ctx;
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_run_pdf_quality_check(p_export uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_eng uuid; v_status text; v_bucket text; v_path text; v_size bigint;
  v_obj_exists bool; v_obj_size bigint; v_report jsonb; v_qs text;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, engagement_id, status, storage_bucket, storage_path, file_size into v_company, v_eng, v_status, v_bucket, v_path, v_size
  from annual_report_exports where id=p_export;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_pdf_quality','roll saknar behörighet',v_company,v_eng); raise exception 'Behörighet saknas.' using errcode='42501'; end if;

  select true, coalesce((metadata->>'size')::bigint, 0) into v_obj_exists, v_obj_size
  from storage.objects where bucket_id=coalesce(v_bucket,'annual-report-exports') and name=v_path limit 1;
  v_obj_exists := coalesce(v_obj_exists,false);

  v_report := jsonb_build_object(
    'db_recheck', jsonb_build_object(
      'status_ready', (v_status='ready'),
      'file_in_storage', v_obj_exists,
      'file_size_positive', (coalesce(v_obj_size, v_size, 0) > 0),
      'file_size', coalesce(v_obj_size, v_size, 0)));
  v_qs := case when (v_status='ready' and v_obj_exists and coalesce(v_obj_size, v_size, 0) > 0) then 'passed' else 'failed' end;

  update annual_report_exports set quality_report = quality_report || v_report,
    -- failed recheck nedgraderar alltid; passed recheck uppgraderar bara från not_checked
    quality_status = case when v_qs='failed' then 'failed' when quality_status='not_checked' then 'passed' else quality_status end
  where id=p_export;

  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_export_quality_checked', jsonb_build_object('export_id',p_export,'result',v_qs));
  return v_report || jsonb_build_object('quality_status', v_qs);
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_run_validation(p_draft uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_company uuid; v_eng uuid; v_estatus text; v_dstatus text;
  v_items jsonb := '[]'::jsonb;
  v_open int; v_critical int; v_high int; v_warning int; v_info int;
  v_required text[] := array['forvaltningsberattelse','resultatrakning','balansrakning','noter','faststallelseintyg','underskriftssida'];
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, engagement_id, status into v_company, v_eng, v_dstatus from annual_report_drafts where id=p_draft;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then
    perform log_bokslut_denied('annual_report_validate','ej medlem',v_company,v_eng); raise exception 'forbidden' using errcode='42501'; end if;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_validate','roll saknar behörighet',v_company,v_eng);
    raise exception 'Behörighet saknas: din roll får inte validera årsredovisningsutkast.' using errcode='42501'; end if;
  select status into v_estatus from bokslut_engagements where id=v_eng;

  -- Regel 1: obligatoriska sektioner finns (critical)
  v_items := v_items || coalesce((
    select jsonb_agg(jsonb_build_object(
      'key','missing_section:'||k, 'title','Saknad sektion: '||public.ar_section_label(k),
      'description','Den obligatoriska sektionen saknas i utkastet.', 'severity','critical',
      'source','section', 'source_data',jsonb_build_object('section_key',k),
      'suggested_action','Skapa/uppdatera K2-utkastet så att sektionen genereras.'))
    from unnest(v_required) k
    where not exists (select 1 from annual_report_draft_sections s where s.draft_id=p_draft and s.section_key=k)
  ), '[]'::jsonb);

  -- Regel 2: sektioner ej granskade/godkända (needs_review/rejected) (high)
  v_items := v_items || coalesce((
    select jsonb_agg(jsonb_build_object(
      'key','section_not_reviewed:'||s.section_key, 'section_id',s.id::text,
      'title','Sektion ej granskad: '||public.ar_section_label(s.section_key),
      'description','Sektionen har status "'||s.review_status||'". Den måste granskas eller godkännas.',
      'severity','high', 'source','section', 'source_data',jsonb_build_object('section_key',s.section_key,'review_status',s.review_status),
      'suggested_action','Öppna sektionen och markera den som granskad eller godkänd.'))
    from annual_report_draft_sections s where s.draft_id=p_draft and s.review_status in ('needs_review','rejected')
  ), '[]'::jsonb);

  -- Regel 4: RR/BR saknar strukturerad data (high)
  v_items := v_items || coalesce((
    select jsonb_agg(jsonb_build_object(
      'key','missing_structured:'||s.section_key, 'section_id',s.id::text,
      'title','Strukturerad data saknas: '||public.ar_section_label(s.section_key),
      'description','Resultat-/balansräkning måste vara strukturerad data (tabell), inte enbart fri text.',
      'severity','high', 'source','section', 'source_data',jsonb_build_object('section_key',s.section_key),
      'suggested_action','Kör "Uppdatera utkast" så att beloppen beräknas från bokföringen.'))
    from annual_report_draft_sections s
    where s.draft_id=p_draft and s.section_key in ('resultatrakning','balansrakning')
      and (s.structured_data is null or s.structured_data = '{}'::jsonb)
  ), '[]'::jsonb);

  -- Regel 3: balansräkningen balanserar inte (critical)
  v_items := v_items || coalesce((
    select jsonb_agg(jsonb_build_object(
      'key','br_not_balancing', 'section_id',s.id::text, 'title','Balansräkningen balanserar inte',
      'description','Tillgångar balanserar inte mot eget kapital och skulder (differens '||coalesce(s.structured_data->>'balanskontroll_differens','?')||').',
      'severity','critical', 'source','section', 'source_data',jsonb_build_object('differens',s.structured_data->>'balanskontroll_differens'),
      'suggested_action','Granska bokföringen och rätta differensen innan godkännande.'))
    from annual_report_draft_sections s
    where s.draft_id=p_draft and s.section_key='balansrakning'
      and s.structured_data ? 'balanserar' and (s.structured_data->>'balanserar') = 'false'
  ), '[]'::jsonb);

  -- Regel 5: jämförelsetal saknas i RR/BR (warning)
  v_items := v_items || coalesce((
    select jsonb_agg(jsonb_build_object(
      'key','comparative_missing:'||s.section_key, 'section_id',s.id::text,
      'title','Jämförelsetal saknas: '||public.ar_section_label(s.section_key),
      'description','Jämförelsetal saknas eller kunde inte beräknas. K2 kräver normalt jämförelseår.',
      'severity','warning', 'source','section', 'source_data',jsonb_build_object('section_key',s.section_key),
      'suggested_action','Lägg in/verifiera jämförelseårets siffror manuellt.'))
    from annual_report_draft_sections s
    where s.draft_id=p_draft and s.section_key in ('resultatrakning','balansrakning')
      and coalesce(s.structured_data->>'jamforelsetal','') ilike '%saknas%'
  ), '[]'::jsonb);

  -- Regel 6: öppna kritiska/höga bokslut_checks (blockerar godkännande)
  v_items := v_items || coalesce((
    select jsonb_agg(jsonb_build_object(
      'key','open_check:'||c.id, 'title','Öppen kontroll ('||c.risk_level||'): '||c.title,
      'description','En kvarstående '||c.risk_level||'-kontroll i bokslutschecklistan måste hanteras.',
      'severity',c.risk_level, 'source','bokslut_check', 'source_data',jsonb_build_object('check_id',c.id,'category',c.category),
      'suggested_action','Åtgärda kontrollen i bokslutschecklistan.'))
    from bokslut_checks c
    where c.engagement_id=v_eng and c.status in ('open','in_progress','needs_review') and c.risk_level in ('critical','high')
  ), '[]'::jsonb);

  -- Regel 7: bokslutsbilagor med differens (high)
  v_items := v_items || coalesce((
    select jsonb_agg(jsonb_build_object(
      'key','attachment_differens:'||a.id, 'title','Bilaga med differens: '||a.title,
      'description','Bokslutsbilagan har en differens ('||a.differens||') mellan huvudbok och avstämt belopp.',
      'severity','high', 'source','bokslut_attachment', 'source_data',jsonb_build_object('attachment_id',a.id,'differens',a.differens),
      'suggested_action','Stäm av bilagan så att differensen blir noll, eller ignorera med motivering.'))
    from bokslut_attachments a
    where a.engagement_id=v_eng and a.differens is not null and abs(a.differens) > 0.5
  ), '[]'::jsonb);

  -- Regel 8: AI-förslag som väntar på granskning (info)
  v_items := v_items || coalesce((
    select jsonb_agg(jsonb_build_object(
      'key','ai_suggestion_open:'||sg.id, 'title','AI-förslag väntar på granskning: '||sg.title,
      'description','Ett AI-granskningsförslag är ännu inte bedömt.',
      'severity','info', 'source','ai_suggestion', 'source_data',jsonb_build_object('suggestion_id',sg.id),
      'suggested_action','Bedöm AI-förslaget (acceptera/avvisa/ignorera/åtgärdad).'))
    from bokslut_ai_suggestions sg
    where sg.engagement_id=v_eng and sg.status='needs_review'
  ), '[]'::jsonb);

  -- Regel 9: noter ofullständiga ("Uppgift saknas") (warning)
  v_items := v_items || coalesce((
    select jsonb_agg(jsonb_build_object(
      'key','noter_incomplete', 'section_id',s.id::text, 'title','Noter ofullständiga',
      'description','Noterna innehåller "Uppgift saknas" och måste kompletteras manuellt.',
      'severity','warning', 'source','section', 'source_data','{}'::jsonb,
      'suggested_action','Komplettera noterna (eventualförpliktelser, ställda säkerheter, medelantal anställda m.m.).'))
    from annual_report_draft_sections s
    where s.draft_id=p_draft and s.section_key='noter' and coalesce(s.content,'') ilike '%Uppgift saknas%'
  ), '[]'::jsonb);

  -- Regel 10: låst engagemang (info, read-only)
  if v_estatus='last' then
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'key','engagement_locked', 'title','Engagemanget är låst', 'description','Engagemanget är låst – validering körs i läsläge och statusändringar är blockerade.',
      'severity','info', 'source','engagement', 'source_data','{}'::jsonb,
      'suggested_action','Inga ändringar kan göras medan engagemanget är låst.'));
  end if;

  -- upsert: öppna/uppdatera nuvarande problem; behåll ignored
  insert into annual_report_validation_items (draft_id, engagement_id, company_id, section_id, validation_key, title, description, severity, status, source, source_data, suggested_action)
  select p_draft, v_eng, v_company,
    case when (it->>'section_id') ~ '^[0-9a-fA-F-]{36}$' then (it->>'section_id')::uuid else null end,
    it->>'key', left(it->>'title',300), it->>'description', it->>'severity', 'open',
    coalesce(it->>'source','rule'), coalesce(it->'source_data','{}'::jsonb), it->>'suggested_action'
  from jsonb_array_elements(v_items) it
  on conflict (draft_id, validation_key) do update set
    title=excluded.title, description=excluded.description, severity=excluded.severity, section_id=excluded.section_id,
    source=excluded.source, source_data=excluded.source_data, suggested_action=excluded.suggested_action, updated_at=now(),
    status = case when annual_report_validation_items.status='ignored' then 'ignored' else 'open' end,
    resolved_by = case when annual_report_validation_items.status='ignored' then annual_report_validation_items.resolved_by else null end,
    resolved_at = case when annual_report_validation_items.status='ignored' then annual_report_validation_items.resolved_at else null end;

  -- auto-resolve: öppna poster vars problem inte längre finns (rör inte ignored)
  update annual_report_validation_items set status='resolved', resolved_by=null, resolved_at=now(), updated_at=now()
  where draft_id=p_draft and status='open'
    and validation_key not in (select it->>'key' from jsonb_array_elements(v_items) it);

  select count(*) filter (where status='open'),
         count(*) filter (where status='open' and severity='critical'),
         count(*) filter (where status='open' and severity='high'),
         count(*) filter (where status='open' and severity='warning'),
         count(*) filter (where status='open' and severity='info')
    into v_open, v_critical, v_high, v_warning, v_info
  from annual_report_validation_items where draft_id=p_draft;

  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, model, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_validation_run', 'rule-based',
    jsonb_build_object('draft_id',p_draft,'open',v_open,'critical',v_critical,'high',v_high,'warning',v_warning,'info',v_info));

  return jsonb_build_object('ok',true,'open',v_open,'critical',v_critical,'high',v_high,'warning',v_warning,'info',v_info);
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_save_ai_texts(p_draft uuid, p_payload jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_company uuid; v_eng uuid; v_estatus text; v_dstatus text;
  v_model text; v_pv text; v_count int := 0; it jsonb; v_sk text; v_content text; v_src jsonb; v_upd int;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, engagement_id, status into v_company, v_eng, v_dstatus from annual_report_drafts where id=p_draft;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then
    perform log_bokslut_denied('annual_report_save_ai_texts','ej medlem',v_company,v_eng); raise exception 'forbidden' using errcode='42501'; end if;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_save_ai_texts','roll saknar behörighet',v_company,v_eng);
    raise exception 'Behörighet saknas: din roll får inte spara årsredovisningstext.' using errcode='42501'; end if;
  select status into v_estatus from bokslut_engagements where id=v_eng;
  if v_estatus='last' or v_dstatus='locked' then
    perform log_bokslut_denied('annual_report_save_ai_texts','låst (read-only)',v_company,v_eng);
    raise exception 'Låst – endast läsläge.' using errcode='42501'; end if;
  if p_payload is null or jsonb_typeof(p_payload->'sections') <> 'array' then return 0; end if;

  v_model := coalesce(p_payload->>'model','ai');
  v_pv := p_payload->>'prompt_version';

  for it in select * from jsonb_array_elements(p_payload->'sections') loop
    v_sk := it->>'section_key';
    -- Avvisa försök att ändra RR/BR via AI-text (siffror får aldrig röras).
    if v_sk in ('resultatrakning','balansrakning') then
      perform log_bokslut_denied('annual_report_save_ai_texts','försök ändra RR/BR via AI-text',v_company,v_eng);
      raise exception 'AI får inte ändra resultaträkning eller balansräkning.' using errcode='42501';
    end if;
    -- Endast tillåtna sektioner; övriga (fastställelseintyg/underskriftssida) ignoreras tyst.
    if v_sk not in ('forvaltningsberattelse','noter') then continue; end if;
    v_content := it->>'content';
    if coalesce(trim(v_content),'') = '' then continue; end if;
    -- Kräv källa (source_summary eller source_references).
    v_src := coalesce(it->'source_summary', it->'source_references');
    if v_src is null or jsonb_typeof(v_src) not in ('object','array') then continue; end if;

    update annual_report_draft_sections set
      content = v_content,
      ai_generated = true,
      requires_review = true,
      review_status = 'needs_review',
      reviewed_by = null, reviewed_at = null,
      ai_model = v_model, ai_prompt_version = v_pv, ai_generated_at = now(),
      ai_source_summary = v_src,
      source_references = case when it ? 'source_references' then it->'source_references' else source_references end,
      updated_at = now()
    where draft_id = p_draft and section_key = v_sk;
    get diagnostics v_upd = row_count;
    v_count := v_count + v_upd;
  end loop;

  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, model, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_ai_texts_saved', v_model,
    jsonb_build_object('draft_id',p_draft,'sections_updated',v_count,'prompt_version',v_pv));
  return v_count;
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_set_draft_status(p_draft uuid, p_status text, p_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_eng uuid; v_estatus text; v_cur text; v_block int;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if p_status not in ('draft','needs_review','reviewed','approved','rejected','locked') then raise exception 'ogiltig status' using errcode='22023'; end if;
  select company_id, status into v_company, v_cur from annual_report_drafts where id=p_draft;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  select e.id, e.status into v_eng, v_estatus from bokslut_engagements e join annual_report_drafts d on d.engagement_id=e.id where d.id=p_draft;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_draft_status','roll saknar behörighet',v_company,v_eng); raise exception 'Behörighet saknas.' using errcode='42501'; end if;
  if v_estatus='last' then
    perform log_bokslut_denied('annual_report_draft_status','engagemang låst',v_company,v_eng); raise exception 'Engagemanget är låst.' using errcode='42501'; end if;
  if v_cur='locked' then
    perform log_bokslut_denied('annual_report_draft_status','utkast redan låst',v_company,v_eng); raise exception 'Utkastet är låst och kan inte ändras.' using errcode='42501'; end if;

  -- Granskningsspärr: godkännande kräver att inga öppna high/critical valideringspunkter finns.
  if p_status='approved' then
    select count(*) into v_block from annual_report_validation_items where draft_id=p_draft and status='open' and severity in ('high','critical');
    if v_block > 0 then
      perform log_bokslut_denied('annual_report_draft_status','godkännande blockerat av validering',v_company,v_eng);
      raise exception 'Kan inte godkänna: % öppna valideringspunkter med hög/kritisk allvarlighetsgrad måste åtgärdas eller ignoreras först. Kör "Validera utkast".', v_block using errcode='42501';
    end if;
  end if;
  -- Låsning kräver att inga öppna kritiska valideringspunkter finns.
  if p_status='locked' then
    select count(*) into v_block from annual_report_validation_items where draft_id=p_draft and status='open' and severity='critical';
    if v_block > 0 then
      perform log_bokslut_denied('annual_report_draft_status','låsning blockerad av validering',v_company,v_eng);
      raise exception 'Kan inte låsa: % öppna kritiska valideringspunkter måste åtgärdas eller ignoreras först.', v_block using errcode='42501';
    end if;
  end if;

  update annual_report_drafts set
    status=p_status,
    reviewed_by = case when p_status in ('reviewed','approved') then auth.uid() else reviewed_by end,
    reviewed_at = case when p_status in ('reviewed','approved') then now() else reviewed_at end,
    approved_by = case when p_status='approved' then auth.uid() else approved_by end,
    approved_at = case when p_status='approved' then now() else approved_at end,
    updated_at = now()
  where id=p_draft;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_draft_status_changed', jsonb_build_object('draft_id',p_draft,'status',p_status,'comment',left(coalesce(p_comment,''),500)));
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_set_section_status(p_section uuid, p_status text, p_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_draft uuid; v_eng uuid; v_estatus text; v_dstatus text;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if p_status not in ('needs_review','reviewed','approved','rejected') then raise exception 'ogiltig status' using errcode='22023'; end if;
  select s.company_id, s.draft_id, d.status into v_company, v_draft, v_dstatus
  from annual_report_draft_sections s join annual_report_drafts d on d.id=s.draft_id where s.id=p_section;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  select e.id, e.status into v_eng, v_estatus from bokslut_engagements e join annual_report_drafts d on d.engagement_id=e.id where d.id=v_draft;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_section_status','roll saknar behörighet',v_company,v_eng); raise exception 'Behörighet saknas.' using errcode='42501'; end if;
  if v_estatus='last' or v_dstatus='locked' then
    perform log_bokslut_denied('annual_report_section_status','låst (read-only)',v_company,v_eng); raise exception 'Låst – endast läsläge.' using errcode='42501'; end if;

  update annual_report_draft_sections
    set review_status=p_status, review_comment=coalesce(p_comment, review_comment),
        reviewed_by=auth.uid(), reviewed_at=now(), updated_at=now()
  where id=p_section;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_section_status_changed', jsonb_build_object('section_id',p_section,'status',p_status));
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_set_validation_item_status(p_item uuid, p_status text, p_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_eng uuid; v_draft uuid; v_estatus text; v_dstatus text;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if p_status not in ('open','resolved','ignored') then raise exception 'ogiltig status' using errcode='22023'; end if;
  select i.company_id, i.engagement_id, i.draft_id, d.status into v_company, v_eng, v_draft, v_dstatus
  from annual_report_validation_items i join annual_report_drafts d on d.id=i.draft_id where i.id=p_item;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  select status into v_estatus from bokslut_engagements where id=v_eng;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_validation_status','roll saknar behörighet',v_company,v_eng); raise exception 'Behörighet saknas.' using errcode='42501'; end if;
  if v_estatus='last' or v_dstatus='locked' then
    perform log_bokslut_denied('annual_report_validation_status','låst (read-only)',v_company,v_eng); raise exception 'Låst – endast läsläge.' using errcode='42501'; end if;
  if p_status='ignored' and coalesce(trim(p_comment),'')='' then raise exception 'Ange en motivering för att ignorera.' using errcode='22023'; end if;

  update annual_report_validation_items set
    status=p_status,
    resolved_by = case when p_status='resolved' then auth.uid() else null end,
    resolved_at = case when p_status='resolved' then now() else null end,
    ignored_by  = case when p_status='ignored' then auth.uid() else null end,
    ignored_at  = case when p_status='ignored' then now() else null end,
    ignored_reason = case when p_status='ignored' then p_comment else null end,
    updated_at = now()
  where id=p_item;

  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_validation_status_changed', jsonb_build_object('item_id',p_item,'status',p_status,'reason',left(coalesce(p_comment,''),500)));
end $function$
;

CREATE OR REPLACE FUNCTION public.annual_report_update_section(p_section uuid, p_content text, p_review_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_draft uuid; v_eng uuid; v_estatus text; v_dstatus text;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select s.company_id, s.draft_id, d.status into v_company, v_draft, v_dstatus
  from annual_report_draft_sections s join annual_report_drafts d on d.id=s.draft_id where s.id=p_section;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  select e.id, e.status into v_eng, v_estatus from bokslut_engagements e join annual_report_drafts d on d.engagement_id=e.id where d.id=v_draft;
  if not public.bokslut_can(v_company,'annual_report_write') then
    perform log_bokslut_denied('annual_report_update_section','roll saknar behörighet',v_company,v_eng); raise exception 'Behörighet saknas.' using errcode='42501'; end if;
  if v_estatus='last' or v_dstatus='locked' then
    perform log_bokslut_denied('annual_report_update_section','låst (read-only)',v_company,v_eng); raise exception 'Låst – endast läsläge.' using errcode='42501'; end if;

  update annual_report_draft_sections
    set content=p_content, review_comment=coalesce(p_review_comment, review_comment),
        review_status='needs_review', reviewed_by=null, reviewed_at=null, updated_at=now()
  where id=p_section;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_eng, v_company, auth.uid(), 'annual_report_section_updated', jsonb_build_object('section_id',p_section));
end $function$
;

CREATE OR REPLACE FUNCTION public.apply_email_unsubscribe(p_user_id uuid, p_event_type text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int;
begin
  if p_event_type = any (array['security_event','permission_changed','system_error','locked_account_blocked','user_invited']) then
    return -1; -- vägras: obligatoriskt event
  end if;
  insert into public.notification_preferences (user_id, company_id, event_type, channel, enabled)
  select p_user_id, uc.company_id, p_event_type, 'email', false
  from public.user_companies uc
  where uc.user_id = p_user_id
  on conflict (user_id, company_id, event_type, channel) do update set enabled = false, updated_at = now();
  get diagnostics n = row_count;
  return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.ar_arkiv_forvaltare(p_company uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
      select 1 from byra_medlemskap bm
      where bm.byra_bolag_id = p_company and bm.anvandare_id = auth.uid() and bm.aktiv)
    or exists (
      select 1 from byra_klient bk
      join byra_medlemskap bm on bm.byra_bolag_id = bk.byra_bolag_id
      where bk.klient_bolag_id = p_company and bk.status = 'aktiv'
        and bm.anvandare_id = auth.uid() and bm.aktiv
        and (bm.roll = 'admin' or bk.kundansvarig_anvandare_id = auth.uid()))
    or (
      not exists (select 1 from byra_klient bk where bk.klient_bolag_id = p_company and bk.status = 'aktiv')
      and exists (
        select 1 from user_companies uc
        where uc.company_id = p_company and uc.user_id = auth.uid()
          and lower(coalesce(uc.role, '')) in ('admin', 'owner', 'agare', 'ägare')));
$function$
;

CREATE OR REPLACE FUNCTION public.ar_bolagsadmin(p_company uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.user_companies uc
    where uc.company_id = p_company
      and uc.user_id = auth.uid()
      and uc.role = 'admin'
  );
$function$
;

CREATE OR REPLACE FUNCTION public.ar_byra_admin(p_byra_bolag_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.byra_medlemskap bm
    where bm.byra_bolag_id = p_byra_bolag_id
      and bm.anvandare_id = auth.uid() and bm.aktiv and bm.roll = 'admin'
  )
$function$
;

CREATE OR REPLACE FUNCTION public.ar_byra_medlem()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (
    select 1 from public.byra_medlemskap
    where anvandare_id = auth.uid() and aktiv
  );
$function$
;

CREATE OR REPLACE FUNCTION public.ar_min_klient(p_company uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$ select p_company in (select public.mina_klientbolag()) $function$
;

CREATE OR REPLACE FUNCTION public.ar_section_label(p_key text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case p_key
    when 'forvaltningsberattelse' then 'Förvaltningsberättelse'
    when 'resultatrakning' then 'Resultaträkning'
    when 'balansrakning' then 'Balansräkning'
    when 'noter' then 'Noter'
    when 'faststallelseintyg' then 'Fastställelseintyg'
    when 'underskriftssida' then 'Underskriftssida'
    else p_key end;
$function$
;

CREATE OR REPLACE FUNCTION public.arkiv_arkivera_systemfil(p_company uuid, p_systemnyckel text, p_storage_path text, p_file_name text, p_mime_type text, p_file_size bigint, p_kalla text, p_beskrivning text, p_hoppa_om_finns boolean DEFAULT false)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_mapp uuid; v_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from user_companies where user_id = auth.uid() and company_id = p_company) then
    raise exception 'forbidden';
  end if;
  if not public.can_company_write(p_company) then
    raise exception 'Tjänsten är pausad för det här företaget';
  end if;
  select id into v_mapp from arkiv_mappar where company_id = p_company and systemnyckel = p_systemnyckel;
  if v_mapp is null then
    perform public.arkiv_skapa_standardmappar(p_company);
    select id into v_mapp from arkiv_mappar where company_id = p_company and systemnyckel = p_systemnyckel;
  end if;
  if v_mapp is null then raise exception 'Mappen % saknas', p_systemnyckel; end if;
  if p_storage_path is null or p_storage_path not like p_company::text || '/' || v_mapp::text || '/%' then
    raise exception 'Ogiltig sökväg för arkivfilen';
  end if;
  if p_hoppa_om_finns then
    select id into v_id from arkiv_filer
    where mapp_id = v_mapp and file_name = p_file_name and raderad_at is null limit 1;
    if v_id is not null then return v_id; end if;
  end if;
  insert into arkiv_filer (company_id, mapp_id, storage_path, file_name, mime_type, file_size, kalla, beskrivning)
  values (p_company, v_mapp, p_storage_path, p_file_name, p_mime_type, p_file_size,
          coalesce(p_kalla, 'uppladdad'), p_beskrivning)
  returning id into v_id;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.arkiv_fil_fore_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is not null then
    new.uppladdad_av := auth.uid();
    new.created_at := now();
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.arkiv_fil_logga_radering()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_rad record; v_action text;
begin
  if tg_op = 'DELETE' then
    v_rad := old; v_action := 'radera_permanent';
  else
    if new.raderad_at is null or old.raderad_at is not null then return new; end if;
    v_rad := new; v_action := 'radera';
    new.raderad_av := auth.uid();
  end if;
  insert into audit_log (company_id, entity, entity_ref, action, old_data, changed_by, source)
  values (v_rad.company_id, 'arkiv_fil', v_rad.id::text, v_action,
          jsonb_build_object('file_name', v_rad.file_name, 'mapp_id', v_rad.mapp_id,
                             'document_id', v_rad.document_id, 'kalla', v_rad.kalla),
          auth.uid(), 'ui');
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.arkiv_mapp_fore_radering()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not exists (select 1 from companies where id = old.company_id) then
    return old;
  end if;
  if exists (select 1 from arkiv_filer f where f.mapp_id = old.id) then
    raise exception 'Mappen innehåller dokument (även i papperskorgen) – töm den först';
  end if;
  if exists (select 1 from arkiv_mappar m where m.parent_id = old.id) then
    raise exception 'Mappen har undermappar – ta bort dem först';
  end if;
  return old;
end $function$
;

CREATE OR REPLACE FUNCTION public.arkiv_mapp_logga_synlighet()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.synlighet is distinct from old.synlighet then
    insert into audit_log (company_id, entity, entity_ref, action, old_data, new_data, changed_by, source)
    values (new.company_id, 'arkiv_mapp', new.id::text, 'andra_synlighet',
            jsonb_build_object('namn', old.namn, 'synlighet', old.synlighet),
            jsonb_build_object('namn', new.namn, 'synlighet', new.synlighet),
            auth.uid(), 'ui');
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.arkiv_mapp_skydda_systemmapp()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if old.systemnyckel is not null then
    if new.systemnyckel is distinct from old.systemnyckel then
      raise exception 'Standardmappens systemnyckel kan inte ändras';
    end if;
    if old.systemnyckel = 'personal' and new.synlighet <> 'byra' then
      raise exception 'Personalmappen innehåller personuppgifter om anställda och kan inte öppnas för alla användare i bolaget';
    end if;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.arkiv_mapp_validera()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid; v_djup int := 0; v_foralder_synlighet text;
begin
  if new.parent_id is not null then
    if new.parent_id = new.id then
      raise exception 'En mapp kan inte ligga i sig själv';
    end if;
    if not exists (select 1 from arkiv_mappar p where p.id = new.parent_id and p.company_id = new.company_id) then
      raise exception 'Mappen måste ligga i samma bolag som sin överordnade mapp';
    end if;
    -- En undermapp får ALDRIG vara synlig för kunden när föräldern är byråintern.
    select synlighet into v_foralder_synlighet from arkiv_mappar where id = new.parent_id;
    if v_foralder_synlighet = 'byra' and new.synlighet <> 'byra' then
      raise exception 'Mappen ligger i en byråintern mapp och kan därför bara vara synlig för byrån';
    end if;
    v_id := new.parent_id;
    while v_id is not null loop
      v_djup := v_djup + 1;
      if v_id = new.id then
        raise exception 'Mappen kan inte flyttas in i sin egen undermapp';
      end if;
      if v_djup > 10 then
        raise exception 'För djup mappstruktur (max 10 nivåer)';
      end if;
      select parent_id into v_id from arkiv_mappar where id = v_id;
    end loop;
  end if;
  -- Att stänga en mapp för kunden får inte lämna kvar öppna undermappar.
  if tg_op = 'UPDATE' and new.synlighet = 'byra' and old.synlighet <> 'byra'
     and exists (select 1 from arkiv_mappar m where m.parent_id = new.id and m.synlighet <> 'byra') then
    raise exception 'Mappen har undermappar som är synliga för kunden – ändra dem först';
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.arkiv_skapa_standardmappar(p_company uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_antal int := 0; r record;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from user_companies where user_id = auth.uid() and company_id = p_company) then
    raise exception 'forbidden';
  end if;
  for r in select * from (values
      ('skatteverket',    'Skatteverket',               'kund',       'bfl_7ar',      10),
      ('bokslut',         'Bokslut och årsredovisning', 'kund',       'bfl_7ar',      20),
      -- Avtal och försäkringshandlingar är räkenskapsinformation (BFL 1 kap. 2 § p 8 b).
      ('avtal',           'Avtal',                      'kund_skriv', 'bfl_7ar',      30),
      ('bank_forsakring', 'Bank och försäkring',        'kund_skriv', 'bfl_7ar',      40),
      ('personal',        'Personal',                   'byra',       'gdpr_gallras', 50),
      ('ovrigt',          'Övrigt',                     'kund_skriv', 'ingen',        70)
    ) as t(nyckel, namn, synlighet, gallring, sort)
  loop
    if not exists (select 1 from arkiv_mappar where company_id = p_company and systemnyckel = r.nyckel) then
      insert into arkiv_mappar (company_id, namn, synlighet, gallringsregel, systemnyckel, sortering)
      values (p_company, r.namn, r.synlighet, r.gallring, r.nyckel, r.sort);
      v_antal := v_antal + 1;
    end if;
  end loop;
  return v_antal;
end $function$
;

CREATE OR REPLACE FUNCTION public.arkiv_skydda_rakenskapsinfo()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare v_kalla text; v_namn text;
begin
  if tg_op = 'DELETE' then
    v_kalla := old.kalla; v_namn := old.file_name;
  else
    -- Endast övergången till raderad räknas; övriga uppdateringar är fria.
    if new.raderad_at is null or old.raderad_at is not null then return new; end if;
    v_kalla := new.kalla; v_namn := new.file_name;
  end if;
  if v_kalla in ('moms', 'agi', 'sie', 'arsredovisning', 'arkivexport') then
    raise exception '% är räkenskapsinformation och måste bevaras i sju år (bokföringslagen 7 kap. 2 §)', v_namn;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.assert_period_open(p_company uuid, p_datum date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_lock text; v_lock_end date; v_fy int; v_open int;
begin
  if current_setting('app.periodlas_bypass', true) = 'on' then return; end if;
  if p_company is null or p_datum is null then return; end if;

  select bokforing_last_tom into v_lock from public.companies where id = p_company;
  if not found then return; end if;   -- företaget håller på att raderas (cascade) – inget att skydda

  if v_lock is not null and v_lock <> '' then
    if v_lock ~ '^\d{4}-\d{2}$' then
      v_lock_end := (to_date(v_lock || '-01', 'YYYY-MM-DD') + interval '1 month - 1 day')::date;
    elsif v_lock ~ '^\d{4}-\d{2}-\d{2}$' then
      v_lock_end := to_date(v_lock, 'YYYY-MM-DD');
    end if;
    if v_lock_end is not null and p_datum <= v_lock_end then
      raise exception 'PERIODLÅST: Bokföringen är låst till och med %. Verifikationer daterade % eller tidigare kan inte skapas, ändras eller raderas. Justera låset under Inställningar om det är fel.', v_lock, v_lock_end;
    end if;
  end if;

  select count(*) into v_fy from public.fiscal_years where company_id = p_company;
  if v_fy = 0 then
    raise exception 'RÄKENSKAPSÅR SAKNAS: Företaget har inget räkenskapsår upplagt. Lägg upp räkenskapsår under Inställningar → Räkenskapsår innan du bokför.';
  end if;
  select count(*) into v_open from public.fiscal_years
    where company_id = p_company and status = 'active' and p_datum between start_date and end_date;
  if v_open = 0 then
    raise exception 'PERIODLÅST: Datumet % ligger utanför öppet räkenskapsår. Öppna rätt räkenskapsår under Inställningar → Räkenskapsår.', p_datum;
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.assign_archive_number()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare candidate bigint; tries int := 0;
begin
  if NEW.archive_number is not null then return NEW; end if;
  loop
    candidate := 1000000 + floor(random() * 9000000)::bigint;   -- 1000000..9999999
    exit when not exists (select 1 from public.companies where archive_number = candidate);
    tries := tries + 1;
    if tries > 100 then raise exception 'Kunde inte generera unikt arkivnummer'; end if;
  end loop;
  NEW.archive_number := candidate;
  return NEW;
end $function$
;

CREATE OR REPLACE FUNCTION public.assign_mc_item(p_item uuid, p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record;
begin
  g := public._mc_item_guard(p_item);
  if p_user is not null and not exists (select 1 from user_companies uc where uc.user_id=p_user and uc.company_id=g.company_id) then
    raise exception 'användaren tillhör inte företaget' using errcode='22023'; end if;
  update monthly_control_items set assigned_to=p_user, updated_at=now() where id=p_item;
  insert into monthly_control_events(monthly_control_id, item_id, company_id, user_id, event_type, detail)
  values (g.monthly_control_id, p_item, g.company_id, auth.uid(), 'assigned', jsonb_build_object('assigned_to', p_user));
end $function$
;

CREATE OR REPLACE FUNCTION public.assign_support_ticket(p_ticket_id uuid, p_admin_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_view_support() then raise exception 'forbidden' using errcode='42501'; end if;
  if p_admin_id is not null and not (p_admin_id = any(public.support_admin_ids())) then
    raise exception 'mottagaren är inte support-admin' using errcode='22023'; end if;
  update support_tickets set assigned_admin_id=p_admin_id, status=case when status='new' then 'open' else status end, updated_at=now()
    where id=p_ticket_id;
  perform public.log_platform_audit('support_ticket_assigned', p_ticket_id::text, jsonb_build_object('assigned_admin_id', p_admin_id));
end $function$
;

CREATE OR REPLACE FUNCTION public.audit_customer_invoice_booked()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_src text := coalesce(nullif(current_setting('app.audit_source', true), ''),
                               case when auth.uid() is not null then 'ui' else 'system' end);
begin
  begin
    if (tg_op = 'INSERT' and new.verifikation_id is not null)
       or (tg_op = 'UPDATE' and new.verifikation_id is not null and old.verifikation_id is null) then
      perform public.log_accounting_audit('customer_invoice_booked', 'invoice', new.id::text, v_src,
        jsonb_build_object('invoice_nr', new.invoice_nr, 'customer_id', new.customer_id, 'verifikation_id', new.verifikation_id,
          'total_amount', new.total_amount, 'vat_amount', new.vat_amount),
        new.company_id, null, null);
    end if;
  exception when others then null;
  end;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.audit_supplier_invoice_booked()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_src text := coalesce(nullif(current_setting('app.audit_source', true), ''),
                               case when auth.uid() is not null then 'ui' else 'system' end);
begin
  begin
    if (tg_op = 'INSERT' and coalesce(new.bokford, false))
       or (tg_op = 'UPDATE' and coalesce(new.bokford, false) and not coalesce(old.bokford, false)) then
      perform public.log_accounting_audit('supplier_invoice_booked', 'supplier_invoice', new.id::text, v_src,
        jsonb_build_object('invoice_nr', new.invoice_nr, 'supplier_id', new.supplier_id, 'verifikation_id', new.verifikation_id,
          'total_amount', new.total_amount, 'vat_amount', new.vat_amount, 'is_credit_invoice', new.kreditfaktura),
        new.company_id, null, null);
    end if;
  exception when others then null;
  end;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.audit_verifikation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_src text := coalesce(nullif(current_setting('app.audit_source', true), ''),
                         case when auth.uid() is not null then 'ui' else 'system' end);
begin
  begin
    if tg_op = 'INSERT' then
      perform public.log_accounting_audit('verification_created', 'verifikation', new.id::text, v_src,
        jsonb_build_object('ver_nr', new.ver_nr, 'ver_serie', new.ver_serie, 'datum', new.datum,
          'total_debet', new.total_debet, 'total_kredit', new.total_kredit), new.company_id, null, null);
    elsif tg_op = 'UPDATE' then
      perform public.log_accounting_audit('verification_updated', 'verifikation', new.id::text, v_src,
        jsonb_build_object('ver_nr', new.ver_nr), new.company_id,
        jsonb_build_object('beskrivning', old.beskrivning, 'total_debet', old.total_debet, 'total_kredit', old.total_kredit, 'is_locked', old.is_locked),
        jsonb_build_object('beskrivning', new.beskrivning, 'total_debet', new.total_debet, 'total_kredit', new.total_kredit, 'is_locked', new.is_locked));
    elsif tg_op = 'DELETE' then
      perform public.log_accounting_audit('verification_deleted_current_legacy_flow', 'verifikation', old.id::text, v_src,
        jsonb_build_object('warning', 'Legacy deletion flow, should be replaced by reversal flow'), old.company_id,
        jsonb_build_object('ver_nr', old.ver_nr, 'ver_serie', old.ver_serie, 'datum', old.datum, 'beskrivning', old.beskrivning,
          'total_debet', old.total_debet, 'total_kredit', old.total_kredit,
          'rader', (select coalesce(jsonb_agg(jsonb_build_object('konto', vr.account_nr, 'debet', vr.debet, 'kredit', vr.kredit) order by vr.sort_order), '[]'::jsonb)
                    from public.verifikation_rows vr where vr.verifikation_id = old.id)), null);
    end if;
  exception
    when foreign_key_violation then
      null;   -- bolaget raderas (cascade) – audit-raden har inget att peka på
    when others then
      raise;  -- allt annat är ett riktigt auditfel och stoppar transaktionen
  end;
  return case when tg_op = 'DELETE' then old else new end;
end $function$
;

CREATE OR REPLACE FUNCTION public.audit_verifikation_rows()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ver uuid; v_company uuid; v_ver_nr text;
begin
  -- Enbart avstämningsmarkering: arbetsmarkering, inte bokföringsdata.
  if tg_op = 'UPDATE'
     and new.account_nr = old.account_nr
     and new.account_name is not distinct from old.account_name
     and coalesce(new.debet, 0) = coalesce(old.debet, 0)
     and coalesce(new.kredit, 0) = coalesce(old.kredit, 0)
     and new.transaction_info is not distinct from old.transaction_info
     and new.sort_order is not distinct from old.sort_order
     and new.verifikation_id is not distinct from old.verifikation_id then
    return new;
  end if;

  v_ver := case when tg_op = 'DELETE' then old.verifikation_id else new.verifikation_id end;
  select v.company_id, v.ver_nr into v_company, v_ver_nr
    from public.verifikationer v where v.id = v_ver;

  -- Moderverifikationen är redan borta (kaskadradering) – huvudets egen
  -- audit-post innehåller hela raduppsättningen, så vi loggar inte dubbelt.
  if not found then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  begin
    perform public.log_accounting_audit(
      case tg_op when 'INSERT' then 'row_created'
                 when 'UPDATE' then 'row_updated'
                 else 'row_deleted' end,
      'verifikation_rad',
      (case when tg_op = 'DELETE' then old.id else new.id end)::text,
      nullif(current_setting('app.audit_source', true), ''),
      jsonb_build_object('verifikation_id', v_ver, 'ver_nr', v_ver_nr),
      v_company,
      case when tg_op <> 'INSERT' then jsonb_build_object(
        'konto', old.account_nr, 'kontonamn', old.account_name,
        'debet', old.debet, 'kredit', old.kredit,
        'text', old.transaction_info, 'ordning', old.sort_order) end,
      case when tg_op <> 'DELETE' then jsonb_build_object(
        'konto', new.account_nr, 'kontonamn', new.account_name,
        'debet', new.debet, 'kredit', new.kredit,
        'text', new.transaction_info, 'ordning', new.sort_order) end
    );
  exception
    when foreign_key_violation then
      null;   -- bolaget raderas (cascade) – audit-raden har inget att peka på
    when others then
      raise;  -- riktigt auditfel stoppar transaktionen
  end;

  return case when tg_op = 'DELETE' then old else new end;
end $function$
;

CREATE OR REPLACE FUNCTION public.bas_class(p_nr text)
 RETURNS smallint
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case when p_nr ~ '^[1-8]' then substr(p_nr,1,1)::smallint else null end
$function$
;

CREATE OR REPLACE FUNCTION public.bas_type(p_nr text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case substr(coalesce(p_nr,''),1,1)
    when '1' then 'tillgång'
    when '2' then 'eget_kapital_skuld'
    when '3' then 'intäkt'
    when '4' then 'kostnad'
    when '5' then 'kostnad'
    when '6' then 'kostnad'
    when '7' then 'kostnad'
    when '8' then 'finansiell'
    else null end
$function$
;

CREATE OR REPLACE FUNCTION public.billing_admin_ids()
 RETURNS uuid[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select array_agg(distinct u.id) from auth.users u where lower(u.email) in (
    select lower(email) from public.platform_admins
    union select lower(email) from public.platform_user_roles where role='billing_admin')
$function$
;

CREATE OR REPLACE FUNCTION public.bokfor_verifikation(p_company_id uuid, p_serie text, p_datum date, p_beskrivning text, p_rader jsonb, p_motpart text DEFAULT NULL::text, p_created_by uuid DEFAULT NULL::uuid, p_source text DEFAULT NULL::text, p_kommentar text DEFAULT NULL::text, p_ersatter uuid DEFAULT NULL::uuid)
 RETURNS verifikationer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_nr text;
  v_ver public.verifikationer;
  v_debet numeric := 0;
  v_kredit numeric := 0;
  rad jsonb;
  i int := 0;
begin
  -- Ersätter RLS-skyddet som gällde när funktionen var SECURITY INVOKER.
  perform public._assert_company_access(p_company_id);

  if p_source is not null and p_source in ('ai', 'mcp') then
    perform set_config('app.audit_source', p_source, true);
  end if;
  if p_rader is null or jsonb_array_length(p_rader) = 0 then
    raise exception 'Verifikationen saknar rader';
  end if;
  select coalesce(sum(coalesce((x->>'debet')::numeric, 0)), 0),
         coalesce(sum(coalesce((x->>'kredit')::numeric, 0)), 0)
    into v_debet, v_kredit
    from jsonb_array_elements(p_rader) x;
  if round(v_debet, 2) <> round(v_kredit, 2) then
    raise exception 'Verifikationen balanserar inte (debet %, kredit %)', v_debet, v_kredit;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_company_id::text || '|' || p_serie, 0));
  v_nr := public.next_ver_nr(p_company_id, p_serie);

  insert into public.verifikationer
    (company_id, ver_nr, ver_serie, datum, beskrivning, motpart, kommentar, ersatter,
     total_debet, total_kredit, created_by)
  values
    (p_company_id, v_nr, p_serie, p_datum, left(p_beskrivning, 500),
     nullif(trim(coalesce(p_motpart, '')), ''), nullif(trim(coalesce(p_kommentar, '')), ''),
     p_ersatter, round(v_debet, 2), round(v_kredit, 2),
     coalesce(p_created_by, auth.uid()))
  returning * into v_ver;

  perform set_config('app.ver_insert', 'on', true);
  for rad in select * from jsonb_array_elements(p_rader) loop
    insert into public.verifikation_rows
      (verifikation_id, account_nr, account_name, debet, kredit, transaction_info, sort_order)
    values
      (v_ver.id, rad->>'account_nr', rad->>'account_name',
       coalesce((rad->>'debet')::numeric, 0), coalesce((rad->>'kredit')::numeric, 0),
       nullif(rad->>'transaction_info', ''), coalesce((rad->>'sort_order')::int, i));
    i := i + 1;
  end loop;
  perform set_config('app.ver_insert', 'off', true);

  return v_ver;
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_ai_context(p_engagement uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_status text; v_res jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, status into v_company, v_status from bokslut_engagements where id=p_engagement;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then raise exception 'forbidden' using errcode='42501'; end if;
  if not public.bokslut_can(v_company,'ai_suggestion_write') then raise exception 'Behörighet saknas: din roll får inte generera AI-förslag.' using errcode='42501'; end if;
  if v_status='last' then raise exception 'engagemanget är låst' using errcode='42501'; end if;
  select jsonb_build_object(
    'engagement', (select jsonb_build_object('id', e.id, 'regelverk', e.regelverk, 'status', e.status, 'open_count', e.open_count, 'critical_count', e.critical_count, 'high_count', e.high_count) from bokslut_engagements e where e.id=p_engagement),
    'checks', coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'category', c.category, 'title', c.title, 'description', c.description, 'account_nr', c.account_nr, 'saldo', c.saldo, 'risk_level', c.risk_level, 'status', c.status, 'rule_key', c.rule_key) order by c.risk_level, c.category) from bokslut_checks c where c.engagement_id=p_engagement), '[]'::jsonb),
    'attachments', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'type', a.type, 'title', a.title, 'account_nr', a.account_nr, 'saldo_huvudbok', a.saldo_huvudbok, 'avstamt_belopp', a.avstamt_belopp, 'differens', a.differens, 'status', a.status)) from bokslut_attachments a where a.engagement_id=p_engagement), '[]'::jsonb)
  ) into v_res;
  return v_res;
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_assign_check(p_check uuid, p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record;
begin
  g := public._bokslut_check_guard(p_check);
  if not public.bokslut_can(g.company_id, 'assign_check') then raise exception 'Behörighet saknas: din roll får inte tilldela kontroller.' using errcode='42501'; end if;
  if p_user is not null and not exists (select 1 from user_companies uc where uc.user_id=p_user and uc.company_id=g.company_id) then raise exception 'användaren tillhör inte företaget' using errcode='22023'; end if;
  update bokslut_checks set assigned_to=p_user, updated_at=now() where id=p_check;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (g.engagement_id, g.company_id, auth.uid(), 'check_assign', jsonb_build_object('check', p_check, 'assigned_to', p_user));
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_can(p_company uuid, p_action text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  with m as (select coalesce(role, 'member') as role from user_companies where user_id = auth.uid() and company_id = p_company)
  select case
    when not public.has_ai_feature(p_company, 'ai_bokslut_arsredovisning') then false
    when not exists (select 1 from m) then false
    else (select case p_action
      when 'read' then true
      when 'run_analysis' then true
      when 'assign_check' then true
      when 'comment_check' then true
      when 'resolve_check' then role = 'admin'
      when 'ignore_check' then role = 'admin'
      when 'manage_status' then role = 'admin'
      when 'attachment_write' then role = 'admin'
      when 'attachment_approve' then role = 'admin'
      when 'ai_suggestion_write' then role = 'admin'
      when 'annual_report_write' then role = 'admin'
      when 'approve_later' then role = 'admin'
      when 'create_draft_later' then role = 'admin'
      else false end from m) end;
$function$
;

CREATE OR REPLACE FUNCTION public.bokslut_comment_check(p_check uuid, p_comment text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record; v_norm text; v_appr boolean;
begin
  if p_comment is null or length(trim(p_comment)) = 0 then
    raise exception 'tom kommentar' using errcode = '22023'; end if;
  v_norm := normalize(p_comment, nfc);
  if octet_length(v_norm) > 8000 then
    raise exception 'Kommentaren är för lång (max 8000 byte).' using errcode = '22023'; end if;
  g := public._bokslut_check_guard(p_check);
  select exists (select 1 from bokslut_engagements e where e.id = g.engagement_id and e.status = 'godkand') into v_appr;
  if v_appr then
    raise exception 'Engagemanget är godkänt – kommentarer kan inte ändras.' using errcode = '42501'; end if;
  if not public.bokslut_can(g.company_id, 'comment_check') then
    raise exception 'Behörighet saknas: din roll får inte kommentera kontroller.' using errcode = '42501'; end if;
  update bokslut_checks set comment = v_norm, updated_at = now() where id = p_check;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (g.engagement_id, g.company_id, auth.uid(), 'check_comment', jsonb_build_object('check', p_check));
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_create_attachment(p_engagement uuid, p_type text, p_title text, p_account_nr text DEFAULT NULL::text, p_saldo numeric DEFAULT NULL::numeric, p_avstamt numeric DEFAULT NULL::numeric, p_source text DEFAULT NULL::text, p_source_data jsonb DEFAULT '{}'::jsonb, p_check_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_status text; v_id uuid; v_diff numeric; v_rule text;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, status into v_company, v_status from bokslut_engagements where id = p_engagement;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id = auth.uid() and uc.company_id = v_company) then raise exception 'forbidden' using errcode='42501'; end if;
  if v_status = 'last' then raise exception 'engagemanget är låst' using errcode='42501'; end if;
  if not public.bokslut_can(v_company, 'attachment_write') then raise exception 'Behörighet saknas: din roll får inte skapa bokslutsbilagor.' using errcode='42501'; end if;
  if p_type not in ('bank','kundfordringar','leverantorsskulder','moms','skattekonto','anlaggningstillgangar','avskrivningar','periodiseringar','skatt','eget_kapital','arets_resultat','ovrigt') then raise exception 'ogiltig bilagetyp' using errcode='22023'; end if;
  if p_title is null or length(trim(p_title)) = 0 then raise exception 'titel krävs' using errcode='22023'; end if;
  v_diff := case when p_saldo is not null and p_avstamt is not null then round(p_saldo - p_avstamt, 2) else null end;
  if p_check_id is not null then select rule_key into v_rule from bokslut_checks where id = p_check_id and engagement_id = p_engagement; end if;
  insert into bokslut_attachments (engagement_id, company_id, type, title, account_nr, saldo_huvudbok, avstamt_belopp, differens, source, source_data, check_id, rule_key, created_by)
  values (p_engagement, v_company, p_type, left(p_title,200), p_account_nr, p_saldo, p_avstamt, v_diff, p_source, coalesce(p_source_data,'{}'::jsonb), p_check_id, v_rule, auth.uid())
  returning id into v_id;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (p_engagement, v_company, auth.uid(), 'attachment_created', jsonb_build_object('attachment', v_id, 'type', p_type));
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_generate_ai_suggestions(p_engagement uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_status text; v_items jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, status into v_company, v_status from bokslut_engagements where id=p_engagement;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then raise exception 'forbidden' using errcode='42501'; end if;
  if not public.bokslut_can(v_company,'ai_suggestion_write') then raise exception 'Behörighet saknas: din roll får inte generera AI-förslag.' using errcode='42501'; end if;
  if v_status='last' then raise exception 'engagemanget är låst' using errcode='42501'; end if;

  v_items := (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
    select jsonb_build_object('suggestion_type','risk_explanation','title', left('Risk: '||c.title,180), 'summary', c.description,
      'reasoning','Kontrollen har risknivå '||c.risk_level||'.'||coalesce(' '||c.suggested_action,''), 'risk_level', c.risk_level,
      'confidence', 0.7, 'related_check_id', c.id::text, 'source_data', jsonb_build_object('rule_key',c.rule_key,'saldo',c.saldo,'kalla','regelbaserad'),
      'suggested_next_action', coalesce(c.suggested_action,'Granska manuellt.')) as x
    from bokslut_checks c where c.engagement_id=p_engagement and c.status in ('open','in_progress','needs_review') and c.risk_level in ('critical','high')
    union all
    select jsonb_build_object('suggestion_type','missing_documentation','title', left('Saknat underlag: '||c.title,180), 'summary', c.description,
      'reasoning','Kontrollen indikerar saknat underlag.', 'risk_level', c.risk_level, 'confidence', 0.6, 'related_check_id', c.id::text,
      'source_data', jsonb_build_object('rule_key',c.rule_key,'kalla','regelbaserad'), 'suggested_next_action','Komplettera underlag eller dokumentera varför det saknas.')
    from bokslut_checks c where c.engagement_id=p_engagement and c.rule_key in ('journal_entry_without_attachment','missing_documents') and c.status in ('open','in_progress','needs_review')
    union all
    select jsonb_build_object('suggestion_type','attachment_review','title', left('Differens i bilaga: '||a.title,180), 'summary','Bilagan har en differens som bör utredas.',
      'reasoning','Saldo enligt huvudbok och avstämt belopp skiljer sig åt.', 'risk_level','high', 'confidence',0.8, 'related_attachment_id', a.id::text,
      'source_data', jsonb_build_object('differens',a.differens,'kalla','regelbaserad'), 'suggested_next_action','Stäm av bilagan mot underlag.')
    from bokslut_attachments a where a.engagement_id=p_engagement and a.differens is not null and abs(a.differens) > 0.5 and a.status not in ('approved','ignored')
  ) t);

  return public.bokslut_save_ai_suggestions(p_engagement, v_items, 'rule-based');
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_generate_attachment_suggestions(p_engagement uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_status text; v_count int;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, status into v_company, v_status from bokslut_engagements where id = p_engagement;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id = auth.uid() and uc.company_id = v_company) then raise exception 'forbidden' using errcode='42501'; end if;
  if v_status = 'last' then raise exception 'engagemanget är låst' using errcode='42501'; end if;
  if not public.bokslut_can(v_company, 'attachment_write') then raise exception 'Behörighet saknas: din roll får inte föreslå bokslutsbilagor.' using errcode='42501'; end if;

  with map(category, atype, title) as (values
    ('bankavstamning','bank','Bank'),
    ('kundfordringar','kundfordringar','Kundfordringar'),
    ('leverantorsskulder','leverantorsskulder','Leverantörsskulder'),
    ('moms','moms','Moms'),
    ('skattekonto','skattekonto','Skattekonto'),
    ('anlaggningstillgangar','anlaggningstillgangar','Anläggningstillgångar'),
    ('avskrivningar','avskrivningar','Avskrivningar'),
    ('periodiseringar','periodiseringar','Periodiseringar'),
    ('skatt','skatt','Skatt'),
    ('eget_kapital','eget_kapital','Eget kapital'),
    ('arets_resultat','arets_resultat','Årets resultat')),
  src as (
    select distinct on (m.atype) m.atype, m.title, c.account_nr, c.saldo, c.id as check_id, c.rule_key
    from bokslut_checks c join map m on m.category = c.category
    where c.engagement_id = p_engagement
    order by m.atype, c.saldo desc nulls last
  )
  insert into bokslut_attachments (engagement_id, company_id, type, title, account_nr, saldo_huvudbok, source, source_data, status, check_id, rule_key, created_by)
  select p_engagement, v_company, s.atype, s.title, s.account_nr, s.saldo, 'Regelförslag',
    jsonb_build_object('from_check', s.check_id, 'rule_key', s.rule_key), 'draft', s.check_id, s.rule_key, auth.uid()
  from src s
  where not exists (select 1 from bokslut_attachments a where a.engagement_id = p_engagement and a.type = s.atype);
  get diagnostics v_count = row_count;

  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (p_engagement, v_company, auth.uid(), 'attachment_suggestion_generated', jsonb_build_object('created', v_count));
  return v_count;
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_get_or_create(p_company uuid, p_fiscal_year_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_list_ai_suggestions(p_engagement uuid)
 RETURNS SETOF bokslut_ai_suggestions
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid;
begin
  select company_id into v_company from bokslut_engagements where id=p_engagement;
  if v_company is null then return; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then raise exception 'forbidden' using errcode='42501'; end if;
  if not public.has_ai_feature(v_company,'ai_bokslut_arsredovisning') then raise exception 'feature_not_licensed' using errcode='42501'; end if;
  return query select * from bokslut_ai_suggestions where engagement_id=p_engagement order by case risk_level when 'critical' then 0 when 'high' then 1 when 'medium' then 2 else 3 end, created_at desc;
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_list_attachments(p_engagement uuid)
 RETURNS SETOF bokslut_attachments
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid;
begin
  select company_id into v_company from bokslut_engagements where id = p_engagement;
  if v_company is null then return; end if;
  if not exists (select 1 from user_companies uc where uc.user_id = auth.uid() and uc.company_id = v_company) then raise exception 'forbidden' using errcode='42501'; end if;
  if not public.has_ai_feature(v_company, 'ai_bokslut_arsredovisning') then raise exception 'feature_not_licensed' using errcode='42501'; end if;
  return query select * from bokslut_attachments where engagement_id = p_engagement order by type, created_at;
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_my_permissions(p_company uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'read', public.bokslut_can(p_company,'read'),
    'run_analysis', public.bokslut_can(p_company,'run_analysis'),
    'assign_check', public.bokslut_can(p_company,'assign_check'),
    'comment_check', public.bokslut_can(p_company,'comment_check'),
    'resolve_check', public.bokslut_can(p_company,'resolve_check'),
    'ignore_check', public.bokslut_can(p_company,'ignore_check'),
    'manage_status', public.bokslut_can(p_company,'manage_status'),
    'attachment_write', public.bokslut_can(p_company,'attachment_write'),
    'attachment_approve', public.bokslut_can(p_company,'attachment_approve'),
    'ai_suggestion_write', public.bokslut_can(p_company,'ai_suggestion_write'),
    'annual_report_write', public.bokslut_can(p_company,'annual_report_write'),
    'approve_later', public.bokslut_can(p_company,'approve_later'),
    'create_draft_later', public.bokslut_can(p_company,'create_draft_later'));
$function$
;

CREATE OR REPLACE FUNCTION public.bokslut_open_counts(p_company uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when not public.has_ai_feature(p_company, 'ai_bokslut_arsredovisning') then '{"critical":0,"high":0,"open":0}'::jsonb
    else (select jsonb_build_object(
      'critical', count(*) filter (where risk_level='critical'),
      'high', count(*) filter (where risk_level='high'),
      'open', count(*))
    from bokslut_checks where company_id=p_company and status in ('open','in_progress','needs_review')) end;
$function$
;

CREATE OR REPLACE FUNCTION public.bokslut_save_ai_suggestions(p_engagement uuid, p_items jsonb, p_model text DEFAULT 'ai'::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_status text; v_count int;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, status into v_company, v_status from bokslut_engagements where id=p_engagement;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then raise exception 'forbidden' using errcode='42501'; end if;
  if not public.bokslut_can(v_company,'ai_suggestion_write') then raise exception 'Behörighet saknas: din roll får inte spara AI-förslag.' using errcode='42501'; end if;
  if v_status='last' then raise exception 'engagemanget är låst' using errcode='42501'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then return 0; end if;

  insert into bokslut_ai_suggestions (engagement_id, company_id, suggestion_type, title, summary, reasoning, risk_level, confidence, related_check_id, related_attachment_id, source_data, suggested_next_action, status, model)
  select p_engagement, v_company,
    it->>'suggestion_type', left(it->>'title',200), it->>'summary', it->>'reasoning',
    coalesce(it->>'risk_level','medium'),
    least(greatest(coalesce(nullif(it->>'confidence','')::numeric, 0.5), 0), 1),
    case when (it->>'related_check_id') ~ '^[0-9a-fA-F-]{36}$' and exists (select 1 from bokslut_checks c where c.id=(it->>'related_check_id')::uuid and c.engagement_id=p_engagement) then (it->>'related_check_id')::uuid else null end,
    case when (it->>'related_attachment_id') ~ '^[0-9a-fA-F-]{36}$' and exists (select 1 from bokslut_attachments a where a.id=(it->>'related_attachment_id')::uuid and a.engagement_id=p_engagement) then (it->>'related_attachment_id')::uuid else null end,
    coalesce(it->'source_data','{}'::jsonb), it->>'suggested_next_action', 'needs_review', p_model
  from jsonb_array_elements(p_items) it
  where (it->>'suggestion_type') in ('risk_explanation','next_action','missing_documentation','attachment_review','balance_issue','vat_issue','tax_issue','equity_issue','payroll_issue','manual_review_required')
    and coalesce(trim(it->>'title'),'') <> ''
    and coalesce(it->>'risk_level','medium') in ('low','medium','high','critical')
    and not exists (select 1 from bokslut_ai_suggestions s where s.engagement_id=p_engagement and s.title=left(it->>'title',200) and s.status in ('draft','needs_review','accepted'));
  get diagnostics v_count = row_count;

  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, model, detail)
  values (p_engagement, v_company, auth.uid(), 'ai_suggestions_generated', p_model, jsonb_build_object('created', v_count));
  return v_count;
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_set_ai_suggestion_status(p_suggestion uuid, p_status text, p_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_engagement uuid; v_eng_status text;
begin
  if p_status not in ('draft','needs_review','accepted','rejected','resolved','ignored') then raise exception 'ogiltig status' using errcode='22023'; end if;
  select s.company_id, s.engagement_id, e.status into v_company, v_engagement, v_eng_status
  from bokslut_ai_suggestions s join bokslut_engagements e on e.id=s.engagement_id where s.id=p_suggestion;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then raise exception 'forbidden' using errcode='42501'; end if;
  if v_eng_status='last' then raise exception 'engagemanget är låst' using errcode='42501'; end if;
  if not public.bokslut_can(v_company,'ai_suggestion_write') then raise exception 'Behörighet saknas: din roll får inte granska AI-förslag.' using errcode='42501'; end if;
  update bokslut_ai_suggestions set status=p_status,
    reviewed_by = case when p_status in ('accepted','rejected','resolved','ignored') then auth.uid() else reviewed_by end,
    reviewed_at = case when p_status in ('accepted','rejected','resolved','ignored') then now() else reviewed_at end,
    review_comment = coalesce(p_comment, review_comment), updated_at=now()
  where id=p_suggestion;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (v_engagement, v_company, auth.uid(), 'ai_suggestion_status_changed', jsonb_build_object('suggestion', p_suggestion, 'status', p_status));
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_set_attachment_status(p_attachment uuid, p_status text, p_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record; v_action text;
begin
  if p_status not in ('draft','needs_review','reviewed','approved','ignored') then raise exception 'ogiltig status' using errcode='22023'; end if;
  g := public._bokslut_attachment_guard(p_attachment);
  v_action := case when p_status = 'approved' then 'attachment_approve' else 'attachment_write' end;
  if not public.bokslut_can(g.company_id, v_action) then raise exception 'Behörighet saknas: din roll får inte ändra bilagestatus.' using errcode='42501'; end if;
  update bokslut_attachments set status = p_status,
    reviewed_by = case when p_status in ('reviewed','approved') then auth.uid() else reviewed_by end,
    reviewed_at = case when p_status in ('reviewed','approved') then now() else reviewed_at end,
    comment = coalesce(p_comment, comment), updated_at = now()
  where id = p_attachment;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (g.engagement_id, g.company_id, auth.uid(), 'attachment_status_changed', jsonb_build_object('attachment', p_attachment, 'status', p_status));
  if p_status = 'reviewed' then
    insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail) values (g.engagement_id, g.company_id, auth.uid(), 'attachment_reviewed', jsonb_build_object('attachment', p_attachment));
  elsif p_status = 'approved' then
    insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail) values (g.engagement_id, g.company_id, auth.uid(), 'attachment_approved', jsonb_build_object('attachment', p_attachment));
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_set_check_status(p_check uuid, p_status text, p_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record; v_action text;
begin
  if p_status not in ('open','in_progress','needs_review','resolved','ignored') then raise exception 'ogiltig status' using errcode='22023'; end if;
  g := public._bokslut_check_guard(p_check);
  v_action := case p_status when 'resolved' then 'resolve_check' when 'ignored' then 'ignore_check' else 'comment_check' end;
  if not public.bokslut_can(g.company_id, v_action) then
    raise exception 'Behörighet saknas: din roll får inte markera kontroller som %.', (case p_status when 'resolved' then 'klara' when 'ignored' then 'ignorerade' else 'ändrade' end) using errcode='42501';
  end if;
  update bokslut_checks set status=p_status,
    resolved_by = case when p_status in ('resolved','ignored') then auth.uid() else null end,
    resolved_at = case when p_status in ('resolved','ignored') then now() else null end,
    comment = coalesce(p_comment, comment), updated_at=now()
  where id=p_check;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (g.engagement_id, g.company_id, auth.uid(), 'check_status', jsonb_build_object('check', p_check, 'status', p_status, 'comment', p_comment));
  perform public._bokslut_recount(g.engagement_id);
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_sync_comment(p_idempotency_key uuid, p_check uuid, p_operation_type text, p_comment text, p_base_revision bigint, p_client_created_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid; v_company uuid; v_engagement uuid; v_fy uuid; v_status text; v_role text;
  v_cur_comment text; v_cur_rev bigint; v_norm text; v_hash text; v_rowcount int;
  v_existing public.bokslut_sync_operations; v_new_rev bigint; v_action text := null;
  v_result jsonb; v_cv public.bokslut_checks; v_bound boolean;
begin
  perform set_config('lock_timeout', '3000', true);
  perform set_config('statement_timeout', '10000', true);

  v_uid := auth.uid();
  if v_uid is null then raise exception 'unauthorized' using errcode = '28000'; end if;
  if p_operation_type not in ('upsert_comment','clear_comment','overwrite_comment') then
    raise exception 'invalid operation_type' using errcode = '22023'; end if;

  select * into v_existing from public.bokslut_sync_operations
    where user_id = v_uid and idempotency_key = p_idempotency_key;
  v_bound := (v_existing.id is not null and v_existing.entity_id = p_check);

  select c.company_id, c.engagement_id, c.comment, c.comment_revision, e.fiscal_year_id, e.status
    into v_company, v_engagement, v_cur_comment, v_cur_rev, v_fy, v_status
    from public.bokslut_checks c join public.bokslut_engagements e on e.id = c.engagement_id
    where c.id = p_check;

  if v_company is null then
    if v_bound then
      return jsonb_build_object('outcome','rejected','errorCode','entity_deleted','retryable',false,
        'operationId',p_idempotency_key,'entityId',p_check);
    end if;
    return jsonb_build_object('outcome','rejected','errorCode','not_found','retryable',false,
      'operationId',p_idempotency_key,'entityId',p_check);
  end if;

  select uc.role into v_role from public.user_companies uc
    where uc.user_id = v_uid and uc.company_id = v_company;
  if v_role is null then
    if v_bound then
      raise exception 'membership_removed' using errcode = '42501';
    end if;
    return jsonb_build_object('outcome','rejected','errorCode','not_found','retryable',false,
      'operationId',p_idempotency_key,'entityId',p_check);
  end if;
  v_role := coalesce(v_role, 'member');

  if p_operation_type = 'overwrite_comment' and v_role <> 'admin' then
    raise exception 'forbidden' using errcode = '42501'; end if;

  if not exists (select 1 from public.company_ai_features f
        where f.company_id = v_company and f.feature_key = 'offline_autosave_sync' and f.enabled) then
    return jsonb_build_object('outcome','rejected','errorCode','feature_disabled','retryable',false,
      'operationId',p_idempotency_key,'entityId',p_check); end if;

  if v_status = 'godkand' then
    return jsonb_build_object('outcome','rejected','errorCode','engagement_approved','retryable',false,
      'operationId',p_idempotency_key,'entityId',p_check,'baseRevision',p_base_revision,'currentRevision',v_cur_rev);
  elsif v_status = 'last' then
    return jsonb_build_object('outcome','rejected','errorCode','engagement_locked','retryable',false,
      'operationId',p_idempotency_key,'entityId',p_check,'baseRevision',p_base_revision,'currentRevision',v_cur_rev);
  end if;

  if p_operation_type = 'clear_comment' then v_norm := null;
  else v_norm := normalize(coalesce(p_comment, ''), nfc); end if;
  v_hash := pg_catalog.encode(extensions.digest(pg_catalog.convert_to(
      jsonb_build_object('version',1,'entity_type','bokslut_check','entity_id',p_check,
        'operation_type',p_operation_type,'base_revision',p_base_revision,
        'comment', case when p_operation_type = 'clear_comment' then null else v_norm end)::text,'UTF8'),
      'sha256'),'hex');

  begin
    insert into public.bokslut_sync_operations
      (user_id, company_id, entity_type, entity_id, operation_type, idempotency_key,
       request_hash, base_revision, status, created_at, expires_at)
    values (v_uid, v_company, 'bokslut_check', p_check, p_operation_type, p_idempotency_key,
       v_hash, p_base_revision, 'claimed', pg_catalog.now(), pg_catalog.now() + interval '90 days')
    on conflict (user_id, idempotency_key) do nothing;
    get diagnostics v_rowcount = row_count;
  exception when lock_not_available or query_canceled then
    return jsonb_build_object('outcome','retryable_error','errorCode','transaction_retry','retryable',true,
      'operationId',p_idempotency_key,'entityId',p_check);
  end;

  if v_rowcount = 0 then
    select * into v_existing from public.bokslut_sync_operations
      where user_id = v_uid and idempotency_key = p_idempotency_key;
    if v_existing.request_hash is distinct from v_hash then
      return jsonb_build_object('outcome','rejected','errorCode','idempotency_payload_mismatch','retryable',false,
        'operationId',p_idempotency_key,'entityId',p_check); end if;
    return v_existing.result_payload;
  end if;

  if p_operation_type = 'clear_comment' then
    if v_cur_comment is null then
      v_result := jsonb_build_object('outcome','no_change','errorCode',null,'retryable',false,
        'operationId',p_idempotency_key,'entityId',p_check,'baseRevision',p_base_revision,'currentRevision',v_cur_rev);
    else
      update public.bokslut_checks set comment = null
        where id = p_check and comment_revision = p_base_revision returning comment_revision into v_new_rev;
      if not found then
        select * into v_cv from public.bokslut_checks where id = p_check;
        v_result := jsonb_build_object('outcome','conflict','errorCode','revision_conflict','retryable',false,
          'operationId',p_idempotency_key,'entityId',p_check,'baseRevision',p_base_revision,'currentRevision',v_cv.comment_revision,
          'serverVersion', jsonb_build_object('commentRevision',v_cv.comment_revision,
            'commentUpdatedAt',v_cv.comment_updated_at,'commentUpdatedBy',v_cv.comment_updated_by,
            'hasServerComment',(v_cv.comment is not null),
            'serverCommentHash', case when v_cv.comment is null then null
              else pg_catalog.encode(extensions.digest(pg_catalog.convert_to(normalize(v_cv.comment,nfc),'UTF8'),'sha256'),'hex') end),
          'allowedActions', jsonb_build_array('reload_newer','keep_separate','overwrite_with_confirmation'));
      else
        v_action := 'check_comment_sync_clear';
        v_result := jsonb_build_object('outcome','succeeded','errorCode',null,'retryable',false,
          'operationId',p_idempotency_key,'entityId',p_check,'baseRevision',p_base_revision,'currentRevision',v_new_rev);
      end if;
    end if;
  else
    if v_norm is null or pg_catalog.length(pg_catalog.btrim(v_norm)) = 0 then
      v_result := jsonb_build_object('outcome','rejected','errorCode','validation_failed','retryable',false,
        'operationId',p_idempotency_key,'entityId',p_check,'reason','empty');
    elsif pg_catalog.octet_length(v_norm) > 8000 then
      v_result := jsonb_build_object('outcome','rejected','errorCode','validation_failed','retryable',false,
        'operationId',p_idempotency_key,'entityId',p_check,'reason','too_large','bytes',pg_catalog.octet_length(v_norm));
    elsif v_norm is not distinct from v_cur_comment then
      if p_base_revision = v_cur_rev then
        v_result := jsonb_build_object('outcome','no_change','errorCode',null,'retryable',false,
          'operationId',p_idempotency_key,'entityId',p_check,'baseRevision',p_base_revision,'currentRevision',v_cur_rev);
      else
        select * into v_cv from public.bokslut_checks where id = p_check;
        v_result := jsonb_build_object('outcome','conflict','errorCode','revision_conflict','retryable',false,
          'operationId',p_idempotency_key,'entityId',p_check,'baseRevision',p_base_revision,'currentRevision',v_cv.comment_revision,
          'serverVersion', jsonb_build_object('commentRevision',v_cv.comment_revision,
            'commentUpdatedAt',v_cv.comment_updated_at,'commentUpdatedBy',v_cv.comment_updated_by,
            'hasServerComment',(v_cv.comment is not null),
            'serverCommentHash', case when v_cv.comment is null then null
              else pg_catalog.encode(extensions.digest(pg_catalog.convert_to(normalize(v_cv.comment,nfc),'UTF8'),'sha256'),'hex') end),
          'allowedActions', jsonb_build_array('reload_newer','keep_separate','overwrite_with_confirmation'));
      end if;
    else
      update public.bokslut_checks set comment = v_norm
        where id = p_check and comment_revision = p_base_revision returning comment_revision into v_new_rev;
      if not found then
        select * into v_cv from public.bokslut_checks where id = p_check;
        v_result := jsonb_build_object('outcome','conflict','errorCode','revision_conflict','retryable',false,
          'operationId',p_idempotency_key,'entityId',p_check,'baseRevision',p_base_revision,'currentRevision',v_cv.comment_revision,
          'serverVersion', jsonb_build_object('commentRevision',v_cv.comment_revision,
            'commentUpdatedAt',v_cv.comment_updated_at,'commentUpdatedBy',v_cv.comment_updated_by,
            'hasServerComment',(v_cv.comment is not null),
            'serverCommentHash', case when v_cv.comment is null then null
              else pg_catalog.encode(extensions.digest(pg_catalog.convert_to(normalize(v_cv.comment,nfc),'UTF8'),'sha256'),'hex') end),
          'allowedActions', jsonb_build_array('reload_newer','keep_separate','overwrite_with_confirmation'));
      else
        v_action := case when p_operation_type = 'overwrite_comment' then 'check_comment_sync_overwrite'
                         else 'check_comment_sync_upsert' end;
        v_result := jsonb_build_object('outcome','succeeded','errorCode',null,'retryable',false,
          'operationId',p_idempotency_key,'entityId',p_check,'baseRevision',p_base_revision,'currentRevision',v_new_rev);
      end if;
    end if;
  end if;

  if v_action is not null then
    insert into public.bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
    values (v_engagement, v_company, v_uid, v_action,
      jsonb_build_object('check', p_check, 'revision_from', p_base_revision, 'revision_to', v_new_rev, 'operation_id', p_idempotency_key));
  end if;

  update public.bokslut_sync_operations
    set status = 'final', result_payload = v_result, completed_at = pg_catalog.now()
    where user_id = v_uid and idempotency_key = p_idempotency_key;

  return v_result;
end $function$
;

CREATE OR REPLACE FUNCTION public.bokslut_update_attachment(p_attachment uuid, p_title text DEFAULT NULL::text, p_account_nr text DEFAULT NULL::text, p_saldo numeric DEFAULT NULL::numeric, p_avstamt numeric DEFAULT NULL::numeric, p_source text DEFAULT NULL::text, p_source_data jsonb DEFAULT NULL::jsonb, p_comment text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record; v_diff numeric;
begin
  g := public._bokslut_attachment_guard(p_attachment);
  if not public.bokslut_can(g.company_id, 'attachment_write') then raise exception 'Behörighet saknas: din roll får inte ändra bokslutsbilagor.' using errcode='42501'; end if;
  v_diff := case when p_saldo is not null and p_avstamt is not null then round(p_saldo - p_avstamt, 2) else null end;
  update bokslut_attachments set
    title = coalesce(left(p_title,200), title),
    account_nr = p_account_nr,
    saldo_huvudbok = p_saldo,
    avstamt_belopp = p_avstamt,
    differens = v_diff,
    source = coalesce(p_source, source),
    source_data = coalesce(p_source_data, source_data),
    comment = coalesce(p_comment, comment),
    updated_at = now()
  where id = p_attachment;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (g.engagement_id, g.company_id, auth.uid(), 'attachment_updated', jsonb_build_object('attachment', p_attachment));
end $function$
;

CREATE OR REPLACE FUNCTION public.byra_skapa_klient(p_byra_bolag_id uuid, p_namn text, p_org_nr text DEFAULT NULL::text, p_foretagsform text DEFAULT NULL::text, p_momsperiod text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_namn text := trim(coalesce(p_namn, ''));
  v_orgnr text := regexp_replace(coalesce(p_org_nr, ''), '\D', '', 'g');
  v_form text := nullif(trim(coalesce(p_foretagsform, '')), '');
  v_moms text := nullif(trim(coalesce(p_momsperiod, '')), '');
  v_klient uuid;
  v_bk uuid;
  v_epost text;
  v_typ text;
  v_antal_uppdrag int := 0;
  v_hoppade text[] := '{}';
begin
  if auth.uid() is null then raise exception 'Ej inloggad'; end if;
  if not public.ar_byra_admin(p_byra_bolag_id) then
    raise exception 'Endast byråns administratör får lägga till klienter';
  end if;
  if length(v_namn) < 2 then raise exception 'Ange klientens bolagsnamn'; end if;
  if length(v_orgnr) <> 10 then raise exception 'Ange ett giltigt organisationsnummer (10 siffror)'; end if;

  insert into public.companies (name, org_nr, foretagsform, momsperiod, suspended, abonnemang_status)
  values (v_namn, trim(p_org_nr), v_form, v_moms, false, 'testperiod')
  returning id into v_klient;

  insert into public.byra_klient (byra_bolag_id, klient_bolag_id, status, kundansvarig_anvandare_id, tillagd_av)
  values (p_byra_bolag_id, v_klient, 'aktiv', auth.uid(), auth.uid())
  returning id into v_bk;

  select email into v_epost from auth.users where id = auth.uid();
  insert into public.user_companies (user_id, company_id, role, email)
  values (auth.uid(), v_klient, 'admin', v_epost)
  on conflict (user_id, company_id) do nothing;

  -- Standarduppdrag (Byråinställningar → Klientstandarder). Typer som inte kan
  -- bevakas läggs INTE tyst: de returneras i hoppade_typer så UI:t kan varna
  -- (momsdeklaration utan momsperiod genererar aldrig deadlines i byrastod-jobb).
  for v_typ in
    select distinct t from byra_installningar bi, unnest(bi.standard_uppdragstyper) t
    where bi.byra_bolag_id = p_byra_bolag_id
      and t in ('lopande_bokforing','momsdeklaration','lon_agi','bokslut','arsredovisning','inkomstdeklaration')
  loop
    if (v_typ = 'arsredovisning' and coalesce(v_form, '') <> 'Aktiebolag')
       or (v_typ = 'inkomstdeklaration' and coalesce(v_form, '') not in ('Aktiebolag','Enskild näringsidkare'))
       or (v_typ = 'momsdeklaration' and v_moms is null) then
      v_hoppade := v_hoppade || v_typ;
      continue;
    end if;
    insert into public.uppdrag (byra_klient_id, byra_bolag_id, klient_bolag_id, uppdragstyp,
      bokforingstakt, startdatum, status)
    values (v_bk, p_byra_bolag_id, v_klient, v_typ,
      case when v_typ = 'lopande_bokforing' then 'manad' end, date_trunc('month', now())::date, 'aktiv');
    v_antal_uppdrag := v_antal_uppdrag + 1;
  end loop;

  return jsonb_build_object('klient_bolag_id', v_klient, 'byra_klient_id', v_bk,
    'namn', v_namn, 'antal_uppdrag', v_antal_uppdrag, 'hoppade_typer', to_jsonb(v_hoppade));
end $function$
;

CREATE OR REPLACE FUNCTION public.byra_synliga_bolag_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select bm.byra_bolag_id from byra_medlemskap bm
  where bm.anvandare_id = auth.uid() and bm.aktiv
  union
  select bk.klient_bolag_id from byra_klient bk
  join byra_medlemskap bm on bm.byra_bolag_id = bk.byra_bolag_id
  where bm.anvandare_id = auth.uid() and bm.aktiv
    and (bm.roll = 'admin'
         or (bk.kundansvarig_anvandare_id = auth.uid() and bk.status <> 'inaktiv'))
$function$
;

CREATE OR REPLACE FUNCTION public.byra_uppdatera_uppgifter(p_byra_bolag_id uuid, p_namn text, p_org_nr text DEFAULT NULL::text, p_adress text DEFAULT NULL::text, p_postnr text DEFAULT NULL::text, p_postort text DEFAULT NULL::text, p_telefon text DEFAULT NULL::text, p_epost text DEFAULT NULL::text, p_webb text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then raise exception 'Ej inloggad'; end if;
  if not public.ar_byra_admin(p_byra_bolag_id) then
    raise exception 'Endast byråns administratör får ändra byråuppgifterna';
  end if;
  if length(trim(coalesce(p_namn, ''))) < 2 then raise exception 'Ange byråns namn'; end if;
  if nullif(trim(coalesce(p_org_nr, '')), '') is not null
     and length(regexp_replace(p_org_nr, '\D', '', 'g')) <> 10 then
    raise exception 'Ange ett giltigt organisationsnummer (10 siffror)';
  end if;
  update companies set
    name = trim(p_namn),
    org_nr = nullif(trim(coalesce(p_org_nr, '')), ''),
    address = nullif(trim(coalesce(p_adress, '')), ''),
    postnr = nullif(trim(coalesce(p_postnr, '')), ''),
    postort = nullif(trim(coalesce(p_postort, '')), ''),
    phone = nullif(trim(coalesce(p_telefon, '')), ''),
    email = nullif(trim(coalesce(p_epost, '')), ''),
    website = nullif(trim(coalesce(p_webb, '')), '')
  where id = p_byra_bolag_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.byrastod_markera_forsenade()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_antal int;
begin
  if not public._ar_betrodd_backend() and not public.ar_byra_medlem() then
    raise exception 'endast byråmedlem eller systemjobb';
  end if;
  update public.uppdragsuppgift set status = 'forsenad', updated_at = now()
  where status in ('ej_paborjad', 'pagar')
    and coalesce(justerat_forfallodatum, ordinarie_forfallodatum) < current_date;
  get diagnostics v_antal = row_count;
  return v_antal;
end $function$
;

CREATE OR REPLACE FUNCTION public.byrastod_uppgift_fore_update()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_revisionsplikt boolean;
  v_dagar int;
begin
  if new.revisionsstart_datum is distinct from old.revisionsstart_datum then
    select u.revisionsplikt into v_revisionsplikt from public.uppdrag u where u.id = new.uppdrag_id;
    if coalesce(v_revisionsplikt, false) then
      select (parametrar->>'dagar_fore')::int into v_dagar
      from public.deadline_regel
      where uppgiftstyp = 'bokslut' and variant = 'revisionsstart'
        and (giltig_till is null or giltig_till >= current_date)
      order by giltig_fran desc limit 1;
      new.ordinarie_forfallodatum = case
        when new.revisionsstart_datum is null then null
        else new.revisionsstart_datum - coalesce(v_dagar, 14)
      end;
    end if;
  end if;
  if new.status = 'klar' and old.status <> 'klar' and new.klarmarkerad_at is null then
    new.klarmarkerad_at = now();
  end if;
  new.updated_at = now();
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.byrastod_validera_uppdrag()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_form text;
  v_bk record;
begin
  select byra_bolag_id, klient_bolag_id into v_bk from public.byra_klient where id = new.byra_klient_id;
  if v_bk is null then raise exception 'byra_klient saknas'; end if;
  if new.byra_bolag_id <> v_bk.byra_bolag_id or new.klient_bolag_id <> v_bk.klient_bolag_id then
    raise exception 'uppdragets bolagskoppling matchar inte klientkopplingen';
  end if;
  select foretagsform into v_form from public.companies where id = new.klient_bolag_id;
  if new.uppdragstyp = 'arsredovisning' and coalesce(v_form, '') <> 'Aktiebolag' then
    raise exception 'Årsredovisning är endast valbar för aktiebolag';
  end if;
  if new.byraanstand_aktiv and coalesce(v_form, '') <> 'Enskild näringsidkare' then
    raise exception 'Byråanstånd gäller endast enskild näringsverksamhet';
  end if;
  new.updated_at = now();
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.can_company_write(p_company_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case
    when p_company_id is null then true
    when public.can_manage_operations() then true
    else coalesce((select service_state from public.companies where id = p_company_id), 'active') = 'active'
  end
$function$
;

CREATE OR REPLACE FUNCTION public.can_manage_billing()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.has_platform_role('billing_admin') $function$
;

CREATE OR REPLACE FUNCTION public.can_manage_operations()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.has_platform_role('operations_admin') $function$
;

CREATE OR REPLACE FUNCTION public.can_view_billing()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select public.has_platform_role('billing_admin') or public.is_read_only_admin() $function$
;

CREATE OR REPLACE FUNCTION public.can_view_operations()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.has_platform_role('operations_admin') $function$
;

CREATE OR REPLACE FUNCTION public.can_view_support()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.has_platform_role('support_admin') $function$
;

CREATE OR REPLACE FUNCTION public.check_all_plan_limits(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare m text; v jsonb := '[]'::jsonb;
begin
  if not (p_company_id in (select user_company_ids()) or public.can_manage_billing()) then
    raise exception 'forbidden' using errcode='42501'; end if;
  foreach m in array array['users','companies','invoices','documents','storage','ai'] loop
    v := v || jsonb_build_array(public.check_plan_limit(p_company_id, m));
  end loop;
  return v;
end $function$
;

CREATE OR REPLACE FUNCTION public.check_plan_limit(p_company_id uuid, p_metric text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not (p_company_id in (select user_company_ids()) or public.can_manage_billing()) then
    raise exception 'forbidden' using errcode='42501'; end if;
  return public._plan_limit_status(p_company_id, p_metric);
end $function$
;

CREATE OR REPLACE FUNCTION public.clear_chart_of_accounts(p_company uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_deleted int:=0; v_deactivated int:=0; v_preserved_locked int:=0; v_nr text;
  v_email text := auth.jwt()->>'email'; v_uid uuid := auth.uid();
begin
  perform public._assert_company_access(p_company);
  perform set_config('app.bulk_import','on',true);
  select count(*) into v_preserved_locked from public.accounts where company_id=p_company and is_locked=true;
  for v_nr in select account_nr from public.accounts where company_id=p_company and is_locked=false loop
    if exists(select 1 from public.verifikation_rows vr
              join public.verifikationer v on v.id=vr.verifikation_id
              where v.company_id=p_company and vr.account_nr=v_nr) then
      update public.accounts set is_active=false where company_id=p_company and account_nr=v_nr and is_active=true;
      if found then v_deactivated:=v_deactivated+1; end if;
    else
      delete from public.accounts where company_id=p_company and account_nr=v_nr;
      v_deleted:=v_deleted+1;
    end if;
  end loop;
  insert into public.audit_log(company_id, entity, action, new_data, changed_by, changed_by_email)
  values (p_company,'account','clear',
          jsonb_build_object('deleted',v_deleted,'deactivated',v_deactivated,'preserved_locked',v_preserved_locked),
          v_uid,v_email);
  return jsonb_build_object('deleted',v_deleted,'deactivated',v_deactivated,'preserved_locked',v_preserved_locked);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.comment_mc_item(p_item uuid, p_body text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record; v_id uuid;
begin
  if p_body is null or length(trim(p_body)) = 0 then raise exception 'tom kommentar' using errcode='22023'; end if;
  g := public._mc_item_guard(p_item);
  insert into monthly_control_comments(item_id, company_id, user_id, body) values (p_item, g.company_id, auth.uid(), left(p_body,4000)) returning id into v_id;
  insert into monthly_control_events(monthly_control_id, item_id, company_id, user_id, event_type)
  values (g.monthly_control_id, p_item, g.company_id, auth.uid(), 'comment');
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.create_support_ticket(p_company_id uuid, p_subject text, p_category text, p_priority text, p_body text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_id uuid; v_msg uuid; v_company text; v_prio text; v_cat text;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=v_uid and uc.company_id=p_company_id) then
    raise exception 'forbidden' using errcode='42501'; end if;
  v_cat := case when p_category in ('billing','invoice_import','bookkeeping','login_access','technical_error','feature_request','other') then p_category else 'other' end;
  v_prio := case when p_priority='urgent' then 'high' when p_priority in ('low','normal','high') then p_priority else 'normal' end;
  insert into support_tickets(company_id, created_by_user_id, subject, category, priority, status, last_message_at)
  values (p_company_id, v_uid, left(p_subject,200), v_cat, v_prio, 'new', now()) returning id into v_id;
  insert into support_messages(ticket_id, sender_user_id, is_admin, body) values (v_id, v_uid, false, p_body) returning id into v_msg;
  select name into v_company from companies where id=p_company_id;
  perform public.notify_event(p_company_id, 'support_ticket_created',
    jsonb_build_object('subject',left(p_subject,200),'company',coalesce(v_company,''),'category',v_cat,
      'priority',v_prio,'snippet',public._support_snip(p_body),'actionUrl','https://app.bokpilot.se/admin/support'),
    'support_ticket', v_id, '/admin/support', public.support_admin_ids(), v_uid,
    case v_prio when 'high' then 'high' else 'normal' end);
  -- Kundbekräftelse: enbart till ärendeskaparen (in-app + e-post enligt preferenser).
  perform public.notify_event(p_company_id, 'support_ticket_customer_ack',
    jsonb_build_object('subject',left(p_subject,200),'actionUrl','https://app.bokpilot.se/support'),
    'support_ticket', v_id, '/support', array[v_uid], v_uid, 'normal', 'ack:'||v_id::text);
  perform public.log_platform_audit('support_ticket_created', v_id::text, jsonb_build_object('category',v_cat,'priority',v_prio,'company_id',p_company_id));
  return jsonb_build_object('ticket_id', v_id, 'message_id', v_msg);
end $function$
;

CREATE OR REPLACE FUNCTION public.cron_run_monthly_controls()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record; y int; m int;
begin
  y := extract(year from (now() at time zone 'Europe/Stockholm'))::int;
  m := extract(month from (now() at time zone 'Europe/Stockholm'))::int;
  for r in select company_id from monthly_controls where year=y and month=m and status <> 'closed' loop
    begin perform public.run_monthly_control(r.company_id, y, m); exception when others then null; end;
  end loop;
end $function$
;

CREATE OR REPLACE FUNCTION public.customer_close_support_ticket(p_ticket_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); t record;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select * into t from support_tickets where id=p_ticket_id;
  if t is null then raise exception 'not found' using errcode='P0002'; end if;
  if not (t.created_by_user_id=v_uid or t.company_id in (select user_company_ids())) then
    raise exception 'forbidden' using errcode='42501'; end if;
  if t.status='closed' then return; end if;
  update support_tickets set status='closed', closed_at=now(), updated_at=now() where id=p_ticket_id;
  perform public.log_platform_audit('support_ticket_customer_closed', p_ticket_id::text, '{}'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.customer_reply_support_ticket(p_ticket_id uuid, p_body text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); t record; v_company text; v_recips uuid[]; v_msg uuid;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select * into t from support_tickets where id=p_ticket_id;
  if t is null then raise exception 'not found' using errcode='P0002'; end if;
  if not (t.created_by_user_id=v_uid or t.company_id in (select user_company_ids())) then raise exception 'forbidden' using errcode='42501'; end if;
  insert into support_messages(ticket_id, sender_user_id, is_admin, body) values (p_ticket_id, v_uid, false, p_body) returning id into v_msg;
  update support_tickets set status=case when status in ('closed','resolved') then status else 'waiting_for_support' end,
    last_message_at=now(), updated_at=now() where id=p_ticket_id;
  select name into v_company from companies where id=t.company_id;
  select array_agg(distinct x) into v_recips from unnest(public.support_admin_ids() || case when t.assigned_admin_id is not null then array[t.assigned_admin_id] else '{}'::uuid[] end) x;
  perform public.notify_event(t.company_id, 'support_ticket_customer_reply',
    jsonb_build_object('subject',t.subject,'company',coalesce(v_company,''),'snippet',public._support_snip(p_body),'actionUrl','https://app.bokpilot.se/admin/support'),
    'support_ticket', p_ticket_id, '/admin/support', v_recips, v_uid,
    case t.priority when 'urgent' then 'urgent' when 'high' then 'high' else 'normal' end);
  perform public.log_platform_audit('support_customer_reply', p_ticket_id::text, '{}'::jsonb);
  return v_msg;
end $function$
;

CREATE OR REPLACE FUNCTION public.delete_account_safe(p_company uuid, p_account_nr text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_locked boolean;
begin
  perform public._assert_company_access(p_company);
  select is_locked into v_locked from public.accounts where company_id=p_company and account_nr=p_account_nr;
  if v_locked is true then
    raise exception 'KONTO_LAST_RADERA: Detta konto är låst och kan inte raderas.';
  end if;
  if exists(select 1 from public.verifikation_rows vr
            join public.verifikationer v on v.id=vr.verifikation_id
            where v.company_id=p_company and vr.account_nr=p_account_nr) then
    raise exception 'KONTO_ANVANDS: Kontot % används i bokföringen och kan inte raderas. Inaktivera det istället.', p_account_nr;
  end if;
  delete from public.accounts where company_id=p_company and account_nr=p_account_nr;
  return jsonb_build_object('deleted', true);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.enforce_company_write_lock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid;
begin
  v_company := case when TG_OP = 'DELETE' then OLD.company_id else NEW.company_id end;
  if auth.uid() is not null and not public.can_company_write(v_company) then
    raise exception 'Tjänsten är pausad för detta företag. Kontakta BokPilot support.' using errcode = '42501';
  end if;
  if TG_OP = 'DELETE' then return OLD; else return NEW; end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.enforce_immutabel_ver_rows()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_nr text; v_tot_debet numeric; v_tot_kredit numeric;
  v_sum_debet numeric; v_sum_kredit numeric;
begin
  if coalesce(current_setting('app.periodlas_bypass', true), '') = 'on'
     or coalesce(current_setting('app.makulera_insert', true), '') = 'on'
     or coalesce(current_setting('app.ver_insert',      true), '') = 'on' then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    -- Enbart avstämningsmarkering: arbetsmarkering, inte bokföringsdata.
    if new.verifikation_id is not distinct from old.verifikation_id
       and new.account_nr = old.account_nr
       and new.account_name is not distinct from old.account_name
       and coalesce(new.debet, 0) = coalesce(old.debet, 0)
       and coalesce(new.kredit, 0) = coalesce(old.kredit, 0)
       and new.transaction_info is not distinct from old.transaction_info
       and new.sort_order is not distinct from old.sort_order then
      return new;
    end if;
    select v.ver_nr into v_nr from public.verifikationer v
      where v.id = coalesce(old.verifikation_id, new.verifikation_id);
    if found then
      raise exception 'BOKFÖRINGSDATA_LÅST: Raderna i verifikation % är bokförda och kan inte ändras (BFL 5 kap 5 §). Använd Rätta eller Makulera.', v_nr;
    end if;
    return new;   -- modern borta (kaskad) – inget att skydda
  end if;

  -- INSERT: en verifikation är komplett när radsummorna nått huvudets totaler.
  select v.ver_nr, v.total_debet, v.total_kredit into v_nr, v_tot_debet, v_tot_kredit
    from public.verifikationer v where v.id = new.verifikation_id;
  if not found then return new; end if;
  select coalesce(sum(coalesce(r.debet, 0)), 0), coalesce(sum(coalesce(r.kredit, 0)), 0)
    into v_sum_debet, v_sum_kredit
    from public.verifikation_rows r where r.verifikation_id = new.verifikation_id;
  if coalesce(v_tot_debet, 0) + coalesce(v_tot_kredit, 0) > 0
     and round(v_sum_debet, 2) >= round(coalesce(v_tot_debet, 0), 2)
     and round(v_sum_kredit, 2) >= round(coalesce(v_tot_kredit, 0), 2) then
    raise exception 'VERIFIKATION_KOMPLETT: Verifikation % är komplett – nya rader kan inte läggas till (BFL 5 kap 5 §). Använd Rätta.', v_nr;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.enforce_immutabel_verifikation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_old jsonb; v_new jsonb; v_falt text[];
begin
  if coalesce(current_setting('app.rattelse_link',     true), '') = 'on'
     or coalesce(current_setting('app.makulera_insert', true), '') = 'on'
     or coalesce(current_setting('app.periodlas_bypass',true), '') = 'on' then
    return new;
  end if;
  v_old := to_jsonb(old) - 'status' - 'is_locked';
  v_new := to_jsonb(new) - 'status' - 'is_locked';
  if v_old is distinct from v_new then
    select array_agg(t.k order by t.k) into v_falt
    from jsonb_object_keys(v_old || v_new) as t(k)
    where v_old -> t.k is distinct from v_new -> t.k;
    raise exception 'BOKFÖRINGSDATA_LÅST: Verifikation % är bokförd – fälten [%] kan inte ändras (BFL 5 kap 5 §). Använd Rätta eller Makulera.',
      old.ver_nr, array_to_string(v_falt, ', ');
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.enforce_periodlas_ver_rows()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ver uuid; v_company uuid; v_datum date;
begin
  if tg_op = 'UPDATE'
     and new.verifikation_id is not distinct from old.verifikation_id
     and new.account_nr = old.account_nr
     and new.account_name is not distinct from old.account_name
     and coalesce(new.debet, 0) = coalesce(old.debet, 0)
     and coalesce(new.kredit, 0) = coalesce(old.kredit, 0)
     and new.transaction_info is not distinct from old.transaction_info
     and new.sort_order is not distinct from old.sort_order then
    return new;
  end if;
  v_ver := case when tg_op = 'DELETE' then old.verifikation_id else new.verifikation_id end;
  if v_ver is not null then
    select v.company_id, v.datum into v_company, v_datum from public.verifikationer v where v.id = v_ver;
    if found then perform public.assert_period_open(v_company, v_datum); end if;
  end if;
  if tg_op = 'UPDATE' and new.verifikation_id is distinct from old.verifikation_id and old.verifikation_id is not null then
    select v.company_id, v.datum into v_company, v_datum from public.verifikationer v where v.id = old.verifikation_id;
    if found then perform public.assert_period_open(v_company, v_datum); end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $function$
;

CREATE OR REPLACE FUNCTION public.enforce_periodlas_verifikation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op = 'INSERT' then
    perform public.assert_period_open(new.company_id, new.datum);
    return new;
  elsif tg_op = 'UPDATE' then
    if current_setting('app.rattelse_link', true) = 'on'
       and new.datum = old.datum
       and new.company_id is not distinct from old.company_id
       and new.ver_nr = old.ver_nr
       and new.ver_serie is not distinct from old.ver_serie
       and new.beskrivning is not distinct from old.beskrivning
       and coalesce(new.total_debet, 0) = coalesce(old.total_debet, 0)
       and coalesce(new.total_kredit, 0) = coalesce(old.total_kredit, 0) then
      return new;
    end if;
    perform public.assert_period_open(old.company_id, old.datum);
    perform public.assert_period_open(new.company_id, new.datum);
    return new;
  else
    perform public.assert_period_open(old.company_id, old.datum);
    return old;
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.enforce_plan_limit(p_company_id uuid, p_metric text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v jsonb;
begin
  if not (coalesce(auth.jwt() ->> 'role','') = 'service_role'
          or p_company_id in (select user_company_ids()) or public.can_manage_billing()) then
    raise exception 'forbidden' using errcode='42501'; end if;
  v := public._plan_limit_status(p_company_id, p_metric);
  perform public._notify_plan_limit(p_company_id, p_metric, v);
  return v;
end $function$
;

CREATE OR REPLACE FUNCTION public.enforce_write_lock_invoice_rows()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_iid uuid;
begin
  v_iid := case when TG_OP = 'DELETE' then OLD.invoice_id else NEW.invoice_id end;
  select company_id into v_company from public.invoices where id = v_iid;
  if auth.uid() is not null and not public.can_company_write(v_company) then
    raise exception 'Tjänsten är pausad för detta företag. Kontakta BokPilot support.' using errcode = '42501';
  end if;
  if TG_OP = 'DELETE' then return OLD; else return NEW; end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.enforce_write_lock_verifikation_rows()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_vid uuid;
begin
  v_vid := case when TG_OP = 'DELETE' then OLD.verifikation_id else NEW.verifikation_id end;
  select company_id into v_company from public.verifikationer where id = v_vid;
  if auth.uid() is not null and not public.can_company_write(v_company) then
    raise exception 'Tjänsten är pausad för detta företag. Kontakta BokPilot support.' using errcode = '42501';
  end if;
  if TG_OP = 'DELETE' then return OLD; else return NEW; end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.first_open_booking_date(p_company uuid)
 RETURNS date
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_lock text; v_lock_end date; v_start date; v_end date; v_d date;
begin
  select bokforing_last_tom into v_lock from public.companies where id = p_company;
  if v_lock ~ '^\d{4}-\d{2}$' then
    v_lock_end := (to_date(v_lock || '-01', 'YYYY-MM-DD') + interval '1 month - 1 day')::date;
  elsif v_lock ~ '^\d{4}-\d{2}-\d{2}$' then
    v_lock_end := to_date(v_lock, 'YYYY-MM-DD');
  end if;
  select start_date, end_date into v_start, v_end
    from public.fiscal_years where company_id = p_company and status = 'active'
    order by start_date limit 1;
  if v_start is not null then
    v_d := greatest(v_start, coalesce(v_lock_end + 1, v_start));
    if v_d > v_end then
      raise exception 'PERIODLÅST: Det finns inget öppet datum i det aktiva räkenskapsåret. Justera låset under Inställningar eller öppna ett nytt räkenskapsår.';
    end if;
  else
    v_d := coalesce(v_lock_end + 1, current_date);
  end if;
  return v_d;
end $function$
;

CREATE OR REPLACE FUNCTION public.forbjud_andring_bokford_levfaktura()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(OLD.bokford, false) = true
     and coalesce(current_setting('app.periodlas_bypass', true), '') <> 'on'
     and (OLD.total_amount is distinct from NEW.total_amount
       or OLD.vat_amount   is distinct from NEW.vat_amount
       or OLD.kostnadskonto is distinct from NEW.kostnadskonto
       or OLD.invoice_date is distinct from NEW.invoice_date
       or OLD.supplier_id  is distinct from NEW.supplier_id)
  then
    raise exception 'BFL_SKYDD: Fakturan är bokförd – belopp, moms, konto, datum och leverantör kan inte ändras. Makulera och bokför om i stället.';
  end if;
  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.forbjud_bokford_banktx_radering()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if current_setting('app.periodlas_bypass', true) = 'on' then return old; end if;
  if not exists (select 1 from public.companies where id = old.company_id) then
    return old;   -- cascade vid företagsradering
  end if;
  if old.verifikation_id is not null then
    raise exception 'BANKHÄNDELSEN ÄR BOKFÖRD: den är kopplad till en verifikation och kan inte raderas (BFL 7 kap 2 §). Ångra bokföringen först.';
  end if;
  return old;
end $function$
;

CREATE OR REPLACE FUNCTION public.forbjud_bokford_faktura_radering()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if old.bokford or old.verifikation_id is not null then
    raise exception 'Bokförda leverantörsfakturor raderas inte — makulera i stället (rättelse enligt bokföringslagen).';
  end if;
  return old;
end $function$
;

CREATE OR REPLACE FUNCTION public.forbjud_bokford_lonekorning_radering()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(OLD.bokford, false) = true
     and coalesce(current_setting('app.periodlas_bypass', true), '') <> 'on' then
    raise exception 'BFL_SKYDD: Lönekörningen är bokförd och kan inte raderas. Rätta med en omvänd verifikation i stället.';
  end if;
  return OLD;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.forbjud_bokford_radering()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if current_setting('app.periodlas_bypass', true) = 'on'
     or current_setting('app.radera_senaste', true) = 'on' then
    return old;
  end if;
  raise exception 'Bokförda verifikationer får inte raderas (BFL 5 kap 5 §) – använd Makulera, eller Ta bort för senaste i serien';
end $function$
;

CREATE OR REPLACE FUNCTION public.forbjud_sista_admin_bort()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if OLD.role = 'admin'
     and not exists (
       select 1 from public.user_companies uc
       where uc.company_id = OLD.company_id
         and uc.role = 'admin'
         and uc.id <> OLD.id
     )
  then
    raise exception 'SISTA_ADMIN: Bolaget måste ha minst en administratör. Utse en ny innan du tar bort den sista.';
  end if;
  return OLD;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.gallra_gdpr_loggar()
 RETURNS TABLE(tabell text, raderade bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  n bigint;
begin
  delete from public.assistent_logg where created_at < now() - interval '24 months';
  get diagnostics n = row_count;
  tabell := 'assistent_logg'; raderade := n; return next;

  delete from public.robo_bp_messages where created_at < now() - interval '24 months';
  get diagnostics n = row_count;
  tabell := 'robo_bp_messages'; raderade := n; return next;

  delete from public.support_ai_events where created_at < now() - interval '24 months';
  get diagnostics n = row_count;
  tabell := 'support_ai_events'; raderade := n; return next;

  delete from public.kivra_utskick where skickad_at < now() - interval '24 months';
  get diagnostics n = row_count;
  tabell := 'kivra_utskick'; raderade := n; return next;

  delete from public.inbound_email_log where created_at < now() - interval '12 months';
  get diagnostics n = row_count;
  tabell := 'inbound_email_log'; raderade := n; return next;
end $function$
;

CREATE OR REPLACE FUNCTION public.get_ocr_provider_config()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r public.ocr_provider_config;
begin
  if not public.is_superadmin() then
    raise exception 'forbidden';
  end if;
  select * into r from public.ocr_provider_config where id limit 1;
  return jsonb_build_object(
    'folioEnabled', coalesce(r.folio_enabled, false),
    'folioBaseUrl', r.folio_base_url,
    'updatedAt', r.updated_at
  );
end $function$
;

CREATE OR REPLACE FUNCTION public.get_support_ticket(p_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare t record; v_ctx jsonb; v_msgs jsonb; v_notes jsonb; v_att jsonb;
begin
  if not public.can_view_support() then raise exception 'forbidden' using errcode='42501'; end if;
  select * into t from support_tickets where id=p_id;
  if t is null then raise exception 'not found' using errcode='P0002'; end if;
  select jsonb_build_object(
    'company_name', (select name from companies where id=t.company_id),
    'org_nr', (select org_nr from companies where id=t.company_id), 'plan', null,
    'users_count', (select count(*) from user_companies where company_id=t.company_id),
    'last_activity', (select max(created_at) from documents where company_id=t.company_id),
    'recent_inbound_documents', (select count(*) from documents where company_id=t.company_id and source='email' and created_at > now()-interval '30 days'),
    'recent_failed_imports', (select count(*) from account_import_batches where company_id=t.company_id and (status='failed' or error is not null) and created_at > now()-interval '30 days')
  ) into v_ctx;
  select coalesce(jsonb_agg(row_to_json(m) order by m.created_at), '[]'::jsonb) into v_msgs from (
    select id, sender_user_id, is_admin, body, created_at, (select email from auth.users u where u.id=sm.sender_user_id) sender_email
    from support_messages sm where ticket_id=p_id) m;
  select coalesce(jsonb_agg(row_to_json(n) order by n.created_at), '[]'::jsonb) into v_notes from (
    select id, author_admin_id, body, created_at, (select email from auth.users u where u.id=sin.author_admin_id) author_email
    from support_internal_notes sin where ticket_id=p_id) n;
  select coalesce(jsonb_agg(row_to_json(x)), '[]'::jsonb) into v_att from (
    select id, message_id, note_id, file_name, mime_type, file_size, storage_path, visibility, created_at
    from support_attachments where ticket_id=p_id) x;
  perform public.log_platform_audit('support_context_viewed', p_id::text, jsonb_build_object('company_id', t.company_id));
  return jsonb_build_object('ticket', row_to_json(t), 'company_context', v_ctx, 'messages', v_msgs, 'internal_notes', v_notes, 'attachments', v_att);
end $function$
;

CREATE OR REPLACE FUNCTION public.has_ai_feature(p_company uuid, p_key text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=p_company) then false
    else coalesce(
      (select f.enabled from company_ai_features f where f.company_id=p_company and f.feature_key=p_key),
      exists (
        select 1 from company_subscriptions cs join subscription_plans sp on sp.id=cs.plan_id
        where cs.company_id=p_company and coalesce(cs.status,'') in ('active','trialing','trial')
          and sp.features ? p_key),
      false) end;
$function$
;

CREATE OR REPLACE FUNCTION public.has_kyc_clearance(p_company_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case
    when not (public.ar_min_klient(p_company_id)
              or p_company_id in (select public.user_company_ids())
              or public.is_platform_admin())
    then null
    else exists (
      select 1 from kyc_assessments k
      where k.company_id = p_company_id
        and k.status = 'godkand'
        and (k.giltig_till is null or k.giltig_till >= current_date)
        and coalesce(k.sanktion_traff, false) = false
        and k.created_at = (select max(created_at) from kyc_assessments where company_id = p_company_id)
    )
    and not exists (
      select 1 from aml_flags f
      where f.company_id = p_company_id and f.typ = 'sanktionstraff' and f.status = 'oppen'
    )
  end;
$function$
;

CREATE OR REPLACE FUNCTION public.has_platform_role(p_role text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.is_platform_admin()  -- superadmin har alla roller
      or exists (select 1 from public.platform_user_roles r
                 where lower(r.email) = lower(auth.jwt() ->> 'email') and r.role = p_role)
$function$
;

CREATE OR REPLACE FUNCTION public.ignore_mc_item(p_item uuid, p_reason text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record;
begin
  if p_reason is null or length(trim(p_reason)) < 2 then raise exception 'motivering krävs' using errcode='22023'; end if;
  g := public._mc_item_guard(p_item);
  update monthly_control_items set status='ignored', ignored_reason=left(p_reason,500), resolved_by=auth.uid(), resolved_at=now(), updated_at=now() where id=p_item;
  insert into monthly_control_events(monthly_control_id, item_id, company_id, user_id, event_type, detail)
  values (g.monthly_control_id, p_item, g.company_id, auth.uid(), 'ignored', jsonb_build_object('reason', left(p_reason,500)));
  perform public._mc_recount(g.monthly_control_id);
end $function$
;

CREATE OR REPLACE FUNCTION public.import_chart_of_accounts(p_company uuid, p_mode text, p_filename text, p_rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_batch uuid := gen_random_uuid();
  v_email text := auth.jwt() ->> 'email';
  v_uid uuid := auth.uid();
  v_inserted int := 0; v_updated int := 0; v_skipped int := 0;
  v_deactivated int := 0; v_deleted int := 0; v_total int := 0;
  v_ignored_locked int := 0; v_new_locked int := 0;
  r jsonb; v_nr text; v_locked boolean; v_blocked boolean;
begin
  perform public._assert_company_access(p_company);
  if p_mode not in ('replace','add','update') then
    raise exception 'OGILTIGT_LAGE: %', p_mode;
  end if;
  perform set_config('app.bulk_import','on',true);
  v_total := coalesce(jsonb_array_length(p_rows), 0);

  for r in select * from jsonb_array_elements(p_rows) loop
    v_nr := nullif(r->>'account_nr','');
    if v_nr is null then v_skipped := v_skipped + 1; continue; end if;
    v_blocked := coalesce((r->>'is_blocked_for_manual_booking')::boolean, false);

    -- finns kontot, och är det redan låst?
    select is_locked into v_locked from public.accounts
      where company_id = p_company and account_nr = v_nr;

    -- Befintligt LÅST konto: bevara exakt, ignorera all ändring i alla lägen.
    if v_locked is true then
      v_ignored_locked := v_ignored_locked + 1;
      insert into public.audit_log(company_id, entity, entity_ref, action, new_data, batch_id, changed_by, changed_by_email)
      values (p_company, 'account', v_nr, 'import_skip_locked',
              jsonb_build_object('reason','låst systemkonto bevaras','mode',p_mode), v_batch, v_uid, v_email);
      continue;
    end if;

    if v_locked is null then
      -- nytt konto
      if p_mode = 'update' then
        v_skipped := v_skipped + 1; continue;  -- update rör bara befintliga
      end if;
      insert into public.accounts(company_id, account_nr, name, vat_code, sru, is_active,
             account_class, account_type, is_blocked_for_manual_booking, is_locked,
             locked_reason, locked_source, imported_from, import_batch_id)
      values (p_company, v_nr, coalesce(r->>'name',''), nullif(r->>'vat_code',''), nullif(r->>'sru',''),
             coalesce((r->>'is_active')::boolean, true), public.bas_class(v_nr), public.bas_type(v_nr),
             v_blocked, v_blocked,
             case when v_blocked then 'Blockerat för manuell bokföring' end,
             case when v_blocked then coalesce(p_filename,'import') end,
             p_filename, v_batch);
      v_inserted := v_inserted + 1;
      if v_blocked then v_new_locked := v_new_locked + 1; end if;
    else
      -- befintligt, ej låst → uppdatera (add hoppar över befintliga)
      if p_mode = 'add' then v_skipped := v_skipped + 1; continue; end if;
      update public.accounts set name=coalesce(nullif(r->>'name',''), name),
             vat_code=coalesce(nullif(r->>'vat_code',''), vat_code),
             is_active=coalesce((r->>'is_active')::boolean, is_active),
             account_class=public.bas_class(v_nr), account_type=public.bas_type(v_nr),
             is_blocked_for_manual_booking=v_blocked,
             is_locked = (is_locked or v_blocked),
             locked_reason = case when v_blocked then coalesce(locked_reason,'Blockerat för manuell bokföring') else locked_reason end,
             locked_source = case when v_blocked then coalesce(locked_source, p_filename) else locked_source end,
             imported_from=p_filename, import_batch_id=v_batch
      where company_id=p_company and account_nr=v_nr;
      v_updated := v_updated + 1;
      if v_blocked then v_new_locked := v_new_locked + 1; end if;
    end if;
  end loop;

  -- replace: konton som INTE finns i filen och INTE är låsta → inaktivera om använda, annars radera
  if p_mode = 'replace' then
    for v_nr in
      select account_nr from public.accounts
      where company_id = p_company and import_batch_id is distinct from v_batch and is_locked = false
    loop
      if exists(select 1 from public.verifikation_rows vr
                join public.verifikationer v on v.id = vr.verifikation_id
                where v.company_id = p_company and vr.account_nr = v_nr) then
        update public.accounts set is_active=false
          where company_id=p_company and account_nr=v_nr and is_active=true;
        if found then v_deactivated := v_deactivated + 1; end if;
      else
        delete from public.accounts where company_id=p_company and account_nr=v_nr;
        v_deleted := v_deleted + 1;
      end if;
    end loop;
  end if;

  insert into public.account_import_batches(id, company_id, filename, mode, total_rows,
         inserted, updated, skipped, deactivated, deleted, imported_by, imported_by_email)
  values (v_batch, p_company, p_filename, p_mode, v_total,
         v_inserted, v_updated, v_skipped + v_ignored_locked, v_deactivated, v_deleted, v_uid, v_email);

  insert into public.audit_log(company_id, entity, action, new_data, batch_id, changed_by, changed_by_email)
  values (p_company, 'account', case when p_mode='replace' then 'replace' else 'import' end,
         jsonb_build_object('mode',p_mode,'filename',p_filename,'inserted',v_inserted,'updated',v_updated,
                            'skipped',v_skipped,'ignored_locked',v_ignored_locked,'new_locked',v_new_locked,
                            'deactivated',v_deactivated,'deleted',v_deleted),
         v_batch, v_uid, v_email);

  return jsonb_build_object('batch_id',v_batch,'total',v_total,'inserted',v_inserted,'updated',v_updated,
                            'skipped',v_skipped,'ignored_locked',v_ignored_locked,'new_locked',v_new_locked,
                            'deactivated',v_deactivated,'deleted',v_deleted);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.inbox_addr_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if (NEW.email_address is distinct from OLD.email_address)
     or (NEW.inbox_type is distinct from OLD.inbox_type)
     or (NEW.company_id is distinct from OLD.company_id) then
    raise exception 'Mottagningsadressens format kan inte ändras';
  end if;
  NEW.updated_at := now();
  return NEW;
end $function$
;

CREATE OR REPLACE FUNCTION public.is_platform_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists(select 1 from platform_admins where lower(email) = lower(auth.jwt() ->> 'email'))
$function$
;

CREATE OR REPLACE FUNCTION public.is_read_only_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ select public.has_platform_role('read_only_admin') $function$
;

CREATE OR REPLACE FUNCTION public.is_superadmin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.is_platform_admin()
$function$
;

CREATE OR REPLACE FUNCTION public.journalfor_verifikationsandring()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_motpart_id uuid := coalesce(new.rattad_av, new.makulerad_av);
begin
  if new.status in ('rattad', 'makulerad')
     and old.status is distinct from new.status
     and v_motpart_id is not null then
    insert into public.verifikation_andringar
      (company_id, original_id, rattelse_id, orsak, utford_av_epost)
    values (
      new.company_id, new.id, v_motpart_id,
      (select left(v.beskrivning, 500) from public.verifikationer v where v.id = v_motpart_id),
      coalesce(auth.jwt() ->> 'email', 'system')
    );
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.justera_uppgift_deadline(p_uppgift_id uuid, p_nytt_datum date, p_anledning text)
 RETURNS uppdragsuppgift
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_u public.uppdragsuppgift;
  v_behorig boolean;
begin
  select * into v_u from public.uppdragsuppgift where id = p_uppgift_id;
  if v_u is null then raise exception 'uppgiften finns inte'; end if;
  select (
    public.ar_byra_admin(v_u.byra_bolag_id)
    or v_u.uppdragsansvarig_anvandare_id = auth.uid()
    or exists (select 1 from public.uppdrag u join public.byra_klient bk on bk.id = u.byra_klient_id
               where u.id = v_u.uppdrag_id and bk.kundansvarig_anvandare_id = auth.uid())
  ) and v_u.byra_bolag_id in (select public.min_byra_ids()) into v_behorig;
  if not coalesce(v_behorig, false) then
    raise exception 'endast byråns ansvariga får justera förfallodatum';
  end if;
  if length(trim(coalesce(p_anledning, ''))) < 3 then
    raise exception 'anledning krävs vid justering av förfallodatum';
  end if;
  update public.uppdragsuppgift set
    justerat_forfallodatum = p_nytt_datum,
    justering_anledning = trim(p_anledning),
    justerad_av = auth.uid(),
    justerad_at = now(),
    status = case when status = 'forsenad' then 'ej_paborjad' else status end,
    updated_at = now()
  where id = p_uppgift_id
  returning * into v_u;
  return v_u;
end $function$
;

CREATE OR REPLACE FUNCTION public.lager_handelser_appendonly()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(current_setting('app.periodlas_bypass', true), '') = 'on' then
    return coalesce(NEW, OLD);
  end if;

  if TG_OP = 'DELETE' then
    raise exception 'LAGER_LAST: Lagerhändelser kan inte raderas – de är underlag till lagervärderingen (BFL 7 kap. 2 §). Rätta med en motbokande händelse i stället.';
  end if;

  raise exception 'LAGER_LAST: Lagerhändelser kan inte ändras i efterhand. Rätta med en motbokande händelse i stället.';
end;
$function$
;

CREATE OR REPLACE FUNCTION public.lager_inventering_last()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare v_status text;
begin
  if coalesce(current_setting('app.periodlas_bypass', true), '') = 'on' then
    return coalesce(NEW, OLD);
  end if;

  if TG_TABLE_NAME = 'lager_inventeringar' then
    if OLD.status = 'slutford' then
      raise exception 'INVENTERING_LAST: Inventering % är slutförd och kan inte ändras eller tas bort. Gör en ny inventering i stället.', OLD.nr;
    end if;
    return coalesce(NEW, OLD);
  end if;

  select status into v_status from public.lager_inventeringar where id = OLD.inventering_id;
  if v_status = 'slutford' then
    raise exception 'INVENTERING_LAST: Raden hör till en slutförd inventering och kan inte ändras. Förteckningen är underlag till lagervärderingen (lag 1955:257).';
  end if;
  return coalesce(NEW, OLD);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.list_support_admins()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_view_support() then raise exception 'forbidden' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',id,'email',email) order by email)
    from auth.users where id = any(public.support_admin_ids())), '[]'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.list_support_tickets(p_status text DEFAULT NULL::text, p_priority text DEFAULT NULL::text, p_company_id uuid DEFAULT NULL::uuid, p_assigned_admin_id uuid DEFAULT NULL::uuid, p_search text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_view_support() then raise exception 'forbidden' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(row_to_json(r)) from (
    select t.id, t.subject, t.category, t.priority, t.status, t.company_id, c.name company_name,
      t.assigned_admin_id, au.email assigned_email, t.created_at, t.last_message_at, t.closed_at,
      (select count(*) from support_messages m where m.ticket_id=t.id) message_count
    from support_tickets t
    left join companies c on c.id=t.company_id
    left join auth.users au on au.id=t.assigned_admin_id
    where (p_status is null or t.status=p_status)
      and (p_priority is null or t.priority=p_priority)
      and (p_company_id is null or t.company_id=p_company_id)
      and (p_assigned_admin_id is null or t.assigned_admin_id=p_assigned_admin_id)
      and (p_search is null or t.subject ilike '%'||p_search||'%' or c.name ilike '%'||p_search||'%')
    order by case t.priority when 'urgent' then 0 when 'high' then 1 when 'normal' then 2 else 3 end, t.last_message_at desc nulls last
    limit 200) r), '[]'::jsonb);
end $function$
;

CREATE OR REPLACE FUNCTION public.log_accounting_audit(p_action text, p_entity text, p_entity_ref text, p_source text DEFAULT NULL::text, p_metadata jsonb DEFAULT NULL::jsonb, p_company_id uuid DEFAULT NULL::uuid, p_before jsonb DEFAULT NULL::jsonb, p_after jsonb DEFAULT NULL::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_email text := auth.jwt() ->> 'email';
  v_company uuid := p_company_id;
begin
  if v_company is null and p_entity = 'document' and p_entity_ref is not null then
    select company_id into v_company from public.documents where id = p_entity_ref::uuid;
    if v_actor is not null and v_company is not null
       and not exists (select 1 from public.user_companies uc where uc.user_id = v_actor and uc.company_id = v_company) then
      return;
    end if;
  elsif pg_trigger_depth() = 0 and v_actor is not null and v_company is not null then
    perform public._assert_company_access(v_company);
  end if;
  if v_company is null then return; end if;

  begin
    insert into public.audit_log(company_id, entity, entity_ref, action, old_data, new_data, metadata, source, changed_by, changed_by_email)
    values (v_company, p_entity, p_entity_ref, p_action, p_before, p_after, p_metadata,
            coalesce(p_source, case when v_actor is not null then 'ui' else 'system' end), v_actor, v_email);
  exception
    when foreign_key_violation then
      null;   -- bolaget raderas (cascade) – auditraden har inget att peka på
  end;
end $function$
;

CREATE OR REPLACE FUNCTION public.log_ai_error(p_provider text, p_model text, p_status_code integer, p_error_code text, p_error_body text, p_request_id text, p_attempts integer, p_kind text, p_user_id uuid, p_company_id uuid, p_document_id uuid)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  insert into public.ai_error_log(provider, model, status_code, error_code, error_body, request_id, attempts, kind, user_id, company_id, document_id)
  values (p_provider, p_model, p_status_code, p_error_code, left(coalesce(p_error_body, ''), 8000), p_request_id, p_attempts, p_kind, p_user_id, p_company_id, p_document_id);
$function$
;

CREATE OR REPLACE FUNCTION public.log_bokslut_denied(p_action text, p_reason text DEFAULT NULL::text, p_company uuid DEFAULT NULL::uuid, p_engagement uuid DEFAULT NULL::uuid, p_context jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid := p_company; v_eng_company uuid; v_role text;
begin
  if auth.uid() is null then return; end if;
  if p_engagement is not null then
    select company_id into v_eng_company from bokslut_engagements where id = p_engagement;
    if v_eng_company is not null then v_company := v_eng_company; end if;
  end if;
  if v_company is not null then
    select role into v_role from user_companies where user_id = auth.uid() and company_id = v_company;
  end if;
  insert into bokslut_denied_log (user_id, company_id, engagement_id, role, action, reason, context)
  values (auth.uid(), v_company, p_engagement, coalesce(v_role, 'none'),
    left(coalesce(p_action,''), 100), left(coalesce(p_reason,''), 500),
    coalesce(p_context, '{}'::jsonb));
end $function$
;

CREATE OR REPLACE FUNCTION public.log_inbox_download(p_company_id uuid, p_section text, p_kind text, p_file_count integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from user_companies where user_id = auth.uid() and company_id = p_company_id) then
    raise exception 'forbidden';
  end if;
  insert into download_audit_log (user_id, company_id, section, kind, file_count)
  values (auth.uid(), p_company_id, left(coalesce(p_section, ''), 40), left(coalesce(p_kind, ''), 20), greatest(0, coalesce(p_file_count, 0)));
end $function$
;

CREATE OR REPLACE FUNCTION public.log_platform_audit(p_action text, p_target text, p_detail jsonb DEFAULT '{}'::jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.platform_audit_log(actor_email, actor_id, action, target, detail)
  values (auth.jwt() ->> 'email', auth.uid(), p_action, p_target, coalesce(p_detail,'{}'::jsonb));
end $function$
;

CREATE OR REPLACE FUNCTION public.log_robo_bp_event(p_company uuid, p_action text, p_detail jsonb DEFAULT '{}'::jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  if p_company is null or p_company not in (select user_company_ids()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  insert into public.robo_bp_audit_log(company_id, user_id, action, detail)
    values (p_company, auth.uid(), coalesce(nullif(p_action, ''), 'ai_query'), coalesce(p_detail, '{}'::jsonb))
    returning id into v_id;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.log_support_attachment_download(p_attachment_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare a record;
begin
  -- Endast om anroparen har åtkomst (samma villkor som sa_select).
  select * into a from public.support_attachments where id=p_attachment_id and (
    public.can_view_support() or (visibility='customer_visible' and exists (
      select 1 from support_tickets t where t.id=ticket_id and (t.created_by_user_id=auth.uid() or t.company_id in (select user_company_ids())))));
  if a is null then raise exception 'forbidden' using errcode='42501'; end if;
  perform public.log_platform_audit('support_attachment_downloaded', a.ticket_id::text, jsonb_build_object('attachment_id',p_attachment_id));
end $function$
;

CREATE OR REPLACE FUNCTION public.makulera_verifikation(p_ver_id uuid, p_orsak text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_orig public.verifikationer%rowtype;
  v_mot_id uuid;
  v_mot_nr text;
  v_locked boolean := false;
  v_datum date;
begin
  select * into v_orig from public.verifikationer where id = p_ver_id;
  if not found then
    raise exception 'FEL: Verifikationen finns inte.';
  end if;
  if not public._ar_betrodd_backend() and not exists (
    select 1 from public.user_companies uc where uc.user_id = v_actor and uc.company_id = v_orig.company_id
  ) then
    raise exception 'ATKOMST_NEKAD: Du har inte åtkomst till detta företag.';
  end if;
  if v_orig.status = 'makulerad' then
    raise exception 'MAKULERAD: Verifikation % är redan makulerad.', v_orig.ver_nr;
  end if;
  if v_orig.status = 'motverifikation' then
    raise exception 'FEL: En motverifikation kan inte makuleras. Bokför en ny verifikation i stället.';
  end if;
  if v_orig.status in ('rattad', 'rattelse') then
    raise exception 'FEL: Verifikation % ingår i en rättelsekedja (%) och kan inte makuleras.', v_orig.ver_nr, v_orig.status;
  end if;

  -- Ligger originalet i låst period bokförs motverifikationen på första öppna
  -- datum. Det förflutna rörs inte – motposten läggs framåt.
  begin
    perform public.assert_period_open(v_orig.company_id, v_orig.datum);
  exception when others then
    v_locked := true;
  end;
  v_datum := case when v_locked
                  then public.first_open_booking_date(v_orig.company_id)
                  else v_orig.datum end;

  v_mot_nr := public.next_ver_nr(v_orig.company_id, v_orig.ver_serie);
  perform set_config('app.makulera_insert', 'on', true);
  insert into public.verifikationer(company_id, ver_nr, ver_serie, datum, beskrivning,
                                    total_debet, total_kredit, created_by, status, motverkar)
  values (v_orig.company_id, v_mot_nr, v_orig.ver_serie, v_datum,
          left('Makulering av ' || v_orig.ver_nr || coalesce(': ' || nullif(trim(p_orsak), ''), ''), 200),
          v_orig.total_kredit, v_orig.total_debet, v_actor, 'motverifikation', v_orig.id)
  returning id into v_mot_id;
  insert into public.verifikation_rows(verifikation_id, account_nr, account_name, debet, kredit, transaction_info, sort_order)
  select v_mot_id, r.account_nr, r.account_name, coalesce(r.kredit, 0), coalesce(r.debet, 0), r.transaction_info, r.sort_order
  from public.verifikation_rows r where r.verifikation_id = v_orig.id;
  perform set_config('app.makulera_insert', 'off', true);

  perform set_config('app.rattelse_link', 'on', true);
  update public.verifikationer set status = 'makulerad', makulerad_av = v_mot_id where id = v_orig.id;
  perform set_config('app.rattelse_link', 'off', true);

  update public.supplier_invoices set bokford = false, verifikation_id = null where verifikation_id = v_orig.id;
  update public.supplier_invoices set paid_amount = 0, paid_date = null, status = 'unpaid', betalning_ver_id = null
    where betalning_ver_id = v_orig.id;
  update public.invoices set status = 'sent', betalning_ver_id = null where betalning_ver_id = v_orig.id;
  update public.bank_transactions set status = 'unmatched', verifikation_id = null where verifikation_id = v_orig.id;
  update public.invoices set verifikation_id = null where verifikation_id = v_orig.id;

  perform public.log_accounting_audit(
    'verification_voided', 'verifikation', v_orig.id::text, null,
    jsonb_build_object('ver_nr', v_orig.ver_nr, 'motverifikation_id', v_mot_id, 'motverifikation_nr', v_mot_nr,
                       'orsak', left(nullif(trim(p_orsak), ''), 200),
                       'makuleringsdatum', v_datum, 'period_locked_original', v_locked),
    v_orig.company_id,
    jsonb_build_object('status', 'aktiv'),
    jsonb_build_object('status', 'makulerad', 'makulerad_av', v_mot_id));

  return jsonb_build_object('ok', true, 'motverifikation_id', v_mot_id, 'motverifikation_nr', v_mot_nr,
                            'datum', v_datum, 'period_locked_original', v_locked);
end $function$
;

CREATE OR REPLACE FUNCTION public.map_stripe_status(p text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select case p
    when 'trialing' then 'trial' when 'active' then 'active' when 'past_due' then 'past_due'
    when 'canceled' then 'cancelled' when 'unpaid' then 'past_due'
    when 'incomplete' then 'past_due' when 'incomplete_expired' then 'cancelled' else 'past_due' end
$function$
;

CREATE OR REPLACE FUNCTION public.mark_support_read(p_ticket_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into public.support_reads (ticket_id, user_id, last_read_at)
  values (p_ticket_id, auth.uid(), now())
  on conflict (ticket_id, user_id) do update set last_read_at = excluded.last_read_at;
end; $function$
;

CREATE OR REPLACE FUNCTION public.mc_open_counts(p_company uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=p_company)
    then (select jsonb_build_object(
            'critical', count(*) filter (where priority='critical'),
            'high', count(*) filter (where priority='high'),
            'open', count(*))
          from monthly_control_items
          where company_id=p_company
            and status in ('open','in_progress','waiting_for_user','waiting_for_support','blocked'))
    else '{"critical":0,"high":0,"open":0}'::jsonb end;
$function$
;

CREATE OR REPLACE FUNCTION public.min_byra_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select bm.byra_bolag_id from public.byra_medlemskap bm
  where bm.anvandare_id = auth.uid() and bm.aktiv
$function$
;

CREATE OR REPLACE FUNCTION public.mina_byraer()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select bm.byra_bolag_id from public.byra_medlemskap bm
  where bm.anvandare_id = auth.uid() and bm.aktiv = true
$function$
;

CREATE OR REPLACE FUNCTION public.mina_klientbolag()
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select bk.klient_bolag_id from public.byra_klient bk
  where bk.status = 'aktiv' and bk.byra_bolag_id in (select public.mina_byraer())
$function$
;

CREATE OR REPLACE FUNCTION public.my_platform_access()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object(
    'isSuperadmin', public.is_superadmin(),
    'roles', (select coalesce(array_agg(distinct role), array[]::text[]) from (
        select role from public.platform_user_roles where lower(email)=lower(auth.jwt() ->> 'email')
        union select 'superadmin' where public.is_superadmin()) x),
    'canViewOperations', public.can_view_operations(),
    'canManageOperations', public.can_manage_operations(),
    'canViewSupport', public.can_view_support(),
    'canManageBilling', public.can_manage_billing())
$function$
;

CREATE OR REPLACE FUNCTION public.my_subscription(p_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_month timestamptz := date_trunc('month', now());
begin
  if v_uid is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=v_uid and uc.company_id=p_company_id) then
    raise exception 'forbidden' using errcode='42501'; end if;
  return jsonb_build_object(
    'subscription', (select jsonb_build_object('status',status,'billing_period',billing_period,
        'current_period_end',current_period_end,'trial_ends_at',trial_ends_at,'cancelled_at',cancelled_at,'suspended_at',suspended_at)
      from company_subscriptions where company_id=p_company_id),
    'plan', (select row_to_json(p) from subscription_plans p where p.id=(select plan_id from company_subscriptions where company_id=p_company_id)),
    'usage', jsonb_build_object(
      'users', (select count(*) from user_companies where company_id=p_company_id),
      'invoices_this_month', (select count(*) from invoices where company_id=p_company_id and created_at >= v_month),
      'documents_this_month', (select count(*) from documents where company_id=p_company_id and created_at >= v_month),
      'storage_mb', (select coalesce(round(sum(file_size)/1048576.0)::int,0) from documents where company_id=p_company_id)
      -- AI-usage: ingen stabil källa -> utelämnas (frontend visar bara limit)
    ),
    'plans', coalesce((select jsonb_agg(row_to_json(p) order by p.sort_order) from subscription_plans p where p.is_active), '[]'::jsonb));
end $function$
;

CREATE OR REPLACE FUNCTION public.next_ver_nr(p_company_id uuid, p_serie text DEFAULT 'A'::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  max_nr integer;
  prefix text;
begin
  prefix := substring(p_serie from 1 for 1);
  select coalesce(max(
    cast(regexp_replace(ver_nr, '[^0-9]', '', 'g') as integer)
  ), 0) into max_nr
  from verifikationer
  where company_id = p_company_id and ver_serie = p_serie;
  return prefix || (max_nr + 1);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.notify_event(p_company_id uuid, p_event_type text, p_payload jsonb DEFAULT '{}'::jsonb, p_object_type text DEFAULT NULL::text, p_object_id uuid DEFAULT NULL::uuid, p_link_url text DEFAULT NULL::text, p_user_ids uuid[] DEFAULT NULL::uuid[], p_actor uuid DEFAULT NULL::uuid, p_priority text DEFAULT 'normal'::text, p_dedupe_key text DEFAULT NULL::text, p_channels text[] DEFAULT NULL::text[])
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_event_id uuid; v_users uuid[]; u uuid; ch text;
  v_subject text; v_body text; v_tsub text; v_tbody text; v_enabled boolean; v_mandatory boolean;
  v_email_default boolean; v_existing uuid;
begin
  if p_dedupe_key is not null then
    select id into v_existing from public.notification_events
      where company_id is not distinct from p_company_id and dedupe_key = p_dedupe_key limit 1;
    if v_existing is not null then return v_existing; end if;
  end if;

  begin
    insert into public.notification_events(company_id, event_type, payload, actor_user_id, object_type, object_id, dedupe_key)
    values (p_company_id, p_event_type, coalesce(p_payload,'{}'::jsonb), p_actor, p_object_type, p_object_id, p_dedupe_key)
    returning id into v_event_id;
  exception when unique_violation then
    select id into v_existing from public.notification_events
      where company_id is not distinct from p_company_id and dedupe_key = p_dedupe_key limit 1;
    return v_existing;
  end;

  if p_user_ids is not null then v_users := p_user_ids;
  else select array_agg(user_id) into v_users from public.user_companies where company_id = p_company_id; end if;

  v_mandatory := p_event_type in ('security_event','permission_changed','system_error','locked_account_blocked','user_invited');
  v_email_default := not (p_event_type = any (array['underlag_received','kvitto_classified','verifikation_created','bookkeeping_suggestion','chart_import_done']));

  foreach u in array coalesce(v_users,'{}'::uuid[]) loop
    foreach ch in array coalesce(p_channels, array['in_app','email','sms','push']) loop
      select enabled into v_enabled from public.notification_preferences
        where user_id=u and company_id=p_company_id and event_type=p_event_type and channel=ch;
      if v_enabled is null then
        v_enabled := case ch when 'in_app' then true when 'email' then v_email_default else false end;
      end if;
      if v_mandatory and ch in ('in_app','email') then v_enabled := true; end if;
      if not v_enabled then continue; end if;

      if ch in ('sms','push') and not exists (
        select 1 from public.notification_subscriptions s where s.user_id=u and s.channel=ch and s.opt_in and s.is_active
      ) then continue; end if;

      select subject, body into v_tsub, v_tbody from public.notification_templates
        where event_type=p_event_type and channel=ch and lang='sv-SE' and is_active limit 1;
      if v_tbody is null then
        select subject, body into v_tsub, v_tbody from public.notification_templates
          where event_type=p_event_type and channel='in_app' and lang='sv-SE' and is_active limit 1;
      end if;
      if v_tbody is null then continue; end if;

      v_subject := public.render_template(v_tsub, coalesce(p_payload,'{}'::jsonb));
      v_body := public.render_template(v_tbody, coalesce(p_payload,'{}'::jsonb));

      insert into public.notification_queue(event_id, company_id, user_id, channel, priority, status,
        subject, body, link_url, object_type, object_id, idempotency_key)
      values (v_event_id, p_company_id, u, ch, p_priority,
        case ch when 'in_app' then 'sent' else 'pending' end,
        v_subject, v_body, p_link_url, p_object_type, p_object_id,
        v_event_id::text || ':' || u::text || ':' || ch)
      on conflict (idempotency_key) do nothing;
    end loop;
  end loop;
  return v_event_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.notify_on_bookkeeping_suggestion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if NEW.tolkad is true and coalesce(OLD.tolkad,false) = false and NEW.tolkning is not null then
    perform public.notify_event(NEW.company_id, 'bookkeeping_suggestion',
      jsonb_build_object('documentType', coalesce(initcap(NEW.kategori),'Underlag'), 'actionUrl','https://app.bokpilot.se/inkorg'),
      'document', NEW.id, '/inkorg', null, null, 'normal',
      'bookkeeping_suggestion:'||NEW.id::text);
  end if;
  return NEW;
end $function$
;

CREATE OR REPLACE FUNCTION public.notify_on_import_failed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if (NEW.status = 'failed' or NEW.error is not null)
     and (TG_OP='INSERT' or coalesce(OLD.status,'') is distinct from coalesce(NEW.status,'')
          or coalesce(OLD.error,'') is distinct from coalesce(NEW.error,'')) then
    perform public.notify_event(NEW.company_id, 'import_failed',
      jsonb_build_object('importType','Kontoplansimport','fileName', coalesce(NEW.filename,''), 'actionUrl','https://app.bokpilot.se/installningar/import-export'),
      'account_import_batch', NEW.id, '/installningar/import-export', null, NEW.imported_by, 'high',
      'import_failed:'||NEW.id::text);
  end if;
  return NEW;
end $function$
;

CREATE OR REPLACE FUNCTION public.notify_on_inbound_document()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare et text; dt text;
begin
  if NEW.source is distinct from 'email' then return NEW; end if;
  dt := case NEW.kategori
    when 'kvitto' then 'Kvitto' when 'leverantorsfaktura' then 'Leverantörsfaktura'
    when 'kundfaktura' then 'Kundfaktura' when 'avtal' then 'Avtal' when 'dokument' then 'Dokument'
    else 'Underlag' end;
  et := case
    when NEW.status = 'needs_review' or NEW.kategori = 'okand' then 'invoice_needs_review'
    when NEW.kategori = 'kvitto' then 'kvitto_classified'
    when NEW.kategori = 'leverantorsfaktura' then 'supplier_invoice_received'
    else 'underlag_received' end;
  perform public.notify_event(
    NEW.company_id, et,
    jsonb_build_object(
      'documentType', dt,
      'confidence', coalesce(round(NEW.confidence * 100)::text, ''),
      'actionUrl', 'https://app.bokpilot.se/inkorg'),
    'document', NEW.id, '/inkorg');
  return NEW;
end $function$
;

CREATE OR REPLACE FUNCTION public.notify_on_verifikation_created()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_users uuid[];
begin
  if NEW.beskrivning ilike 'Momsredovisning%' then return NEW; end if; -- vat_report_ready täcker dessa
  if NEW.created_by is not null then v_users := array[NEW.created_by]; end if;
  perform public.notify_event(NEW.company_id, 'verifikation_created',
    jsonb_build_object('verNr', coalesce(NEW.ver_nr,''), 'actionUrl','https://app.bokpilot.se/bokforing/'||NEW.id::text),
    'verifikation', NEW.id, '/bokforing/'||NEW.id::text, v_users, NEW.created_by, 'normal',
    'verifikation_created:'||NEW.id::text);
  return NEW;
end $function$
;

CREATE OR REPLACE FUNCTION public.notify_subscription_lifecycle()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record; n_trial int := 0; n_exp int := 0;
begin
  for r in select company_id, trial_ends_at from company_subscriptions
           where status='trial' and trial_ends_at is not null and trial_ends_at between now() and now()+interval '3 days' loop
    perform public.notify_event(r.company_id,'subscription_trial_ending',
      jsonb_build_object('trialEnds', to_char(r.trial_ends_at,'YYYY-MM-DD'),'actionUrl','https://app.bokpilot.se/installningar'),
      'subscription', null, '/installningar', null, null, 'normal',
      'subscription_trial_ending:'||r.company_id::text||':'||to_char(r.trial_ends_at,'YYYYMMDD'));
    n_trial := n_trial + 1;
  end loop;
  for r in select company_id, current_period_end from company_subscriptions
           where status='active' and current_period_end is not null and current_period_end between now() and now()+interval '7 days' loop
    perform public.notify_event(r.company_id,'subscription_expiring',
      jsonb_build_object('periodEnds', to_char(r.current_period_end,'YYYY-MM-DD'),'actionUrl','https://app.bokpilot.se/installningar'),
      'subscription', null, '/installningar', null, null, 'normal',
      'subscription_expiring:'||r.company_id::text||':'||to_char(r.current_period_end,'YYYYMMDD'));
    n_exp := n_exp + 1;
  end loop;
  return jsonb_build_object('trial_ending',n_trial,'expiring',n_exp);
end $function$
;

CREATE OR REPLACE FUNCTION public.notify_vat_report_ready(p_company_id uuid, p_verifikation_id uuid, p_period text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not exists (select 1 from public.user_companies uc where uc.user_id=v_uid and uc.company_id=p_company_id) then
    raise exception 'forbidden' using errcode = '42501'; end if;
  return public.notify_event(p_company_id, 'vat_report_ready',
    jsonb_build_object('period', coalesce(p_period,''), 'actionUrl','https://app.bokpilot.se/bokforing/'||coalesce(p_verifikation_id::text,'')),
    'verifikation', p_verifikation_id,
    case when p_verifikation_id is not null then '/bokforing/'||p_verifikation_id::text else '/moms' end,
    null, v_uid, 'normal',
    'vat_report_ready:'||coalesce(p_verifikation_id::text, p_company_id::text||':'||coalesce(p_period,'')));
end $function$
;

CREATE OR REPLACE FUNCTION public.observe_verifikation_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_falt text[] := '{}'::text[]; v_sanktionerad boolean;
begin
  if new.company_id  is distinct from old.company_id  then v_falt := v_falt || 'company_id'::text;  end if;
  if new.ver_nr      is distinct from old.ver_nr      then v_falt := v_falt || 'ver_nr'::text;      end if;
  if new.ver_serie   is distinct from old.ver_serie   then v_falt := v_falt || 'ver_serie'::text;   end if;
  if new.datum       is distinct from old.datum       then v_falt := v_falt || 'datum'::text;       end if;
  if new.beskrivning is distinct from old.beskrivning then v_falt := v_falt || 'beskrivning'::text; end if;
  if new.motpart     is distinct from old.motpart     then v_falt := v_falt || 'motpart'::text;     end if;
  if new.kommentar   is distinct from old.kommentar   then v_falt := v_falt || 'kommentar'::text;   end if;
  if coalesce(new.total_debet,0)  <> coalesce(old.total_debet,0)  then v_falt := v_falt || 'total_debet'::text;  end if;
  if coalesce(new.total_kredit,0) <> coalesce(old.total_kredit,0) then v_falt := v_falt || 'total_kredit'::text; end if;

  if array_length(v_falt, 1) is null then
    return new;   -- endast status-/kopplingsfält: rättelseflödets normala arbete
  end if;

  v_sanktionerad := coalesce(current_setting('app.rattelse_link',   true), '') = 'on'
                 or coalesce(current_setting('app.makulera_insert', true), '') = 'on'
                 or coalesce(current_setting('app.periodlas_bypass',true), '') = 'on';

  perform public.log_accounting_audit(
    'verification_mutation_observed', 'verifikation', new.id::text,
    nullif(current_setting('app.audit_source', true), ''),
    jsonb_build_object('ver_nr', old.ver_nr, 'andrade_falt', v_falt, 'sanktionerad', v_sanktionerad),
    new.company_id,
    jsonb_build_object('ver_nr', old.ver_nr, 'ver_serie', old.ver_serie, 'datum', old.datum,
      'beskrivning', old.beskrivning, 'motpart', old.motpart, 'kommentar', old.kommentar,
      'total_debet', old.total_debet, 'total_kredit', old.total_kredit),
    jsonb_build_object('ver_nr', new.ver_nr, 'ver_serie', new.ver_serie, 'datum', new.datum,
      'beskrivning', new.beskrivning, 'motpart', new.motpart, 'kommentar', new.kommentar,
      'total_debet', new.total_debet, 'total_kredit', new.total_kredit)
  );
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.on_verifikation_delete()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Bokf√∂ringsverifikation borttagen -> faktura l√•ses upp
  update supplier_invoices set bokford = false, verifikation_id = null
    where verifikation_id = old.id;
  -- Betalningsverifikation borttagen -> faktura √•ter obetald
  update supplier_invoices set paid_amount = 0, paid_date = null, status = 'unpaid', betalning_ver_id = null
    where betalning_ver_id = old.id;
  -- Bankh√§ndelse kopplad till verifikationen -> √•ter ej bokf√∂rd
  update bank_transactions set status = 'unmatched', verifikation_id = null
    where verifikation_id = old.id;
  return old;
end $function$
;

CREATE OR REPLACE FUNCTION public.protect_archive_number()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if NEW.archive_number is distinct from OLD.archive_number then
    NEW.archive_number := OLD.archive_number;
  end if;
  return NEW;
end $function$
;

CREATE OR REPLACE FUNCTION public.protect_locked_account()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if current_setting('app.allow_locked_change', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE' then
    if old.is_locked then
      raise exception 'KONTO_LAST_RADERA: Detta konto är låst och kan inte raderas.';
    end if;
    return old;
  else
    if old.is_locked then
      -- Jämför alla fält utom opening_balance och updated_at; ändras något annat → blockera.
      if (to_jsonb(new) - 'opening_balance' - 'updated_at')
           is distinct from (to_jsonb(old) - 'opening_balance' - 'updated_at') then
        raise exception 'KONTO_LAST: Detta konto är låst – endast ingående balans kan ändras.';
      end if;
    end if;
    return new;
  end if;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.protect_makulerad_ver_rows()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_ver uuid; v_status text; v_nr text;
begin
  if current_setting('app.periodlas_bypass', true) = 'on'
     or current_setting('app.makulera_insert', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'UPDATE'
     and new.verifikation_id is not distinct from old.verifikation_id
     and new.account_nr = old.account_nr
     and new.account_name is not distinct from old.account_name
     and coalesce(new.debet, 0) = coalesce(old.debet, 0)
     and coalesce(new.kredit, 0) = coalesce(old.kredit, 0)
     and new.transaction_info is not distinct from old.transaction_info
     and new.sort_order is not distinct from old.sort_order then
    return new;
  end if;
  v_ver := case when tg_op = 'DELETE' then old.verifikation_id else new.verifikation_id end;
  if v_ver is not null then
    select v.status, v.ver_nr into v_status, v_nr from public.verifikationer v where v.id = v_ver;
    if found and v_status in ('makulerad', 'motverifikation', 'rattad', 'rattelse') then
      raise exception 'MAKULERAD: Verifikation % är % – raderna kan inte ändras. Historiken bevaras enligt Bokföringslagen.', v_nr, v_status;
    end if;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $function$
;

CREATE OR REPLACE FUNCTION public.protect_makulerad_verifikation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if current_setting('app.periodlas_bypass', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if old.status in ('makulerad', 'motverifikation', 'rattad', 'rattelse') then
    raise exception 'MAKULERAD: Verifikation % är % och kan inte ändras eller raderas. Historiken bevaras enligt Bokföringslagen.', old.ver_nr, old.status;
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $function$
;

CREATE OR REPLACE FUNCTION public.provision_company_inboxes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if NEW.archive_number is null then return NEW; end if;
  insert into public.inbox_addresses (company_id, inbox_type, email_address)
  values (NEW.id, 'underlag', NEW.archive_number::text || 'underlag@bokpilot.se')
  on conflict (company_id, inbox_type) do nothing;
  return NEW;
end $function$
;

CREATE OR REPLACE FUNCTION public.purge_test_data(p_company uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_email text := auth.jwt() ->> 'email';
  v_uid uuid := auth.uid();
  d jsonb := '{}'::jsonb; n int; v_accounts int;
begin
  if not public.is_platform_admin() then
    raise exception 'ATKOMST_NEKAD: Endast administratörer kan tömma testdata.';
  end if;
  if p_company is null then
    raise exception 'FEL: företag saknas.';
  end if;

  perform set_config('app.periodlas_bypass', 'on', true);

  delete from public.documents          where company_id = p_company; get diagnostics n = row_count; d := d || jsonb_build_object('documents', n);
  delete from public.bank_transactions  where company_id = p_company; get diagnostics n = row_count; d := d || jsonb_build_object('bank_transactions', n);
  delete from public.invoices           where company_id = p_company; get diagnostics n = row_count; d := d || jsonb_build_object('invoices', n);
  delete from public.supplier_invoices  where company_id = p_company; get diagnostics n = row_count; d := d || jsonb_build_object('supplier_invoices', n);
  delete from public.verifikationer     where company_id = p_company; get diagnostics n = row_count; d := d || jsonb_build_object('verifikationer', n);
  delete from public.salaries           where company_id = p_company; get diagnostics n = row_count; d := d || jsonb_build_object('salaries', n);
  delete from public.account_import_batches where company_id = p_company; get diagnostics n = row_count; d := d || jsonb_build_object('import_batches', n);
  delete from public.products           where company_id = p_company; get diagnostics n = row_count; d := d || jsonb_build_object('products', n);
  delete from public.customers          where company_id = p_company; get diagnostics n = row_count; d := d || jsonb_build_object('customers', n);
  delete from public.suppliers          where company_id = p_company; get diagnostics n = row_count; d := d || jsonb_build_object('suppliers', n);

  select count(*) into v_accounts from public.accounts where company_id = p_company;

  insert into public.audit_log(company_id, entity, action, new_data, changed_by, changed_by_email)
  values (p_company, 'company', 'purge_test_data',
          d || jsonb_build_object('chart_of_accounts_preserved', true, 'preserved_accounts', v_accounts),
          v_uid, v_email);

  return jsonb_build_object('ok', true, 'deleted', d,
                            'chart_of_accounts_preserved', true, 'preserved_accounts', v_accounts);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.radera_senaste_verifikation(p_ver_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v public.verifikationer;
  v_max_nr int;
  v_nr int;
begin
  select * into v from public.verifikationer where id = p_ver_id;
  if not found then
    raise exception 'Verifikationen finns inte';
  end if;
  -- Ersätter RLS-filtreringen som gällde när funktionen var SECURITY INVOKER.
  perform public._assert_company_access(v.company_id);

  if coalesce(v.status, 'aktiv') <> 'aktiv' then
    raise exception 'Endast aktiva verifikationer kan tas bort – makulerade/rättade poster bevaras';
  end if;
  select max(nullif(regexp_replace(ver_nr, '\D', '', 'g'), '')::int) into v_max_nr
    from public.verifikationer
   where company_id = v.company_id and ver_serie = v.ver_serie;
  v_nr := nullif(regexp_replace(v.ver_nr, '\D', '', 'g'), '')::int;
  if v_nr is distinct from v_max_nr then
    raise exception 'Endast den senaste verifikationen i serien kan tas bort (nummerserien måste vara obruten) – använd Makulera';
  end if;

  perform set_config('app.radera_senaste', 'on', true);

  update public.supplier_invoices
     set bokford = false, verifikation_id = null
   where company_id = v.company_id and verifikation_id = p_ver_id;

  update public.supplier_invoices
     set status = 'unpaid', paid_date = null, betalning_ver_id = null,
         paid_amount = greatest(0, round(coalesce(paid_amount, 0) - coalesce(v.total_debet, 0), 2))
   where company_id = v.company_id and betalning_ver_id = p_ver_id;

  update public.bank_transactions
     set status = 'unmatched', verifikation_id = null
   where company_id = v.company_id and verifikation_id = p_ver_id;

  delete from public.verifikationer where id = p_ver_id;
  perform set_config('app.radera_senaste', '', true);
  return jsonb_build_object('ok', true, 'ver_nr', v.ver_nr);
end $function$
;

CREATE OR REPLACE FUNCTION public.ratta_verifikation(p_ver_id uuid, p_orsak text, p_datum date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor uuid := auth.uid();
  v_orig public.verifikationer%rowtype;
  v_locked boolean := false;
  v_datum date;
  v_rat_id uuid;
  v_rat_nr text;
begin
  if nullif(trim(p_orsak), '') is null then
    raise exception 'FEL: Ange en orsak till rättelsen.';
  end if;
  select * into v_orig from public.verifikationer where id = p_ver_id;
  if not found then
    raise exception 'FEL: Verifikationen finns inte.';
  end if;
  if not public._ar_betrodd_backend() and not exists (
    select 1 from public.user_companies uc where uc.user_id = v_actor and uc.company_id = v_orig.company_id
  ) then
    raise exception 'ATKOMST_NEKAD: Du har inte åtkomst till detta företag.';
  end if;
  if v_orig.status = 'makulerad' then
    raise exception 'MAKULERAD: Verifikation % är makulerad och kan inte rättas.', v_orig.ver_nr;
  end if;
  if v_orig.status = 'motverifikation' then
    raise exception 'FEL: En motverifikation kan inte rättas.';
  end if;
  if v_orig.status = 'rattad' then
    raise exception 'RÄTTAD: Verifikation % är redan rättad.', v_orig.ver_nr;
  end if;
  if v_orig.status = 'rattelse' then
    raise exception 'FEL: En rättelseverifikation kan inte rättas. Bokför en ny verifikation i stället.';
  end if;

  begin
    perform public.assert_period_open(v_orig.company_id, v_orig.datum);
  exception when others then
    v_locked := true;
  end;
  v_datum := coalesce(p_datum,
                      case when v_locked then public.first_open_booking_date(v_orig.company_id) else v_orig.datum end);

  perform public.log_accounting_audit(
    'verification_correction_started', 'verifikation', v_orig.id::text, null,
    jsonb_build_object('original_verification_id', v_orig.id, 'original_ver_nr', v_orig.ver_nr,
                       'reason', left(trim(p_orsak), 200), 'correction_date', v_datum,
                       'period_locked_original', v_locked),
    v_orig.company_id, null, null);

  v_rat_nr := public.next_ver_nr(v_orig.company_id, 'R - Rättelser');
  perform set_config('app.makulera_insert', 'on', true);
  insert into public.verifikationer(company_id, ver_nr, ver_serie, datum, beskrivning,
                                    total_debet, total_kredit, created_by, status, rattar)
  values (v_orig.company_id, v_rat_nr, 'R - Rättelser', v_datum,
          left('Rättelse av verifikation ' || v_orig.ver_nr || ': ' || trim(p_orsak), 200),
          v_orig.total_kredit, v_orig.total_debet, v_actor, 'rattelse', v_orig.id)
  returning id into v_rat_id;
  insert into public.verifikation_rows(verifikation_id, account_nr, account_name, debet, kredit, transaction_info, sort_order)
  select v_rat_id, r.account_nr, r.account_name, coalesce(r.kredit, 0), coalesce(r.debet, 0), r.transaction_info, r.sort_order
  from public.verifikation_rows r where r.verifikation_id = v_orig.id;
  perform set_config('app.makulera_insert', 'off', true);

  perform set_config('app.rattelse_link', 'on', true);
  update public.verifikationer set status = 'rattad', rattad_av = v_rat_id where id = v_orig.id;
  perform set_config('app.rattelse_link', 'off', true);

  perform public.log_accounting_audit(
    'verification_reversal_created', 'verifikation', v_rat_id::text, null,
    jsonb_build_object('original_verification_id', v_orig.id, 'original_ver_nr', v_orig.ver_nr,
                       'reversal_verification_id', v_rat_id, 'reversal_ver_nr', v_rat_nr,
                       'reason', left(trim(p_orsak), 200), 'correction_date', v_datum,
                       'period_locked_original', v_locked),
    v_orig.company_id,
    jsonb_build_object('status', 'aktiv'),
    jsonb_build_object('status', 'rattad', 'rattad_av', v_rat_id));

  return jsonb_build_object('ok', true, 'rattelse_id', v_rat_id, 'rattelse_nr', v_rat_nr,
                            'datum', v_datum, 'period_locked_original', v_locked);
end $function$
;

CREATE OR REPLACE FUNCTION public.record_ai_usage(p_company_id uuid, p_kind text DEFAULT 'ocr'::text)
 RETURNS void
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  insert into public.ai_usage_log(company_id, kind) values (p_company_id, p_kind);
$function$
;

CREATE OR REPLACE FUNCTION public.record_worker_health(p_component text, p_ok boolean, p_error text DEFAULT NULL::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_consec int;
begin
  insert into public.worker_health(component, last_success_at, last_failure_at, consecutive_failures, last_error, updated_at)
  values (p_component,
    case when p_ok then now() else null end,
    case when p_ok then null else now() end,
    case when p_ok then 0 else 1 end,
    case when p_ok then null else left(p_error,300) end, now())
  on conflict (component) do update set
    last_success_at = case when p_ok then now() else worker_health.last_success_at end,
    last_failure_at = case when p_ok then worker_health.last_failure_at else now() end,
    consecutive_failures = case when p_ok then 0 else worker_health.consecutive_failures + 1 end,
    last_error = case when p_ok then null else left(p_error,300) end,  -- rensa fel vid lyckad körning
    updated_at = now()
  returning consecutive_failures into v_consec;
  return v_consec;
end $function$
;

CREATE OR REPLACE FUNCTION public.render_template(p_tmpl text, p_vars jsonb)
 RETURNS text
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
declare result text; k text; v text;
begin
  if p_tmpl is null then return null; end if;
  result := p_tmpl;
  for k, v in select key, value from jsonb_each_text(coalesce(p_vars, '{}'::jsonb)) loop
    result := replace(result, '{{' || k || '}}', coalesce(v, ''));
  end loop;
  result := regexp_replace(result, '\{\{[a-zA-Z0-9_]+\}\}', '', 'g');
  return result;
end $function$
;

CREATE OR REPLACE FUNCTION public.reopen_mc_item(p_item uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record;
begin
  g := public._mc_item_guard(p_item);
  update monthly_control_items set status='open', resolved_by=null, resolved_at=null, ignored_reason=null, updated_at=now() where id=p_item;
  insert into monthly_control_events(monthly_control_id, item_id, company_id, user_id, event_type)
  values (g.monthly_control_id, p_item, g.company_id, auth.uid(), 'reopened');
  perform public._mc_recount(g.monthly_control_id);
end $function$
;

CREATE OR REPLACE FUNCTION public.reply_support_ticket(p_ticket_id uuid, p_body text, p_attachment_count integer DEFAULT 0)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); t record; v_msg uuid; v_url text; v_attnote text;
begin
  if not public.can_view_support() then raise exception 'forbidden' using errcode='42501'; end if;
  select * into t from support_tickets where id=p_ticket_id;
  if t is null then raise exception 'not found' using errcode='P0002'; end if;
  insert into support_messages(ticket_id, sender_user_id, is_admin, body) values (p_ticket_id, v_uid, true, p_body) returning id into v_msg;
  update support_tickets set status=case when status in ('closed','resolved') then status else 'waiting_for_customer' end,
    last_message_at=now(), updated_at=now() where id=p_ticket_id;
  if t.created_by_user_id is not null then
    v_url := 'https://app.bokpilot.se/support/'||p_ticket_id::text;
    v_attnote := case when coalesce(p_attachment_count,0) > 0
      then 'Svaret innehåller '||p_attachment_count||' '||case when p_attachment_count = 1 then 'bilaga' else 'bilagor' end||'.'
      else '' end;
    perform public.notify_event(t.company_id, 'support_ticket_admin_reply',
      jsonb_build_object('subject', t.subject, 'excerpt', left(coalesce(p_body,''),300),
        'attachmentNote', v_attnote, 'actionUrl', v_url),
      'support_ticket', p_ticket_id, '/support/'||p_ticket_id::text, array[t.created_by_user_id], v_uid, 'normal');
  end if;
  perform public.log_platform_audit('support_admin_reply', p_ticket_id::text, '{}'::jsonb);
  return v_msg;
end $function$
;

CREATE OR REPLACE FUNCTION public.report_system_error(p_component text, p_message text, p_company_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_admins uuid[]; v_key text;
begin
  v_key := 'system_error:'||coalesce(p_component,'okänd')||':'||md5(coalesce(p_message,''))||':'||to_char(now(),'YYYYMMDDHH24');
  select array_agg(u.id) into v_admins from auth.users u where u.email in (select email from public.platform_admins);
  if v_admins is null or array_length(v_admins,1) is null then return null; end if;
  return public.notify_event(p_company_id, 'system_error',
    jsonb_build_object('component', coalesce(p_component,'okänd'), 'message', left(coalesce(p_message,''),300), 'actionUrl','https://app.bokpilot.se/'),
    'system', null, '/', v_admins, null, 'urgent', v_key);
end $function$
;

CREATE OR REPLACE FUNCTION public.report_system_error(p_component text, p_message text, p_company_id uuid DEFAULT NULL::uuid, p_severity text DEFAULT 'error'::text, p_error_code text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb, p_occurred_at timestamp with time zone DEFAULT now())
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  insert into public.system_error_log(component, message, severity, error_code, metadata, company_id, occurred_at)
  values (p_component, left(coalesce(p_message, ''), 4000), p_severity, p_error_code, p_metadata, p_company_id, coalesce(p_occurred_at, now()))
  returning id into v_id;
  begin perform public.report_system_error(p_component, p_message, p_company_id); exception when others then null; end;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.request_subscription_change(p_company_id uuid, p_desired_plan_id uuid, p_message text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_ticket uuid; v_company text; v_plan text; v_body text;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=v_uid and uc.company_id=p_company_id) then
    raise exception 'forbidden' using errcode='42501'; end if;
  select name into v_company from companies where id=p_company_id;
  select name into v_plan from subscription_plans where id=p_desired_plan_id;
  v_body := 'Önskad plan: '||coalesce(v_plan,'(ej angiven)')||E'\n\n'||coalesce(p_message,'');
  insert into support_tickets(company_id, created_by_user_id, subject, category, priority, status, last_message_at)
  values (p_company_id, v_uid, 'Begäran om abonnemangsändring', 'billing', 'normal', 'new', now()) returning id into v_ticket;
  insert into support_messages(ticket_id, sender_user_id, is_admin, body) values (v_ticket, v_uid, false, v_body);
  -- Notis till billing-admins (superadmin + billing_admin)
  perform public.notify_event(p_company_id, 'subscription_change_requested',
    jsonb_build_object('company',coalesce(v_company,''),'desiredPlan',coalesce(v_plan,'(ej angiven)'),
      'actionUrl','https://app.bokpilot.se/admin/billing'),
    'support_ticket', v_ticket, '/admin/billing', public.billing_admin_ids(), v_uid, 'normal');
  perform public.log_platform_audit('subscription_upgrade_requested', p_company_id::text, jsonb_build_object('desired_plan_id',p_desired_plan_id,'ticket_id',v_ticket));
  return v_ticket;
end $function$
;

CREATE OR REPLACE FUNCTION public.reset_company(p_company uuid, p_opts jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_email text := auth.jwt() ->> 'email';
  v_uid uuid := auth.uid();
  v jsonb := '{}'::jsonb; n int;
  v_har_bokforing boolean;
  v_skyddade text[] := array[
    'bookkeeping','customer_invoices','supplier_invoices',
    'bank_transactions','documents','salaries','chart_of_accounts',
    'customers','suppliers'
  ];
  v_begard text[];
begin
  perform public._assert_company_access(p_company);

  if not (public.ar_bolagsadmin(p_company) or public.is_platform_admin()) then
    raise exception 'ATKOMST_NEKAD: Endast bolagets administratör kan återställa företaget.';
  end if;

  select coalesce(array_agg(k), '{}')
    into v_begard
  from jsonb_each(p_opts) as e(k, val)
  where k = any(v_skyddade)
    and coalesce((val #>> '{}')::boolean, false);

  if array_length(v_begard, 1) > 0 then
    select exists(select 1 from public.verifikationer where company_id = p_company)
      into v_har_bokforing;

    if v_har_bokforing then
      raise exception 'BFL_SKYDD: Bolaget har bokföring och kan inte återställas. Räkenskapsinformation måste bevaras i sju år (BFL 7 kap. 2 §). Rätta i stället med makulering/omvänd verifikation, eller avsluta bolaget med arkivexport.';
    end if;

    perform set_config('app.periodlas_bypass', 'on', true);
  end if;

  if coalesce((p_opts->>'bookkeeping')::boolean, false) then
    delete from public.verifikationer where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('verifikationer', n);
  end if;
  if coalesce((p_opts->>'customer_invoices')::boolean, false) then
    delete from public.invoices where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('invoices', n);
  end if;
  if coalesce((p_opts->>'supplier_invoices')::boolean, false) then
    delete from public.supplier_invoices where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('supplier_invoices', n);
  end if;
  if coalesce((p_opts->>'bank_transactions')::boolean, false) then
    delete from public.bank_transactions where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('bank_transactions', n);
  end if;
  if coalesce((p_opts->>'documents')::boolean, false) then
    delete from public.documents where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('documents', n);
  end if;
  if coalesce((p_opts->>'salaries')::boolean, false) then
    delete from public.salaries where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('salaries', n);
  end if;
  if coalesce((p_opts->>'products')::boolean, false) then
    delete from public.products where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('products', n);
  end if;
  if coalesce((p_opts->>'customers')::boolean, false) then
    update public.invoices set customer_id = null where company_id = p_company and customer_id is not null;
    delete from public.customers where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('customers', n);
  end if;
  if coalesce((p_opts->>'suppliers')::boolean, false) then
    update public.supplier_invoices set supplier_id = null where company_id = p_company and supplier_id is not null;
    delete from public.suppliers where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('suppliers', n);
  end if;
  if coalesce((p_opts->>'chart_of_accounts')::boolean, false) then
    perform set_config('app.bulk_import', 'on', true);
    perform set_config('app.allow_locked_change', 'on', true);
    delete from public.accounts where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('accounts', n);
  end if;
  if coalesce((p_opts->>'settings')::boolean, false) then
    begin
      update public.companies set onboarded = false where id = p_company;
      v := v || jsonb_build_object('settings_reset', true);
    exception when undefined_column then
      v := v || jsonb_build_object('settings_reset', false);
    end;
  end if;

  insert into public.audit_log(company_id, entity, action, new_data, changed_by, changed_by_email)
  values (p_company, 'company', 'reset', p_opts || jsonb_build_object('result', v), v_uid, v_email);
  return jsonb_build_object('ok', true, 'deleted', v);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.reset_lonekorning_on_makulering()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update public.lonekorningar
     set bokford = false, verifikation_id = null, status = 'utkast'
   where verifikation_id = new.id;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.resolve_mc_item(p_item uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record;
begin
  g := public._mc_item_guard(p_item);
  update monthly_control_items set status='resolved', resolved_by=auth.uid(), resolved_at=now(), updated_at=now() where id=p_item;
  insert into monthly_control_events(monthly_control_id, item_id, company_id, user_id, event_type)
  values (g.monthly_control_id, p_item, g.company_id, auth.uid(), 'resolved');
  perform public._mc_recount(g.monthly_control_id);
end $function$
;

CREATE OR REPLACE FUNCTION public.robo_bp_context(p_company uuid, p_fiscal_year_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_start date; v_end date;
  v_accounts jsonb; v_balances jsonb; v_vers jsonb; v_sup jsonb; v_cust jsonb;
begin
  if p_company is null or p_company not in (select user_company_ids()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_fiscal_year_id is not null then
    select start_date, end_date into v_start, v_end from public.fiscal_years where id = p_fiscal_year_id and company_id = p_company;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object('nr', account_nr, 'name', name, 'class', substr(account_nr, 1, 1), 'active', is_active) order by account_nr), '[]'::jsonb)
    into v_accounts
  from (select account_nr, name, is_active from public.accounts where company_id = p_company order by account_nr limit 200) a;

  select coalesce(jsonb_agg(jsonb_build_object('class', klass, 'debet', round(d, 2), 'kredit', round(k, 2), 'saldo', round(d - k, 2)) order by klass), '[]'::jsonb)
    into v_balances
  from (
    select substr(vr.account_nr, 1, 1) as klass, sum(coalesce(vr.debet, 0)) d, sum(coalesce(vr.kredit, 0)) k
    from public.verifikation_rows vr join public.verifikationer v on v.id = vr.verifikation_id
    where v.company_id = p_company and v.makulerad_av is null
      and (v_start is null or v.datum between v_start and v_end)
    group by 1
  ) b;

  select coalesce(jsonb_agg(jsonb_build_object('id', id::text, 'verNr', ver_nr, 'datum', datum, 'beskrivning', left(coalesce(beskrivning, ''), 120), 'total', round(coalesce(total_debet, 0), 2), 'status', status) order by datum desc, ver_nr desc), '[]'::jsonb)
    into v_vers
  from (select id, ver_nr, datum, beskrivning, total_debet, status from public.verifikationer where company_id = p_company and makulerad_av is null order by datum desc, ver_nr desc nulls last limit 10) t;

  select coalesce(jsonb_agg(jsonb_build_object('id', si.id::text, 'supplierId', si.supplier_id::text, 'supplier', left(coalesce(s.name, ''), 80), 'invoiceDate', si.invoice_date, 'dueDate', si.due_date, 'total', round(coalesce(si.total_amount, 0), 2), 'vat', round(coalesce(si.vat_amount, 0), 2), 'status', si.status, 'kredit', coalesce(si.kreditfaktura, false)) order by si.invoice_date desc), '[]'::jsonb)
    into v_sup
  from (select id, supplier_id, invoice_date, due_date, total_amount, vat_amount, status, kreditfaktura from public.supplier_invoices where company_id = p_company and coalesce(makulerad, false) = false order by invoice_date desc nulls last limit 10) si
  left join public.suppliers s on s.id = si.supplier_id;

  select coalesce(jsonb_agg(jsonb_build_object('id', i.id::text, 'customerId', i.customer_id::text, 'customer', left(coalesce(c.name, ''), 80), 'invoiceDate', i.invoice_date, 'total', round(coalesce(i.total_amount, 0), 2), 'status', i.status) order by i.invoice_date desc), '[]'::jsonb)
    into v_cust
  from (select id, customer_id, invoice_date, total_amount, status from public.invoices where company_id = p_company order by invoice_date desc nulls last limit 10) i
  left join public.customers c on c.id = i.customer_id;

  return jsonb_build_object(
    'accounts', v_accounts, 'balances', v_balances, 'verifications', v_vers,
    'supplierInvoices', v_sup, 'customerInvoices', v_cust,
    'counts', jsonb_build_object('accounts', jsonb_array_length(v_accounts), 'verifications', jsonb_array_length(v_vers), 'supplierInvoices', jsonb_array_length(v_sup), 'customerInvoices', jsonb_array_length(v_cust))
  );
end $function$
;

CREATE OR REPLACE FUNCTION public.robo_bp_context(p_company uuid, p_fiscal_year_id uuid DEFAULT NULL::uuid, p_view text DEFAULT NULL::text, p_question text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_start date; v_end date;
  v_classes text[] := '{}';
  v_accounts jsonb; v_balances jsonb; v_vers jsonb; v_sup jsonb; v_cust jsonb; v_summary jsonb;
begin
  if p_company is null or p_company not in (select user_company_ids()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if p_fiscal_year_id is not null then
    select start_date, end_date into v_start, v_end from public.fiscal_years where id = p_fiscal_year_id and company_id = p_company;
  end if;
  v_classes := case lower(coalesce(p_view, ''))
    when 'leverantorsfakturor' then array['2', '4', '5', '6', '7']
    when 'kundfakturor' then array['1', '2', '3']
    when 'kassa_bank' then array['1', '2']
    when 'moms' then array['2']
    else array[]::text[] end;

  with used as (
    select distinct vr.account_nr from public.verifikation_rows vr join public.verifikationer v on v.id = vr.verifikation_id
    where v.company_id = p_company and v.makulerad_av is null and (v_start is null or v.datum between v_start and v_end)
  ),
  qwords as (select unnest(regexp_split_to_array(lower(coalesce(p_question, '')), '\s+')) as w),
  ranked as (
    select a.account_nr, a.name, a.is_active,
      (case when a.is_active then 1 else 0 end)
      + (case when a.account_nr in (select account_nr from used) then 5 else 0 end)
      + (case when coalesce(a.opening_balance, 0) <> 0 then 1 else 0 end)
      + (case when substr(a.account_nr, 1, 1) = any (v_classes) then 2 else 0 end)
      + (case when exists (select 1 from qwords q where char_length(q.w) >= 3 and lower(a.name) like '%' || q.w || '%') then 3 else 0 end)
      + (case when a.account_nr in (select w from qwords where w ~ '^[0-9]{3,4}$') then 6 else 0 end) as score
    from public.accounts a where a.company_id = p_company
  )
  select coalesce(jsonb_agg(jsonb_build_object('nr', account_nr, 'name', name, 'class', substr(account_nr, 1, 1), 'active', is_active)), '[]'::jsonb)
    into v_accounts
  from (select account_nr, name, is_active from ranked order by score desc, account_nr limit 300) r;

  select coalesce(jsonb_agg(jsonb_build_object('class', klass, 'saldo', round(d - k, 2)) order by klass), '[]'::jsonb) into v_balances
  from (select substr(vr.account_nr, 1, 1) klass, sum(coalesce(vr.debet, 0)) d, sum(coalesce(vr.kredit, 0)) k
        from public.verifikation_rows vr join public.verifikationer v on v.id = vr.verifikation_id
        where v.company_id = p_company and v.makulerad_av is null and (v_start is null or v.datum between v_start and v_end)
        group by 1) b;

  select coalesce(jsonb_agg(jsonb_build_object('id', id::text, 'verNr', ver_nr, 'datum', datum, 'beskrivning', left(coalesce(beskrivning, ''), 120), 'total', round(coalesce(total_debet, 0), 2), 'status', status) order by datum desc, ver_nr desc), '[]'::jsonb) into v_vers
  from (select id, ver_nr, datum, beskrivning, total_debet, status from public.verifikationer where company_id = p_company and makulerad_av is null order by datum desc, ver_nr desc nulls last limit 10) t;

  select coalesce(jsonb_agg(jsonb_build_object('id', si.id::text, 'supplierId', si.supplier_id::text, 'supplier', left(coalesce(s.name, ''), 80), 'invoiceDate', si.invoice_date, 'dueDate', si.due_date, 'total', round(coalesce(si.total_amount, 0), 2), 'vat', round(coalesce(si.vat_amount, 0), 2), 'status', si.status, 'kredit', coalesce(si.kreditfaktura, false)) order by si.invoice_date desc), '[]'::jsonb) into v_sup
  from (select id, supplier_id, invoice_date, due_date, total_amount, vat_amount, status, kreditfaktura from public.supplier_invoices where company_id = p_company and coalesce(makulerad, false) = false order by invoice_date desc nulls last limit 10) si
  left join public.suppliers s on s.id = si.supplier_id;

  select coalesce(jsonb_agg(jsonb_build_object('id', i.id::text, 'customerId', i.customer_id::text, 'customer', left(coalesce(c.name, ''), 80), 'invoiceDate', i.invoice_date, 'dueDate', i.due_date, 'total', round(coalesce(i.total_amount, 0), 2), 'status', i.status) order by i.invoice_date desc), '[]'::jsonb) into v_cust
  from (select id, customer_id, invoice_date, due_date, total_amount, status from public.invoices where company_id = p_company order by invoice_date desc nulls last limit 10) i
  left join public.customers c on c.id = i.customer_id;

  select jsonb_build_object(
    'hasFiscalYear', (p_fiscal_year_id is not null),
    'verCount', (select count(*) from public.verifikationer v where v.company_id = p_company and v.makulerad_av is null and (v_start is null or v.datum between v_start and v_end)),
    'supCount', (select count(*) from public.supplier_invoices si where si.company_id = p_company and coalesce(si.makulerad, false) = false),
    'custCount', (select count(*) from public.invoices i where i.company_id = p_company),
    'supOpen', (select count(*) from public.supplier_invoices si where si.company_id = p_company and coalesce(si.makulerad, false) = false and coalesce(si.paid_amount, 0) < coalesce(si.total_amount, 0)),
    'supOverdue', (select count(*) from public.supplier_invoices si where si.company_id = p_company and coalesce(si.makulerad, false) = false and coalesce(si.paid_amount, 0) < coalesce(si.total_amount, 0) and si.due_date < current_date),
    'custOpen', (select count(*) from public.invoices i where i.company_id = p_company and lower(coalesce(i.status, '')) not in ('betald', 'paid', 'krediterad', 'makulerad')),
    'custOverdue', (select count(*) from public.invoices i where i.company_id = p_company and lower(coalesce(i.status, '')) not in ('betald', 'paid', 'krediterad', 'makulerad') and i.due_date < current_date),
    'incomeTotal', (select round(coalesce(sum(vr.kredit - vr.debet), 0), 2) from public.verifikation_rows vr join public.verifikationer v on v.id = vr.verifikation_id where v.company_id = p_company and v.makulerad_av is null and substr(vr.account_nr, 1, 1) = '3' and (v_start is null or v.datum between v_start and v_end)),
    'costTotal', (select round(coalesce(sum(vr.debet - vr.kredit), 0), 2) from public.verifikation_rows vr join public.verifikationer v on v.id = vr.verifikation_id where v.company_id = p_company and v.makulerad_av is null and substr(vr.account_nr, 1, 1) in ('4', '5', '6', '7') and (v_start is null or v.datum between v_start and v_end)),
    'momsBalance', (select round(coalesce(sum(vr.debet - vr.kredit), 0), 2) from public.verifikation_rows vr join public.verifikationer v on v.id = vr.verifikation_id where v.company_id = p_company and v.makulerad_av is null and substr(vr.account_nr, 1, 2) = '26' and (v_start is null or v.datum between v_start and v_end)),
    'missingVerDesc', (select count(*) from public.verifikationer v where v.company_id = p_company and v.makulerad_av is null and (v_start is null or v.datum between v_start and v_end) and coalesce(btrim(v.beskrivning), '') = ''),
    'unbalancedVer', (select count(*) from public.verifikationer v where v.company_id = p_company and v.makulerad_av is null and (v_start is null or v.datum between v_start and v_end) and abs(coalesce(v.total_debet, 0) - coalesce(v.total_kredit, 0)) > 0.01),
    'supplierNoName', (select count(*) from public.supplier_invoices si left join public.suppliers s on s.id = si.supplier_id where si.company_id = p_company and coalesce(si.makulerad, false) = false and coalesce(btrim(s.name), '') = ''),
    'itemsWithoutStatus', (select count(*) from public.verifikationer v where v.company_id = p_company and v.makulerad_av is null and coalesce(btrim(v.status), '') = '')
  ) into v_summary;

  return jsonb_build_object(
    'accounts', v_accounts, 'balances', v_balances, 'verifications', v_vers,
    'supplierInvoices', v_sup, 'customerInvoices', v_cust, 'summary', v_summary,
    'counts', jsonb_build_object('accounts', jsonb_array_length(v_accounts), 'verifications', jsonb_array_length(v_vers), 'supplierInvoices', jsonb_array_length(v_sup), 'customerInvoices', jsonb_array_length(v_cust))
  );
end $function$
;

CREATE OR REPLACE FUNCTION public.robo_bp_create_check(p_company uuid, p_view text, p_fiscal_year_id uuid, p_title text, p_description text, p_risk_level text, p_affected_objects jsonb DEFAULT '[]'::jsonb, p_conversation_id uuid DEFAULT NULL::uuid, p_decision_basis text DEFAULT NULL::text, p_confidence_label text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_role text; v_id uuid; v_risk text; v_aff jsonb; v_basis text; v_conf text;
begin
  if p_company is null or p_company not in (select user_company_ids()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not public.has_ai_feature(p_company, 'robo_bp') then
    insert into public.robo_bp_audit_log(company_id, user_id, action, detail) values (p_company, auth.uid(), 'denied', jsonb_build_object('reason', 'no_license', 'op', 'create_check'));
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select role into v_role from public.user_companies where user_id = auth.uid() and company_id = p_company limit 1;
  if v_role is null or lower(v_role) in ('viewer', 'read_only', 'readonly', 'lasare', 'guest', 'gast') then
    insert into public.robo_bp_audit_log(company_id, user_id, action, detail) values (p_company, auth.uid(), 'denied', jsonb_build_object('reason', 'role', 'op', 'create_check'));
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if coalesce(btrim(p_title), '') = '' then raise exception 'title_required' using errcode = '22023'; end if;
  v_risk := case when p_risk_level in ('low', 'medium', 'high', 'critical') then p_risk_level else 'medium' end;
  v_aff := case when jsonb_typeof(p_affected_objects) = 'array' then p_affected_objects else '[]'::jsonb end;
  v_basis := case when p_decision_basis in ('system_observation', 'ai_finding') then p_decision_basis else null end;
  v_conf := nullif(left(coalesce(p_confidence_label, ''), 40), '');

  select id into v_id from public.robo_bp_checks
    where company_id = p_company and status = 'open' and title = left(p_title, 200)
      and coalesce(conversation_id::text, '') = coalesce(p_conversation_id::text, '')
    order by created_at desc limit 1;
  if v_id is not null then return v_id; end if;

  insert into public.robo_bp_checks(company_id, source, view, fiscal_year_id, title, description, risk_level, affected_objects, status, conversation_id, created_by, decision_basis, confidence_label)
    values (p_company, 'robo_bp', p_view, p_fiscal_year_id, left(p_title, 200), left(coalesce(p_description, ''), 2000), v_risk, v_aff, 'open', p_conversation_id, auth.uid(), v_basis, v_conf)
    returning id into v_id;

  insert into public.robo_bp_audit_log(company_id, user_id, action, detail)
    values (p_company, auth.uid(), 'check_created', jsonb_build_object(
      'source', 'robo_bp', 'view', p_view, 'risk_level', v_risk, 'checkId', v_id,
      'affectedIds', (select coalesce(jsonb_agg(o->>'id'), '[]'::jsonb) from jsonb_array_elements(v_aff) o),
      'decisionBasis', v_basis, 'confidenceLabel', v_conf));
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.robo_bp_get_settings(p_company uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;
begin
  if p_company is null or p_company not in (select user_company_ids()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not public.has_ai_feature(p_company, 'robo_bp') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select * into r from public.robo_bp_settings where company_id = p_company;
  if not found then
    return jsonb_build_object('sensitivity', 'standard',
      'categories', '["saknade_underlag","balansrakning","skulder","fordringar"]'::jsonb,
      'moms_period', null, 'isDefault', true);
  end if;
  return jsonb_build_object('sensitivity', r.sensitivity, 'categories', r.categories,
    'moms_period', r.moms_period, 'isDefault', false);
end $function$
;

CREATE OR REPLACE FUNCTION public.robo_bp_run_control(p_company uuid, p_fiscal_year_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_sum jsonb; v_obs jsonb := '[]'::jsonb; v_id uuid; n numeric;
  v_set jsonb; v_cats jsonb; v_sens text; v_excluded jsonb := '[]'::jsonb;
  inc_saknade boolean; inc_skulder boolean; inc_fordringar boolean; inc_balans boolean;
begin
  if p_company is null or p_company not in (select user_company_ids()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not public.has_ai_feature(p_company, 'robo_bp') then
    insert into public.robo_bp_audit_log(company_id, user_id, action, detail)
      values (p_company, auth.uid(), 'denied', jsonb_build_object('reason', 'no_license', 'op', 'run_control'));
    raise exception 'forbidden' using errcode = '42501';
  end if;

  select jsonb_build_object('sensitivity', sensitivity, 'categories', categories, 'moms_period', moms_period)
    into v_set from public.robo_bp_settings where company_id = p_company;
  if v_set is null then
    v_set := jsonb_build_object('sensitivity', 'standard',
      'categories', '["saknade_underlag","balansrakning","skulder","fordringar"]'::jsonb, 'moms_period', null);
  end if;
  v_sens := v_set ->> 'sensitivity';
  v_cats := coalesce(v_set -> 'categories', '[]'::jsonb);
  inc_saknade    := (v_sens <> 'anpassad') or (v_cats ? 'saknade_underlag');
  inc_skulder    := (v_sens <> 'anpassad') or (v_cats ? 'skulder');
  inc_fordringar := (v_sens <> 'anpassad') or (v_cats ? 'fordringar');
  inc_balans     := true;
  if not inc_saknade then v_excluded := v_excluded || to_jsonb('saknade_underlag'::text); end if;
  if not inc_skulder then v_excluded := v_excluded || to_jsonb('skulder'::text); end if;
  if not inc_fordringar then v_excluded := v_excluded || to_jsonb('fordringar'::text); end if;
  if v_sens = 'anpassad' and not (v_cats ? 'balansrakning') then v_excluded := v_excluded || to_jsonb('balansrakning_kritisk_kors_anda'::text); end if;

  v_sum := coalesce(public.robo_bp_context(p_company, p_fiscal_year_id, 'oversikt', 'kontrollkorning') -> 'summary', '{}'::jsonb);

  if coalesce((v_sum ->> 'hasFiscalYear')::boolean, false) = false then
    v_obs := v_obs || jsonb_build_object('code', 'no_fiscal_year', 'severity', 'medium', 'text', 'Inget räkenskapsår valt – siffrorna kan avse all historik.', 'count', 0, 'status', 'open');
  end if;
  if inc_saknade then
    n := coalesce((v_sum ->> 'missingVerDesc')::numeric, 0);
    if n > 0 then v_obs := v_obs || jsonb_build_object('code', 'missing_ver_desc', 'severity', 'low', 'text', n || ' verifikation(er) saknar beskrivning.', 'count', n, 'status', 'open'); end if;
  end if;
  if inc_balans then
    n := coalesce((v_sum ->> 'unbalancedVer')::numeric, 0);
    if n > 0 then v_obs := v_obs || jsonb_build_object('code', 'unbalanced_ver', 'severity', 'high', 'text', n || ' verifikation(er) verkar obalanserade (debet ≠ kredit).', 'count', n, 'status', 'open'); end if;
  end if;
  if inc_skulder then
    n := coalesce((v_sum ->> 'supplierNoName')::numeric, 0);
    if n > 0 then v_obs := v_obs || jsonb_build_object('code', 'supplier_no_name', 'severity', 'low', 'text', n || ' leverantörsfaktura(or) saknar leverantörsnamn.', 'count', n, 'status', 'open'); end if;
    n := coalesce((v_sum ->> 'supOverdue')::numeric, 0);
    if n > 0 then v_obs := v_obs || jsonb_build_object('code', 'supplier_overdue', 'severity', 'medium', 'text', n || ' förfallen(na) leverantörsfaktura(or).', 'count', n, 'status', 'open'); end if;
  end if;
  if inc_fordringar then
    n := coalesce((v_sum ->> 'custOverdue')::numeric, 0);
    if n > 0 then v_obs := v_obs || jsonb_build_object('code', 'customer_overdue', 'severity', 'medium', 'text', n || ' förfallen(na) kundfaktura(or).', 'count', n, 'status', 'open'); end if;
  end if;

  insert into public.robo_bp_control_runs(company_id, fiscal_year_id, started_by, status, summary)
    values (p_company, p_fiscal_year_id, auth.uid(), 'done',
      jsonb_build_object('deviationCount', jsonb_array_length(v_obs), 'observations', v_obs,
        'settingsSnapshot', v_set || jsonb_build_object('excludedCategories', v_excluded)))
    returning id into v_id;

  insert into public.robo_bp_audit_log(company_id, user_id, action, detail)
    values (p_company, auth.uid(), 'control_run_created', jsonb_build_object(
      'runId', v_id, 'fiscalYearId', p_fiscal_year_id, 'deviationCount', jsonb_array_length(v_obs),
      'codes', (select coalesce(jsonb_agg(o ->> 'code'), '[]'::jsonb) from jsonb_array_elements(v_obs) o),
      'sensitivity', v_sens, 'excludedCategories', v_excluded));

  return jsonb_build_object('id', v_id, 'deviationCount', jsonb_array_length(v_obs), 'observations', v_obs, 'startedAt', now());
end $function$
;

CREATE OR REPLACE FUNCTION public.robo_bp_save_settings(p_company uuid, p_sensitivity text, p_categories jsonb, p_moms_period text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_role text; v_old record; v_changed text[] := '{}'; c text;
begin
  if p_company is null or p_company not in (select user_company_ids()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not public.has_ai_feature(p_company, 'robo_bp') then
    insert into public.robo_bp_audit_log(company_id, user_id, action, detail)
      values (p_company, auth.uid(), 'denied', jsonb_build_object('reason', 'no_license', 'op', 'save_settings'));
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select role into v_role from public.user_companies where user_id = auth.uid() and company_id = p_company limit 1;
  if v_role is null or lower(v_role) in ('viewer', 'read_only', 'readonly', 'lasare', 'guest', 'gast') then
    insert into public.robo_bp_audit_log(company_id, user_id, action, detail)
      values (p_company, auth.uid(), 'denied', jsonb_build_object('reason', 'role', 'op', 'save_settings'));
    raise exception 'forbidden' using errcode = '42501';
  end if;

  if p_sensitivity not in ('standard', 'utokad', 'anpassad') then raise exception 'invalid_sensitivity' using errcode = '22023'; end if;
  if p_moms_period is not null and p_moms_period not in ('manadsvis', 'kvartalsvis', 'arsvis') then raise exception 'invalid_moms_period' using errcode = '22023'; end if;
  if jsonb_typeof(p_categories) is distinct from 'array' then raise exception 'invalid_categories' using errcode = '22023'; end if;
  for c in select jsonb_array_elements_text(p_categories) loop
    if c not in ('saknade_underlag', 'balansrakning', 'skulder', 'fordringar') then
      raise exception 'unknown_category' using errcode = '22023';
    end if;
  end loop;

  select * into v_old from public.robo_bp_settings where company_id = p_company;
  if not found or v_old.sensitivity is distinct from p_sensitivity then v_changed := array_append(v_changed, 'sensitivity'); end if;
  if not found or v_old.categories is distinct from p_categories then v_changed := array_append(v_changed, 'categories'); end if;
  if not found or v_old.moms_period is distinct from p_moms_period then v_changed := array_append(v_changed, 'moms_period'); end if;

  insert into public.robo_bp_settings(company_id, sensitivity, categories, moms_period, updated_by, updated_at)
    values (p_company, p_sensitivity, p_categories, p_moms_period, auth.uid(), now())
    on conflict (company_id) do update set sensitivity = excluded.sensitivity, categories = excluded.categories,
      moms_period = excluded.moms_period, updated_by = excluded.updated_by, updated_at = now();

  insert into public.robo_bp_audit_log(company_id, user_id, action, detail)
    values (p_company, auth.uid(), 'settings_changed', jsonb_build_object(
      'changed', to_jsonb(v_changed), 'sensitivity', p_sensitivity, 'momsPeriod', p_moms_period, 'categories', p_categories));

  return jsonb_build_object('sensitivity', p_sensitivity, 'categories', p_categories, 'moms_period', p_moms_period, 'isDefault', false);
end $function$
;

CREATE OR REPLACE FUNCTION public.robo_bp_set_check_status(p_check uuid, p_status text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_role text; v_from text; v_view text; v_risk text;
begin
  if p_status not in ('open', 'in_progress', 'done', 'dismissed') then
    raise exception 'invalid_status' using errcode = '22023';
  end if;
  select company_id, status, view, risk_level into v_company, v_from, v_view, v_risk from public.robo_bp_checks where id = p_check;
  if v_company is null then raise exception 'not_found' using errcode = 'P0002'; end if;
  if v_company not in (select user_company_ids()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not public.has_ai_feature(v_company, 'robo_bp') then
    insert into public.robo_bp_audit_log(company_id, user_id, action, detail) values (v_company, auth.uid(), 'denied', jsonb_build_object('reason', 'no_license', 'op', 'set_check_status'));
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select role into v_role from public.user_companies where user_id = auth.uid() and company_id = v_company limit 1;
  if v_role is null or lower(v_role) in ('viewer', 'read_only', 'readonly', 'lasare', 'guest', 'gast') then
    insert into public.robo_bp_audit_log(company_id, user_id, action, detail) values (v_company, auth.uid(), 'denied', jsonb_build_object('reason', 'role', 'op', 'set_check_status'));
    raise exception 'forbidden' using errcode = '42501';
  end if;

  update public.robo_bp_checks set status = p_status, updated_at = now() where id = p_check;
  insert into public.robo_bp_audit_log(company_id, user_id, action, detail)
    values (v_company, auth.uid(), 'check_status_changed', jsonb_build_object('checkId', p_check, 'fromStatus', v_from, 'toStatus', p_status, 'view', v_view, 'risk_level', v_risk));
  return p_status;
end $function$
;

CREATE OR REPLACE FUNCTION public.robo_bp_set_control_observation_status(p_run_id uuid, p_code text, p_status text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_fy uuid; v_sum jsonb; v_new jsonb := '[]'::jsonb; o jsonb; v_from text; v_found boolean := false;
begin
  if p_status not in ('open', 'resolved', 'dismissed') then raise exception 'invalid_status' using errcode = '22023'; end if;
  select company_id, fiscal_year_id, summary into v_company, v_fy, v_sum from public.robo_bp_control_runs where id = p_run_id;
  if v_company is null then raise exception 'not_found' using errcode = 'P0002'; end if;
  if v_company not in (select user_company_ids()) then raise exception 'forbidden' using errcode = '42501'; end if;
  if not public.has_ai_feature(v_company, 'robo_bp') then
    insert into public.robo_bp_audit_log(company_id, user_id, action, detail)
      values (v_company, auth.uid(), 'denied', jsonb_build_object('reason', 'no_license', 'op', 'set_control_observation_status'));
    raise exception 'forbidden' using errcode = '42501';
  end if;

  for o in select * from jsonb_array_elements(coalesce(v_sum -> 'observations', '[]'::jsonb)) loop
    if o ->> 'code' = p_code then
      v_from := coalesce(o ->> 'status', 'open'); v_found := true;
      o := jsonb_set(o, '{status}', to_jsonb(p_status));
      o := jsonb_set(o, '{marked_by}', to_jsonb(auth.uid()::text));
      o := jsonb_set(o, '{marked_at}', to_jsonb(now()::text));
    end if;
    v_new := v_new || o;
  end loop;
  if not v_found then raise exception 'code_not_found' using errcode = 'P0002'; end if;

  update public.robo_bp_control_runs set summary = jsonb_set(v_sum, '{observations}', v_new) where id = p_run_id;

  insert into public.robo_bp_audit_log(company_id, user_id, action, detail)
    values (v_company, auth.uid(), 'control_observation_status_changed', jsonb_build_object(
      'runId', p_run_id, 'code', p_code, 'fromStatus', v_from, 'toStatus', p_status, 'fiscalYearId', v_fy));

  return jsonb_build_object('runId', p_run_id, 'code', p_code, 'fromStatus', v_from, 'toStatus', p_status);
end $function$
;

CREATE OR REPLACE FUNCTION public.run_bokslut_analysis(p_engagement uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_company uuid; v_fy uuid; v_status text; v_start date; v_end date; v_run timestamptz := now();
  v_trial numeric; v_result numeric; v_res jsonb;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, fiscal_year_id, status into v_company, v_fy, v_status from bokslut_engagements where id=p_engagement;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then raise exception 'forbidden' using errcode='42501'; end if;
  if not public.has_ai_feature(v_company, 'ai_bokslut_arsredovisning') then raise exception 'feature_not_licensed' using errcode='42501'; end if;
  if v_status = 'last' then raise exception 'engagemanget är låst' using errcode='42501'; end if;
  select start_date, end_date into v_start, v_end from fiscal_years where id=v_fy;

  -- Saldon per konto: ingående balans + rörelse under räkenskapsåret (ej makulerade verifikationer).
  drop table if exists tmp_bal;
  create temp table tmp_bal as
    select a.account_nr, a.name, a.account_class,
      coalesce(a.opening_balance,0) + coalesce(m.mov,0) as closing
    from accounts a
    left join (
      select r.account_nr, sum(coalesce(r.debet,0)-coalesce(r.kredit,0)) mov
      from verifikation_rows r join verifikationer v on v.id=r.verifikation_id
      where v.company_id=v_company and v.makulerad_av is null and v.datum between v_start and v_end
      group by r.account_nr
    ) m on m.account_nr=a.account_nr
    where a.company_id=v_company;

  -- 1. Bokföringen balanserar inte (trial balance ≠ 0) → kritisk.
  select coalesce(sum(closing),0) into v_trial from tmp_bal;
  insert into bokslut_checks (engagement_id, company_id, category, title, description, risk_level, status, suggested_action, source, action_url, rule_key, source_data)
  select p_engagement, v_company, 'arets_resultat', 'Bokföringen balanserar inte',
    'Summan av alla konton (ingående balans + årets rörelse) är ' || round(v_trial,2) || ' kr, inte 0. Något är obalanserat.', 'critical', 'open',
    'Hitta obalanserade verifikationer/ingående balanser och rätta så att debet = kredit.', 'Huvudbok', '/granskning', 'trial_balance_not_zero', jsonb_build_object('trial', round(v_trial,2))
  where abs(v_trial) > 0.5
  on conflict (engagement_id, rule_key, coalesce(account_nr,'-')) do update set title=excluded.title, description=excluded.description, risk_level=excluded.risk_level, suggested_action=excluded.suggested_action, source_data=excluded.source_data, updated_at=now(),
    status = case when bokslut_checks.status='resolved' and bokslut_checks.resolved_by is null then 'open' else bokslut_checks.status end;

  -- 2. Bankavstämning: omatchade bankhändelser i året → hög.
  insert into bokslut_checks (engagement_id, company_id, category, title, description, account_nr, saldo, risk_level, status, suggested_action, source, action_url, rule_key, source_data)
  select p_engagement, v_company, 'bankavstamning', 'Omatchade bankhändelser', n.cnt || ' bankhändelser i räkenskapsåret är inte matchade mot bokföringen.', null, null, 'high', 'open',
    'Öppna Kassa & bank och matcha/bokför händelserna före bokslut.', 'Bank', '/kassa-bank', 'unmatched_bank', jsonb_build_object('count', n.cnt)
  from (select count(*) cnt from bank_transactions where company_id=v_company and status='unmatched' and verifikation_id is null and datum between v_start and v_end) n
  where n.cnt > 0
  on conflict (engagement_id, rule_key, coalesce(account_nr,'-')) do update set title=excluded.title, description=excluded.description, risk_level=excluded.risk_level, suggested_action=excluded.suggested_action, source_data=excluded.source_data, updated_at=now(),
    status = case when bokslut_checks.status='resolved' and bokslut_checks.resolved_by is null then 'open' else bokslut_checks.status end;

  -- 3. Saknade underlag: verifikationer utan kopplat dokument → medel.
  insert into bokslut_checks (engagement_id, company_id, category, title, description, risk_level, status, suggested_action, source, action_url, rule_key, source_data)
  select p_engagement, v_company, 'saknade_underlag', 'Verifikationer utan underlag', n.cnt || ' verifikationer i räkenskapsåret saknar kopplat underlag.', 'medium', 'open',
    'Gå igenom verifikationerna och koppla underlag, eller dokumentera varför underlag saknas.', 'Bokföring', '/bokforing', 'missing_documents', jsonb_build_object('count', n.cnt)
  from (select count(*) cnt from verifikationer v where v.company_id=v_company and v.makulerad_av is null and v.datum between v_start and v_end and not exists (select 1 from documents d where d.verifikation_id=v.id)) n
  where n.cnt > 0
  on conflict (engagement_id, rule_key, coalesce(account_nr,'-')) do update set title=excluded.title, description=excluded.description, risk_level=excluded.risk_level, suggested_action=excluded.suggested_action, source_data=excluded.source_data, updated_at=now(),
    status = case when bokslut_checks.status='resolved' and bokslut_checks.resolved_by is null then 'open' else bokslut_checks.status end;

  -- 4. Ovanliga saldon: tillgångskonto (klass 1) med kreditsaldo, eller EK/skuld (klass 2) med debetsaldo → hög. En per konto.
  insert into bokslut_checks (engagement_id, company_id, category, title, description, account_nr, saldo, risk_level, status, suggested_action, source, action_url, rule_key, source_data)
  select p_engagement, v_company, 'ovanliga_saldon',
    'Ovanligt saldo på ' || b.account_nr || ' ' || coalesce(b.name,''),
    case when b.account_class=1 then 'Tillgångskonto med kreditsaldo (' || round(b.closing,2) || ' kr).' else 'Skuld-/EK-konto med debetsaldo (' || round(b.closing,2) || ' kr).' end,
    b.account_nr, round(b.closing,2), 'high', 'open',
    'Kontrollera konteringen – saldot har ovanligt tecken för kontoklassen.', 'Huvudbok', '/kontoanalys', 'unusual_balance', jsonb_build_object('account', b.account_nr, 'closing', round(b.closing,2), 'class', b.account_class)
  from tmp_bal b
  where ((b.account_class=1 and b.closing < -0.5) or (b.account_class=2 and b.closing > 0.5))
  on conflict (engagement_id, rule_key, coalesce(account_nr,'-')) do update set title=excluded.title, description=excluded.description, saldo=excluded.saldo, risk_level=excluded.risk_level, suggested_action=excluded.suggested_action, source_data=excluded.source_data, updated_at=now(),
    status = case when bokslut_checks.status='resolved' and bokslut_checks.resolved_by is null then 'open' else bokslut_checks.status end;

  -- 5. Moms: saldo på 2650 (momsredovisning) ≠ 0 vid årets slut → medel.
  insert into bokslut_checks (engagement_id, company_id, category, title, description, account_nr, saldo, risk_level, status, suggested_action, source, action_url, rule_key, source_data)
  select p_engagement, v_company, 'moms', 'Momsredovisningskonto ej noll', 'Konto 2650 har saldo ' || round(b.closing,2) || ' kr. Kontrollera att all moms är redovisad och omförd.', '2650', round(b.closing,2), 'medium', 'open',
    'Stäm av momsen och omför saldot på 2650 mot skuld/fordran.', 'Moms', '/moms', 'vat_settlement_open', jsonb_build_object('closing', round(b.closing,2))
  from tmp_bal b where b.account_nr='2650' and abs(b.closing) > 0.5
  on conflict (engagement_id, rule_key, coalesce(account_nr,'-')) do update set title=excluded.title, description=excluded.description, saldo=excluded.saldo, suggested_action=excluded.suggested_action, source_data=excluded.source_data, updated_at=now(),
    status = case when bokslut_checks.status='resolved' and bokslut_checks.resolved_by is null then 'open' else bokslut_checks.status end;

  -- 6. Kontrollkonton: saldovisning + needs_review per kontrollområde (om saldo ≠ 0).
  insert into bokslut_checks (engagement_id, company_id, category, title, description, account_nr, saldo, risk_level, status, suggested_action, source, action_url, rule_key, source_data)
  select p_engagement, v_company, c.category, c.title, c.descr || ' Saldo enligt huvudbok: ' || round(s.saldo,2) || ' kr.', null, round(s.saldo,2), c.risk, 'needs_review',
    c.action, 'Huvudbok', '/kontoanalys', c.rule_key, jsonb_build_object('saldo', round(s.saldo,2), 'prefixes', c.prefixes)
  from (values
    ('kundfordringar','Kundfordringar att stämma av','Stäm av kundreskontran mot konto 15xx.','Stäm av öppna kundfakturor mot kundfordringskontot.','medium','review_kundfordringar', array['15']),
    ('leverantorsskulder','Leverantörsskulder att stämma av','Stäm av leverantörsreskontran mot konto 24xx.','Stäm av obetalda leverantörsfakturor mot leverantörsskuldkontot.','medium','review_leverantorsskulder', array['24']),
    ('skattekonto','Skattekonto att stämma av','Stäm av mot Skatteverkets kontoutdrag (16xx).','Jämför saldot mot Skatteverkets skattekontoutdrag.','medium','review_skattekonto', array['16']),
    ('eget_kapital','Eget kapital','Kontrollera eget kapital och föregående års resultatdisposition (20xx).','Kontrollera resultatdisposition och bundet/fritt eget kapital.','low','review_eget_kapital', array['20']),
    ('anlaggningstillgangar','Anläggningstillgångar','Kontrollera anläggningsregister (10–12).','Stäm av anläggningsregistret mot bokfört värde.','low','review_anlaggningstillgangar', array['10','11','12']),
    ('avskrivningar','Avskrivningar','Kontrollera årets avskrivningar (78xx).','Kontrollera att planenliga avskrivningar är bokförda.','low','review_avskrivningar', array['78']),
    ('periodiseringar','Periodiseringar','Kontrollera förutbetalda/upplupna poster (17xx/29xx).','Periodisera intäkter och kostnader korrekt över årsskiftet.','medium','review_periodiseringar', array['17','29']),
    ('lon_arbetsgivaravgift','Lön och arbetsgivaravgifter','Stäm av löneskulder och arbetsgivaravgifter (27xx).','Stäm av personalskatter och arbetsgivaravgifter mot deklarationer.','medium','review_lon', array['27']),
    ('skatt','Skatt på årets resultat','Beräkna och boka skatt på årets resultat (25xx/89xx).','Beräkna bolagsskatt och boka skattekostnad.','medium','review_skatt', array['25'])
  ) as c(category,title,descr,action,risk,rule_key,prefixes)
  cross join lateral (
    select coalesce(sum(b.closing),0) saldo from tmp_bal b where exists (select 1 from unnest(c.prefixes) p where b.account_nr like p || '%')
  ) s
  where abs(s.saldo) > 0.5
  on conflict (engagement_id, rule_key, coalesce(account_nr,'-')) do update set title=excluded.title, description=excluded.description, saldo=excluded.saldo, suggested_action=excluded.suggested_action, source_data=excluded.source_data, updated_at=now();

  -- 7. Årets resultat (needs_review, informativ): resultat = -(summa klass 3-8).
  select coalesce(-sum(closing),0) into v_result from tmp_bal where account_class between 3 and 8;
  insert into bokslut_checks (engagement_id, company_id, category, title, description, saldo, risk_level, status, suggested_action, source, action_url, rule_key, source_data)
  values (p_engagement, v_company, 'arets_resultat', 'Årets resultat enligt bokföringen',
    'Beräknat resultat (intäkter − kostnader) för räkenskapsåret: ' || round(v_result,2) || ' kr. Kontrollera mot resultaträkningen och boka årets resultat.', round(v_result,2),
    'low', 'needs_review', 'Stäm av mot resultatrapporten och boka om årets resultat till eget kapital.', 'Resultaträkning', '/rapporter', 'arets_resultat_review', jsonb_build_object('result', round(v_result,2)))
  on conflict (engagement_id, rule_key, coalesce(account_nr,'-')) do update set description=excluded.description, saldo=excluded.saldo, source_data=excluded.source_data, updated_at=now();

  -- 8. Scaffold: noter + bokslutsverifikationer (manuell bedömning, ingen automatik).
  insert into bokslut_checks (engagement_id, company_id, category, title, description, risk_level, status, suggested_action, source, action_url, rule_key)
  values
    (p_engagement, v_company, 'noter', 'Noter till årsredovisningen', 'Säkerställ att noter enligt K2 är kompletta (redovisningsprinciper, anläggningstillgångar, m.m.).', 'low', 'needs_review', 'Gå igenom K2-notkraven och komplettera årsredovisningsutkastet (kommer i nästa steg).', 'K2', '/ai-bokslut', 'review_noter'),
    (p_engagement, v_company, 'bokslutsverifikationer', 'Bokslutsverifikationer', 'Kontrollera att alla bokslutsverifikationer (periodiseringar, avskrivningar, skatt) är bokförda.', 'medium', 'needs_review', 'Skapa och granska bokslutsverifikationer manuellt – AI får endast föreslå utkast.', 'Bokföring', '/bokforing', 'review_bokslutsverifikationer')
  on conflict (engagement_id, rule_key, coalesce(account_nr,'-')) do update set updated_at=now();

  -- Auto-resolve risk-checkar som inte längre gäller (endast status='open', orörda denna körning).
  update bokslut_checks set status='resolved', resolved_at=now(), updated_at=now()
    where engagement_id=p_engagement and status='open' and updated_at < v_run;

  perform public._bokslut_recount(p_engagement);
  update bokslut_engagements set last_analysis_at=now() where id=p_engagement;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, model, prompt_version, detail)
  values (p_engagement, v_company, auth.uid(), 'run_analysis', 'rule-engine', 'v1', jsonb_build_object('trial', round(v_trial,2), 'result', round(v_result,2)));

  select to_jsonb(e) into v_res from bokslut_engagements e where e.id=p_engagement;
  return v_res;
end $function$
;

CREATE OR REPLACE FUNCTION public.run_monthly_control(p_company_id uuid, p_year integer, p_month integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_control uuid;
  v_start date := make_date(p_year, p_month, 1);
  v_end date := (make_date(p_year, p_month, 1) + interval '1 month')::date - 1;
  v_run timestamptz := now();
  v_res jsonb;
begin
  if not public._ar_betrodd_backend() and not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=p_company_id) then
    raise exception 'forbidden' using errcode='42501'; end if;
  if p_month < 1 or p_month > 12 then raise exception 'ogiltig månad' using errcode='22023'; end if;

  insert into monthly_controls (company_id, year, month, status)
  values (p_company_id, p_year, p_month, 'in_progress')
  on conflict (company_id, year, month) do update set updated_at=now()
  returning id into v_control;

  -- 1. Inkorg
  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'inkorg', 'document', d.id, 'Underlag saknar koppling: ' || coalesce(d.file_name,'(namnlöst)'),
    'Underlaget är uppladdat men inte kopplat till någon verifikation.', 'high', 'Öppna Inkorgen och koppla underlaget till rätt verifikation.', '/inkorg',
    'unlinked_inbox_documents', jsonb_build_object('file_name', d.file_name, 'source', d.source, 'received_at', coalesce(d.received_at, d.created_at))
  from documents d where d.company_id=p_company_id and d.verifikation_id is null and coalesce(d.received_at, d.created_at)::date between v_start and v_end
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'inkorg', 'document', d.id, 'Underlag ej tolkat: ' || coalesce(d.file_name,'(namnlöst)'),
    'Bild/PDF har inte tolkats av AI ännu.', 'normal', 'Öppna underlaget och kör "Tolka underlaget".', '/inkorg',
    'untolkad_documents', jsonb_build_object('file_name', d.file_name, 'ai_status', d.ai_status)
  from documents d where d.company_id=p_company_id and coalesce(d.tolkad,false)=false and d.ai_status is distinct from 'completed' and coalesce(d.received_at, d.created_at)::date between v_start and v_end
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'inkorg', 'document', d.id, 'Underlag med låg AI-träffsäkerhet: ' || coalesce(d.file_name,'(namnlöst)'),
    'AI-tolkningen har låg konfidens (' || round(d.confidence*100) || ' %). Kontrollera värdena manuellt.', 'normal', 'Granska tolkningens fält mot underlaget innan bokföring.', '/inkorg',
    'low_confidence_documents', jsonb_build_object('file_name', d.file_name, 'confidence', d.confidence)
  from documents d where d.company_id=p_company_id and d.confidence is not null and d.confidence < 0.6 and coalesce(d.tolkad,false)=true and coalesce(d.received_at, d.created_at)::date between v_start and v_end
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'inkorg', 'document', d.id, 'Misslyckad AI-tolkning: ' || coalesce(d.file_name,'(namnlöst)'),
    'AI-tolkningen misslyckades' || case when d.ai_last_error is not null then ': ' || left(d.ai_last_error,200) else '.' end, 'high', 'Öppna underlaget och försök tolka igen, eller bokför manuellt.', '/inkorg',
    'failed_ai_interpretations', jsonb_build_object('file_name', d.file_name, 'ai_status', d.ai_status, 'ai_last_error', left(coalesce(d.ai_last_error,''),300))
  from documents d where d.company_id=p_company_id and (d.ai_status='failed' or d.ai_last_error is not null) and coalesce(d.received_at, d.created_at)::date between v_start and v_end
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  -- 2. Bokföring
  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'bokforing', 'verifikation', v.id, 'Obalanserad verifikation ' || coalesce(v.ver_serie,'') || coalesce(v.ver_nr,''),
    'Debet (' || round(coalesce(v.total_debet,0),2) || ') och kredit (' || round(coalesce(v.total_kredit,0),2) || ') stämmer inte. Differens ' || round(coalesce(v.total_debet,0)-coalesce(v.total_kredit,0),2) || ' kr.',
    'critical', 'Öppna verifikationen och rätta raderna så att debet = kredit.', '/bokforing/' || v.id,
    'unbalanced_journal_entries', jsonb_build_object('ver', coalesce(v.ver_serie,'')||coalesce(v.ver_nr,''), 'debet', v.total_debet, 'kredit', v.total_kredit, 'datum', v.datum)
  from verifikationer v where v.company_id=p_company_id and v.makulerad_av is null and v.datum between v_start and v_end and round(coalesce(v.total_debet,0),2) <> round(coalesce(v.total_kredit,0),2)
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'bokforing', 'verifikation', v.id, 'Verifikation utan underlag ' || coalesce(v.ver_serie,'') || coalesce(v.ver_nr,''),
    'Verifikationen saknar kopplat underlag (kvitto/faktura).', 'normal', 'Öppna verifikationen och koppla ett underlag, eller bekräfta att inget krävs.', '/bokforing/' || v.id,
    'journal_entry_without_attachment', jsonb_build_object('ver', coalesce(v.ver_serie,'')||coalesce(v.ver_nr,''), 'datum', v.datum)
  from verifikationer v where v.company_id=p_company_id and v.makulerad_av is null and v.datum between v_start and v_end and not exists (select 1 from documents d where d.verifikation_id=v.id)
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  -- 3. Leverantörsfakturor
  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'leverantorsfakturor', 'supplier_invoice', si.id, 'Leverantörsfaktura ej bokförd: ' || coalesce(si.invoice_nr, '#'||si.lopnr::text, '(utan nr)'),
    'Fakturan är registrerad men inte bokförd.', 'high', 'Öppna leverantörsfakturan, kontrollera kontering och bokför.', '/leverantorsfakturor/' || si.id,
    'unbooked_supplier_invoices', jsonb_build_object('invoice_nr', si.invoice_nr, 'total', si.total_amount, 'invoice_date', si.invoice_date)
  from supplier_invoices si where si.company_id=p_company_id and coalesce(si.makulerad,false)=false and coalesce(si.bokford,false)=false and si.invoice_date between v_start and v_end
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'leverantorsfakturor', 'supplier_invoice', si.id, 'Leverantörsfaktura utan kontering: ' || coalesce(si.invoice_nr, '#'||si.lopnr::text, '(utan nr)'),
    'Fakturan saknar kostnadskonto/kontering.', 'normal', 'Öppna fakturan och ange kostnadskonto/kontering.', '/leverantorsfakturor/' || si.id,
    'supplier_invoice_without_kontering', jsonb_build_object('invoice_nr', si.invoice_nr, 'total', si.total_amount)
  from supplier_invoices si where si.company_id=p_company_id and coalesce(si.makulerad,false)=false and coalesce(si.bokford,false)=false and coalesce(si.kostnadskonto,'')='' and si.invoice_date between v_start and v_end
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'leverantorsfakturor', 'supplier_invoice', si.id, 'Förfallen obetald leverantörsfaktura: ' || coalesce(si.invoice_nr, '#'||si.lopnr::text, '(utan nr)'),
    'Fakturan förföll ' || si.due_date || ' och är inte fullt betald.', 'critical', 'Betala fakturan eller markera betalning, kontrollera annars förfallodatum.', '/leverantorsfakturor/' || si.id,
    'overdue_supplier_invoices', jsonb_build_object('invoice_nr', si.invoice_nr, 'due_date', si.due_date, 'total', si.total_amount, 'paid', si.paid_amount)
  from supplier_invoices si where si.company_id=p_company_id and coalesce(si.makulerad,false)=false and coalesce(si.status,'')<>'paid' and coalesce(si.paid_amount,0) < coalesce(si.total_amount,0) and si.due_date is not null and si.due_date < current_date
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'leverantorsfakturor', 'supplier_invoice', si.id, 'Kreditfaktura ej hanterad: ' || coalesce(si.invoice_nr, '#'||si.lopnr::text, '(utan nr)'),
    'Leverantörskreditfaktura är inte bokförd.', 'high', 'Bokför kreditfakturan med omvänd kontering mot originalet.', '/leverantorsfakturor/' || si.id,
    'unhandled_credit_invoices', jsonb_build_object('invoice_nr', si.invoice_nr, 'total', si.total_amount)
  from supplier_invoices si where si.company_id=p_company_id and coalesce(si.kreditfaktura,false)=true and coalesce(si.makulerad,false)=false and coalesce(si.bokford,false)=false and si.invoice_date between v_start and v_end
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  -- 4. Kundfakturor
  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'kundfakturor', 'invoice', inv.id, 'Kundfaktura ej bokförd: ' || coalesce(inv.invoice_nr,'(utan nr)'),
    'Kundfakturan saknar kopplad verifikation.', 'high', 'Öppna kundfakturan och bokför den.', '/fakturor/' || inv.id,
    'unbooked_customer_invoices', jsonb_build_object('invoice_nr', inv.invoice_nr, 'total', inv.total_amount, 'invoice_date', inv.invoice_date, 'status', inv.status)
  from invoices inv where inv.company_id=p_company_id and inv.verifikation_id is null and inv.invoice_date between v_start and v_end
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  -- 5. Bank
  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'bank', 'bank_transaction', bt.id, 'Bankhändelse saknar matchning: ' || coalesce(left(bt.text,40),'') || ' (' || round(coalesce(bt.amount,0),2) || ' kr)',
    'Importerad bankhändelse är inte matchad mot någon verifikation.', 'high', 'Öppna bankavstämning och matcha händelsen.', '/kassa-bank',
    'unmatched_bank_transactions', jsonb_build_object('text', bt.text, 'amount', bt.amount, 'datum', bt.datum)
  from bank_transactions bt where bt.company_id=p_company_id and bt.status='unmatched' and bt.verifikation_id is null and bt.datum between v_start and v_end
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  -- 6. Lön
  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'lon', 'employee', e.id, 'Anställd saknar uppgifter: ' || coalesce(nullif(trim(e.namn),''), trim(coalesce(e.fornamn,'')||' '||coalesce(e.efternamn,'')), '(namnlös)'),
    'Aktiv anställd saknar personnummer, skattetabell eller bankkonto.', 'normal', 'Öppna anställdregistret och komplettera uppgifterna.', '/lon/anstallda',
    'employees_missing_data', jsonb_build_object('saknar_personnummer', (e.personnummer is null or e.personnummer=''), 'saknar_skattetabell', (e.skattetabell is null), 'saknar_bankkonto', (coalesce(nullif(e.bankkontonummer,''), nullif(e.kontonr,'')) is null))
  from employees e where e.company_id=p_company_id and coalesce(e.is_active,true)=true and ((e.personnummer is null or e.personnummer='') or e.skattetabell is null or coalesce(nullif(e.bankkontonummer,''), nullif(e.kontonr,'')) is null)
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  -- 7. Moms (regler som bara reagerar på riktiga signaler – inga falsklarm för tomma månader)
  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'moms', 'vat_report', null, 'Momsrapport ej skapad för ' || to_char(v_start,'YYYY-MM'),
    'Det finns bokförd moms i perioden men ingen momsrapport är registrerad.', 'normal', 'Gå till Moms, ta fram och bokför momsredovisningen för perioden.', '/moms',
    'vat_report_not_created', jsonb_build_object('year', p_year, 'month', p_month)
  where not exists (select 1 from vat_reports vr where vr.company_id=p_company_id and vr.year=p_year and vr.month=p_month)
    and exists (select 1 from verifikation_rows r join verifikationer v on v.id=r.verifikation_id
      where v.company_id=p_company_id and v.makulerad_av is null and v.datum between v_start and v_end
        and (r.account_nr like '261%' or r.account_nr like '262%' or r.account_nr like '263%' or r.account_nr like '264%'))
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'moms', 'vat_report', vr.id, 'Momsrapport ej kontrollerad för ' || to_char(v_start,'YYYY-MM'),
    'Momsrapporten är registrerad men inte markerad som kontrollerad.', 'normal', 'Granska momsrapporten och markera den som kontrollerad.', '/moms',
    'vat_report_not_checked', jsonb_build_object('status', vr.status)
  from vat_reports vr where vr.company_id=p_company_id and vr.year=p_year and vr.month=p_month and vr.status not in ('checked','submitted')
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  insert into monthly_control_items (monthly_control_id, company_id, module, related_type, related_id, title, description, priority, suggested_action, action_url, rule_key, source_data)
  select v_control, p_company_id, 'moms', 'vat_report', vr.id, 'Momsrapport har differens (' || round(vr.difference,2) || ' kr)',
    'Det finns en differens mellan bokförd moms och momsrapporten. Utred innan redovisning.', 'critical', 'Stäm av momskontona mot momsrapporten och rätta differensen.', '/moms',
    'vat_report_difference', jsonb_build_object('difference', vr.difference)
  from vat_reports vr where vr.company_id=p_company_id and vr.year=p_year and vr.month=p_month and round(coalesce(vr.difference,0),2) <> 0
  on conflict (monthly_control_id, rule_key, coalesce(related_id,'00000000-0000-0000-0000-000000000000'::uuid)) do update
    set title=excluded.title, description=excluded.description, priority=excluded.priority, suggested_action=excluded.suggested_action, action_url=excluded.action_url, source_data=excluded.source_data, updated_at=now(),
        status = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then 'open' else monthly_control_items.status end,
        resolved_at = case when monthly_control_items.status='resolved' and monthly_control_items.resolved_by is null then null else monthly_control_items.resolved_at end;

  -- Auto-resolve punkter som inte längre gäller (orörda denna körning).
  with ar as (
    update monthly_control_items set status='resolved', resolved_at=now(), updated_at=now()
      where monthly_control_id=v_control and status='open' and updated_at < v_run returning id, company_id
  )
  insert into monthly_control_events (monthly_control_id, item_id, company_id, event_type, detail)
  select v_control, id, company_id, 'auto_resolved', jsonb_build_object('reason','villkoret gäller inte längre') from ar;

  perform public._mc_recount(v_control);
  update monthly_controls set last_run_at=now() where id=v_control;
  insert into monthly_control_events (monthly_control_id, company_id, user_id, event_type, detail)
  values (v_control, p_company_id, auth.uid(), 'run', jsonb_build_object('year',p_year,'month',p_month,'system', auth.uid() is null));

  select jsonb_build_object('control_id', mc.id, 'status', mc.status, 'progress_percent', mc.progress_percent,
    'critical', mc.critical_count, 'high', mc.high_count, 'normal', mc.normal_count, 'low', mc.low_count, 'resolved', mc.resolved_count)
  into v_res from monthly_controls mc where mc.id=v_control;
  return v_res;
end $function$
;

CREATE OR REPLACE FUNCTION public.run_scheduled_notifications()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record; n_cust int := 0; n_sup int := 0; n_bank int := 0;
begin
  for r in select i.id, i.company_id, i.invoice_nr, i.due_date, i.total_amount from public.invoices i
           where i.status='sent' and i.due_date < current_date loop
    perform public.notify_event(r.company_id,'payment_overdue',
      jsonb_build_object('party','kund','invoiceNumber',coalesce(r.invoice_nr,''),'dueDate',r.due_date::text,
        'amount', to_char(coalesce(r.total_amount,0),'FM999G999G990')||' kr','actionUrl','https://app.bokpilot.se/fakturor/'||r.id::text),
      'invoice', r.id, '/fakturor/'||r.id::text, null, null, 'high',
      'payment_overdue:'||r.id::text||':'||r.due_date::text);
    n_cust := n_cust + 1;
  end loop;

  for r in select s.id, s.company_id, s.invoice_nr, s.due_date,
             (coalesce(s.total_amount,0)-coalesce(s.paid_amount,0)) saldo
           from public.supplier_invoices s
           where coalesce(s.makulerad,false)=false and coalesce(s.kreditfaktura,false)=false
             and s.due_date < current_date and (coalesce(s.total_amount,0)-coalesce(s.paid_amount,0)) > 0.005 loop
    perform public.notify_event(r.company_id,'payment_overdue',
      jsonb_build_object('party','leverantör','invoiceNumber',coalesce(r.invoice_nr,''),'dueDate',r.due_date::text,
        'amount', to_char(r.saldo,'FM999G999G990')||' kr','actionUrl','https://app.bokpilot.se/leverantorsfakturor/'||r.id::text),
      'supplier_invoice', r.id, '/leverantorsfakturor/'||r.id::text, null, null, 'high',
      'payment_overdue:'||r.id::text||':'||r.due_date::text);
    n_sup := n_sup + 1;
  end loop;

  for r in select bt.company_id, count(*) c from public.bank_transactions bt
           where bt.status='unmatched' group by bt.company_id loop
    perform public.notify_event(r.company_id,'bank_reconciliation_action',
      jsonb_build_object('count', r.c::text, 'actionUrl','https://app.bokpilot.se/kassa-bank'),
      'bank', null, '/kassa-bank', null, null, 'normal',
      'bank_reconciliation_action:'||r.company_id::text||':'||current_date::text);
    n_bank := n_bank + 1;
  end loop;

  return jsonb_build_object('customer_overdue',n_cust,'supplier_overdue',n_sup,'bank_action',n_bank,'ran_at',now());
end $function$
;

CREATE OR REPLACE FUNCTION public.run_scheduled_plan_enforcement()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record; m text; v jsonb; v_checked int := 0; v_warn int := 0; v_exc int := 0; v_err int := 0;
  v_start timestamptz := clock_timestamp(); v_admins uuid[];
begin
  for r in select cs.company_id from company_subscriptions cs
           where cs.status in ('active','trial') and cs.plan_id is not null loop
    v_checked := v_checked + 1;
    foreach m in array array['users','companies','invoices','documents','storage','ai'] loop
      begin
        v := public._plan_limit_status(r.company_id, m);
        if v->>'status' = 'warning' then v_warn := v_warn + 1; perform public._notify_plan_limit(r.company_id, m, v);
        elsif v->>'status' = 'exceeded' then v_exc := v_exc + 1; perform public._notify_plan_limit(r.company_id, m, v); end if;
      exception when others then v_err := v_err + 1;
      end;
    end loop;
  end loop;
  -- Summary till billing-admins om något är över gräns.
  if v_exc > 0 then
    select public.billing_admin_ids() into v_admins;
    if v_admins is not null and array_length(v_admins,1) is not null then
      perform public.notify_event(null, 'plan_usage_summary',
        jsonb_build_object('exceeded',v_exc,'warnings',v_warn,'companies',v_checked,'actionUrl','https://app.bokpilot.se/admin/billing'),
        'plan_usage', null, '/admin/billing', v_admins, null, 'high',
        'plan_usage_summary:'||to_char(now(),'YYYYMMDD'), array['in_app','email']);
    end if;
  end if;
  perform public.log_platform_audit('plan_enforcement_run', null,
    jsonb_build_object('companies_checked',v_checked,'warnings',v_warn,'exceeded',v_exc,'errors',v_err,
      'duration_ms', round(extract(epoch from (clock_timestamp()-v_start))*1000)));
  return jsonb_build_object('companies_checked',v_checked,'warnings',v_warn,'exceeded',v_exc,'errors',v_err);
end $function$
;

CREATE OR REPLACE FUNCTION public.run_subscription_grace_enforcement()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record; n int := 0;
begin
  for r in select cs.company_id from public.company_subscriptions cs join public.companies c on c.id = cs.company_id
    where cs.status = 'past_due' and cs.grace_until is not null and cs.grace_until <= now()
      and coalesce(c.service_state,'active') = 'active' and coalesce(c.service_state_manual,false) = false
  loop perform public.sync_company_service_state_from_billing(r.company_id); n := n + 1; end loop;
  perform public.log_platform_audit('subscription_grace_enforcement_run', 'system', jsonb_build_object('paused', n));
  return n;
end $function$
;

CREATE OR REPLACE FUNCTION public.safe_uuid(t text)
 RETURNS uuid
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
begin
  return t::uuid;
exception when others then
  return null;
end $function$
;

CREATE OR REPLACE FUNCTION public.seed_bas_accounts(p_company uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare n int;
begin
  perform public._assert_company_access(p_company);
  perform set_config('app.bulk_import','on',true);
  insert into public.accounts(company_id, account_nr, name, vat_code, is_active,
         account_class, account_type, imported_from)
  select p_company, b.account_nr, b.name, nullif(b.vat_code,''), b.is_active,
         public.bas_class(b.account_nr), public.bas_type(b.account_nr), 'BAS 2026'
  from public.bas_accounts b
  where not exists (
    select 1 from public.accounts a where a.company_id = p_company and a.account_nr = b.account_nr
  );
  get diagnostics n = row_count;
  insert into public.audit_log(company_id, entity, action, new_data, changed_by, changed_by_email)
  values (p_company, 'account', 'import', jsonb_build_object('source','BAS 2026','inserted',n),
          auth.uid(), auth.jwt() ->> 'email');
  return jsonb_build_object('inserted', n);
end;
$function$
;

CREATE OR REPLACE FUNCTION public.seed_new_company()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into accounts (company_id, account_nr, name, vat_code, is_active)
    select NEW.id, account_nr, name, vat_code, is_active from bas_accounts
    on conflict (company_id, account_nr) do nothing;
  return NEW;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.send_test_notification(p_company_id uuid, p_channel text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_event uuid; v_qid uuid; v_status text;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not exists (select 1 from public.user_companies uc where uc.user_id = v_uid and uc.company_id = p_company_id) then
    raise exception 'forbidden: inte medlem i företaget' using errcode = '42501';
  end if;
  if p_channel not in ('in_app','email') then
    raise exception 'testnotis stöds bara för in_app och email' using errcode = '22023';
  end if;
  insert into public.notification_events (company_id, event_type, payload)
  values (p_company_id, 'test_notification', jsonb_build_object('channel', p_channel)) returning id into v_event;
  v_status := case when p_channel = 'in_app' then 'sent' else 'pending' end;
  insert into public.notification_queue (event_id, company_id, user_id, channel, status, priority, subject, body, link_url, scheduled_at, idempotency_key)
  values (v_event, p_company_id, v_uid, p_channel, v_status, 'normal',
    'BokPilot — testnotis',
    case when p_channel = 'in_app' then 'Det här är en testnotis i appen. Notissystemet fungerar.'
         else 'Det här är ett testmail från BokPilot. Om du ser det här fungerar email-leveransen.' end,
    '/installningar/notiser', now(), 'test:' || v_event::text)
  returning id into v_qid;
  return v_qid;
end $function$
;

CREATE OR REPLACE FUNCTION public.set_bokslut_engagement_status(p_engagement uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_cur text;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  select company_id, status into v_company, v_cur from bokslut_engagements where id=p_engagement;
  if v_company is null then raise exception 'not found' using errcode='P0002'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=v_company) then raise exception 'forbidden' using errcode='42501'; end if;
  if not public.has_ai_feature(v_company,'ai_bokslut_arsredovisning') then raise exception 'feature_not_licensed' using errcode='42501'; end if;
  if v_cur = 'last' then raise exception 'Engagemanget är låst – inga ändringar tillåts (endast läsning).' using errcode='42501'; end if;
  if p_status not in ('klar_for_konsult','godkand','avvisad','last') then raise exception 'ogiltig målstatus' using errcode='22023'; end if;
  if not public.bokslut_can(v_company,'manage_status') then raise exception 'Behörighet saknas: endast admin kan ändra bokslutsstatus.' using errcode='42501'; end if;
  update bokslut_engagements set status=p_status, updated_at=now() where id=p_engagement;
  insert into bokslut_audit_log (engagement_id, company_id, user_id, action, detail)
  values (p_engagement, v_company, auth.uid(), 'engagement_status', jsonb_build_object('from', v_cur, 'to', p_status));
end $function$
;

CREATE OR REPLACE FUNCTION public.set_notification_preference(p_company_id uuid, p_event_type text, p_channel text, p_enabled boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not authenticated' using errcode = '28000'; end if;
  if not exists (select 1 from public.user_companies uc where uc.user_id = v_uid and uc.company_id = p_company_id) then
    raise exception 'forbidden: inte medlem i företaget' using errcode = '42501';
  end if;
  if p_channel not in ('in_app','email','sms','push') then
    raise exception 'ogiltig kanal: %', p_channel using errcode = '22023';
  end if;
  if not p_enabled
     and p_event_type = any (array['security_event','permission_changed','system_error','locked_account_blocked','user_invited'])
     and p_channel in ('in_app','email') then
    raise exception 'Obligatorisk notis kan inte stängas av för %', p_channel using errcode = '22023';
  end if;
  if p_enabled and p_channel in ('sms','push') then
    if not exists (
      select 1 from public.notification_subscriptions s
      where s.user_id = v_uid and s.channel = p_channel
        and coalesce(s.opt_in, false) = true and coalesce(s.is_active, false) = true
    ) then
      raise exception '% kräver aktiv opt-in', p_channel using errcode = '22023';
    end if;
  end if;
  insert into public.notification_preferences (user_id, company_id, event_type, channel, enabled)
  values (v_uid, p_company_id, p_event_type, p_channel, p_enabled)
  on conflict (user_id, company_id, event_type, channel) do update set enabled = excluded.enabled, updated_at = now();
end $function$
;

CREATE OR REPLACE FUNCTION public.set_ocr_provider_config(p_enabled boolean, p_base_url text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_email text := lower(auth.jwt() ->> 'email'); v_clean text;
begin
  if not public.is_superadmin() then raise exception 'forbidden'; end if;
  v_clean := nullif(btrim(coalesce(p_base_url, '')), '');
  update public.ocr_provider_config
    set folio_enabled = coalesce(p_enabled, false),
        folio_base_url = v_clean,
        updated_at = now(),
        updated_by = auth.uid()
    where id;
  insert into public.platform_audit_log (actor_email, actor_id, action, target, detail)
    values (v_email, auth.uid(), 'ocr_config_update', 'ocr_provider_config',
      jsonb_build_object('folioEnabled', coalesce(p_enabled, false), 'baseUrlSet', v_clean is not null));
  return jsonb_build_object('folioEnabled', coalesce(p_enabled, false), 'folioBaseUrl', v_clean);
end $function$
;

CREATE OR REPLACE FUNCTION public.set_org_nr_normalized()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare d text;
begin
  d := regexp_replace(coalesce(new.org_nr, ''), '\D', '', 'g');
  if length(d) = 12 then d := substr(d, 3); end if;
  new.org_nr_normalized := case when length(d) = 10 then d else null end;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin new.updated_at := now(); return new; end;
$function$
;

CREATE OR REPLACE FUNCTION public.sie_importera_verifikation(p_company uuid, p_ver_nr text, p_ver_serie text, p_datum date, p_beskrivning text, p_rader jsonb, p_sie_import_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
  v_debet numeric := 0;
  v_kredit numeric := 0;
  v_diff numeric;
begin
  perform public._assert_company_access(p_company);

  if p_rader is null or jsonb_array_length(p_rader) = 0 then
    raise exception 'SIE_TOM: Verifikation % saknar konteringsrader.', p_ver_nr;
  end if;

  select coalesce(sum(round((r->>'debet')::numeric, 2)), 0),
         coalesce(sum(round((r->>'kredit')::numeric, 2)), 0)
    into v_debet, v_kredit
  from jsonb_array_elements(p_rader) r;

  v_diff := round(v_debet - v_kredit, 2);
  if v_diff <> 0 then
    raise exception 'SIE_OBALANS: Verifikation % balanserar inte (debet %, kredit %, differens %).',
      p_ver_nr, v_debet, v_kredit, v_diff;
  end if;

  if exists (select 1 from verifikationer where company_id = p_company and ver_nr = p_ver_nr) then
    raise exception 'SIE_DUBBLETT: Verifikationsnumret % finns redan i bolaget.', p_ver_nr;
  end if;

  insert into verifikationer (company_id, ver_nr, ver_serie, datum, beskrivning,
                              total_debet, total_kredit, created_by, sie_import_id)
  values (p_company, p_ver_nr, p_ver_serie, p_datum, coalesce(p_beskrivning, 'SIE-import'),
          v_debet, v_kredit, auth.uid(), p_sie_import_id)
  returning id into v_id;

  perform set_config('app.ver_insert', 'on', true);   -- sanktionerad atomisk radinsättning (etapp 2)
  insert into verifikation_rows (verifikation_id, account_nr, account_name, debet, kredit, sort_order)
  select v_id,
         r->>'account_nr',
         coalesce(r->>'account_name', ''),
         round((r->>'debet')::numeric, 2),
         round((r->>'kredit')::numeric, 2),
         (r->>'sort_order')::int
  from jsonb_array_elements(p_rader) r;
  perform set_config('app.ver_insert', 'off', true);

  return v_id;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.skapa_beta_ansokan(p_bolagsnamn text, p_org_nr text DEFAULT NULL::text, p_meddelande text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_user uuid := auth.uid();
  v_epost text := coalesce(auth.jwt() ->> 'email', '');
  v_approved boolean := coalesce(((auth.jwt() -> 'app_metadata') ->> 'approved')::boolean, false);
  v_company uuid;
  v_ansokan uuid;
begin
  if v_user is null then
    raise exception 'Ej inloggad';
  end if;
  if p_bolagsnamn is null or length(trim(p_bolagsnamn)) = 0 then
    raise exception 'Bolagsnamn saknas';
  end if;
  if length(coalesce(p_meddelande, '')) > 2000 then
    raise exception 'Meddelandet är för långt (max 2000 tecken)';
  end if;
  -- Idempotent: har användaren redan ett bolag skapas inget nytt.
  if exists (select 1 from user_companies where user_id = v_user) then
    raise exception 'Användaren är redan kopplad till ett bolag';
  end if;

  insert into companies (name, org_nr, suspended)
    values (trim(p_bolagsnamn), nullif(trim(coalesce(p_org_nr, '')), ''), not v_approved)
    returning id into v_company;

  insert into user_companies (user_id, company_id, role, email)
    values (v_user, v_company, 'admin', v_epost);

  if not v_approved then
    insert into beta_ansokningar (user_id, company_id, epost, bolagsnamn, org_nr, meddelande)
      values (v_user, v_company, v_epost, trim(p_bolagsnamn),
              nullif(trim(coalesce(p_org_nr, '')), ''),
              nullif(trim(coalesce(p_meddelande, '')), ''))
      returning id into v_ansokan;
  end if;

  return jsonb_build_object('company_id', v_company, 'ansokan_id', v_ansokan);
end $function$
;

CREATE OR REPLACE FUNCTION public.skydda_bokfort_underlag()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if current_setting('app.periodlas_bypass', true) = 'on'
     or current_setting('app.radera_senaste', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE' then
    if old.verifikation_id is not null then
      raise exception 'Underlaget hör till bokföringen och ska bevaras i 7 år (BFL 7 kap 2 §) – det kan inte raderas';
    end if;
    if old.kategori = 'kontoutdrag' and old.import_batch is not null
       and exists (select 1 from public.bank_transactions bt
                   where bt.import_batch = old.import_batch and bt.verifikation_id is not null) then
      raise exception 'Kontoutdraget är underlag för bokförda verifikationer (BFL 7 kap 2 §) – det kan inte raderas. Ångra bokföringarna först.';
    end if;
    return old;
  end if;
  if old.verifikation_id is not null and new.verifikation_id is null then
    raise exception 'Underlagets koppling till bokföringen kan inte tas bort (BFL 7 kap 2 §)';
  end if;
  if old.kategori = 'kontoutdrag' and old.import_batch is not null
     and new.import_batch is distinct from old.import_batch
     and exists (select 1 from public.bank_transactions bt
                 where bt.import_batch = old.import_batch and bt.verifikation_id is not null) then
    raise exception 'Kontoutdragets koppling till bokförda verifikationer kan inte tas bort (BFL 7 kap 2 §)';
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.skydda_rakenskapsar()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_antal int;
begin
  if current_setting('app.periodlas_bypass', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if not exists (select 1 from public.companies where id = old.company_id) then
    return case when tg_op = 'DELETE' then old else new end;   -- cascade vid företagsradering
  end if;
  if tg_op = 'DELETE' then
    select count(*) into v_antal from public.verifikationer
      where company_id = old.company_id and datum between old.start_date and old.end_date;
    if v_antal > 0 then
      raise exception 'RÄKENSKAPSÅRSSKYDD: Räkenskapsår % innehåller % bokförda verifikationer och kan inte raderas (BFL 7 kap). Makulera posterna eller kontakta support om året är felupplagt.', old.year, v_antal;
    end if;
    return old;
  end if;
  -- UPDATE: statusbyten är fria, men datumgränserna får inte ändras så att
  -- bokförda poster hamnar utanför året.
  if new.start_date is distinct from old.start_date or new.end_date is distinct from old.end_date then
    select count(*) into v_antal from public.verifikationer
      where company_id = old.company_id
        and datum between old.start_date and old.end_date
        and datum not between new.start_date and new.end_date;
    if v_antal > 0 then
      raise exception 'RÄKENSKAPSÅRSSKYDD: % bokförda verifikationer skulle hamna utanför räkenskapsår % med de nya datumgränserna. Ändringen stoppades.', v_antal, old.year;
    end if;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.skydda_sista_byra_admin()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if old.roll = 'admin' and old.aktiv
     and (tg_op = 'DELETE' or new.roll <> 'admin' or not new.aktiv) then
    -- Radlås byråns medlemskap: två samtidiga transaktioner kan annars
    -- inaktivera varandras "sista admin" (TOCTOU).
    perform 1 from byra_medlemskap where byra_bolag_id = old.byra_bolag_id for update;
    if not exists (
      select 1 from byra_medlemskap
      where byra_bolag_id = old.byra_bolag_id and id <> old.id and aktiv and roll = 'admin'
    ) then
      raise exception 'Byråns sista administratör kan inte inaktiveras, nedgraderas eller tas bort';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.start_mc_item(p_item uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare g record;
begin
  g := public._mc_item_guard(p_item);
  update monthly_control_items set status='in_progress', updated_at=now() where id=p_item;
  insert into monthly_control_events(monthly_control_id, item_id, company_id, user_id, event_type)
  values (g.monthly_control_id, p_item, g.company_id, auth.uid(), 'started');
  perform public._mc_recount(g.monthly_control_id);
end $function$
;

CREATE OR REPLACE FUNCTION public.stripe_checkout_context(p_company_id uuid, p_plan_id uuid, p_billing_period text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_uid uuid := auth.uid(); v_price text; v_cust text; v_email text;
begin
  if v_uid is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=v_uid and uc.company_id=p_company_id) then
    raise exception 'forbidden' using errcode='42501'; end if;
  if p_billing_period not in ('monthly','yearly') then raise exception 'ogiltig period' using errcode='22023'; end if;
  select case when p_billing_period='yearly' then stripe_price_yearly else stripe_price_monthly end into v_price
    from subscription_plans where id=p_plan_id and is_active;
  if v_price is null then return jsonb_build_object('configured', false); end if;
  select payment_customer_id into v_cust from company_subscriptions where company_id=p_company_id;
  select email into v_email from auth.users where id=v_uid;
  perform public.log_platform_audit('stripe_checkout_created', p_company_id::text, jsonb_build_object('plan_id',p_plan_id,'period',p_billing_period));
  return jsonb_build_object('configured', true, 'priceId', v_price, 'customerId', v_cust, 'email', v_email, 'companyId', p_company_id::text);
end $function$
;

CREATE OR REPLACE FUNCTION public.stripe_handle_event(p_event_id text, p_type text, p_customer_id text DEFAULT NULL::text, p_subscription_id text DEFAULT NULL::text, p_price_id text DEFAULT NULL::text, p_stripe_status text DEFAULT NULL::text, p_period_start timestamp with time zone DEFAULT NULL::timestamp with time zone, p_period_end timestamp with time zone DEFAULT NULL::timestamp with time zone, p_client_reference text DEFAULT NULL::text, p_invoice_id text DEFAULT NULL::text, p_next_attempt timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_company uuid; v_plan uuid; v_period text; v_status text; v_planname text; v_admins uuid[]; v_old_plan uuid;
begin
  begin insert into stripe_event_log(event_id, type) values (p_event_id, p_type);
  exception when unique_violation then return 'duplicate'; end;
  if p_client_reference is not null then
    begin v_company := p_client_reference::uuid; exception when others then v_company := null; end;
  end if;
  if v_company is null and p_customer_id is not null then
    select company_id into v_company from company_subscriptions where payment_customer_id = p_customer_id;
  end if;
  if v_company is null then return 'no_company'; end if;
  select plan_id into v_old_plan from company_subscriptions where company_id=v_company;
  if p_type = 'checkout.session.completed' then
    update company_subscriptions set payment_provider='stripe', payment_customer_id=coalesce(p_customer_id,payment_customer_id),
      payment_subscription_id=coalesce(p_subscription_id,payment_subscription_id), payment_checkout_session_id=p_event_id, updated_at=now()
      where company_id=v_company;
    perform public.log_platform_audit('stripe_checkout_completed', v_company::text, jsonb_build_object('subscription_id',p_subscription_id));
  elsif p_type in ('customer.subscription.created','customer.subscription.updated') then
    if p_price_id is not null then
      select id, 'monthly' into v_plan, v_period from subscription_plans where stripe_price_monthly = p_price_id;
      if v_plan is null then select id, 'yearly' into v_plan, v_period from subscription_plans where stripe_price_yearly = p_price_id; end if;
      if v_plan is null then
        perform public.report_system_error('stripe-webhook', 'Okänt Stripe price_id: '||p_price_id, v_company, 'error', 'unknown_price_id',
          jsonb_build_object('price_id', p_price_id, 'subscription_id', p_subscription_id));
        return 'unknown_price';
      end if;
    end if;
    v_status := public.map_stripe_status(p_stripe_status);
    update company_subscriptions set plan_id = coalesce(v_plan, plan_id), billing_period = coalesce(v_period, billing_period),
      status = coalesce(v_status, status), payment_provider='stripe',
      payment_customer_id=coalesce(p_customer_id,payment_customer_id), payment_subscription_id=coalesce(p_subscription_id,payment_subscription_id),
      payment_price_id=coalesce(p_price_id,payment_price_id),
      current_period_start=coalesce(p_period_start,current_period_start), current_period_end=coalesce(p_period_end,current_period_end),
      next_billing_at=coalesce(p_period_end,next_billing_at), updated_at=now() where company_id=v_company;
    perform public.log_platform_audit('stripe_subscription_synced', v_company::text, jsonb_build_object('status',v_status,'plan_id',v_plan));
    if v_plan is not null and v_plan is distinct from v_old_plan then
      select name into v_planname from subscription_plans where id=v_plan;
      perform public.notify_event(v_company, 'plan_changed',
        jsonb_build_object('planName',coalesce(v_planname,''),'actionUrl','https://app.bokpilot.se/installningar/abonnemang'),
        'subscription', null, '/installningar/abonnemang', null, null, 'normal');
    end if;
  elsif p_type = 'customer.subscription.deleted' then
    update company_subscriptions set status='cancelled', cancelled_at=now(), cancel_at=coalesce(cancel_at,now()), updated_at=now() where company_id=v_company;
    select name into v_planname from subscription_plans where id=v_old_plan;
    perform public.notify_event(v_company, 'subscription_cancelled',
      jsonb_build_object('planName',coalesce(v_planname,'ditt abonnemang'),'actionUrl','https://app.bokpilot.se/installningar/abonnemang'),
      'subscription', null, '/installningar/abonnemang', null, null, 'normal');
    select public.billing_admin_ids() into v_admins;
    if v_admins is not null then perform public.notify_event(v_company,'subscription_cancelled',
      jsonb_build_object('planName',coalesce(v_planname,''),'actionUrl','https://app.bokpilot.se/admin/billing'),
      'subscription', null, '/admin/billing', v_admins, null, 'normal', null, array['in_app']); end if;
    perform public.log_platform_audit('stripe_subscription_cancelled', v_company::text, '{}'::jsonb);
  elsif p_type = 'invoice.finalized' then
    update company_subscriptions set stripe_latest_invoice_id=coalesce(p_invoice_id,stripe_latest_invoice_id), updated_at=now() where company_id=v_company;
  elsif p_type = 'invoice.payment_succeeded' then
    update company_subscriptions set payment_status='paid', last_payment_at=now(),
      grace_until=null, last_payment_failed_at=null, next_payment_attempt_at=null,
      stripe_latest_invoice_id=coalesce(p_invoice_id,stripe_latest_invoice_id), next_billing_at=coalesce(p_period_end,next_billing_at),
      status=case when status in ('past_due','suspended') then 'active' else status end, updated_at=now() where company_id=v_company;
    select name into v_planname from subscription_plans where id=v_old_plan;
    perform public.notify_event(v_company, 'payment_succeeded',
      jsonb_build_object('planName',coalesce(v_planname,'din plan'),'nextBilling',to_char(coalesce(p_period_end,now()),'YYYY-MM-DD'),'actionUrl','https://app.bokpilot.se/installningar/abonnemang'),
      'subscription', null, '/installningar/abonnemang', null, null, 'normal');
    perform public.log_platform_audit('stripe_payment_succeeded', v_company::text, '{}'::jsonb);
  elsif p_type = 'invoice.payment_failed' then
    update company_subscriptions set payment_status='failed', status='past_due',
      last_payment_failed_at=now(), next_payment_attempt_at=p_next_attempt,
      stripe_latest_invoice_id=coalesce(p_invoice_id,stripe_latest_invoice_id),
      grace_until = now() + interval '7 days', updated_at=now() where company_id=v_company;
    select name into v_planname from subscription_plans where id=v_old_plan;
    perform public.notify_event(v_company, 'payment_failed',
      jsonb_build_object('planName',coalesce(v_planname,'din plan'),'actionUrl','https://app.bokpilot.se/installningar/abonnemang'),
      'subscription', null, '/installningar/abonnemang', null, null, 'high');
    perform public.notify_event(v_company, 'grace_period_started',
      jsonb_build_object('companyName',(select name from companies where id=v_company),'graceDays','7','actionUrl','https://app.bokpilot.se/installningar/abonnemang'),
      'subscription', null, '/installningar/abonnemang', null, null, 'high',
      'grace_period_started:'||v_company::text||':'||to_char(now(),'YYYY-MM-DD'), array['in_app','email']);
    select public.billing_admin_ids() into v_admins;
    if v_admins is not null then perform public.notify_event(v_company,'payment_failed',
      jsonb_build_object('planName',coalesce(v_planname,''),'actionUrl','https://app.bokpilot.se/admin/billing'),
      'subscription', null, '/admin/billing', v_admins, null, 'high', null, array['in_app','email']); end if;
    perform public.log_platform_audit('stripe_payment_failed', v_company::text, '{}'::jsonb);
  end if;
  perform public.sync_company_service_state_from_billing(v_company);
  return 'ok';
end $function$
;

CREATE OR REPLACE FUNCTION public.support_admin_ids()
 RETURNS uuid[]
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select array_agg(distinct u.id) from auth.users u where lower(u.email) in (
    select lower(email) from public.platform_admins
    union select lower(email) from public.platform_user_roles where role='support_admin')
$function$
;

CREATE OR REPLACE FUNCTION public.support_admin_queue_count()
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when public.can_view_support()
    then (select count(*)::int from public.support_tickets where status in ('new', 'waiting_for_support'))
    else 0 end;
$function$
;

CREATE OR REPLACE FUNCTION public.support_unread_count()
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(count(*), 0)::int
  from public.support_messages m
  join public.support_tickets t on t.id = m.ticket_id
  left join public.support_reads r on r.ticket_id = t.id and r.user_id = auth.uid()
  where t.created_by_user_id = auth.uid()
    and t.status <> 'closed'
    and m.is_admin = true
    and m.sender_user_id is distinct from auth.uid()
    and m.created_at > coalesce(r.last_read_at, t.created_at);
$function$
;

CREATE OR REPLACE FUNCTION public.sync_company_service_state_from_billing(p_company uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_sub record; v_cur text; v_manual boolean; v_target text; v_name text; v_admins uuid[];
begin
  select * into v_sub from public.company_subscriptions where company_id = p_company;
  if not found then return 'no_subscription'; end if;
  select service_state, coalesce(service_state_manual,false), name into v_cur, v_manual, v_name from public.companies where id = p_company;
  if v_manual then return 'manual_lock_respected'; end if;
  v_target := case
    when v_sub.status in ('trial','active') then 'active'
    when v_sub.status = 'past_due' then case when v_sub.grace_until is null or v_sub.grace_until > now() then 'active' else 'paused' end
    when v_sub.status in ('cancelled','expired','suspended') then 'paused'
    else 'active' end;
  if v_target is distinct from coalesce(v_cur,'active') then
    update public.companies set service_state = v_target,
      service_reason = case when v_target='active' then null else 'Utebliven betalning' end,
      service_changed_at = now(), service_changed_by = null, service_state_manual = false, suspended = (v_target <> 'active')
    where id = p_company;
    perform public.log_platform_audit('billing_service_state_'||v_target, p_company::text,
      jsonb_build_object('from', v_cur, 'to', v_target, 'sub_status', v_sub.status, 'source', 'stripe'));
    if v_target = 'paused' then
      select array_agg(user_id) into v_admins from public.user_companies where company_id=p_company and role='admin';
      perform public.notify_event(p_company, 'account_paused_unpaid',
        jsonb_build_object('companyName', v_name, 'actionUrl', 'https://app.bokpilot.se/support'),
        'company', p_company, 'https://app.bokpilot.se/support', v_admins, null, 'high',
        'account_paused_unpaid:'||p_company::text||':'||to_char(now(),'YYYY-MM-DD'), array['in_app','email']);
    end if;
  end if;
  return v_target;
end $function$
;

CREATE OR REPLACE FUNCTION public.update_support_ticket_priority(p_ticket_id uuid, p_priority text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if not public.can_view_support() then raise exception 'forbidden' using errcode='42501'; end if;
  if p_priority not in ('low','normal','high','urgent') then raise exception 'ogiltig prioritet' using errcode='22023'; end if;
  update support_tickets set priority=p_priority, updated_at=now() where id=p_ticket_id;
  perform public.log_platform_audit('support_priority_changed', p_ticket_id::text, jsonb_build_object('to',p_priority));
end $function$
;

CREATE OR REPLACE FUNCTION public.update_support_ticket_status(p_ticket_id uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_old text;
begin
  if not public.can_view_support() then raise exception 'forbidden' using errcode='42501'; end if;
  if p_status not in ('new','open','waiting_for_customer','waiting_for_support','resolved','closed') then
    raise exception 'ogiltig status' using errcode='22023'; end if;
  select status into v_old from support_tickets where id=p_ticket_id;
  update support_tickets set status=p_status, closed_at=case when p_status='closed' then now() else null end, updated_at=now()
    where id=p_ticket_id;
  perform public.log_platform_audit(
    case when p_status='closed' then 'support_ticket_closed'
         when v_old in ('closed','resolved') and p_status not in ('closed','resolved') then 'support_ticket_reopened'
         else 'support_status_changed' end,
    p_ticket_id::text, jsonb_build_object('from',v_old,'to',p_status));
end $function$
;

CREATE OR REPLACE FUNCTION public.upsert_vat_report(p_company_id uuid, p_year integer, p_month integer, p_status text, p_utgaende numeric, p_ingaende numeric, p_difference numeric DEFAULT 0, p_verifikation_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'not authenticated' using errcode='28000'; end if;
  if not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=p_company_id) then
    raise exception 'forbidden' using errcode='42501'; end if;
  insert into vat_reports (company_id, year, month, period_start, period_end, status, utgaende_moms, ingaende_moms, moms_att_betala, difference, verifikation_id, created_by)
  values (p_company_id, p_year, p_month, make_date(p_year,p_month,1), (make_date(p_year,p_month,1)+interval '1 month')::date-1,
    coalesce(p_status,'submitted'), coalesce(p_utgaende,0), coalesce(p_ingaende,0), coalesce(p_utgaende,0)-coalesce(p_ingaende,0), coalesce(p_difference,0), p_verifikation_id, auth.uid())
  on conflict (company_id, year, month) do update set
    status=excluded.status, utgaende_moms=excluded.utgaende_moms, ingaende_moms=excluded.ingaende_moms,
    moms_att_betala=excluded.moms_att_betala, difference=excluded.difference, verifikation_id=coalesce(excluded.verifikation_id, vat_reports.verifikation_id), updated_at=now()
  returning id into v_id;
  return v_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.user_company_ids()
 RETURNS SETOF uuid
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select uc.company_id
  from public.user_companies uc
  join public.companies c on c.id = uc.company_id
  where uc.user_id = auth.uid()
    and coalesce(c.suspended, false) = false
$function$
;

CREATE OR REPLACE FUNCTION public.validate_verifikation_links()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_company uuid; v_status text;
begin
  if current_setting('app.periodlas_bypass', true) = 'on' then return new; end if;
  if new.status in ('makulerad', 'rattad') then
    raise exception 'FEL: En ny verifikation kan inte skapas med status %.', new.status;
  end if;
  if new.status in ('motverifikation', 'rattelse') and current_setting('app.makulera_insert', true) <> 'on' then
    raise exception 'FEL: Verifikationer med status % skapas endast via systemets makulerings-/rättelsefunktion.', new.status;
  end if;
  if new.ersatter is not null then
    select company_id, status into v_company, v_status from public.verifikationer where id = new.ersatter;
    if not found then
      raise exception 'FEL: Verifikationen som ska ersättas finns inte.';
    end if;
    if v_company is distinct from new.company_id then
      raise exception 'ATKOMST_NEKAD: Ersättningen måste avse en verifikation i samma företag.';
    end if;
    if v_status <> 'rattad' then
      raise exception 'FEL: Endast en rättad verifikation kan ersättas.';
    end if;
  end if;
  if new.rattar is not null then
    select company_id into v_company from public.verifikationer where id = new.rattar;
    if not found or v_company is distinct from new.company_id or new.status <> 'rattelse' then
      raise exception 'FEL: Ogiltig rättelsekoppling.';
    end if;
  end if;
  if new.motverkar is not null then
    select company_id into v_company from public.verifikationer where id = new.motverkar;
    if not found or v_company is distinct from new.company_id or new.status <> 'motverifikation' then
      raise exception 'FEL: Ogiltig makuleringskoppling.';
    end if;
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.verifikation_andringar_appendonly()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if current_setting('app.periodlas_bypass', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception 'RÄTTELSEJOURNAL: posterna är oföränderliga (BFL 5 kap 5 §) och kan varken ändras eller raderas.';
end $function$
;