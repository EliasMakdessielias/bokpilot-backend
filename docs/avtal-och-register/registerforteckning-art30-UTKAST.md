# UTKAST — ska granskas och fastställas av personuppgiftsansvarig innan användning

# Registerförteckning enligt artikel 30 dataskyddsförordningen (GDPR)

## AcountX Redovisningsbyrå AB, org.nr 559165-8181

| | |
|---|---|
| **Dokument** | Register över behandling av personuppgifter — i rollen som personuppgiftsansvarig (art. 30.1) och i rollen som personuppgiftsbiträde (art. 30.2) |
| **Version** | 0.1 (utkast) |
| **Datum** | 2026-08-26 |
| **Upprättad av** | [KLAMMER — namn]; utkastet är framtaget med AI-stöd ur systemdokumentation och kod och ska granskas manuellt i sin helhet |
| **Fastställd av** | [KLAMMER — Elias Makdessi, VD] |
| **Fastställandedatum** | [KLAMMER] |
| **Nästa översyn** | [KLAMMER — senast tolv månader efter fastställande, samt vid varje ny behandling, nytt underbiträde, ny tredjelandsöverföring eller väsentlig systemändring] |
| **Förvaring** | `docs/avtal-och-register/` i repot `bokpilot-sverige` (elektroniskt format, art. 30.3) samt [KLAMMER — byråns dokumentarkiv i Microsoft 365] |
| **Ansvarig för samtliga behandlingar** | [KLAMMER — Elias Makdessi, VD], om inget annat anges vid respektive behandling |

---

## 0. Läsanvisning

- Fält i **[KLAMMER]** ska fyllas i, bekräftas eller strykas av personuppgiftsansvarig innan förteckningen fastställs. Där ett förslag ges står det inom klammern.
- Förteckningen har **en tabell per behandling**. Raderna följer de uppgifter som Integritetsskyddsmyndigheten (IMY) anger att registret ska innehålla (se avsnitt 1), kompletterade med *rättslig grund* och *system/lagringsplats*. De två sista är inte krav enligt art. 30 men rekommenderas för den interna kontrollen och behövs för att kunna svara på registrerades begäranden och på tillsynsfrågor.
- Uppgifter om tabeller, buckets, funktioner och bevarandetider är hämtade ur kodbasen `bokpilot-sverige` (Supabase-projektet `vzeqvapebkbapwflozbi`, dump 2026-08-20/25) och ur BokPilot AB:s egen registerförteckning (`docs/GDPR-REGISTERFORTECKNING.md` i repot `bokpilot`, senast rättad 2026-08-17). Bevarandetider markerade *fastställd 2026-08-17* är redan beslutade och tekniskt genomförda i det nattliga gallringsjobbet.
- Spiris-bryggans behandling (AI-stödd kontering för klienter i Visma eAccounting/Fortnox) har en egen biträdesförteckning i `Projekt\spiris-bridge\REGISTERFORTECKNING.md` (2026-08-03). Den ska föras in i denna samlade förteckning; se B4 och avsnitt 3.4.

---

## 1. Rättslig grund för förteckningen och vad den ska innehålla

**Skyldigheten.** Enligt art. 30.1 ska varje personuppgiftsansvarig föra ett register över behandling som utförts under dess ansvar, och enligt art. 30.2 ska varje personuppgiftsbiträde föra ett register över alla kategorier av behandling som utförts för en personuppgiftsansvarigs räkning. Registret ska upprättas skriftligen, finnas i elektroniskt format och hållas uppdaterat (art. 30.3) samt på begäran göras tillgängligt för tillsynsmyndigheten (art. 30.4).

**Innehåll enligt IMY:s vägledning** (IMY, *Föra register över behandlingar*, senast uppdaterad av IMY 2025-09-25 — se bilaga 3):

*För personuppgiftsansvarig (art. 30.1):*
1. namn och kontaktuppgifter för den personuppgiftsansvarige, dennes företrädare samt dataskyddsombudet;
2. ändamålen med behandlingen;
3. en beskrivning av kategorierna av registrerade och kategorierna av personuppgifter;
4. de kategorier av mottagare till vilka personuppgifterna har lämnats eller ska lämnas ut;
5. i tillämpliga fall överföringar till tredjeland eller internationell organisation, med angivande av skyddsåtgärder;
6. om möjligt de förutsedda tidsfristerna för radering av de olika kategorierna av uppgifter;
7. om möjligt en allmän beskrivning av tekniska och organisatoriska säkerhetsåtgärder (art. 32.1).

*För personuppgiftsbiträde (art. 30.2):*
1. namn och kontaktuppgifter för biträdet, för varje personuppgiftsansvarig för vars räkning biträdet agerar, för deras företrädare och för dataskyddsombudet;
2. de kategorier av behandling som utförts för varje personuppgiftsansvarigs räkning;
3. i tillämpliga fall tredjelandsöverföringar med skyddsåtgärder;
4. om möjligt en allmän beskrivning av tekniska och organisatoriska säkerhetsåtgärder.

**Undantaget i art. 30.5 gäller inte.** Undantaget för organisationer med färre än 250 anställda förutsätter att behandlingen är tillfällig, inte medför risk för de registrerades rättigheter och inte omfattar känsliga uppgifter eller uppgifter om lagöverträdelser. Ingen av förutsättningarna är uppfylld: byråns behandling av bokförings-, löne- och kundkännedomsuppgifter är löpande och systematisk, lönehanteringen omfattar uppgifter om hälsa och i förekommande fall fackligt medlemskap (art. 9), kundkännedomen kan omfatta uppgifter om misstänkta lagöverträdelser (art. 10), och personnummer behandlas i stor omfattning. IMY rekommenderar dessutom att alla organisationer för register oavsett undantag. Förteckningen förs därför i sin helhet.

**Rollfördelningen** styr vilken del av förteckningen en behandling hör till:

| Behandling som avser | Byråns roll | Del |
|---|---|---|
| Byråns egna användare, klientkontakter, avtal, fakturering, marknadsföring | Personuppgiftsansvarig | A |
| Byråns egna skyldigheter enligt penningtvättslagen (kundkännedom) | Personuppgiftsansvarig | A |
| Byråns egna anställda | Personuppgiftsansvarig | A |
| Drift-, säkerhets- och spårbarhetsloggar i byråns system | Personuppgiftsansvarig (klientens bokföringsspår följer dock bokföringen, del B) | A |
| Klienternas bokföring, fakturor, bank, lön, bokslut, arkiv och AI-stöd | Personuppgiftsbiträde (klienten är ansvarig) | B |

---

## 2. Uppgifter om den personuppgiftsansvarige respektive personuppgiftsbiträdet (art. 30.1 a och 30.2 a)

| Uppgift | Innehåll |
|---|---|
| Namn | AcountX Redovisningsbyrå AB |
| Organisationsnummer | 559165-8181 |
| Postadress | [KLAMMER] |
| Besöksadress | [KLAMMER] |
| Kontaktperson (dataskyddsfrågor) | Elias Makdessi, auktoriserad redovisningskonsult och VD |
| E-post | [KLAMMER — förslag: info@acountx.se] |
| Telefon | [KLAMMER] |
| Företrädare enligt art. 27 | Ej tillämpligt — byrån är etablerad inom EU |
| Dataskyddsombud (art. 37) | [KLAMMER — bedömning: krav på dataskyddsombud föreligger sannolikt inte; kärnverksamheten innebär inte regelbunden och systematisk övervakning i stor omfattning eller behandling av känsliga uppgifter i stor omfattning. Bedömningen dokumenteras här och omprövas vid översyn. Kontaktpunkt för dataskyddsfrågor: kontaktpersonen ovan.] |
| Verksamhet | Redovisningstjänster: löpande bokföring, fakturering, lön, bokslut, årsredovisning, deklarationer, rådgivning |
| Registrering enligt penningtvättslagen | Registrerad i Bolagsverkets register mot penningtvätt (bekräftat 2026-07-10); tillsynsmyndighet Länsstyrelsen i Stockholms län |
| Antal anställda | [KLAMMER — enligt byråns AML-riskbedömning 2026-07-10: 1 (ägaren)] |
| Personuppgiftsansvariga för vilkas räkning byrån är biträde (art. 30.2 a) | Byråns klienter — förtecknas med kontaktuppgifter och biträdesavtal i **bilaga 1** |

---

## 3. Roller, system och avgränsningar

### 3.1 BokPilot och BokPilot AB — att fastställa

Byråns huvudsystem är BokPilot. Backend (databas, autentisering, fillagring, edge functions) körs i Supabase-projektet `bokpilot-sverige` i AWS-regionen eu-north-1 (Stockholm); frontend (app.bokpilot.se, byra.bokpilot.se, admin.bokpilot.se) körs på Cloudflare Pages. BokPilot AB (org.nr [KLAMMER — 559208-1219, bekräfta]) är en egen juridisk person med en egen registerförteckning, i vilken BokPilot AB anges som biträde åt sina kunder.

Denna förteckning utgår, i enlighet med uppdraget, från att byrån själv svarar för BokPilot-driften och därför förtecknar Supabase, Cloudflare, Anthropic m.fl. som sina egna biträden/underbiträden. **Relationen mellan AcountX och BokPilot AB måste fastställas innan förteckningen antas**, eftersom den avgör vem som ska ha biträdesavtal med vem:

| Alternativ | Innebörd | Följd för förteckningen |
|---|---|---|
| [KLAMMER — a] BokPilot AB tillhandahåller BokPilot till AcountX som tjänst | BokPilot AB är **personuppgiftsbiträde** åt AcountX (del A) och **underbiträde** i förhållande till klienterna (del B); Supabase, Anthropic m.fl. är BokPilot AB:s underbiträden | Biträdesavtal AcountX–BokPilot AB krävs (art. 28.3), daterat [KLAMMER]; underbiträdeskedjan redovisas via BokPilot AB:s förteckning; BokPilot AB förs in överst i avsnitt 6 |
| [KLAMMER — b] AcountX är själv avtalspart mot Supabase, Anthropic, Cloudflare m.fl. | Leverantörerna är AcountX egna biträden/underbiträden | Förteckningen gäller som den står; avtalen ska stå i AcountX namn |

### 3.2 Systemöversikt

