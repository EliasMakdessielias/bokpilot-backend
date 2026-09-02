-- Följdfix etapp 14: kör KYC-bevakningen FÖRE driftvakten (03:50), annars ser vakten
-- "aldrig lyckats" första natten och "blev frisk" andra natten — två larm utan innehåll.
-- Baslinjen för de två nya komponenterna sätts till OK av samma skäl som i etapp 11:
-- vakten ska larma om förändringar, inte om nuläget.
select cron.unschedule('kyc-bevakning-natt');
select cron.schedule('kyc-bevakning-natt', '30 3 * * *', 'select public.cron_kyc_bevakning()');

update public.driftkomponenter
set beskrivning = replace(beskrivning, '04:35', '03:30')
where namn = 'kyc-bevakning-natt';

update public.driftkomponenter
set senast_rapporterad_status = 'OK'
where namn in ('kyc-bevakning-natt', 'driftkontroll-natt')
  and senast_rapporterad_status is null;
