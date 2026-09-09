-- notis_inkommande_kalla_v1 (2026-09-09): notiser för inmejlade underlag.
--
-- notify_on_inbound_document() avbröt när documents.source inte var exakt 'email', men
-- Cloudflare-workern skriver 'cloudflare-email' — inga notiser gick alltså för underlag som
-- kom in med e-post (fynd från granskningen 2026-09-09, Elias ja samma dag). Nu räknas båda
-- e-postkällorna. Uppladdningar i appen (source null eller annat) notifieras som förut inte,
-- eftersom användaren själv just laddade upp dem. Innehållet i notisen är oförändrat.
create or replace function public.notify_on_inbound_document()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare et text; dt text;
begin
  -- 'email' = historisk IMAP-import, 'cloudflare-email' = Cloudflare Email Routing (produktion).
  if coalesce(NEW.source, '') not in ('email', 'cloudflare-email') then return NEW; end if;
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
end $function$;
