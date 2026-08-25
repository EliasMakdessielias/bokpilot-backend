-- Etapp 4 forts.: funktioner som saknar intern behörighetskontroll och som frontenden
-- ALDRIG anropar (verifierat mot samtliga 119 rpc-namn i produktionsbundeln) låses till
-- service_role/cron. Nästlade anrop från andra SECURITY DEFINER-funktioner påverkas inte
-- (privilegiekontrollen sker då mot ägaren postgres, inte mot API-rollen).

-- Notis-/e-postmaskineriet: kunde annars användas för att skicka godtyckliga notiser och
-- e-post i BokPilots namn till valfritt bolags användare, samt spamma plattformsadmins.
revoke execute on function public.notify_event(uuid,text,jsonb,text,uuid,text,uuid[],uuid,text,text,text[]) from authenticated;
revoke execute on function public._notify_plan_limit(uuid,text,jsonb) from authenticated;
revoke execute on function public.report_system_error(text,text,uuid) from authenticated;
revoke execute on function public.report_system_error(text,text,uuid,text,text,jsonb,timestamp with time zone) from authenticated;
revoke execute on function public.run_scheduled_notifications() from authenticated;
revoke execute on function public.apply_email_unsubscribe(uuid,text) from authenticated;

-- Driftstelemetri: falsk "frisk"-status kunde dölja verkliga avbrott.
revoke execute on function public.record_worker_health(text,boolean,text) from authenticated;

-- Byråjobbet (nattlig markering av försenade uppgifter) körs av edge-funktionen
-- byrastod-jobb med service_role. Dess medlemskoll är villkorad av att auth.uid() finns
-- och skyddar därför inte mot rollkontexter utan uid.
revoke execute on function public.byrastod_markera_forsenade() from authenticated;

-- Interna hjälpare: exponerade plangränser, spärrdatum och administratörers user-id.
revoke execute on function public._assert_company_access(uuid) from authenticated;
revoke execute on function public._support_snip(text) from authenticated;
revoke execute on function public._limit_for(uuid,text) from authenticated;
revoke execute on function public._plan_used(uuid,text) from authenticated;
revoke execute on function public._plan_limit_status(uuid,text) from authenticated;
revoke execute on function public._bokslut_recount(uuid) from authenticated;
revoke execute on function public._bokslut_attachment_guard(uuid) from authenticated;
revoke execute on function public._bokslut_check_guard(uuid) from authenticated;
revoke execute on function public._mc_recount(uuid) from authenticated;
revoke execute on function public._mc_item_guard(uuid) from authenticated;
revoke execute on function public.assert_period_open(uuid,date) from authenticated;
revoke execute on function public.first_open_booking_date(uuid) from authenticated;
revoke execute on function public.billing_admin_ids() from authenticated;
revoke execute on function public.support_admin_ids() from authenticated;
