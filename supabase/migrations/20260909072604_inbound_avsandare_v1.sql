-- Migration inbound_avsandare_v1 (2026-09-09): avsändarkontroll för inmejlade underlag.
-- documents får avsandare_verifierad (true/false/null) och avsandare_kontroll (jsonb med
-- metod, orsak, domäner och SPF/DKIM/DMARC-resultat – aldrig rubriktext). Sätts av edge-
-- funktionen inbound-email utifrån Cloudflares autentiseringsresultat (alignment mellan
-- autentiserad domän och synlig From-domän, se _shared/avsandare.ts). false ⇒ underlaget
-- hamnar under Behöver granskas och AI-tolkas inte automatiskt; Inkorgen visar
-- "Avsändare ej verifierad". Klientlogik: src/pages/Inkorg.jsx (classBadge).
alter table public.documents
  add column if not exists avsandare_verifierad boolean,
  add column if not exists avsandare_kontroll jsonb;
comment on column public.documents.avsandare_verifierad is 'Inmejlat underlag: true = avsändardomänen bekräftad (DMARC, eller alignad DKIM/SPF); false = kunde inte bekräftas (Behöver granskas, ingen automatisk AI-tolkning); null = okänt eller inte e-post.';
comment on column public.documents.avsandare_kontroll is 'Avsändarkontrollens sammanfattning: metod, orsak, avsändar-/kuvertdomän, SPF/DKIM/DMARC-resultat och tidpunkt. Inga rubriker i klartext.';