| System/tjänst | Leverantör | Plats för behandling | Används för |
|---|---|---|---|
| BokPilot — databas, auth, Storage, edge functions | Supabase, Inc. (drift på AWS) | AWS eu-north-1, Stockholm | Alla behandlingar i del A (utom A4 helt) och del B |
| BokPilot — frontend, DNS, e-postrouting | Cloudflare, Inc. | Cloudflare Pages/Workers; globalt nätverk, transient | A1, A5, A6, B1 (inkommande underlag per e-post) |
| AI-tjänster (Claude Haiku 4.5, Claude Sonnet 5 via api.anthropic.com) | Anthropic Ireland Limited (avtalspart) / Anthropic PBC (behandling) | USA | B4, A5 (support-ai) |
| Transaktionsmejl | Resend, Inc. | Region eu-west-1 (Irland), domän verifierad 2026-07-14 | A1, A2, A5, A7 |
| Digital brevlåda | Kivra AB | Sverige | B7, B2, B5 |
| Microsoft 365 (e-post, Teams, OneDrive/SharePoint); planerat arkiv i Azure Blob Storage | Microsoft Ireland Operations Ltd | EU Data Boundary; Azure-regionen Sweden Central (Sverige) för arkivet | A2, A4, A5, A7, B1, B6, B8 |
| Betalning och abonnemang [om det tas i bruk] | Stripe Payments Europe, Ltd. | EU/USA | A2 |
| Skatteverkets API (skattekonto) via SKV-gateway [om i drift] | Skatteverket; gateway hos Fly.io, Inc. | Sverige (region arn) | B3 |
| Företagsuppslag | UC AB / Allabolag (apiverket.se) [KLAMMER — vilken källa som är aktiv] | Sverige | B2 |
| Visma eAccounting (Spiris) [KLAMMER] | Visma Spcs AB | [KLAMMER] | Byråns egen bokföring (A2) och klienter på Spiris (del B) |
| Fortnox [KLAMMER — om klienter finns på Fortnox] | Fortnox AB | Sverige | Del B |
| Lokala enheter | — | Byråns datorer; mapparna Dokument och Skrivbord är omdirigerade till företagets OneDrive | Arbetskopior; inga hemligheter utanför `C:\Users\Elias\Projekt\` |

### 3.3 Instruktioner, biträdesavtal och underbiträden

Byråns behandling för klienternas räkning styrs av uppdragsavtalet (Reko) och personuppgiftsbiträdesavtalet med respektive klient (art. 28.3), kompletterat av klientens egna val av funktioner i systemet (t.ex. lönemodul, Kivra, AI-stöd). Biträdesavtalet ska innehålla ett allmänt förhandstillstånd till de underbiträden som förtecknas i avsnitt 6 samt rutin för underrättelse om ändringar (art. 28.2). Mall: [KLAMMER — byråns egen mall; BokPilot AB:s mall `docs/GDPR-BITRADESAVTAL-MALL.md` kan tjäna som förlaga men avser BokPilot AB som part]. Status per klient anges i bilaga 1.

### 3.4 Avgränsningar

- Klienter vars bokföring förs i Visma eAccounting (Spiris) eller Fortnox omfattas av del B på samma sätt, men lagringsplatsen är då respektive leverantör i stället för Supabase. Spiris-bryggans AI-kontering (pseudonymiserad, strikt läge utan fritext) redovisas i B4 med hänvisning till bryggans egen förteckning.
- Byråns egen bokföring och fakturering förs i [KLAMMER — Spiris/BokPilot]; den redovisas i A2.
- Operatörskonsolen (admin.bokpilot.se, funktionen `konsol`) och tabellerna `konsol_*` tillhör plattformsdriften. De tas upp i A5/A6 eftersom byråns personal är plattformsadministratör; om BokPilot AB fastställs som separat biträde (3.1) flyttas de dit.

---

## 4. Del A — Behandlingar där AcountX Redovisningsbyrå AB är personuppgiftsansvarig (art. 30.1)

### A1. Användarkonton, inloggning och behörigheter

| Fält | Innehåll |
|---|---|
| **Ändamål** | Identifiera användare, styra behörighet per bolag, roll och modul, skydda systemet (inloggnings- och sessionshantering), hantera inbjudningar och lösenordsåterställning, styra notiser, dokumentera behörighet till kundkännedomsdata (spårbarhet enligt penningtvättslagen). |
| **Rättslig grund** | Avtal (art. 6.1 b) för klienternas användare; berättigat intresse (art. 6.1 f) — informationssäkerhet; rättslig förpliktelse (art. 6.1 c) — spårbar behörighet till KYC/AML-data (PTL). |
| **Kategorier av registrerade** | Byråns personal; klienternas företrädare och anställda som fått konto; inbjudna personer (`company_invites`); plattformsadministratörer (`platform_admins`, `platform_user_roles`). |
| **Kategorier av personuppgifter** | Namn, e-postadress, lösenordshash, sessions- och inloggningsuppgifter (tidpunkt, IP-adress, enhet — i Supabase Auth och plattformsloggar), roll och bolagskoppling (`user_companies.role`, `moduler`, `byra_medlemskap`, `byra_klient`, `byra_medlemmar`), notisinställningar inklusive push-endpoint och telefonnummer (`notification_preferences`, `notification_subscriptions`), samtycke till supportåtkomst (`konsol_support_samtycken`). |
| **Känsliga uppgifter / personnummer** | Nej. [KLAMMER — om inloggning med BankID införs tillkommer personnummer; för då in det här och i A3.] |
| **System och lagringsplats** | Supabase Auth och tabellerna ovan (Stockholm); frontend på Cloudflare Pages; e-post via Resend (`byra-inbjudan`, `byra-medarbetare`, `losenord-notis`). |
| **Mottagare / underbiträden** | Supabase, Inc.; Cloudflare, Inc. (transient); Resend, Inc. Inga externa mottagare i övrigt. |
| **Tredjelandsöverföring och skyddsåtgärd** | Uppgifterna lagras inom EU. Supabase, Cloudflare och Resend är amerikanska bolag; fjärråtkomst för drift och support från tredjeland kan förekomma och täcks av standardavtalsklausuler (SCC) i respektive biträdesavtal — se avsnitt 6. |
| **Gallringstid** | Konto inaktiveras när användarens uppdrag eller anställning upphör och raderas efter [KLAMMER — förslag 12 månader]. Inaktiverade byråmedlemskap och avslutade klientkopplingar bevaras som behörighetshistorik i 5 år efter affärsförbindelsens slut (PTL 5 kap. 3 §) [KLAMMER — bekräfta]. Inbjudningar som inte accepterats: [KLAMMER — förslag 30 dagar]. Supabase Auth-loggar: enligt Supabases planvillkor [KLAMMER — Pro-planen, verifiera antal dagar]. |
| **Säkerhetsåtgärder (art. 32)** | Radnivåsäkerhet (RLS) på samtliga 123 tabeller, 160 policies; rollen `anon` saknar all åtkomst (etapp 4 och 7, 2026-08-25); lösenordsåterställning med recovery-session; nyckelrotation genomförd 2026-08-25; rutin för avslut av behörigheter (senast tillämpad 2026-08-25); plattformsadministration endast via konsolen med append-only-logg. [KLAMMER — bekräfta att flerfaktorsautentisering är påslagen för samtliga byråkonton i BokPilot, Supabase-dashboarden, Cloudflare och Microsoft 365.] Se även avsnitt 7. |

### A2. Klientregister, uppdragsavtal, uppdragsstyrning och fakturering

| Fält | Innehåll |
|---|---|
| **Ändamål** | Ingå och fullgöra uppdragsavtal enligt Reko; kontakt med klientens företrädare; planera och följa upp uppdrag och lagstadgade tidsfrister (Byråstödet: `uppdrag`, `uppdragsuppgift`, `deadline_regel`); fakturera och bokföra byråns egna intäkter; hantera förfrågningar från potentiella klienter. |
| **Rättslig grund** | Avtal (art. 6.1 b) när klienten är fysisk person; berättigat intresse (art. 6.1 f) för kontaktpersoner hos klienter som är juridiska personer; rättslig förpliktelse (art. 6.1 c) — bokföringslagen för fakturor och avtal som utgör räkenskapsinformation. |
| **Kategorier av registrerade** | Klienters företrädare, ägare och kontaktpersoner; enskilda näringsidkare (klienter som är fysiska personer); potentiella klienter; revisorer och andra kontaktpersoner hos klienten. |
| **Kategorier av personuppgifter** | Namn, roll, e-post, telefon, adress, organisationsnummer (för enskild firma = personnummer), avtalsuppgifter och uppdragets omfattning, fakturerings- och betalningsuppgifter, korrespondens, anteckningar om uppdraget, uppföljnings- och tidsfristdata. |
| **Känsliga uppgifter / personnummer** | Personnummer för enskilda näringsidkare — klart motiverat med hänsyn till säker identifiering, fakturering och bokföringslagen (dataskyddslagen 3 kap. 10 §). Inga känsliga uppgifter avses behandlas. |
| **System och lagringsplats** | BokPilot (`companies`, `byra_klient`, `uppdrag`, `uppdragsuppgift`); Microsoft 365 (e-post, Teams, klientmappar i SharePoint/OneDrive); byråns egen bokföring i [KLAMMER — Spiris (Visma eAccounting) / BokPilot]; Stripe [KLAMMER — om det tas i bruk för byråns avgifter]. |
| **Mottagare / underbiträden** | Supabase, Inc.; Microsoft Ireland Operations Ltd; Visma Spcs AB [KLAMMER]; Stripe Payments Europe, Ltd. [om]; Resend, Inc. (utskick); byråns bank (betalningar); Skatteverket (byråns egen moms- och inkomstdeklaration); byråns revisor [KLAMMER — om revisor finns]. |
| **Tredjelandsöverföring och skyddsåtgärd** | Microsoft: behandling inom EU Data Boundary; begränsad överföring till USA för support, telemetri och säkerhet under SCC och Microsofts DPF-certifiering. Stripe [om]: SCC/DPF. Se avsnitt 6. |
| **Gallringstid** | Fakturor, avtal och annan räkenskapsinformation: 7 år efter utgången av det kalenderår då räkenskapsåret avslutades (BFL 7 kap. 2 §). Uppdragsdokumentation och korrespondens: under uppdraget och därefter [KLAMMER — förslag 10 år, med hänsyn till preskriptionstiden för skadeståndsanspråk och Reko]. Potentiella klienter utan avtal: [KLAMMER — förslag 12 månader efter senaste kontakt]. Byråstödets uppgifter: [KLAMMER]. |
| **Säkerhetsåtgärder (art. 32)** | Behörighetsstyrda klientmappar i Microsoft 365; omdirigerade mappar (Dokument, Skrivbord) så att arbetskopior alltid ligger i företagets OneDrive och inte lokalt utanför synk; RLS per bolag i BokPilot; e-post med personnummer eller känsligt innehåll skickas [KLAMMER — rutin: krypterad kanal/Kivra/portal i stället för öppen e-post]. Se avsnitt 7. |

### A3. Kundkännedom och övervakning enligt penningtvättslagen (KYC/AML)

| Fält | Innehåll |
|---|---|
| **Ändamål** | Fullgöra byråns skyldigheter som verksamhetsutövare enligt lagen (2017:630) om åtgärder mot penningtvätt och finansiering av terrorism: identitetskontroll, kontroll av verklig huvudman, PEP-kontroll, sanktionskontroll, riskklassning, dokumentation av affärsförbindelsens syfte och art, löpande uppföljning och transaktionsövervakning (`aml_flags`), rapportering av misstänkta transaktioner till Finanspolisen (goAML) samt bevarande av handlingar. |
| **Rättslig grund** | Rättslig förpliktelse (art. 6.1 c) — PTL 3 kap. (kundkännedom), 4 kap. (övervakning och rapportering), 5 kap. (bevarande och behandling av personuppgifter). Uppgifter om misstänkt penningtvätt är uppgifter om lagöverträdelser (art. 10) och behandlas med stöd av PTL:s särskilda bestämmelser om personuppgiftsbehandling [KLAMMER — kontrollera lagrumshänvisningen till PTL 5 kap. 5–7 §§ i gällande lydelse]. |
| **Kategorier av registrerade** | Klienters företrädare, firmatecknare, verkliga huvudmän och ägare; personer i politiskt utsatt ställning samt deras familjemedlemmar och kända medarbetare; enskilda näringsidkare; personer som förekommer i flaggade transaktioner eller misstankerapporter. |
| **Kategorier av personuppgifter** | Identitetsuppgifter inklusive personnummer; kopia av identitetshandling [KLAMMER — var förvaras kopior: behörighetsbegränsad mapp i BokPilots arkiv eller M365]; resultat av elektronisk identitetskontroll [KLAMMER — BankID-/ID-tjänst och leverantör]; uppgifter om ägande och kontroll; PEP-status; resultat av sanktionskontroll; riskklass; syfte och art; anteckningar och beslut (`kyc_assessments`); flaggade transaktioner med beskrivning och beslutsanteckning (`aml_flags`); misstankerapporter till Finanspolisen [KLAMMER — var förvaras kopior]. |
| **Känsliga uppgifter / personnummer** | Personnummer — klart motiverat, krävs enligt PTL (dataskyddslagen 3 kap. 10 §). Uppgifter om lagöverträdelser (art. 10) vid sanktionsträff, flaggning eller rapport. Fritextfält får inte användas för känsliga uppgifter enligt art. 9 [KLAMMER — rutin]. |
| **System och lagringsplats** | BokPilots KYC/AML-modul (`kyc_assessments`, `aml_flags`, `aml_installningar`) i Supabase, Stockholm; externa kontrollkällor: Bolagsverkets register över verkliga huvudmän, EU:s och FN:s sanktionslistor, [KLAMMER — PEP-/sanktionstjänst och leverantör]; goAML (Finanspolisen); byråns allmänna riskbedömning (`AML-RISKBEDOMNING-BYRA.md`, utkast 2026-07-10). |
| **Mottagare / underbiträden** | Supabase, Inc.; [KLAMMER — leverantör av PEP-/sanktions-/ID-kontroll]. Självständiga mottagare: Finanspolisen (rapport), Länsstyrelsen i Stockholms län (på begäran vid tillsyn), Bolagsverket. **Aldrig** till AI-tjänster: tabellerna är läsbara enbart för byråmedlemmar via RLS och MCP-servern saknar verktyg för dem. |
| **Tredjelandsöverföring och skyddsåtgärd** | Nej. |
| **Gallringstid** | Handlingar och uppgifter om kundkännedom bevaras 5 år efter det att affärsförbindelsen upphörde eller transaktionen utfördes (PTL 5 kap. 3 §); 10 år när det behövs enligt PTL 5 kap. 4 § (t.ex. efter misstankerapport eller begäran från Finanspolisen). Bedömningar förnyas som nya rader — historiken bevaras. **Observera:** BFL-spärren vid bolagsavveckling i BokPilot skyddar inte KYC/AML-posterna; `avveckla_bolag()` loggar omfattningen och raderar dem. [KLAMMER — rutin: exportera och arkivera KYC-materialet på annat sätt innan ett klientbolag avvecklas i systemet.] |
| **Säkerhetsåtgärder (art. 32)** | Åtkomst begränsad till byråmedlemmar (RLS via `byra_medlemmar`/`byra_medlemskap`) — vilket samtidigt genomdriver meddelandeförbudet (PTL 4 kap. 9 §) och åtkomstbegränsningen för uppgifter om lagöverträdelser; klientens egna användare ser aldrig KYC/AML-data; deterministiska kontroller utan AI-anrop; flaggor uppdateras aldrig destruktivt; beslut om rapportering fattas alltid av en människa; behörighet till modulen förutsätter dokumenterad utbildning (PTL 2 kap. 14 §, utbildningslogg i riskbedömningen). Se avsnitt 7. |

### A4. Egna anställda, uppdragstagare och rekrytering

| Fält | Innehåll |
|---|---|
| **Ändamål** | Administrera anställnings- och uppdragsförhållanden: avtal, lön, skatteavdrag och arbetsgivardeklaration på individnivå, tidsredovisning, frånvaro och semester, pension och försäkring, arbetsmiljö och rehabilitering, kompetens och lagstadgad utbildning (PTL 2 kap. 14 §), behörigheter, rekrytering och avslut. |
| **Rättslig grund** | Avtal (art. 6.1 b); rättslig förpliktelse (art. 6.1 c) — skatteförfarandelagen, bokföringslagen, semesterlagen, arbetsmiljölagen, penningtvättslagen; berättigat intresse (art. 6.1 f) — rekrytering och intern administration; art. 9.2 b (skyldigheter inom arbetsrätten) för hälsa och fackligt medlemskap; art. 10 [KLAMMER — endast om utdrag ur belastningsregistret inhämtas; kräver stöd i dataskyddslagen 3 kap.]. |
| **Kategorier av registrerade** | Anställda, tidigare anställda, arbetssökande, uppdragstagare och konsulter, anhöriga (nödkontakt). [KLAMMER — antal anställda i dag: 1 (ägaren) enligt riskbedömningen; förteckningen omfattar ändå kategorin för framtida anställningar.] |
| **Kategorier av personuppgifter** | Namn, personnummer, adress och kontaktuppgifter, bankkonto, lön och förmåner, skattetabell och jämkning, anställningsvillkor, arbetstid, frånvaro (sjukdom, vård av barn, föräldraledighet — omfattning), semester, pensions- och försäkringsuppgifter, utbildnings- och utvecklingsdokumentation, behörigheter, anhöriguppgifter, rekryteringsunderlag (ansökan, CV, referenser). |
| **Känsliga uppgifter / personnummer** | Hälsa: sjukfrånvaro, läkarintyg, rehabiliteringsdokumentation. Fackligt medlemskap: om löneavdrag för fackavgift förekommer [KLAMMER]. Personnummer: krävs för arbetsgivardeklaration (klart motiverat, dataskyddslagen 3 kap. 10 §). |
| **System och lagringsplats** | [KLAMMER — lönesystem: BokPilots lönemodul / Spiris]; personalakt i behörighetsbegränsad mapp i Microsoft 365; Skatteverket (arbetsgivardeklaration); Försäkringskassan; [KLAMMER — pension/försäkring, t.ex. Fora/Collectum/försäkringsbolag]; [KLAMMER — företagshälsovård]; byråns bank. |
| **Mottagare / underbiträden** | Skatteverket, Försäkringskassan, pensions- och försäkringsbolag, bank (självständigt ansvariga); Supabase, Inc. (om BokPilots lönemodul används); Microsoft Ireland Operations Ltd; Kivra AB (om lönebesked skickas via Kivra); [KLAMMER — övriga]. |
| **Tredjelandsöverföring och skyddsåtgärd** | Nej i vila. Microsoft: se A2 och avsnitt 6. |
| **Gallringstid** | Löneunderlag, lönespecifikationer och arbetsgivardeklarationer: 7 år (BFL 7 kap. 2 §). Anställningsavtal och personalakt: under anställningen och därefter [KLAMMER — förslag 10 år, preskriptionslagen 2 §]. Läkarintyg och rehabiliteringsdokumentation: så länge ärendet pågår och därefter [KLAMMER — gallras när de inte längre behövs, senast X år efter avslut]. Rekryteringsunderlag för personer som inte anställts: [KLAMMER — förslag 2 år med hänsyn till diskrimineringslagens preskriptionstid]. Utbildningslogg enligt PTL: [KLAMMER — förslag 5 år]. Anhöriguppgifter: raderas vid anställningens slut. |
| **Säkerhetsåtgärder (art. 32)** | Personalakt i mapp med behörighet enbart för VD/lönehanterare; hälsouppgifter förvaras separat från övrig personalinformation; personnummer skickas inte i öppen e-post [KLAMMER — rutin]; flerfaktorsautentisering i Microsoft 365 [KLAMMER — verifiera]; lönemodulens RLS och BFL-skydd (se B5). Se avsnitt 7. |

### A5. Supportärenden, felanmälningar och kommunikation med användare

| Fält | Innehåll |
|---|---|
| **Ändamål** | Ta emot och hantera supportärenden och felanmälningar från klienternas användare och byråns personal; felsöka; AI-stödd support (`support-ai`); tidsbegränsad, samtyckesbaserad åtkomst till klientens bolag för felsökning (`konsol_support_samtycken`); återkoppling och förbättring (`help_feedback`); felrapporter från klienten (`report-error`). |
| **Rättslig grund** | Avtal (art. 6.1 b); berättigat intresse (art. 6.1 f) — felsökning, produktkvalitet och säkerhet; samtycke (art. 6.1 a) för operatörsåtkomst till klientens bolag — dokumenterat med giltighetstid och återkallelse. |
| **Kategorier av registrerade** | Klienternas användare; byråns personal; tredje man som förekommer i bifogade skärmbilder eller filer. |
| **Kategorier av personuppgifter** | Namn, e-post, ärendets innehåll och kategori, bilagor (bucket `support`, max 10 MB), interna anteckningar (`support_internal_notes`), AI-konversationer (`support_ai_events`), tekniska uppgifter (felmeddelanden, webbläsare, identifierare), samtyckets giltighetstid. |
| **Känsliga uppgifter / personnummer** | Kan oavsiktligt förekomma i fritext och bilagor. [KLAMMER — rutin: personnummer och känsliga uppgifter ska inte lämnas i supportärenden; bilagor granskas och rensas vid behov.] |
| **System och lagringsplats** | BokPilot (`support_tickets`, `support_messages`, `support_attachments`, `support_internal_notes`, `support_reads`, `support_ai_events`, `help_feedback`, `konsol_support_samtycken`) i Supabase, Stockholm; Anthropic (support-ai, Claude Haiku 4.5); Resend (notiser); Microsoft 365 (e-post, Teams); telefon. |
| **Mottagare / underbiträden** | Supabase, Inc.; Anthropic Ireland Limited/Anthropic PBC — endast användarens fråga och handbokskontext (`kb`), ingen bokföringsdata; Resend, Inc.; Microsoft Ireland Operations Ltd. |
| **Tredjelandsöverföring och skyddsåtgärd** | Ja — Anthropic (USA): SCC (modul 2/3) i Anthropics DPA, DPF-certifiering [KLAMMER — verifiera], Zero Data Retention [KLAMMER — verifiera påslaget], överföringskonsekvensbedömning (TIA) [KLAMMER — dokumentera]. Se B4 och avsnitt 6. |
| **Gallringstid** | `support_ai_events`: 24 månader (fastställd 2026-08-17, automatisk gallring). Ärenden, meddelanden och bilagor: [KLAMMER — förslag 24 månader efter att ärendet stängts]. Samtycken till supportåtkomst: giltighetstiden och därefter [KLAMMER — förslag 24 månader som bevis]. `help_feedback`: [KLAMMER]. |
| **Säkerhetsåtgärder (art. 32)** | Support-AI:n svarar enbart inom supportområdet, ändrar aldrig data och exponerar inga hemligheter; privat bucket; rollstyrd åtkomst (supportadministratör); operatörsåtgärder loggas append-only i `konsol_audit_logg`; åtkomst till klientbolag kräver aktivt samtycke med giltighetstid. Se avsnitt 7. |

### A6. Drift-, säkerhets- och spårbarhetsloggar

| Fält | Innehåll |
|---|---|
| **Ändamål** | Informationssäkerhet (art. 32), felsökning och driftövervakning, incidenthantering (art. 33–34), spårbarhet av ändringar i bokföring och behörigheter (bokföringslagens krav på behandlingshistorik och verifieringskedja), spårbar behörighet till KYC/AML-data (PTL), plattformsadministration, kvotstyrning av AI-anrop. |
| **Rättslig grund** | Berättigat intresse (art. 6.1 f) — säkerhet och drift; rättslig förpliktelse (art. 6.1 c) — BFL 5 kap. och 7 kap. (behandlingshistorik som räkenskapsinformation), PTL. |
| **Kategorier av registrerade** | Användare hos byrån och klienterna; plattformsadministratörer; personer som förekommer i loggade data (t.ex. motparter och anställda i `audit_log.old_data/new_data`, avsändare i `inbound_email_log`). |
| **Kategorier av personuppgifter** | Användar-id och e-post, tidpunkt, åtgärd, käll-IP och enhet (Supabase- och Cloudflare-loggar), ändrat innehåll (före/efter), felmeddelanden (kan innehålla fritext), metadata om AI-anrop, nedladdningar, e-postavsändare och ämne. |
| **Känsliga uppgifter / personnummer** | Kan förekomma i ändringsinnehåll och fritext. Personnummer maskeras i `kivra_utskick`; övriga flöden [KLAMMER — genomgång att personnummer inte loggas i klartext, öppen punkt sedan 2026-07-26]. |
| **System och lagringsplats** | Supabase (Stockholm) — tabeller enligt nedan samt plattformsloggar (API, Auth, Edge); Cloudflare (trafik- och Worker-loggar, transienta); Resend (leveransloggar); Microsoft 365 (granskningsloggar). |
| **Mottagare / underbiträden** | Supabase, Inc.; Cloudflare, Inc.; Resend, Inc.; Microsoft Ireland Operations Ltd. Vid personuppgiftsincident: IMY (art. 33) och berörda klienter i egenskap av personuppgiftsansvariga (art. 33.2). |
| **Tredjelandsöverföring och skyddsåtgärd** | Loggar lagras i EU; leverantörernas fjärråtkomst täcks av SCC — se avsnitt 6. |
| **Gallringstid** | Se loggtabellen nedan. |
| **Säkerhetsåtgärder (art. 32)** | Append-only-triggrar och förfalskningsskydd i `log_accounting_audit` (etapp 4, 2026-08-25); `anon` saknar åtkomst; elva interna tabeller (bl.a. `system_error_log`, `konsol_audit_logg`, `stripe_event_log`, `interna_nycklar`) är åtkomliga enbart för `service_role`; driftövervakning (etapp 11) med larm vid förändring mot baslinje 2026-08-26; hjärtslag i `worker_health`; nattlig kontroll av lagringsintegritet 03:25. [KLAMMER — bucketen `shimo-audio` är publik: kontrollera innehåll och om den ska vara publik.] Se avsnitt 7. |

Loggar och bevarandetider:

| Logg | Innehåll | Bevarandetid |
|---|---|---|
| `audit_log`, `verifikation_andringar` (rättelsejournal), `ai_bokforing_logg`, `download_audit_log`, `bokslut_audit_log`, `robo_bp_audit_log` | Ändringshistorik i bokföring och behörigheter, AI-förslag kopplade till verifikation, nedladdning av räkenskapsinformation | Bevaras med den bokföring de hör till — 7 år (BFL); gallras aldrig automatiskt (fastställt 2026-08-17) |
| `platform_audit_log` | Plattformsadministratörers åtgärder, bl.a. bolagsavveckling (överlever kaskadradering) | [KLAMMER — förslag: bevaras 10 år] |
| `system_error_log` | Driftfel, komponent, allvarlighetsgrad, metadata, ev. bolags-id | [KLAMMER — förslag 12 månader; ingår i dag inte i gallringsjobbet] |
| `konsol_audit_logg`, `mcp_audit_log`, `ai_call_log`, `ai_usage_log`, `stripe_event_log`, `notification_queue`, `notification_deliveries`, `notification_provider_logs`, `notification_events` | Operatörsåtgärder, MCP-anrop med parametrar, AI-kvoter, betalhändelser, notisutskick (e-post, telefon) | [KLAMMER — fastställ; ingår i dag inte i gallringsjobbet. Förslag: 24 månader, `stripe_event_log` 7 år om händelserna utgör bokföringsunderlag] |
| `inbound_email_log` | Avsändare, mottagaradress, ämne för inkommande underlag | 12 månader (fastställd 2026-08-17, automatisk) |
| `assistent_logg`, `robo_bp_messages`, `support_ai_events`, `kivra_utskick` | AI-konversationer respektive leveransbevis Kivra (personnummer maskerat) | 24 månader (fastställd 2026-08-17, automatisk) |
| `worker_health`, `driftkomponenter` | Hjärtslag och komponentstatus — inga personuppgifter | Löpande överskrivning |
| Supabase plattformsloggar (API, Auth, Edge Functions) | IP, user-agent, användar-id, tidpunkt | Enligt Supabases planvillkor [KLAMMER — verifiera antal dagar på Pro-planen] |
| Cloudflare (Pages, Workers, Email Routing) | Trafikmetadata, transient | [KLAMMER — enligt Cloudflares villkor] |
| Resend | Mottagaradress, leveransstatus, ämne | [KLAMMER — enligt Resends villkor] |
| Microsoft 365 granskningsloggar | Inloggning, filåtkomst | Enligt Microsofts standard [KLAMMER — verifiera] |

### A7. Marknadsföring och extern kommunikation [KLAMMER — om tillämpligt]

| Fält | Innehåll |
|---|---|
| **Ändamål** | Marknadsföra byråns tjänster (webbplats, nyhetsbrev, sociala medier, direktkontakt); informera befintliga klienter om lagändringar, tidsfrister och nyheter; bjuda in till evenemang. |
| **Rättslig grund** | Berättigat intresse (art. 6.1 f) för befintliga klienter och kontaktpersoner hos företag, med rätt att när som helst invända (art. 21.2); samtycke (art. 6.1 a) för nyhetsbrev till övriga; marknadsföringslagen 19 § för e-postmarknadsföring till fysiska personer. |
| **Kategorier av registrerade** | Klienters kontaktpersoner; prenumeranter; potentiella klienter; webbplatsbesökare. |
| **Kategorier av personuppgifter** | Namn, e-post, företag, roll, prenumerationsstatus och avregistrering, [KLAMMER — öppnings- och klickstatistik], [KLAMMER — cookies och webbanalys på acountx.se]. |
| **Känsliga uppgifter / personnummer** | Nej. |
| **System och lagringsplats** | [KLAMMER — nyhetsbrevsverktyg, t.ex. Resend Broadcasts]; [KLAMMER — webbplatsens hosting och analysverktyg]; [KLAMMER — sociala medier: LinkedIn/Meta]; Microsoft 365 (e-post). |
| **Mottagare / underbiträden** | Resend, Inc. [om]; Cloudflare, Inc. [om webbplatsen ligger där]; Microsoft Ireland Operations Ltd; sociala medieplattformar (självständigt eller gemensamt ansvariga för sidstatistik) [KLAMMER]. |
| **Tredjelandsöverföring och skyddsåtgärd** | Resend/Cloudflare: SCC (se avsnitt 6). Sociala medieplattformar: DPF/SCC enligt respektive plattforms villkor [KLAMMER]. |
| **Gallringstid** | Till dess mottagaren avregistrerar sig eller invänder; potentiella klienter utan kontakt: [KLAMMER — förslag 12 månader]; avregistreringslista bevaras för att respektera invändningen; statistik: [KLAMMER]. |
| **Säkerhetsåtgärder (art. 32)** | Avregistreringslänk i varje utskick; spärrlista; åtkomst begränsad till behörig personal; inga personnummer i marknadsföringssystem. |

---

## 5. Del B — Behandlingar där AcountX Redovisningsbyrå AB är personuppgiftsbiträde för klienternas räkning (art. 30.2)

För samtliga behandlingar i del B gäller: **personuppgiftsansvarig** är respektive klient (uppdragsgivare) enligt bilaga 1; **instruktionerna** utgörs av uppdragsavtalet, personuppgiftsbiträdesavtalet och klientens egna val av funktioner i systemet; **kontaktuppgifter** för klienterna och deras eventuella företrädare och dataskyddsombud förs i bilaga 1 (art. 30.2 a). Bevarandetiderna följer klientens rättsliga skyldigheter; byrån raderar inte räkenskapsinformation under bevarandetiden (art. 17.3 b) och lämnar vid uppdragets slut tillbaka uppgifterna genom export (SIE, PDF, CSV) innan övrig data raderas.

### B1. Löpande bokföring och verifikationsunderlag

| Fält | Innehåll |
|---|---|
| **Personuppgiftsansvarig** | Klienten (bilaga 1). |
| **Kategorier av behandling (art. 30.2 b)** | Insamling (uppladdning, e-postmottagning på `{arkivnummer}underlag@in.bokpilot.se`, import från Kivra, SIE-import), lagring, strukturering och klassificering, registrering av verifikationer, bearbetning och avstämning, momsrapportering, rapportering, utlämnande till myndigheter och revisor på klientens uppdrag, arkivering. |
| **Klientens ändamål** | Lagstadgad bokföring (BFL), momsredovisning, ekonomisk uppföljning. |
| **Kategorier av registrerade** | Klientens kunder, leverantörer och andra motparter som är fysiska personer eller enskilda näringsidkare; kontaktpersoner hos motparter; klientens anställda i den mån de förekommer i verifikationer (utlägg, löneutbetalningar); klientens företrädare; tredje man som förekommer på underlag. |
| **Kategorier av personuppgifter** | Namn, adress, organisationsnummer (för enskild firma = personnummer), bankgiro/kontonummer, belopp och betalningsinformation, fakturauppgifter, fritext i bankhändelser, underlagens fullständiga innehåll (kvitton, fakturor, avtal), avsändaradress för inkommande underlag. |
| **Känsliga uppgifter / personnummer** | Personnummer för enskilda näringsidkare. Känsliga uppgifter kan förekomma i underlag (t.ex. kvitton för sjukvård eller friskvård, fackavgifter) och behandlas då enbart som del av räkenskapsinformationen, utan separat registrering. |
| **System och lagringsplats** | BokPilot: `verifikationer`, `verifikation_rows`, `verifikation_andringar`, `documents`, `bank_transactions`, `vat_reports`, `sie_imports`, `fiscal_years`; bucket `underlag` (privat, 50 MB per fil) — Supabase, Stockholm. Inkommande e-post via Cloudflare Email Routing och Email Worker (HMAC-signerad till `inbound-email`). Klientmappar i Microsoft 365 [KLAMMER]. För klienter i Spiris/Fortnox: respektive system [KLAMMER]. |
| **Mottagare / underbiträden** | Supabase, Inc.; Cloudflare, Inc. (inkommande e-post, transient); Anthropic (se B4); Kivra AB (se B7); Visma Spcs AB / Fortnox AB [KLAMMER]. Självständiga mottagare på klientens uppdrag: Skatteverket (momsdeklaration), klientens revisor. |
| **Tredjelandsöverföring och skyddsåtgärd** | Räkenskapsinformationen förvaras i Sverige (BFL 7 kap.; verifierat 2026-07-10 — ingen anmälan till Skatteverket behövs). Cloudflare: transient behandling i globalt nätverk under SCC/DPF. Anthropic: se B4. |
| **Gallringstid** | 7 år efter utgången av det kalenderår då räkenskapsåret avslutades (BFL 7 kap. 2 §); raderingsskydd på databasnivå. Efter uppdragets slut: fortsatt lagring tills klienten skriftligen bekräftat att materialet arkiverats på annat håll, därefter radering; uppgifter som inte är räkenskapsinformation raderas efter exportfrist om [KLAMMER — förslag 90 dagar]. `inbound_email_log`: 12 månader. |
| **Säkerhetsåtgärder (art. 32)** | RLS per bolag; oföränderlig bokföring (BFL-skydd v3–v6: bokförda verifikationer kan inte ändras eller raderas, rättelse sker genom omvänd verifikation, rättelsejournal append-only); periodlås; audit-triggrar; privata buckets med storleks- och MIME-begränsning; slumpmässigt sjusiffrigt arkivnummer som mottagaradress; nattlig avstämning databas–Storage; dagliga backuper (Storage ingår inte — se B8). Se avsnitt 7. |

### B2. Leverantörs- och kundfakturor (reskontra)

| Fält | Innehåll |
|---|---|
| **Personuppgiftsansvarig** | Klienten (bilaga 1). |
| **Kategorier av behandling (art. 30.2 b)** | Registrering av kund- och leverantörsregister, upprättande och utskick av kundfakturor (e-post, Kivra), registrering och attest av leverantörsfakturor, betalningsbevakning, påminnelser, uppslag av företagsuppgifter, lagring. |
| **Klientens ändamål** | Fakturering, inköp, betalning och lagstadgad bokföring. |
| **Kategorier av registrerade** | Klientens kunder (privatpersoner vid konsumentförsäljning, enskilda näringsidkare, kontaktpersoner hos företagskunder); leverantörer (enskilda näringsidkare, kontaktpersoner); företrädare för motparter (från företagsuppslag). |
| **Kategorier av personuppgifter** | Namn, adress, e-post, telefon, organisationsnummer/personnummer, kundnummer, referenser (personnamn i "vår/er referens"), betalningsvillkor, fakturarader (kan avslöja köp och tjänster), bankgiro/IBAN för leverantörer, anteckningar; från uppslag: företagsuppgifter inklusive styrelse och firmatecknare. |
| **Känsliga uppgifter / personnummer** | Personnummer för enskilda näringsidkare och för adressering via Kivra. Fakturarader kan i undantagsfall avslöja känsliga uppgifter (t.ex. vårdtjänster); klienten ansvarar för innehållet. |
| **System och lagringsplats** | BokPilot: `customers`, `suppliers`, `invoices`, `invoice_rows`, `supplier_invoices`, `supplier_accounting_rules`, `inkopsordrar`, `products`, `company_lookup_cache` — Supabase, Stockholm; `hamta-foretag` mot UC Affärsinformation/Allabolag [KLAMMER — aktiv källa]; Kivra (utskick). [KLAMMER — hur kundfakturor skickas per e-post: via Resend eller klientens egen e-post.] |
| **Mottagare / underbiträden** | Supabase, Inc.; Kivra AB; Anthropic (fakturauppgifter ingår i AI-flödena, se B4); UC AB/Allabolag (självständigt ansvariga — endast organisationsnummer skickas); bank; fakturamottagare. |
| **Tredjelandsöverföring och skyddsåtgärd** | Anthropic — se B4. I övrigt nej. |
| **Gallringstid** | Fakturor: räkenskapsinformation, 7 år (BFL 7 kap. 2 §). Kund- och leverantörsregister: så länge relationen består och därefter [KLAMMER — förslag: inaktiveras (`is_active=false`) och raderas när ingen faktura längre omfattas av bevarandetiden]. `company_lookup_cache`: [KLAMMER]. |
| **Säkerhetsåtgärder (art. 32)** | RLS; bokförda fakturor kan inte raderas (`forbjud_bokford_faktura_radering`); frekvensbegränsning av uppslag (`company_lookup_rate`); leverantörshemligheter för uppslag enbart server-side; Kivra-utskick loggas med maskerat personnummer. Se avsnitt 7. |

### B3. Bankavstämning och skattekonto

| Fält | Innehåll |
|---|---|
| **Personuppgiftsansvarig** | Klienten (bilaga 1). |
| **Kategorier av behandling (art. 30.2 b)** | Insamling av bankhändelser (fil-/SIE-import, manuell registrering; skattekontots transaktioner via Skatteverkets API), matchning mot verifikationer och fakturor, regelstyrd kontering (Swish- och skattekontoregler), lagring. |
| **Klientens ändamål** | Avstämning av bank- och skattekonto, lagstadgad bokföring. |
| **Kategorier av registrerade** | Motparter i bankhändelser (kunder, leverantörer, privatpersoner som betalar via Swish), klientens anställda (löneutbetalningar), klientens företrädare (egna uttag och insättningar). |
| **Kategorier av personuppgifter** | Transaktionstext (namn, meddelanden, telefonnummer vid Swish), belopp, datum, klientens kontonummer/bankgiro/IBAN (`bank_accounts`), skattekontots saldo och transaktioner. |
| **Känsliga uppgifter / personnummer** | Personnummer kan förekomma i transaktionstext. Kontonummer. |
| **System och lagringsplats** | BokPilot: `bank_accounts`, `bank_transactions`, `account_import_batches`, `swish_regler`, `skattekonto_regler` — Supabase, Stockholm. Skatteverkets API via SKV-gateway (mTLS med organisationslegitimation) hos Fly.io, region arn (Stockholm) [KLAMMER — driftläge: mock/enkel/test/prod]. Ingen direkt bankkoppling i dag [KLAMMER — bekräfta]. |
| **Mottagare / underbiträden** | Supabase, Inc.; Fly.io, Inc. (endast transit) [om i drift]; Anthropic — bankhändelsernas fritext ingår i AI-assistentflödena (se B4). Självständig part: Skatteverket (klienten måste registrera byrån som ombud med läsbehörighet för skattekontot). |
| **Tredjelandsöverföring och skyddsåtgärd** | Fly.io är ett amerikanskt bolag; behandlingen är pinnad till Stockholm och inget lagras i vila [KLAMMER — bekräfta region-pinning och arkivera Fly.io:s DPA med SCC]. Anthropic — se B4. |
| **Gallringstid** | Bankhändelser som ingår i bokföringen: 7 år (BFL). Importrader som inte matchats eller bokförts: [KLAMMER]. |
| **Säkerhetsåtgärder (art. 32)** | RLS; låsbara bankkonton; unikhetskrav; dubblettskydd vid import; mTLS och hemligheter enbart i edge-secrets. Se avsnitt 7. |

### B4. AI-tolkning av underlag och AI-assistans (Anthropic)

| Fält | Innehåll |
|---|---|
| **Personuppgiftsansvarig** | Klienten (bilaga 1). Anthropic är byråns underbiträde; klientens tillstånd enligt art. 28.2 ska framgå av biträdesavtalet. |
| **Kategorier av behandling (art. 30.2 b)** | Överföring till underbiträde, automatiserad tolkning och extraktion av underlag (OCR och strukturering), konteringsförslag, granskning och månadskontroll, bokslutsstöd och årsredovisningstext, frågesvar (assistent, robo-bp), Claude-connector via MCP [om aktiverad för klienten], loggning. |
| **Delflöden** | **B4a — tolkning av underlag** (`tolka-underlag`, `inbound-email`, Claude Haiku 4.5): underlagets bild/PDF, kontoplan och eventuellt OCR-textlager skickas — aldrig KYC-data, historik eller kunddata utöver själva underlaget. **B4b — assistent och chattar** (`assistent-ai`, `bokforingsassistent`, `bokfor-ai`, `granska-ai`, `manadskontroll-ai`, `bokslut-ai`, `annual-report-ai`, `ekonomichef-ai`, `robo-bp-chat`; Haiku 4.5/Sonnet 5): bankhändelsernas fritext (innehåller regelmässigt motpartsnamn och uppgift om löneutbetalningar), verifikationer och huvudbok, kund- och leverantörsfakturor med motpartsuppgifter, underlagstolkningar samt användarens frågor — inte personnummer ur lönemodulen, inte KYC-material. **B4c — Spiris-bryggan** (klienter i Visma eAccounting/Fortnox): pseudonymiserade leverantörsfakturarader utan fritext; egen förteckning 2026-08-03. **B4d — MCP-connector** (`mcp-server`): läs- och skrivverktyg via användarens egen Claude-klient med tvåstegsbekräftelse; aktiverad per bolag (`company_ai_features.claude_connector`), i dag endast för testbolag. |
| **Klientens ändamål** | Effektiv och korrekt bokföring; AI-förslag är alltid underlag för mänskligt beslut. Inget automatiserat beslutsfattande med rättslig verkan (art. 22). AI-genererade förslag märks tydligt (AI-förordningen art. 50). |
| **Kategorier av registrerade** | Motparter (fysiska personer, enskilda näringsidkare, kontaktpersoner), klientens anställda i den mån de framgår av bankhändelsetext, klientens företrädare, tredje man på underlag, användaren (egna frågor). |
| **Kategorier av personuppgifter** | Namn, adress, organisations-/personnummer på underlag, belopp, datum, fakturauppgifter, bankhändelsetext, konteringar, användarens frågor och svar. |
| **Känsliga uppgifter / personnummer** | Personnummer kan förekomma på underlag (t.ex. enskild firma) och skickas då som del av bilden. Lönemodulens personnummer och KYC-data skickas aldrig (tekniskt genomdrivet via RLS och avsaknad av MCP-verktyg). |
| **System och lagringsplats** | Edge functions i Supabase (Stockholm) anropar `api.anthropic.com/v1/messages` (rå HTTP, strukturerade svar). Loggar: `ai_bokforing_logg`, `assistent_logg`, `robo_bp_messages`, `support_ai_events`, `ai_call_log`, `ai_usage_log`, `mcp_audit_log`, `bokslut_ai_suggestions`, `annual_report_draft_sections`. |
| **Mottagare / underbiträden** | Anthropic Ireland Limited (avtalspart inom EU) med behandling hos Anthropic PBC i USA; Supabase, Inc. (loggar). |
| **Tredjelandsöverföring och skyddsåtgärd** | **Ja — USA.** Det direkta API:t erbjuder ingen EU-inferens (EU-residens finns endast via Bedrock/Vertex, som inte används). Skyddsåtgärder: standardavtalsklausuler (kommissionens beslut 2021/914, modul 2 och 3) införlivade i Anthropics DPA; vidareöverföringen från Anthropic Ireland Limited till Anthropic PBC ska dokumenteras [KLAMMER]; Anthropic uppges vara certifierat under EU–US Data Privacy Framework [KLAMMER — verifiera i DPF-listan och notera datum]; överföringskonsekvensbedömning (TIA) enligt EDPB:s rekommendation 01/2020 [KLAMMER — dokumentera]. Kompletterande åtgärder: dataminimering i kod (policy per flöde ovan), pseudonymisering i Spiris-bryggan, Zero Data Retention [KLAMMER — beslut 2026-07-05, verifiera att det är påslaget för organisationens API-nyckel], API-data används inte för träning (kommersiella villkor). Lagring hos Anthropic: 30 dagar som standard, 0 dagar med ZDR, **upp till 2 år vid flaggning för missbruk — gäller även med ZDR** och ska stå i klientens biträdesavtal. [KLAMMER — MCP-connector: säkerställ att Claude-klienten används under kommersiella villkor (API/Team/Enterprise) och inte konsumentvillkor.] |
| **Gallringstid** | `assistent_logg`, `robo_bp_messages`, `support_ai_events`: 24 månader (fastställd 2026-08-17, automatisk). `ai_bokforing_logg`: bevaras med bokföringen (BFL). `ai_call_log`, `ai_usage_log`, `mcp_audit_log`, `bokslut_ai_suggestions`, utkast till årsredovisning: [KLAMMER — ingår inte i gallringsjobbet]. Hos Anthropic: enligt ovan. |
| **Säkerhetsåtgärder (art. 32)** | Dataminimering per flöde (dokumenterad i `_shared/claudeChat.ts` och `_shared/claudeOcr.ts`); KYC-tabeller läsbara enbart för byråmedlemmar; strukturerade svar med fast schema; tidsgränser och omförsök; kvoter och nedkylning (`ai_cooldowns`, `ai_usage_log`) [KLAMMER — kvoterna är noterade som oåtgärdade i edge-granskningen 2026-08-25]; människa-i-loopen före bokföring; funktionsgrindar per bolag för robo-bp, AI-bokslut och connector — **tolkning och assistent kan inte stängas av per bolag**, vilket ska framgå av biträdesavtalet; MCP: tvåstegsbekräftelse, användarens egen RLS, append-only-logg. Se avsnitt 7. |

### B5. Lönehantering [KLAMMER — om lönemodulen används för klienten]

| Fält | Innehåll |
|---|---|
| **Personuppgiftsansvarig** | Klienten i egenskap av arbetsgivare (bilaga 1). |
| **Kategorier av behandling (art. 30.2 b)** | Registrering av anställda, beräkning av lön, skatteavdrag och arbetsgivaravgifter, upprättande av lönebesked, arbetsgivardeklaration på individnivå (AGI) till Skatteverket, utbetalningsunderlag, utskick via Kivra, bokföring av lön, lagring. |
| **Klientens ändamål** | Fullgöra skyldigheter som arbetsgivare (anställningsavtal, skatteförfarandelagen, socialavgiftslagen, bokföringslagen). |
| **Kategorier av registrerade** | Klientens anställda och tidigare anställda, uppdragstagare med A-skatt. |
| **Kategorier av personuppgifter** | Namn, personnummer, kommun, e-post, telefon, befattning, anställningsform, månads-/timlön, tillägg och avdrag (`lonebesked.tillagg`), skattetabell, skattekolumn, jämkning, sidoinkomst, arbetsgivaravgift, bankkonto (clearing- och kontonummer), ackumulerad lön och skatt, individuppgifter i AGI (`agi_deklarationer.individuppgifter`). |
| **Känsliga uppgifter / personnummer** | **Art. 9:** hälsa — sjukavdrag och sjukfrånvaro (omfattning, aldrig diagnos), vård av barn; fackligt medlemskap — vid löneavdrag för fackavgift [KLAMMER — förekommer det bland klienterna]. Rättslig grund hos klienten: art. 9.2 b (arbetsrätt); byrån behandlar på instruktion. Personnummer: krävs för AGI (dataskyddslagen 3 kap. 10 §). Utmätning i lön (Kronofogden) kan förekomma som avdrag. |
| **System och lagringsplats** | BokPilot lönemodul: `employees`, `lonekorningar`, `lonebesked`, `salaries`, `agi_deklarationer` — Supabase, Stockholm; Kivra (lönebesked, hålls hos Kivra i upp till 390 dagar i väntan på mottagare); Skatteverket [KLAMMER — AGI lämnas via fil/e-tjänst/API]; bank [KLAMMER — utbetalningsfil]. |
| **Mottagare / underbiträden** | Supabase, Inc.; Kivra AB. Självständiga mottagare på klientens uppdrag: Skatteverket, bank, Försäkringskassan [om], Kronofogden [om], pensions- och försäkringsbolag [om]. **Inte Anthropic** (personnummer ur lönemodulen skickas aldrig); löneutbetalningar syns dock i bankhändelsetext i B4b. |
| **Tredjelandsöverföring och skyddsåtgärd** | Nej. |
| **Gallringstid** | Löneunderlag, lönebesked och AGI utgör räkenskapsinformation: 7 år (BFL 7 kap. 2 §) — omfattas av BFL-spärren vid bolagsavveckling (etapp 8). Personalregistret (`employees`): under anställningen och därefter [KLAMMER — inaktiveras; raderas när inga lönebesked längre omfattas av bevarandetiden]. Uppgifter enligt art. 9 i tillägg/avdrag: endast som del av lönebeskedet — fritext minimeras [KLAMMER — rutin]. `kivra_utskick`: 24 månader. |
| **Säkerhetsåtgärder (art. 32)** | RLS; BFL-skydd för lön (2026-07-25); personnummer maskeras i loggar; modulåtkomst styrs per användare (`user_companies.moduler`) [KLAMMER — verifiera att lönemodulen kräver särskild modulbehörighet]; Kivra-adressering över TLS med OAuth2; lönebesked renderas server-side. Se avsnitt 7. |

### B6. Bokslut, årsredovisning och deklarationer

| Fält | Innehåll |
|---|---|
| **Personuppgiftsansvarig** | Klienten (bilaga 1). |
| **Kategorier av behandling (art. 30.2 b)** | Sammanställning och beräkning, kontroller (`bokslut_checks`), AI-stödda förslag (B4), upprättande av årsredovisning och inkomstdeklaration, inlämning till Bolagsverket och Skatteverket som ombud, kommunikation med revisor, export och lagring. |
| **Klientens ändamål** | Årsbokslut/årsredovisning (ÅRL), inkomstdeklaration (SFL), revision. |
| **Kategorier av registrerade** | Klientens företrädare (styrelse, VD, firmatecknare), ägare, revisor, anställda (aggregerat i noter), motparter i undantagsfall. [KLAMMER — om byrån även upprättar ägarnas privata deklarationer (K10 m.m.) tillkommer ägarnas privatekonomiska uppgifter; för i så fall in det som egen behandling.] |
| **Kategorier av personuppgifter** | Namn, personnummer (underskrifter, fastställelseintyg, digital inlämning), roll, ägarandel, ekonomiska uppgifter, deklarationsuppgifter (INK2), bilagor (`bokslut_attachments`). |
| **Känsliga uppgifter / personnummer** | Personnummer för företrädare vid inlämning och signering (klart motiverat). |
| **System och lagringsplats** | BokPilot: `bokslut_engagements`, `bokslut_checks`, `bokslut_ai_suggestions`, `bokslut_attachments`, `annual_report_drafts`, `annual_report_draft_sections`, `annual_report_validation_items`, `annual_report_exports` (bucket), `ink2_deklarationstidpunkt` — Supabase, Stockholm; Anthropic (`bokslut-ai`, `annual-report-ai` — B4); Bolagsverket [KLAMMER — e-tjänst för digital inlämning]; Skatteverket (deklarationsombud); [KLAMMER — e-signeringstjänst]; Microsoft 365. |
| **Mottagare / underbiträden** | Supabase, Inc.; Anthropic (B4); [KLAMMER — e-signeringsleverantör]. Självständiga mottagare: Bolagsverket, Skatteverket, klientens revisor, [KLAMMER — bank/ägare på klientens uppdrag]. |
| **Tredjelandsöverföring och skyddsåtgärd** | Anthropic — se B4. E-signering: [KLAMMER]. |
| **Gallringstid** | Årsredovisning, bokslutsunderlag och deklarationsunderlag: räkenskapsinformation, 7 år (BFL 7 kap. 2 §). Utkast, AI-förslag och exportfiler: [KLAMMER — förslag: raderas 24 månader efter fastställd årsredovisning; ingår inte i gallringsjobbet]. |
| **Säkerhetsåtgärder (art. 32)** | RLS; `bokslut_audit_log` och `bokslut_denied_log`; funktionsgrind för AI-bokslut per bolag; mänskligt godkännande; periodlås efter bokslut; privat exportbucket. Se avsnitt 7. |

### B7. Digital post via Kivra

| Fält | Innehåll |
|---|---|
| **Personuppgiftsansvarig** | Klienten (bilaga 1). |
| **Kategorier av behandling (art. 30.2 b)** | Utskick av kundfakturor och lönebesked till mottagarens digitala brevlåda via Kivras Tenant API (`kivra-skicka`); hämtning av klientens företagsbrevlåda via Kivras Partner API var tionde minut efter klientens medgivande i Kivra (`kivra-sync`) med import till Inkorgen (B1); loggning av utskick. |
| **Klientens ändamål** | Säker och spårbar leverans av fakturor och lönebesked; mottagning av myndighets- och leverantörspost. |
| **Kategorier av registrerade** | Fakturamottagare (privatpersoner, enskilda näringsidkare, kontaktpersoner); klientens anställda (lönebesked); avsändare av post till klientens företagsbrevlåda. |
| **Kategorier av personuppgifter** | Personnummer (adresseringsnyckel; Kivra matchar i ordningen organisationsnummer, personnummer, e-post), namn, e-post, fakturans och lönebeskedets innehåll (PDF), metadata om inkommande post (avsändare, ämne, datum, innehållsnycklar). |
| **Känsliga uppgifter / personnummer** | Personnummer — nödvändigt för säker adressering (dataskyddslagen 3 kap. 10 §). Lönebesked kan innehålla uppgifter enligt art. 9 (se B5). |
| **System och lagringsplats** | BokPilot (`kivra_utskick`, `documents` med `source='kivra'`) — Supabase, Stockholm; Kivra AB — Sverige. Driftläge [KLAMMER — mock/sandbox/prod; avsändaravtal och partneravtal med datum]. |
| **Mottagare / underbiträden** | Kivra AB — roll [KLAMMER — fastställ enligt Kivras avtal: personuppgiftsbiträde för utskicket respektive självständigt ansvarig för mottagarens brevlåda]; Supabase, Inc. |
| **Tredjelandsöverföring och skyddsåtgärd** | Nej [KLAMMER — kontrollera Kivras underbiträdeslista]. |
| **Gallringstid** | `kivra_utskick`: 24 månader som leveransbevis (fastställd 2026-08-17, automatisk; personnummer maskerat). Hos Kivra: enligt Kivras villkor (lönebesked med `retain` upp till 390 dagar i väntan på mottagare). Importerade dokument: följer B1 (7 år). |
| **Säkerhetsåtgärder (art. 32)** | OAuth2 client credentials (8 timmars token) över TLS; personnummer aldrig i klartext i loggar; mock-läge som standard tills avtal finns; dubblettspärr hos Kivra; cron-hemlighet i `interna_nycklar` (endast `service_role`); RLS; PDF renderas server-side. Se avsnitt 7. |

### B8. Arkivering och långtidslagring av räkenskapsinformation

| Fält | Innehåll |
|---|---|
| **Personuppgiftsansvarig** | Klienten (bilaga 1). Bevarandeplikten enligt BFL åvilar klienten; byrån bevarar på uppdrag. |
| **Kategorier av behandling (art. 30.2 b)** | Lagring och bevarande, återläsning, export och återlämnande, säkerhetskopiering, kontroll av lagringsintegritet, gallring efter bevarandetid, avveckling av klientbolag. |
| **Klientens ändamål** | Uppfylla arkiveringsplikten (BFL 7 kap.) och hålla räkenskapsinformationen tillgänglig för myndigheter och revisor. |
| **Kategorier av registrerade** | Samma som B1–B6. Dokumentarkivets mapp *Personal* kan innehålla anställningsavtal och andra personalhandlingar (art. 9 kan förekomma). |
| **Kategorier av personuppgifter** | All räkenskapsinformation; dokumentarkivets filer (`arkiv_mappar`, `arkiv_filer`; mappar: Skatteverket, Bokslut, Avtal, Bank och försäkring, Personal, Övrigt). |
| **Känsliga uppgifter / personnummer** | Kan förekomma, se ovan; klienten styr innehållet i arkivet. |
| **System och lagringsplats** | Supabase Storage (buckets `underlag`, `arkiv`, `annual-report-exports`) och databas — Stockholm; Supabase dagliga backuper (Pro-plan, 7 dagars retention; **Storage ingår inte i backuperna**); planerat oföränderligt arkiv i Azure Blob Storage, Sweden Central (ZRS, Cold, container-level WORM per räkenskapsår; verifieringsdokument 2026-08-26) [KLAMMER — beslut och driftsättningsdatum]; oberoende andrakopia [KLAMMER]; byråns klientmappar i Microsoft 365 [KLAMMER]. |
| **Mottagare / underbiträden** | Supabase, Inc.; Microsoft Ireland Operations Ltd (Azure — planerat; M365). |
| **Tredjelandsöverföring och skyddsåtgärd** | Nej i vila: Supabase i Stockholm, Azure Sweden Central i Sverige (parregion Sweden South ligger också i Sverige). Microsofts support- och driftåtkomst under SCC/DPF; EU Data Boundary är en EU/EFTA-gräns och åberopas inte för den svenska placeringen. |
| **Gallringstid** | Räkenskapsinformation: 7 år (BFL 7 kap. 2 §) — därefter aktiv, kalenderförd gallring (i Azure fungerar lifecycle-radering inte i oföränderliga containrar, så gallringen måste göras manuellt). Dokumentarkivets mappar: Skatteverket, Bokslut, Avtal, Bank och försäkring 7 år; Personal gallras löpande; Övrigt ingen särskild regel. **Gallringen av arkivet sker i dag manuellt** — [KLAMMER — fastställ intervall och ansvarig, öppen punkt sedan 2026-07-25]. Avveckling av klientbolag: endast via `avveckla_bolag()` efter export och klientens skriftliga bekräftelse [KLAMMER — rutin]. |
| **Säkerhetsåtgärder (art. 32)** | BFL-spärr vid bolagsradering (trigger `trg_forbjud_radera_bolag_med_rakenskapsinfo`, sanktionerad väg `avveckla_bolag()` med permanent post i `platform_audit_log`); `arkiv_skydda_rakenskapsinfo`; mappsynlighet (endast byrån / klienten läser / klienten laddar upp); nedladdning av räkenskapsinformation loggas (`download_audit_log`); MIME- och storleksgränser; nattlig kontroll av lagringsintegritet med larm vid saknade filer (21 kända föräldralösa filer följs upp); WORM-lås och attesteringsbrev (planerat); säkrad betalning och eskaleringsrutin för arkivabonnemanget [KLAMMER]. Se avsnitt 7. |

---

## 6. Del C — Mottagare, biträden, underbiträden och tredjelandsöverföringar (samlad förteckning)

### 6.1 Biträden och underbiträden

Tabellen utgör samtidigt underlag för bilaga A (underbiträdesförteckning) i byråns biträdesavtal med klienterna. Kolumnen *Avtal* avser det skriftliga biträdesavtal som krävs enligt art. 28.3; kopia ska arkiveras i [KLAMMER — byråns avtalsmapp].

| Leverantör (juridisk person) | Säte | Tjänst och roll | Plats för behandling | Personuppgifter | Tredjelandsöverföring och skyddsåtgärd | Avtal (art. 28) | Att göra / status |
|---|---|---|---|---|---|---|---|
| [KLAMMER] BokPilot AB, org.nr [559208-1219] | Sverige | Tillhandahållare av BokPilot — biträde (del A) / underbiträde (del B) **om alternativ a i 3.1** | Se Supabase m.fl. | All data i BokPilot | Ingen egen | Biträdesavtal AcountX–BokPilot AB [KLAMMER — datum] | Fastställ rollen (3.1) |
| Supabase, Inc. | USA | Databas, autentisering, fillagring, edge functions, backuper — biträde/underbiträde | AWS eu-north-1, Stockholm (AWS är Supabases underbiträde) | All applikationsdata | Ja — fjärråtkomst för drift och support från tredjeland kan förekomma; SCC (modul 2/3) i Supabases DPA, Supabases TIA; AWS DPF-certifierat | Supabase DPA (accepteras genom tjänstevillkoren) | Arkivera DPA, TIA och underbiträdeslistan (version daterad 2026-06-01) i AcountX/BokPilot AB:s namn [KLAMMER] |
| Cloudflare, Inc. | USA | Pages (frontend), DNS, Email Routing och Email Worker (inkommande underlag), CDN/WAF — underbiträde | Globalt nätverk; transient, EU-noder i normalfallet | Trafikmetadata; e-postinnehåll passerar workern | Ja — transient global behandling; SCC i Cloudflares DPA, Cloudflare DPF-certifierat [KLAMMER — verifiera]; Data Localization Suite används inte [KLAMMER] | Cloudflare DPA (självbetjäning) | Arkivera DPA; ta ställning till EU-lokalisering av Workers |
| Anthropic Ireland Limited (avtalspart) / Anthropic PBC (behandling) | Irland / USA | AI-tolkning och AI-assistans (B4), support-AI (A5) — underbiträde | USA (api.anthropic.com) | Underlagens innehåll, bokföringsmaterial, frågor och svar | **Ja — USA.** SCC modul 2/3 i Anthropics DPA; vidareöverföring Irland–USA ska dokumenteras; DPF-certifiering [verifiera]; ZDR [verifiera]; TIA [dokumentera]; lagring 30 dagar/0 dagar/upp till 2 år vid flaggning | Anthropic Commercial Terms + DPA (Console) | Ladda ned och arkivera DPA och underbiträdeslista; bekräfta ZDR; dokumentera TIA; verifiera DPF-post |
| Resend, Inc. | USA | Transaktionsmejl (inbjudningar, notiser, lösenord, beslut); ev. nyhetsbrev (A7) — underbiträde | Region eu-west-1 (Irland); domän bokpilot.se verifierad 2026-07-14 | E-postadresser, namn, notisinnehåll | Ja — amerikanskt bolag; SCC i Resends DPA; data i vila i EU | Resend DPA | Arkivera DPA; kontrollera Resends underbiträden (t.ex. AWS) |
| Kivra AB | Sverige | Digital brevlåda: utskick (Tenant API) och företagsbrevlåda (Partner API) — roll [KLAMMER] | Sverige | Personnummer, namn, fakturor, lönebesked, inkommande post | Nej [KLAMMER — kontrollera Kivras underbiträden] | Avsändaravtal / partneravtal [KLAMMER — datum, driftläge] | Fastställ roll; arkivera avtal |
| Microsoft Ireland Operations Ltd | Irland | Microsoft 365 (e-post, Teams, OneDrive/SharePoint: byråns dokument, personalakter, klientmappar); planerat arkiv i Azure Blob Storage — biträde/underbiträde | EU Data Boundary (EU/EFTA); Azure Sweden Central (Sverige) för arkivet | Byråns egen dokumentation; klienthandlingar; personaluppgifter | Begränsad — support, telemetri, säkerhet: SCC i Microsofts DPA, Microsoft DPF-certifierat | Microsoft Products and Services DPA (via Microsoft Customer Agreement) | Arkivera DPA (maj 2026) och underbiträdeslista; läs MCA-avsnitten om avstängning och kunddata före arkivbeslut |
| Stripe Payments Europe, Ltd. / Stripe, Inc. | Irland / USA | Betalning och abonnemang **[om det tas i bruk — webhooken har aldrig fungerat i drift]** | EU/USA | Kontaktuppgifter, betalningshistorik; kortuppgifter endast hos Stripe (hosted checkout) | Ja — SCC och DPF (Stripe, Inc.) [KLAMMER — verifiera] | Stripe Services Agreement inkl. DPA | Ta ställning till om Stripe ska tas i bruk; annars stryk |
| Fly.io, Inc. | USA | SKV-gateway (mTLS-proxy mot Skatteverkets API) **[om i drift]** | Region arn (Stockholm) | Organisationsnummer och skattekontodata i transit, inget i vila | Ja — amerikanskt bolag; SCC i Fly.io:s DPA; region-pinning [bekräfta] | Fly.io DPA | Arkivera DPA; bekräfta pinning |
| UC AB / Allabolag (apiverket.se) [KLAMMER — aktiv källa] | Sverige | Uppslag av företagsuppgifter (B2) — självständigt ansvarig, inte biträde | Sverige | Organisationsnummer skickas; företagsuppgifter inkl. företrädare returneras | Nej | Tjänstevillkor | Arkivera villkor |
| Visma Spcs AB [KLAMMER] | Sverige | Visma eAccounting (Spiris): byråns egen bokföring och klienter på Spiris; Spiris-bryggan (client id `acountxredovisningsbyraab`, produktionsåtkomst 2026-08-26) | [KLAMMER — Vismas driftregion] | Bokföringsdata | [KLAMMER — enligt Vismas DPA och underbiträdeslista] | Vismas DPA [KLAMMER] | Arkivera DPA; koppla till Spiris-bryggans förteckning |
| Fortnox AB [KLAMMER — om klienter finns på Fortnox] | Sverige | Bokföringssystem för klienter; integration "AcountX" i Fortnox utvecklarportal | Sverige | Bokföringsdata | Nej | Fortnox DPA [KLAMMER] | Arkivera DPA |
| [KLAMMER — leverantör av ID-/PEP-/sanktionskontroll] | | A3 | | Identitets- och PEP-uppgifter | | | Fastställ |
| [KLAMMER — lönesystem, pensions-/försäkringsbolag, företagshälsovård] | | A4 | | Anställdas uppgifter | | | Fastställ |
| [KLAMMER — e-signeringstjänst] | | A2, B6 | | Namn, personnummer, IP | | | Fastställ |

### 6.2 Självständigt personuppgiftsansvariga mottagare

Följande mottagare behandlar uppgifterna för egna ändamål och är inte byråns biträden: Skatteverket (moms- och arbetsgivardeklarationer, inkomstdeklarationer, skattekonto), Bolagsverket (årsredovisningar, register), Finanspolisen (misstankerapporter enligt PTL — meddelandeförbud gäller), Länsstyrelsen i Stockholms län (tillsyn enligt PTL), Försäkringskassan, Kronofogden, banker, klienternas revisorer, domstolar och myndigheter vid lagstadgad skyldighet att lämna ut uppgifter, samt mottagare av fakturor och lönebesked.

### 6.3 Dokumentation av tredjelandsöverföringar

För varje överföring markerad *Ja* i 6.1 ska följande finnas arkiverat innan förteckningen fastställs: (1) exportör och importör med juridisk person; (2) överföringsmekanismen — SCC enligt kommissionens beslut (EU) 2021/914 med angiven modul, eller adekvansbeslut (EU–US Data Privacy Framework, kontrollerat mot den amerikanska DPF-listan med datum); (3) överföringskonsekvensbedömning (TIA) enligt EDPB:s rekommendation 01/2020, eftersom SCC enligt IMY inte alltid är tillräckligt i sig (Schrems II); (4) kompletterande åtgärder (kryptering, minimering, pseudonymisering, lagringsbegränsning); (5) accepterat eller undertecknat biträdesavtal och leverantörens aktuella underbiträdeslista; (6) datum för årlig kontroll. Skillnad görs mellan överföring *i vila* (Anthropic) och *transient behandling eller fjärråtkomst* (Cloudflare, Supabase, Resend, Microsoft, Fly.io).

---

## 7. Del D — Tekniska och organisatoriska säkerhetsåtgärder (art. 32) — allmän beskrivning

Beskrivningen gäller samtliga behandlingar och kompletteras av raden *Säkerhetsåtgärder* i respektive tabell.

**D1. Åtkomst och behörighet.** Radnivåsäkerhet (RLS) på samtliga 123 tabeller med 160 policies; rollen `anon` saknar sedan 2026-08-25 all åtkomst till schemat, så RLS är inte längre det enda skyddet; behörighetskoll frikopplad från `auth.uid()` (etapp 6); rollstyrning per bolag, roll och modul; KYC/AML-data läsbar enbart för byråmedlemmar; plattformsadministration endast via konsolen med verifiering mot `platform_admins` och append-only-logg; supportåtkomst till klientbolag kräver aktivt, tidsbegränsat samtycke; rutin för tilldelning och avslut av behörigheter (senast tillämpad 2026-08-25 med rotation av samtliga nycklar). [KLAMMER — flerfaktorsautentisering ska vara obligatorisk för byråns konton i BokPilot, Supabase, Cloudflare, Microsoft 365, Kivra, Stripe och Anthropic Console; verifiera och dokumentera.]

**D2. Kryptering.** TLS i transit; kryptering i vila (AES-256) hos Supabase/AWS och Microsoft; hemligheter enbart i edge-secrets och i tabellen `interna_nycklar` (åtkomlig endast för `service_role`); Skatteverkets API via mTLS med organisationslegitimation; enhetskryptering på byråns datorer [KLAMMER — BitLocker aktiverat, verifiera]; lösenordshanterare [KLAMMER].

**D3. Integritet och oföränderlighet.** Bokförda verifikationer kan inte ändras eller raderas (BFL-skydd v3–v6, etapp 1–3 avslutade 2026-08-25); rättelse sker genom omvänd verifikation med append-only-rättelsejournal; periodlås; förfalskningsskydd i audit-triggrarna; BFL-spärr vid bolagsradering med sanktionerad avvecklingsväg som loggas permanent; planerat WORM-arkiv i Azure Sweden Central.

**D4. Dataminimering och pseudonymisering.** Dokumenterad policy per AI-flöde för vad som får skickas till Anthropic; KYC-data och lönemodulens personnummer skickas aldrig; pseudonymisering och strikt läge utan fritext i Spiris-bryggan; personnummer maskeras i Kivra-loggen; slumpmässigt arkivnummer i stället för löpnummer i mottagaradresser; supportassistenten saknar åtkomst till bokföringsdata.

**D5. Loggning, övervakning och incidenthantering.** Behandlingshistorik i `audit_log` och rättelsejournal; nedladdningslogg; MCP- och konsollogg; driftövervakning (etapp 11) som bevakar cron-jobb och komponenter och larmar vid förändring mot baslinjen 2026-08-26; hjärtslag i `worker_health`; felrapportering till plattformsadministratörer. Incidentrutin: personuppgiftsincident bedöms omedelbart, anmäls till IMY inom 72 timmar när så krävs (art. 33), berörda klienter underrättas utan onödigt dröjsmål i egenskap av personuppgiftsansvariga, registrerade informeras vid hög risk (art. 34), incidentlogg förs [KLAMMER — skriftlig rutin och incidentlogg upprättas].

**D6. Säkerhetskopiering, kontinuitet och lagringsintegritet.** Dagliga databasbackuper hos Supabase (Pro-plan, 7 dagars retention) [KLAMMER — ta ställning till point-in-time recovery]; Storage ingår inte i backuperna, vilket kompenseras av nattlig avstämning databas–Storage med larm vid saknade filer; planerat oföränderligt arkiv i Azure Sweden Central och oberoende andrakopia utanför Azure [KLAMMER]; säkrad betalning och eskaleringsrutin för arkivabonnemanget; återläsningstest [KLAMMER — intervall].

**D7. Gallring.** Nattligt gallringsjobb (`gallra_gdpr_loggar()`, pg_cron 03:40, i drift sedan 2026-08-17) för AI- och driftloggar enligt fastställda bevarandetider; räkenskapsinformation bevaras 7 år och gallras därefter enligt rutin [KLAMMER]; dokumentarkiv och Azure-arkiv gallras manuellt enligt kalenderförd rutin [KLAMMER]; KYC-material gallras efter 5 respektive 10 år [KLAMMER — rutin, separat från bolagsavveckling].

**D8. Leverantörsstyrning.** Biträdesavtal med samtliga biträden och underbiträden (avsnitt 6); arkiverade underbiträdeslistor och överföringsdokumentation; årlig kontroll av leverantörernas certifieringar (DPF, SOC 2/ISO 27001) [KLAMMER]; underrättelse till klienterna vid byte av underbiträde enligt biträdesavtalet.

**D9. Organisatoriska åtgärder.** Tystnadsplikt och sekretess enligt Reko och uppdragsavtal; sekretessförbindelse för personal och konsulter [KLAMMER]; utbildning i dataskydd och penningtvättsregler vid anställning och därefter årligen (logg i riskbedömningen); inbyggt dataskydd och dataskydd som standard vid ny utveckling (art. 25) — registerförteckningen uppdateras samtidigt med koden, inte efteråt; bedömning av behovet av konsekvensbedömning (art. 35) dokumenteras: [KLAMMER — preliminär bedömning: ingen DPIA krävs för nuvarande utformning eftersom AI-förslagen inte verkställs utan mänskligt beslut och känsliga uppgifter inte behandlas i stor omfattning; bedömningen omprövas om AI-förslag börjar verkställas automatiskt, om kundreskontra med privatpersoner i stor omfattning kopplas till AI-flöden, eller om löne-/sjukfrånvarounderlag börjar skickas till AI-tjänst]; rutin för registrerades rättigheter (art. 15–22) med svar inom en månad och hänvisning till art. 17.3 b när bevarandeplikt hindrar radering [KLAMMER — rutin]; integritetspolicy på webbplatsen och information till klienternas registrerade via klienten (art. 13–14) [KLAMMER].

**D10. Kända brister och åtgärdslista (art. 32.1 d — regelbunden utvärdering).** Att bristerna är kända och förtecknade är i sig en del av ansvarsskyldigheten (art. 5.2):

| Brist | Konsekvens | Status |
|---|---|---|
| `stripe-webhook` har aldrig fungerat i drift (`price_UNKNOWN`) | Betalhändelser behandlas inte; Stripe ska antingen sättas i drift korrekt eller strykas | Oåtgärdad (driftövervakning 2026-08-26) |
| `folio-ocr` har aldrig lyckats (`health 404`) | Experimentell OCR-tjänst; ska stängas ned eller lagas — inga personuppgifter flödar i dag | Oåtgärdad |
| AI-kvoter (`ai_cooldowns`, `ai_usage_log`) | Risk för kostnads- och volymöverskridande; inte en integritetsrisk i sig | Oåtgärdad (edge-granskning 2026-08-25) |
| Konsolens `ilike`-grind | Sökgrind i operatörskonsolen bör stramas åt | Oåtgärdad |
| 21 föräldralösa filer i Storage efter raderade bolag | Lagringsminimering (art. 5.1 c och e); ingen dataförlust | Följs upp nattligen; gallring [KLAMMER] |
| Bucketen `shimo-audio` är publik | Innehåll och behov av publik åtkomst ska kontrolleras | [KLAMMER] |
| KYC/AML-poster raderas vid bolagsavveckling | Bevarandekravet i PTL (5/10 år) kan brytas om material inte arkiverats separat | Rutin [KLAMMER] |
| Manuell gallring av dokumentarkiv och Azure-arkiv | Kräver kalenderförd rutin med ansvarig | Intervall och ansvarig [KLAMMER] |
| Storage ingår inte i Supabases backuper; ingen oberoende andrakopia | Enskild felpunkt för räkenskapsinformation | Kompenserande kontroll finns; andrakopia [KLAMMER] |
| Tolkning och assistent kan inte stängas av per bolag | Klient som inte accepterar AI-behandling kan inte använda tjänsten i befintligt skick — måste framgå av biträdesavtalet | Avtalsfråga |

---

## 8. Del E — Öppna punkter före fastställande

1. Fastställ relationen AcountX–BokPilot AB (3.1) och därmed vem som är part i avtalen med Supabase, Anthropic, Cloudflare, Resend, Kivra, Stripe och Fly.io.
2. Fyll i bilaga 1: samtliga klienter med kontaktperson, biträdesavtal (datum) och använda moduler (lön, Kivra, AI, connector).
3. Ladda ned och arkivera samtliga biträdesavtal och underbiträdeslistor (6.1); kontrollera att de står i rätt bolags namn.
4. Anthropic: bekräfta att Zero Data Retention är påslaget för organisationens API-nyckel (beslut 2026-07-05); verifiera DPF-posten; dokumentera vidareöverföringen Irland–USA och en TIA; skriv in tvåårsundantaget vid flaggning i klienternas biträdesavtal.
5. Besluta om Stripe ska tas i bruk (webhooken fungerar inte i dag) — annars stryk Stripe ur förteckningen och avtalen.
6. Fastställ bevarandetider för de loggar som inte ingår i gallringsjobbet (A6-tabellen) samt för supportärenden, utkast, AI-förslag och exportfiler; utöka `gallra_gdpr_loggar()` i motsvarande mån.
7. Fastställ gallringsintervall och ansvarig för dokumentarkivet (öppet sedan 2026-07-25) och för det planerade Azure-arkivet.
8. Inför rutin som säkrar KYC/AML-materialets bevarande (5/10 år) innan ett klientbolag avvecklas i BokPilot.
9. Verifiera och dokumentera flerfaktorsautentisering, enhetskryptering och lösenordshantering (D1–D2).
10. Kontrollera bucketen `shimo-audio` (publik) och genomgången att personnummer inte loggas i klartext utanför Kivra-loggen.
11. Fastställ rollen för Kivra (biträde/självständigt ansvarig) och driftläget (mock/sandbox/prod) samt avtalens datum.
12. Ange leverantörer för ID-/PEP-/sanktionskontroll (A3), lönesystem/pension/företagshälsovård (A4) och e-signering (A2, B6), eller stryk fälten.
13. Ta ställning till dataskyddsombud (art. 37) och dokumentera bedömningen i avsnitt 2.
14. Dokumentera DPIA-bedömningen (D9), incidentrutinen (D5) och rutinen för registrerades rättigheter (D9).
15. För in Spiris-bryggans förteckning (B4c) och komplettera Visma/Fortnox som lagringsplats för de klienter det gäller.
16. Stäm av att uppdragsavtal och biträdesavtal med klienterna redovisar samma underbiträden och samma bevarandetider som denna förteckning.
17. Bevaka att EU:s penningtvättsförordning (AMLR, förordning (EU) 2024/1624) ersätter PTL 2027-07-10 — A3 ses över dessförinnan.

---

## Bilaga 1 — Förteckning över personuppgiftsansvariga för vilkas räkning byrån är biträde (art. 30.2 a)

Förs som separat, elektroniskt underhållen lista; uppgifterna nedan är minimum. Klienter som är fysiska personer (enskild firma) förtecknas med organisationsnummer.

| # | Klient (juridisk person / enskild näringsidkare) | Org.nr | Kontaktperson och e-post | Företrädare / DSO (art. 30.2 a) | Uppdragsavtal (datum) | Biträdesavtal (datum, version) | System | Moduler (bokföring / fakturor / bank / lön / bokslut / Kivra / AI / connector) | Anteckning |
|---|---|---|---|---|---|---|---|---|---|
| 1 | [KLAMMER] | [KLAMMER] | [KLAMMER] | Ej tillämpligt / [KLAMMER] | [KLAMMER] | [KLAMMER] | BokPilot / Spiris / Fortnox | [KLAMMER] | |
| 2 | [KLAMMER] | | | | | | | | |

## Bilaga 2 — Gallringsöversikt per uppgiftskategori

| Uppgiftskategori | Bevarandetid | Grund | Genomförande |
|---|---|---|---|
| Räkenskapsinformation (verifikationer, underlag, fakturor, bankhändelser, lönebesked, AGI, årsredovisning, bokslutsunderlag) samt tillhörande spårbarhetsloggar | 7 år efter utgången av det kalenderår då räkenskapsåret avslutades | BFL 7 kap. 2 §; art. 17.3 b | Raderingsskydd i databasen; gallring efter bevarandetid enligt rutin [KLAMMER] |
| Kundkännedom och övervakning enligt PTL | 5 år efter affärsförbindelsens slut; 10 år enligt PTL 5 kap. 4 § | PTL 5 kap. 3–4 §§ | Manuell rutin [KLAMMER]; skydd vid bolagsavveckling saknas |
| Avtal, uppdragsdokumentation, korrespondens | Uppdragstiden + [KLAMMER — förslag 10 år] | Preskription, Reko | Manuell rutin |
| Personalakt, anställningsavtal | Anställningen + [KLAMMER — förslag 10 år] | Preskription | Manuell rutin |
| Rekryteringsunderlag (ej anställda) | [KLAMMER — förslag 2 år] | Diskrimineringslagen | Manuell rutin |
| Användarkonton | Inaktivering vid avslut; radering efter [KLAMMER — 12 månader] | Art. 5.1 e | Manuell rutin |
| Byråmedlemskap och klientkopplingar (behörighetshistorik) | 5 år efter affärsförbindelsens slut | PTL 5 kap. 3 § | Inaktivering, ingen radering |
| AI-konversationer (`assistent_logg`, `robo_bp_messages`, `support_ai_events`), `kivra_utskick` | 24 månader | Fastställd 2026-08-17 | Automatiskt, pg_cron 03:40 |
| `inbound_email_log` | 12 månader | Fastställd 2026-08-17 | Automatiskt |
| Supportärenden och bilagor | [KLAMMER — 24 månader efter avslut] | Art. 5.1 e | [KLAMMER] |
| Övriga drift- och plattformsloggar | Enligt A6-tabellen | Art. 5.1 e, art. 32 | Delvis leverantörsstyrt |
| Marknadsföringsregister | Till avregistrering/invändning; leads [KLAMMER — 12 månader] | Art. 21 | Manuell rutin/spärrlista |

## Bilaga 3 — Källor och lagrum

**IMY (Integritetsskyddsmyndigheten):**
- *Föra register över behandlingar* — https://www.imy.se/verksamhet/dataskydd/det-har-galler-enligt-gdpr/personuppgiftsansvariga-och-personuppgiftsbitraden/fora-register-over-behandling/ (senast uppdaterad av IMY 2025-09-25). Källa till innehållskraven i avsnitt 1, formkraven och undantaget i art. 30.5.
- *Att tänka på som personuppgiftsbiträde* — https://www.imy.se/verksamhet/dataskydd/det-har-galler-enligt-gdpr/personuppgiftsansvariga-och-personuppgiftsbitraden/att-tanka-pa-som-personuppgiftsbitrade/
- *Personuppgiftsbiträdesavtal* — https://www.imy.se/verksamhet/dataskydd/det-har-galler-enligt-gdpr/personuppgiftsansvariga-och-personuppgiftsbitraden/personuppgiftsbitradesavtal/
- *Överföring av personuppgifter till tredjeland* — https://www.imy.se/verksamhet/dataskydd/det-har-galler-enligt-gdpr/overforing-till-tredje-land/
- *Lämpliga skyddsåtgärder vid tredjelandsöverföring* — https://www.imy.se/verksamhet/dataskydd/det-har-galler-enligt-gdpr/overforing-till-tredje-land/lampliga-skyddsatgarder/ (SCC enligt beslut 2021/914; kompletterande åtgärder kan krävas; Schrems II)
- *När ska en konsekvensbedömning genomföras?* — https://www.imy.se/verksamhet/dataskydd/det-har-galler-enligt-gdpr/konsekvensbedomning/nar-ska-en-konsekvensbedomning-genomforas/

**Leverantörer:**
- Supabase — Data Processing Addendum: https://supabase.com/legal/dpa ; Transfer Impact Assessment: https://supabase.com/downloads/docs/Supabase+TIA+250314.pdf
- Anthropic — Privacy Center om Zero Data Retention: https://privacy.claude.com/en/articles/8956058-i-have-a-zero-data-retention-agreement-with-anthropic-what-products-does-it-apply-to ; DPA och underbiträdeslista hämtas från Anthropic Console [KLAMMER — arkivera]
- Microsoft — regionslista och dataplacering: se `docs/arkivlagring-azure-verifiering.md` (verifierat 2026-08-26)

**Lagrum:**
- Dataskyddsförordningen (EU) 2016/679: art. 5, 6, 9, 10, 13–14, 15–22, 25, 27, 28, 30, 32, 33–35, 37, 44–49
- Lag (2018:218) med kompletterande bestämmelser till EU:s dataskyddsförordning (dataskyddslagen): 3 kap. 8–10 §§
- Bokföringslagen (1999:1078): 5 kap., 7 kap. 2 §
- Lag (2017:630) om åtgärder mot penningtvätt och finansiering av terrorism: 2 kap. 14 §, 3 kap., 4 kap. 9 §, 5 kap. 3–7 §§
- Förordning (EU) 2024/1624 (AMLR), tillämplig från 2027-07-10
- Förordning (EU) 2024/1689 (AI-förordningen), art. 50
- Marknadsföringslagen (2008:486) 19 §; diskrimineringslagen (2008:567); preskriptionslagen (1981:130) 2 §
- Kommissionens genomförandebeslut (EU) 2021/914 (standardavtalsklausuler); kommissionens beslut om adekvat skyddsnivå för EU–US Data Privacy Framework (2023)

**Interna underlag:**
- `docs/inventering.md` (2026-08-20/25), `docs/arkivlagring-azure-verifiering.md` (2026-08-26), `schema/tables.sql`, `schema/cron_jobs.sql`, `supabase/migrations/20260817202217_gdpr_gallring_v1.sql`, `supabase/functions/_shared/claudeChat.ts` och `claudeOcr.ts`
- Repot `bokpilot`: `docs/GDPR-REGISTERFORTECKNING.md`, `docs/GDPR-BITRADESAVTAL-MALL.md`, `docs/AML-RISKBEDOMNING-BYRA.md`, `docs/KYC_AML_DESIGN.md`, `docs/REGELEFTERLEVNAD.md`, `docs/inbound-email.md`, `docs/MCP_CONNECTOR_DESIGN.md`
- `Projekt\spiris-bridge\REGISTERFORTECKNING.md` (2026-08-03)

## Ändringslogg

| Version | Datum | Ändring | Av |
|---|---|---|---|
| 0.1 | 2026-08-26 | Första utkast: 7 behandlingar som personuppgiftsansvarig (A1–A7), 8 behandlingar som personuppgiftsbiträde (B1–B8), samlad underbiträdesförteckning, art. 32-beskrivning, öppna punkter | [KLAMMER] |
