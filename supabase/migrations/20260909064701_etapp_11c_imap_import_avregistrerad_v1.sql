-- Etapp 11c: imap-import avregistrerad ur driftvakten.
--
-- IMAP-importen (GitHub Actions-jobbet imap-import.yml som läste Gmail) togs bort
-- 2026-09-07 tillsammans med Google Workspace (kundappens commit 85a56cc). Inkommande
-- underlag går enbart via Cloudflare Email Routing -> edge-funktionen inbound-email.
-- Registerraden lämnas kvar avstängd (samma hantering som folio-ocr) så historiken i
-- worker_health fortsätter att gå att tolka; komponenten försvinner ur driftstatus()
-- och ur vaktens räkning av aktiva komponenter.
update public.driftkomponenter
set aktiv = false,
    beskrivning = 'IMAP-hämtning av e-post. BORTTAGEN 2026-09-07 tillsammans med Google Workspace — inkommande underlag går enbart via Cloudflare Email Routing till inbound-email.'
where namn = 'imap-import';
