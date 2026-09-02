# UTKAST — beslutsunderlag, ska bekräftas av dokumentägaren

**Beslutsunderlag inför fastställande av uppdragsavtal, personuppgiftsbiträdesavtal, registerförteckning (art. 30) och allmän riskbedömning (PTL)**

Dokumentägare: Elias Makdessi, AcountX Redovisningsbyrå AB (559165-8181). Upprättat 2026-09-02 som underlag för åtta ja/nej-beslut plus en kontroll av registreringar. Alla externa källor lästes 2026-09-02 om inget annat anges; fakta som inte kunnat kontrolleras är markerade *ej verifierat*. Underlaget ersätter inte de fyra utkasten utan anger vad som ska ändras i dem när besluten är fattade.

## Sammanfattning — rekommendationer

| # | Fråga | Rekommendation (ja/nej) |
|---|---|---|
| 1 | Reko eller Rex | **Rex.** Auktorisationen ligger hos Srf konsulterna (offentligt register + Tidningen Konsulten). Byt "Reko"/"Reko 140" i PUB, registerförteckning och uppdragsavtal; koden citerar redan Rex. |
| 2 | Systemleverantör | **BokPilot AB (559208-1219).** Lägg driftavtalen (Supabase, Anthropic, Resend, Cloudflare, Fly.io) i BokPilot AB:s namn och teckna SaaS- och biträdesavtal AcountX–BokPilot AB. |
| 3 | Supabases avtalspart | **Supabase Pte. Ltd (Singapore)** enligt ToS v3 och DPA v1, båda 2026-08-01. Rätta "Supabase, Inc." i registerförteckningen; dokumentera TIA för Singapore/USA (support). |
| 4 | Anthropic | **Behåll, men begär nollagring (ZDR) via säljteamet och skriv in USA + SCC modul 3 utan DPF** i klienternas biträdesavtal. Anthropic finns inte i DPF-registret. |
| 5 | Resend | **Behåll under 2026 med DPF/SCC och strikt innehållsminimering;** planera byte till EU-leverantör (Scaleway Transactional Email eller Brevo) innan BokPilot säljs till andra byråer. |
| 6 | PEP-/sanktionsscreening | **UC:s PEP- och sanktionslistor (Allabolag-paketet, ca 6 kr/sökning)** nu; Creditsafe API när löpande bevakning ska byggas in. |
| 7 | Identitetskontroll på distans | **BankID-signering av uppdragsavtal + KYC-förklaring som standardmetod**, SPAR-kontroll + vidimerad id-kopia som reserv; signeringsbeviset sparas som bilaga `identitetshandling`. Videomöte är inte en kontrollmetod enligt tabell 1. |
| 8 | Bevarandetider loggar | **12 mån (ai_call_log, system_error_log), 24 mån (mcp_audit_log med tvåstegsgallring, stripe_event_log), 7 år (download_audit_log, bokslut_ai_suggestions), 10 år (platform_audit_log, konsol_audit_logg).** Fysisk radering. |
| + | Bolagsverket/goAML | **AcountX är registrerat sedan 2024-07-03** (bokförings- och redovisningstjänster, tillsyn Länsstyrelsen i Stockholms län). goAML-registrering kan inte kontrolleras utifrån — registrera nu på fipogoaml.polisen.se. |

---

## 1. Reko eller Rex

**Fråga.** Vilken branschstandard styr uppdragen — Reko (FAR) eller Rex (Srf konsulterna)? Avgörs av var auktorisationen ligger.

**Verifierade fakta.**

- Srf konsulternas offentliga register "Hitta din Srf Auktoriserade konsult" har en profil för Elias Makdessielias med titlarna *Auktoriserad Redovisningskonsult* och *Srf Certifierad Affärsrådgivare*, byrå AcountX Redovisningsbyrå AB, Järfälla. Källa: <https://temp.srfkonsult.se/konsult/elias-makdessielias/> (adressen srfkonsult.se/konsult/… omdirigerar dit), läst 2026-09-02.
- Tidningen Konsulten (Srf konsulternas tidning), artikel 2025-12-03 av Therese Slettengren: auktoriserad redovisningskonsult i mars 2023, driver AcountX sedan sex år; citatet "Srf auktoriserad redovisningskonsult och Certifierad affärsrådgivare". Källa: <https://tidningenkonsulten.se/artiklar/certifieringen-gav-nya-perspektiv-och-har-gett-okat-fortroende-hos-kunderna/>, läst 2026-09-02.
- FAR:s medlemssök (<https://www.far.se/medlem/sok-far-medlem/>) kräver inloggning; sökningen "Makdessi"/"AcountX" mot far.se gav inga träffar i öppna sökmotorer. Att Elias *inte* är FAR-medlem är därför **ej verifierat**, men inget tyder på det.
- I utkasten förekommer "Reko" 14 gånger i biträdesavtalet (bl.a. "Reko 140" som grund för tio års uppdragsdokumentation), 5 gånger i registerförteckningen och 18 gånger i uppdragsavtalet (där som klammer "[Reko/Rex]"). I kodbasen citeras Rex i `supabase/functions/bokfor-ai/index.ts` (tre ställen) och `konsol/index.ts` (ett ställe); ingen förekomst av "Reko" (grep 2026-09-02).

**Alternativ.**
a) Rex – Svensk standard för redovisnings- och lönetjänster (Srf konsulterna). Stämmer med auktorisationen och med koden.
b) Reko (FAR). Kräver FAR-medlemskap som inte finns belagt.

**Rekommendation.** **Fastställ Rex som standard och ersätt alla "Reko"/"Reko 140" i de fyra utkasten med hänvisning till gällande Rex-version; behåll Rex-hänvisningarna i bokfor-ai och konsol.**

**Konsekvens vid fel val.** Avtal som hänvisar till en standard byrån inte är auktoriserad under är felaktiga mot klient och mot Srf:s kvalitetsuppföljning; bevarandetiden för uppdragsdokumentation i PUB 1.3 b och Bilaga 1 §9 skulle vila på fel regelverk.

**Vad som krävs.** (1) Sök/ersätt i de tre dokumenten; (2) kontrollera i medlemsportalen vilket bevarandekrav gällande Rex ställer på uppdragsdokumentation — tio år anges i utkasten men det kravet är **ej verifierat** mot Rex-texten; (3) hämta Srf:s aktuella allmänna villkor som Bilaga E (granskningspunkt 13 i uppdragsavtalet); (4) om Elias trots allt är FAR-medlem: ange det i PUB 1.1 och behåll Reko.

---

## 2. AcountX eller BokPilot AB som systemleverantör

**Fråga.** Ska BokPilot tillhandahållas av AcountX Redovisningsbyrå AB eller av BokPilot AB (559208-1219)?

**Verifierade fakta.**

- BokPilot AB, org.nr 559208-1219: registrerat 2019-06-04, Datavägen 5, 175 43 Järfälla, SNI 62100 (dataprogrammering) och 58290 (utgivning av annan programvara), verksamhetsföremål "utveckla, äga och tillhandahålla molnbaserade programvarutjänster (SaaS) för bokföring, redovisning, fakturering, lönehantering och skatterapportering", styrelseledamot Elias Makdessielias, aktiekapital 50 tkr, F-skatt och moms. Källa: <https://www.allabolag.se/5592081219>, läst 2026-09-02.
- AcountX Redovisningsbyrå AB, 559165-8181: registrerat 2018-07-12, samma adress, SNI 69201, samma styrelseledamot. Källa: <https://www.allabolag.se/5591658181>, läst 2026-09-02.
- Supabase-organisationen som äger projektet `bokpilot-sverige` heter "Bokpilot" och ligger på Pro-planen (Supabase MCP, läsning 2026-09-02). Vilket bolag som är fakturamottagare hos Supabase, Anthropic, Resend och Cloudflare syns inte i API:erna — **ej verifierat**.
- Supabases villkor (ToS v3, 2026-08-01) binder den som accepterar dem som "Customer"; Anthropics Commercial Terms (2025-06-17) anger Anthropic Ireland, Limited som avtalspart för kunder i EES. Se avsnitt 3 och 4.
- Registerförteckningen 3.1 och biträdesavtalets Bilaga 2 är i dag skrivna utifrån att AcountX själv är part mot leverantörerna; uppdragsavtalet 6.1 har båda alternativen som klammer. Registerförteckningen 3.3 nämner att BokPilot AB redan har en egen biträdesavtalsmall (`docs/GDPR-BITRADESAVTAL-MALL.md`, i annat repo — **ej kontrollerad här**).
- Mervärdesskattegrupp är bara möjlig för företag under Finansinspektionens tillsyn med momsfri finansiell verksamhet och deras stödföretag samt i kommissionärsförhållanden (Skatteverkets rättsliga vägledning, <https://www4.skatteverket.se/rattsligvagledning/421198.html>, läst 2026-09-02). Systemavgift mellan bolagen är alltså momspliktig (25 %); AcountX har full avdragsrätt, så det är en likviditetsfråga, inte en kostnad.

**Alternativ.**

| | a) BokPilot AB tillhandahåller BokPilot | b) AcountX är själv part mot leverantörerna |
|---|---|---|
| Roll enligt GDPR | BokPilot AB = personuppgiftsbiträde åt AcountX (del A i förteckningen) och **underbiträde** i förhållande till klienterna (del B). Supabase, Anthropic m.fl. blir BokPilot AB:s underbiträden i andra led. | Leverantörerna är AcountX egna underbiträden. |
| Avtal som krävs | SaaS-avtal + biträdesavtal AcountX–BokPilot AB (art. 28.3) med underbiträdeskedja, incidentrutin, revisionsrätt och exit; klienternas PUB Bilaga 2 får BokPilot AB som rad 1 med länk till BokPilot AB:s underbiträdeslista. Klienternas allmänna förhandstillstånd (art. 28.2) måste omfatta kedjan. | Inget internt avtal. Alla leverantörsavtal ska stå i AcountX namn. |
| Part i Supabase/Anthropic/Resend/Cloudflare/Fly.io | BokPilot AB (kontrollera och ändra faktureringsuppgifter/org.nr i respektive konsol). | AcountX. |
| Ansvarsförsäkring | AcountX: byråns ansvarsförsäkring (Srf) för redovisningsuppdraget. BokPilot AB: egen IT-/produktansvars- och cyberförsäkring för programvaran och dataförlust. Uppdragsavtalet 6.1 låter AcountX svara mot klienten "som för egna" — regress mot BokPilot AB regleras i det interna avtalet. | Byråförsäkringen täcker normalt inte leverantörsansvar för egenutvecklad programvara (granskningspunkt 6 i uppdragsavtalet). |
| Moms/skatt | Månatlig systemavgift med 25 % moms; marknadsmässigt pris (bolagen har samma ägare men ingår inte i koncern — inget koncernbidrag; underpris kan uttagsbeskattas enligt 22 kap. IL). | Inga interna transaktioner. |
| PTL | BokPilot AB är inte verksamhetsutövare (tillhandahåller programvara, inte bokföringstjänster). KYC-data får inte flyttas till BokPilot AB:s egna ändamål. | Oförändrat. |
| BFL | Räkenskapsinformationen förvaras fortfarande i Sverige (Stockholm) — 7 kap. 3 a § utlöses inte. | Oförändrat. |
| Skalbarhet | Andra byråer kan köpa BokPilot av ett neutralt bolag; AcountX konkurrerar inte som deras biträde. | En byrå blir biträde åt konkurrerande byråer; kräver ombyggnad av alla avtal senare. |

**Rekommendation.** **Välj alternativ a: BokPilot AB som systemleverantör och personuppgiftsbiträde åt AcountX, med alla driftavtal i BokPilot AB:s namn och ett skriftligt SaaS- och biträdesavtal mellan bolagen innan första skarpa klientavtal tecknas.**

**Konsekvens vid fel val.** Alternativ b nu och a senare innebär nya biträdesavtal med samtliga klienter, byte av avtalspart hos fem leverantörer och en period där försäkringsskyddet för programvaran saknas. Alternativ a utan internt biträdesavtal är ett brott mot art. 28.3 och gör klienternas underbiträdesförteckning felaktig.

**Vad som krävs för att verkställa.**
1. Upprätta SaaS-avtal + biträdesavtal AcountX–BokPilot AB (BokPilot AB:s befintliga mall som utgångspunkt), daterat, med underbiträdeslista och 30 dagars varsel.
2. Kontrollera och vid behov ändra kundnamn/org.nr/momsnummer i Supabase (Organization → Billing), Anthropic Console (Organization settings), Resend, Cloudflare och Fly.io till BokPilot AB.
3. Ladda ned och arkivera varje leverantörs villkor, DPA och underbiträdeslista i BokPilot AB:s avtalsmapp.
4. Teckna eller bekräfta IT-/produktansvars- och cyberförsäkring för BokPilot AB; be försäkringsgivaren bekräfta skriftligt att byråförsäkringen respektive IT-försäkringen täcker konstruktionen.
5. Ändra utkasten: uppdragsavtalet 6.1 (välj "[SYSTEMBOLAG]"-alternativet), 6.12 (immateriella rättigheter tillhör BokPilot AB), 15.5; PUB Bilaga 2 rad 1 = BokPilot AB, övriga rader blir "underbiträden i andra led"; registerförteckningen 3.1 = alternativ a, 6.1 rad 1 fylls i; riskbedömningen 2.4 (extern leverantör).
6. Fakturera systemavgift månadsvis från BokPilot AB till AcountX med moms.

---

## 3. Supabases avtalspart

**Fråga.** Vilket Supabase-bolag är avtalspart för en EU-kund i dag, vilken DPA-version gäller och var ligger tredjelandsöverföringen?

**Verifierade fakta.**

- **Terms of Service, Version 3 — August 1, 2026**: avtalspart är SUPABASE PTE. LTD., Singapore, 65 Chulia Street #38-02/03, OCBC Centre, Singapore 049513. Ingen regionsberoende avtalspart anges. Kalifornisk rätt, obligatoriskt skiljeförfarande med opt-out. DPA:n inkorporeras genom hänvisning till <https://supabase.com/legal/customer-resources/data-processing-addendum>. Källa: <https://supabase.com/terms>, läst i webbläsare 2026-09-02.
- **Data Processing Addendum, Version 1 — August 1, 2026**: biträde är Supabase Pte. Ltd (samma adress). Accept av villkoren gäller som undertecknande av standardavtalsklausulerna (SCC modul 2 och 3, UK-tillägg, schweiziska anpassningar). Minst 30 dagars varsel vid ändrade underbiträden; underbiträdeslista på <https://supabase.com/legal/customer-resources/subprocessor-list>. Efter uppsägning har kunden 30 dagar att begära återlämning innan radering. Källa: <https://supabase.com/legal/dpa>, läst 2026-09-02.
- **Privacy Policy** (inget datum synligt): "Supabase, Inc" är personuppgiftsansvarig för Supabases egen behandling av konto- och webbplatsdata; överföringar till USA och Singapore under SCC. Källa: <https://supabase.com/privacy>, läst 2026-09-02.
- **Underbiträdeslista daterad June 1, 2026** (PDF <https://supabase.com/legal/subprocessor-list/June-1-2026.pdf>; texten avkodades lokalt ur PDF:en eftersom filen inte kunde läsas direkt — **kontrollera mot originalet**): Supabase, Inc. (supportjänster), Amazon Web Services (hosting), Cloudflare (hosting), Google LLC (hosting), Fly.io (hosting), Vercel (hosting), Upstash (serverlös datalagring), ActiveCampaign/Postmark, FrontApp, HubSpot, Notion, Slack, PandaDoc (kommunikation med användare), Functional Software/Sentry och Braintrust Data (fel- och driftövervakning), Atlassian (statussida), Clay Labs (kundinsikt), Clazar (marknadsplats), ConfigCat (feature flags, Ungern), GitHub (kontoautentisering), Hex Technologies (analys), Sublime Security (e-postsäkerhet), Latacora (MSSP) och OpenAI LLC (språkbehandling). Ingen platskolumn kunde avkodas; bolagsformerna talar för USA utom ConfigCat (EU).
- Säkerhetssidan: databas, Auth och Storage ligger i vald AWS-region (för BokPilot eu-north-1, Stockholm); AES-256 i vila och TLS; SOC 2 Type 2, ISO 27001; dagliga backuper på betalplaner. Källa: <https://supabase.com/security>, läst 2026-09-02.
- Supabase saknas i EU-U.S. Data Privacy Framework-listan (sökning "Supabase" på <https://www.dataprivacyframework.gov/list> gav inga träffar 2026-09-02). Ingen adekvansmekanism — SCC är enda grunden.
- Hur och varifrån Supabases supportpersonal får åtkomst till kunddata beskrivs inte i DPA eller på säkerhetssidan — **ej verifierat**. DPA:n innehåller ingen geografisk begränsning för supportåtkomst.

**Var tredjelandsöverföringen ligger.** (1) *Singapore*: avtalsparten och dess personal (administration, support) — Singapore saknar adekvansbeslut. (2) *USA*: det amerikanska koncernbolaget Supabase, Inc. som uttryckligen listas för supporttjänster, AWS som infrastrukturleverantör (data i vila i Stockholm) samt de amerikanska verktygsleverantörerna för kommunikation, övervakning och analys (berör i första hand kontouppgifter för byråns egna användare av dashboarden, inte klientdata i databasen). Data i vila lämnar inte Sverige; överföringen består av fjärråtkomst och supportärenden.

**Alternativ.**
a) Behåll Supabase, dokumentera överföringen (SCC modul 3 eftersom byrån/BokPilot AB är biträde), gör en överföringskonsekvensbedömning (TIA) för Singapore och USA och begränsa supportåtkomst till ärenden där den behövs.
b) Byt till EU-ägd drift (självhostad Supabase hos europeisk leverantör) — stor omställning utan motsvarande riskminskning eftersom data i vila redan ligger i Sverige.

**Rekommendation.** **Behåll Supabase, rätta avtalsparten till Supabase Pte. Ltd (Singapore) i registerförteckningen (3.2 och 6.1) och biträdesavtalets Bilaga 2, ange ToS v3 och DPA v1 (2026-08-01) samt underbiträdeslistan 2026-06-01, och arkivera en TIA som täcker Singapore (avtalspart) och USA (Supabase, Inc. support, AWS).**

**Konsekvens vid fel val.** Fel juridisk person i underbiträdesförteckningen gör klienternas biträdesavtal formellt oriktiga (art. 28.2 och 28.4) och underminerar förhandstillståndet; utan TIA saknas det underlag IMY förväntar sig efter Schrems II.

**Vad som krävs för att verkställa.** Ladda ned ToS v3, DPA v1 och underbiträdeslistan som PDF till avtalsmappen (i BokPilot AB:s namn, se avsnitt 2); skriv en TIA på 1–2 sidor enligt EDPB:s rekommendation 01/2020 (kryptering i vila, data i Stockholm, supportåtkomst endast på begäran, MFA på organisationen); prenumerera på ändringar av underbiträdeslistan; ändra "Supabase, Inc." till "Supabase Pte. Ltd (avtalspart) / Supabase, Inc. (support, USA)" i registerförteckningen och behåll formuleringen i PUB Bilaga 2 rad 1 med korrekt DPA-datum.

---

## 4. Anthropic

**Fråga.** Vilka villkor gäller för BokPilots API-användning, hur länge lagras data, hur begärs nollagring, finns Anthropic i DPF-registret, var behandlas data — och vad ska stå i klienternas biträdesavtal?

**Verifierade fakta.**

- **Commercial Terms of Service, effective June 17, 2025**: avtalspart Anthropic Ireland, Limited för kunder i EES/Schweiz/UK; Anthropic får inte träna modeller på kundinnehåll; kunden behåller rätten till indata och äger utdata; DPA inkorporeras genom hänvisning; irländsk rätt. Källa: <https://www.anthropic.com/legal/commercial-terms>, läst 2026-09-02.
- **Data Processing Addendum, effective February 24, 2025**: SCC modul 2 (ansvarig→biträde) eller modul 3 (biträde→biträde) med UK- och schweiziska tillägg; ingen hänvisning till DPF eller adekvansbeslut; nya underbiträden meddelas med 15 dagars invändningsfrist; radering av kunddata inom 30 dagar efter avtalets upphörande med undantag för lagkrav, tvist och bekämpning av skadlig användning; revisionsrätt på kundens bekostnad. Källa: <https://www.anthropic.com/legal/data-processing-addendum>, läst 2026-09-02.
- **Underbiträden** (<https://trust.anthropic.com/subprocessors>, läst i webbläsare 2026-09-02): Google Cloud Platform, Amazon Web Services och Microsoft Azure ("Cloud infrastructure, Worldwide"), Cloudflare (CDN, lokalt hos kunden), Stripe, WorkOS, Intercom, Twilio, Iterable, Sentry, Sift, Arkose Labs, Brave Search, ElevenLabs, TurboPuffer, Persona (USA), Nutun (Sydafrika, support), Boldr (Kanada, support), Yoti (UK), Palantir (endast Claude for Government).
- **Standardlagring**: indata och utdata raderas från Anthropics backend inom 30 dagar; innehåll som flaggas av säkerhetssystemen kan bevaras upp till 2 år och klassificeringspoäng upp till 7 år. Källa: <https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data> (uppdaterad 2026-07-01), läst 2026-09-02.
- **Nollagring (ZDR)** enligt <https://platform.claude.com/docs/en/manage-claude/api-and-data-retention> (läst 2026-09-02): begärs hos Anthropics säljteam (<https://claude.com/contact-sales>), aktiveras per organisation och gäller inte automatiskt nya organisationer under samma konto. Omfattar Messages API och token counting för berättigade funktioner, Claude Code med kommersiella API-nycklar samt Claude Platform on AWS. Omfattar **inte** Batch API (29 dagars lagring), Files API, code execution, MCP connector, Agent skills, Managed Agents eller konsumentprodukterna; CORS stöds inte under ZDR. Även med ZDR kan flaggat innehåll bevaras upp till 2 år.
- **Covered Models**: Claude Fable 5/5.1 och Mythos 5/5.1 kräver 30 dagars lagring och kan inte omfattas av ZDR (policy i kraft 2026-06-09). Källa: <https://privacy.claude.com/en/articles/15425996-data-retention-practices-for-covered-models>, läst 2026-09-02. BokPilot använder `claude-haiku-4-5` och `claude-sonnet-5` (grep i `supabase/functions/_shared/claudeChat.ts`, `_shared/claudeOcr.ts`, `bokforingsassistent`, `tolka-underlag`, 2026-09-02) — inga Covered Models, alltså ZDR-berättigade.
- **Behandlingsplats**: parametern `inference_geo` har bara värdena `global` (standard, valfri geografi) och `us`; arbetsytans geo (data i vila och endpoint-behandling) kan bara vara `us`; US-only kostar 1,1× och stöds från Claude 4.6 — Haiku 4.5 ger 400-fel om parametern skickas. Källa: <https://platform.claude.com/docs/en/manage-claude/data-residency>, läst 2026-09-02. Ingen EU-behandling i förstapartstjänsten; EU-region finns enligt tredjepartskällor bara via Amazon Bedrock (eu-central-1) eller Google Vertex AI, där molnleverantören är biträde (t.ex. <https://www.infoq.com/news/2026/07/claude-foundry-ga-europe/>, **ej verifierat mot AWS/Google**).
- **DPF**: sökning "Anthropic" i <https://www.dataprivacyframework.gov/list> gav "Query returned no results" 2026-09-02 (sökfunktionen kontrollerad med Cloudflare och Resend som gav träff). Anthropic PBC är alltså **inte** DPF-certifierat; överföringsgrunden är enbart SCC.
- Nyhet 2026-09-02 (The Register, <https://www.theregister.com/ai-and-ml/2026/09/02/anthropic-promises-zero-data-retention-but-customers-must-check-it-worked/5293789>): Anthropic lanserar "Enterprise Frontier Safeguards" för Fable 5.1 under hösten 2026 och påpekar att ZDR måste sökas aktivt. Berör inte BokPilots modeller.
- Om BokPilots organisation i dag har ZDR aktiverat (beslut 2026-07-05 enligt registerförteckningen) framgår inte av något jag kan läsa — **ej verifierat**; kontrolleras i avtalsvillkoren eller hos kontoansvarig.

**Alternativ.**
a) Behåll Anthropics API med ZDR + SCC modul 3 + TIA + innehållsminimering (ingen lönedata).
b) Behåll med standardlagring 30 dagar i USA — enklare men PUB måste ange lagringen och BFL-frågan om tillfälliga kopior utomlands (granskningsanteckning 5) kvarstår.
c) Anropa Claude via Amazon Bedrock eu-central-1 — data stannar i EU, AWS blir biträde; kräver omskrivning av `_shared/claudeChat.ts`/`claudeOcr.ts`, annan prissättning och avtal med AWS.
d) EU-baserad modelleverantör — kvalitets- och verktygsbyte.

**Rekommendation.** **Behåll Anthropic med Anthropic Ireland, Limited som avtalspart, begär nollagring för organisationen hos säljteamet och få den bekräftad skriftligt, och skriv i klienternas biträdesavtal att behandlingen sker i USA under SCC modul 3 utan DPF, med undantaget att flaggat innehåll kan bevaras i upp till två år.**

**Vad som ska stå i klienternas biträdesavtal (PUB Bilaga 1 punkt 7 och Bilaga 2 rad 2).**
1. Underbiträde: Anthropic Ireland, Limited (Irland); behandling utförs av Anthropic, PBC och dess infrastrukturleverantörer (AWS, Google Cloud, Microsoft Azure) i USA; underbiträdeslista på trust.anthropic.com/subprocessors; 15 dagars invändningsfrist.
2. Överföringsgrund: standardavtalsklausulerna (EU) 2021/914 modul 3 enligt Anthropics DPA (2025-02-24); ingen DPF-certifiering; överföringskonsekvensbedömning finns hos byrån.
3. Lagring: nollagring — indata och utdata lagras inte i vila efter att svaret lämnats (eller, om ZDR inte beviljats: radering inom 30 dagar); innehåll som flaggas av Anthropics säkerhetssystem kan bevaras upp till två år och klassificeringspoäng upp till sju år.
4. Ingen modellträning på klientens data; inga automatiserade beslut (art. 22); utdata granskas av byrån.
5. Teknisk instruktion: endast Messages API med inline-dokument; Batch API, Files API, code execution och MCP connector används inte; modeller som kräver 30 dagars lagring (Covered Models) används inte utan klientens godkännande.
6. Dataminimering: underlag, kontoplan och byråns instruktioner skickas; inga personnummer, bankkonton eller frånvarouppgifter ur lönemodulen om inte klienten instruerat det (granskningsanteckning 8).
7. Klienten kan stänga av AI-tolkningen (PUB 7.4).

**Konsekvens vid fel val.** Att skriva "nollagring" utan att den är aktiverad, eller "DPF-certifierat", är oriktiga uppgifter till personuppgiftsansvariga (art. 5.2 och 28.3). Utan TIA saknas underlag vid tillsyn. Alternativ b lämnar BFL-frågan om kopior utomlands öppen.

**Vad som krävs för att verkställa.** Kontakta säljteamet och begär ZDR för organisationen (i BokPilot AB:s namn); bekräfta i Console → Settings → Privacy/Workspaces att inga arbetsytor har 30-dagarsöverstyrning; kontrollera i koden att inga ZDR-undantagna funktioner används; skriv TIA (USA, SCC, kryptering i transit, nollagring, ingen träning); uppdatera PUB Bilaga 1 §7.3, Bilaga 2 rad 2 ("DPF-certifiering: nej"), registerförteckningen B4 och 6.1 (stryk "DPF [verifiera]", ange "ingen DPF").

---

## 5. Resend (e-postutskick)

**Fråga.** Var lagras innehåll och loggar när EU-regionen används, vilka underbiträden finns, gäller DPF/SCC — och ska byrån behålla Resend eller byta till EU-leverantör?

**Verifierade fakta.**

- Regioner: utskick kan ske från us-east-1, eu-west-1 (Irland), sa-east-1 och ap-northeast-1; "all account data, including email metadata, logs, and API records" lagras i USA oavsett vald region. Källa: <https://resend.com/docs/dashboard/domains/regions>, läst 2026-09-02.
- DPA uppdaterat 2026-08-27: avtalspart Plus Five Five, Inc., 2261 Market Street #5039, San Francisco; överföring under EU- och UK-SCC samt EU-U.S. DPF; underbiträdeslista på /legal/subprocessors; kunddata raderas inom 90 dagar efter kontots avslut. Källa: <https://resend.com/legal/dpa>, läst 2026-09-02.
- Privacy Policy 2026-08-27: behandling i USA. Källa: <https://resend.com/legal/privacy-policy>.
- Underbiträden (uppdaterad 2026-08-27, <https://resend.com/legal/subprocessors>): 22 stycken, samtliga i USA — AWS (hosting och utsändning), Anthropic PBC (AI), Attio, Cloudflare, Datadog, Elastic, Estuary, Google, Inngest, Liveblocks, Metabase, Plain, PlanetScale, Retool, RunPod (egenhostade språkmodeller), Salesforce/Slack, Snowflake, Stripe, Supabase Inc (databas och autentisering), Svix, Tinybird, Vercel.
- DPF-registret: "Resend" (San Francisco) står som *Active – Re-certification under Review* för EU-U.S. DPF och UK-tillägget, icke-HR-data. Källa: <https://www.dataprivacyframework.gov/list>, sökning "Plus Five Five" 2026-09-02.
- Lagringstiden 30 dagar för meddelande- och loggdata som anges i PUB Bilaga 1 §9 kunde inte återfinnas i DPA eller privacy policy — **ej verifierat**.
- Vad BokPilot skickar: inbjudningar, notiser, påminnelser, lösenordsåterställning (PUB Bilaga 2 rad 3); PUB 8.2 förbjuder redan lönebelopp, personnummer och bankuppgifter i meddelandetext.
- EU-alternativ enligt jämförelsesidor (leverantörernas egna påståenden, **ej verifierade var för sig**): Scaleway Transactional Email (Frankrike), Brevo (Frankrike), Mailjet/Sinch, Postkit (Hetzner Wien/Frankfurt), Lettermint (Nederländerna), Remails. Källor: <https://eualternative.eu/categories/transactional-email/>, <https://postscale.io/blog/eu-email-api-gdpr-comparison>, lästa 2026-09-02.

**Alternativ.**
a) Behåll Resend: DPF (aktiv men under omcertifiering) med SCC som reserv, kort TIA, innehållsminimering, dokumentera USA-lagring av loggar i PUB (finns redan).
b) Byt nu till EU-leverantör (Scaleway TEM eller Brevo): all data i EU, enklare biträdeskedja; kräver byte av API-anrop i de edge-funktioner som skickar e-post, ny domänverifiering och IP-uppvärmning.
c) Skicka via byråns Microsoft 365-tenant (Graph API, EU Data Boundary) — ett biträde färre men sämre lämpat för systemnotiser i volym.

**Rekommendation.** **Behåll Resend under 2026 med DPF/SCC och strikt innehållsminimering (endast namn, e-postadress och hänvisning till inloggning), och lägg byte till en EU-leverantör (Scaleway Transactional Email eller Brevo) som backlogpunkt att genomföra innan BokPilot säljs till andra byråer eller om en klient invänder.**

**Konsekvens vid fel val.** Att behålla utan minimering lägger namn och notistext hos 22 amerikanska underbiträden, däribland en AI-leverantör — en klients dataskyddsombud kan invända och tvinga fram bytet ändå. Att byta nu kostar utvecklingstid mitt i go-live och riskerar leveransbarheten under uppvärmningen.

**Vad som krävs för att verkställa.** Kontrollera `notification_templates` och utskicksfunktionerna så att inga personnummer, belopp eller bilagor går med; arkivera DPA och underbiträdeslistan (2026-08-27) och notera DPF-statusen med datum; bekräfta Resends faktiska logglagringstid och ändra PUB Bilaga 1 §9 om 30 dagar inte kan beläggas; sätt bevakning på DPF-omcertifieringen (kontroll vid årlig genomgång).

---

## 6. PEP- och sanktionsscreening

**Fråga.** Vilken tjänst ska byrån använda för PEP/RCA- och sanktionskontroll (3 kap. 10 § PTL) när BokPilot registrerar källa, datum och utfall men inte själv screenar?

**Verifierade fakta (alla lästa 2026-09-02).**

| Tjänst | Listtäckning | API | Löpande bevakning | Prisbild | Källa |
|---|---|---|---|---|---|
| **UC / Allabolag** (UC Affärsinformation AB, Enento) | EU, FN, Storbritannien, OFAC (CSL och SDN) samt nordisk PEP-lista inkl. nära medarbetare och anhöriga (RCA); "globala och nordiska PEP-listor" enligt UC:s artikel | Ja, "API-integration för automatiserad screening" och webbgränssnitt | UC bevakar listorna; bevakning per kund **ej verifierad** | Allabolag: 1 500 sökningar för 7 196 kr (ord. 8 995 kr) ≈ 4,80–6 kr/sökning | <https://www.uc.se/pep-sanktionslistor>; <https://www.allabolag.se/info/pep-och-sanktionslistor/>; <https://www.uc.se/kunskap-inspiration/artiklar/UCs-tjanst-for-pep-och-sanktionslistor> (2024-01-09) |
| **Creditsafe** | >1 000 källor: EU, FN, UK, OFAC, HM Treasury; >800 000 PEP med RCA; Interpol/FBI | Ja | Ja, realtidsuppdatering och larm | Offert (sales@creditsafe.se) | <https://www.creditsafe.com/se/sv/compliance/kyc/pep-sanktionskontroll.html> |
| **Roaring** | Sanktions-API: EU, OFAC (SDN, CSL m.fl.), FN, UK, SECO; PEP/RCA-screening erbjuds men källa **ej verifierad** | Ja (API-first, sandbox gratis) | "Löpande uppföljning" | Från 1 495 kr/mån plus förbrukning, 30 dagars uppsägning | <https://www.roaring.io/pris>; <https://developer.roaring.io/docs/apis/global-sanctions-lists-3.0> |
| **ComplyAdvantage** | Sanktioner och watchlists, PEP/RCA, adverse media | Ja | Ja | Starter från 99 USD/mån för 100 bevakade enheter, självbetjäning | <https://complyadvantage.com/pricing/> |
| **Trapets (InstantWatch)** | Sanktioner, PEP/RCA, UBO, adverse media | Ja | Ja | Offert, inget publikt pris | <https://www.trapets.com/solutions/screening/screening-lists> |
| **Pliance** | UN, EU, DFAT, HMT, OFAC m.fl. | Ja | — | Förvärvat av Verified 2023-11-05; inget publikt pris | <https://verified.eu/pliance> |
| Bisnode/Dun & Bradstreet, Bolagsfakta | — | — | — | **Ej verifierat** — ingen svensk produktsida med PEP-screening hittades | — |

Byråverktyg med inbyggd KYC (relevanta som jämförelse, men dubblerar BokPilots KYC-modul): Blikk KYC från 15 kr/mån och kund (PEP, RCA, SIP, EU:s sanktionslistor, bevakning, BankID, API; kräver Blikk Byrå) — <https://www.blikk.se/funktioner/kyc-aml>; Spiris KYC 199 kr/år och kund (kräver Byråstöd) — <https://www.spiris.se/redovisningsbyra/byrastod/kyc>; Lundify/Due Compliance 16 650 kr/år för en användare (sanktioner, PEP, bevakning, BankID, API) — <https://bjornlunden.com/se/juridik-och-kunskap/due-compliance/for-redovisningsbyran/>. Srf-partnerrabatter: Due Compliance 20 %, Blikk 15 %, Penneo 25 % (<https://srfkonsult.se/for-branschen/srf-partners/>; Penneo-sidan gav 404 — **ej verifierat**).

Gratisalternativ: EU:s konsoliderade sanktionslista och FN:s lista är öppna, men det finns ingen officiell PEP-lista — manuell screening täcker därför inte 3 kap. 10 § och saknar RCA.

**Alternativ.**
a) UC/Allabolag: lägst kostnad, svensk källa med RCA, webb nu och API senare.
b) Creditsafe: bredast täckning och bevakning, offertpris — rimligt när API-integration med `kyc_assessments` ska byggas.
c) ComplyAdvantage Starter: självbetjäning och bevakning, men USD-prissättning och amerikansk leverantör (ny tredjelandsöverföring av företrädares personuppgifter).
d) Byråverktyg (Blikk/Spiris/Lundify): billigt per kund men ett parallellt KYC-system utanför BokPilot.

**Rekommendation.** **Teckna UC:s PEP- och sanktionslistor via Allabolag-paketet (ca 6 kr/sökning) nu, screena kund, företrädare och verkliga huvudmän vid onboarding och vid varje uppföljning enligt riskprofilen, registrera källa/datum/utfall i `kyc_assessments` (`sanktionslista_kalla`/`pep_kalla` = "UC", datum, `pep_traff`/`sanktion_traff`) med utskriften som bilaga av typ `sanktionskontroll`/`pep_kontroll`, och utvärdera Creditsafes API när löpande bevakning ska byggas in i BokPilot.**

**Konsekvens vid fel val.** Ingen eller ofullständig screening är den brist Länsstyrelsen sanktionerar (jämför besluten mot Postulat AB och Y-Ekonomi AB som riskbedömningen citerar); en enterprise-tjänst kostar 15–25 tkr/år för ett fåtal klienter utan att BokPilot kan nyttja den förrän API-integrationen finns.

**Vad som krävs för att verkställa.** Beställ via kontaktformuläret; ange leverantören i riskbedömningen 6.1 punkt 4 och registerförteckningen A3/6.1 (UC är kreditupplysningsföretag och sannolikt självständigt ansvarig för själva sökningen — bedöm rollen); besluta frekvens (onboarding, uppföljning, vid händelse) i rutinen; dokumentera att ingen officiell PEP-lista finns och att UC valts som källa.

---

## 7. Identitetskontroll på distans (01FS 2024:20, tabell 1)

**Fråga.** Vad kräver Länsstyrelsens föreskrifter exakt vid distansidentifiering, vad ska dokumenteras och sparas, och vilken standardrutin ska BokPilot ha?

**Verifierade fakta.** Föreskriften 01FS 2024:20 (beslutad 2024-05-27, i kraft 2024-07-01, ersätter 01FS 2021:36) lästes i sin helhet på <https://www.lansstyrelsen.se/stockholm/om-oss/om-lansstyrelsen-stockholm/lanets-forfattningssamling/forfattningar-2024/forfattningssamling-2024/2024-06-03-01fs-202420.html> 2026-09-02 (PDF: <https://www.lansstyrelsen.se/download/18.707df2a018f9ec7c62149421/1717509242057/01FS%202024-20.pdf>). Den gäller verksamhet enligt 1 kap. 2 § första stycket 16, 17, 19, 20 och 22–24 PTL; punkt 19 är bokföringstjänster och punkt 20 skatterådgivning (<https://lagen.nu/2017:630>, läst 2026-09-02).

- *3 kap. 3 § — identifiering*: fysisk person: namn, personnummer/samordningsnummer eller motsvarande samt adress; juridisk person: namn, organisationsnummer, registrerad adress och företrädare; ombud identifieras på samma sätt.
- *3 kap. 4 § — kontroll av identitet*: utförs och dokumenteras enligt tabellen, oavsett kundens risknivå och även om kunden är känd eller offentlig; dokumentationen ska visa när kontrollen gjordes.

| Vem | Kontrollmetod | Dokumentation som ska bevaras |
|---|---|---|
| Fysisk person (på plats) | (1) pass, körkort eller annan fotoförsedd id-handling från myndighet/behörig utfärdare, (2) tillförlitlig elektronisk legitimation, eller (3) andra dokument/uppgifter från oberoende, tillförlitliga källor (flera källor vid tveksamhet) | (1) handlingens nummer och giltighetstid antecknas eller kopia bevaras; (2) kopia av bekräftelsen på e-legitimationen; (3) kopia av underlaget |
| **Fysisk person på distans** | (1) tillförlitlig elektronisk legitimation, **eller** (2) namn, personnummer och adress kontrolleras mot externa register, intyg eller andra oberoende källor och därefter (a) bekräftelse skickas till folkbokföringsadressen, eller (b) vidimerad kopia av id-handling inhämtas — vidimeringen ska visa att någon annan än kunden intygat med namnteckning, namnförtydligande och kontaktuppgifter att kopian stämmer | kopia av e-legitimationsbekräftelsen; kopia av underlaget samt av bekräftelsebrevet eller den vidimerade kopian |
| Företrädare, ombud | som fysisk person/på distans **plus** fullmakt, förordnande eller motsvarande behörighetshandling | samma som ovan plus kopia av behörighetshandlingen |
| Juridisk person | registreringsbevis, registerutdrag eller uppgifter från andra tillförlitliga, oberoende källor | kopia av de kontrollerade handlingarna |
| Verklig huvudman | som fysisk person/på distans | som fysisk person/på distans |

- *Allmänna råd till 3 kap. 4 §*: registreringsbevis/registerutdrag bör vara högst en vecka gammalt och det bör framgå att uppgifterna kommer från Bolagsverkets näringslivsregister; identitetskontrollen kan normalt begränsas till den företrädare med firmateckningsrätt som företräder bolaget mot byrån; kontroll i registret över verkliga huvudmän utesluter inte ytterligare kontroller.
- *3 kap. 7 § och 5 kap. 1–2 §§*: dokumentationen bevaras i fem år från åtgärden eller från affärsförbindelsens upphörande, ordnad och sökbar; på begäran av Polismyndigheten eller annan behörig myndighet förlängs tiden, sammanlagt högst tio år.
- **Videomöte nämns inte som kontrollmetod.** Ett videomöte kan vara en skärpt åtgärd (3 kap. 6 § allmänna råd) men ersätter inte e-legitimation eller registerkontroll + bekräftelse/vidimering. Riskbedömningens ställningstagande 4 ("videomöte som standard") är därför ett frivilligt tillägg.
- BokPilots fält (schema 2026-09-02): `kyc_assessments.identitetshandling_typ` ∈ {pass, nationellt_id, korkort, bankid, annat}, `identitetshandling_referens`, `identitetshandling_utfardare`, `identitetshandling_giltig_till`, `sanktionslista_kalla/datum`, `pep_kalla/datum`; `kyc_bilagor.typ` ∈ {identitetshandling, huvudman, registerutdrag, sanktionskontroll, pep_kontroll, ovrigt}; `kyc_huvudman.kontrollsatt` ∈ {bolagsverket, registerutdrag, agarforteckning, intyg, annat} (avser hur ägandet utretts, inte identitetskontrollen); bucket `kyc` med sökväg `<company_id>/<kyc_id>/<uuid>`; bevarande via `kyc_arkiv` (etapp 16).

**Alternativ.**
a) E-legitimation som standard: uppdragsavtal och KYC-förklaring signeras med BankID i en e-signeringstjänst; signeringsbeviset (namn, personnummer, tidpunkt, transaktions-id) är "bekräftelsen på den elektroniska legitimationen".
b) Registerkontroll (SPAR/UC) + vidimerad kopia av id-handling per post eller skanning.
c) Registerkontroll + bekräftelsebrev till folkbokföringsadressen.
d) Fysiskt möte med id-handling (kopia eller nummer/giltighetstid antecknas).

**Rekommendation.** **Gör BankID-signering av uppdragsavtalet och en KYC-förklaring via e-signeringstjänst till standardmetod för företrädare och verkliga huvudmän på distans, med SPAR-kontroll plus vidimerad id-kopia som reservmetod, och spara signeringsbeviset som bilaga av typ `identitetshandling` med `identitetshandling_typ = bankid`.**

Standardrutin för BokPilot:
1. *Juridisk person*: hämta registreringsbevis eller registerutdrag från Bolagsverket samma vecka som kontrollen → bilaga `registerutdrag`; kontrollera företrädare och firmateckning mot utdraget; fullmakt vid ombud → bilaga `ovrigt` (behörighetshandling).
2. *Företrädare på distans*: BankID-signering av uppdragsavtal + KYC-förklaring. Registrera `identitetshandling_typ = bankid`, `identitetshandling_referens` = signeringens transaktions-/referensnummer, `identitetshandling_utfardare` = "BankID via [tjänst]", `identitetshandling_giltig_till` lämnas tom; ladda upp bevis-PDF:en som bilaga `identitetshandling`. Reserv: SPAR/UC-kontroll av namn, personnummer och adress + vidimerad kopia av pass/körkort (typ pass/nationellt_id/korkort, nummer och giltighetstid i fälten, kopian som bilaga) eller bekräftelsebrev till folkbokföringsadressen (kopia av brevet som bilaga `ovrigt`).
3. *Verklig huvudman*: utdrag ur Bolagsverkets register över verkliga huvudmän → bilaga `huvudman`; egen utredning (aktiebok/ägarschema) → `kyc_huvudman.kontrollsatt`; identitetskontroll av varje huvudman enligt punkt 2 (BankID-signerad huvudmannaförsäkran eller vidimerad kopia) → bilaga `huvudman`/`identitetshandling`. Observera att `kyc_huvudman` saknar fält för identitetskontrollens metod och datum — anteckna det i bilagan tills fält finns (backlog).
4. *PEP/sanktion*: enligt avsnitt 6 → `sanktionslista_kalla/datum`, `pep_kalla/datum`, bilagor `sanktionskontroll`/`pep_kontroll`.
5. *Tidpunkt och person*: kontrollens datum registreras i `kyc_assessments` (tidsstämpel och audit-trigger finns sedan etapp 12/13).
6. *Skärpta åtgärder vid hög risk*: videomöte eller fysiskt möte som tillägg, fler källor, tätare uppföljning.
7. *Bevarande*: fem år efter affärsförbindelsens slut via `kyc_arkiv` och bucketen `kyc`; förlängning endast på myndighets begäran (max tio år).

**Konsekvens vid fel val.** Att förlita sig på videomöte eller på en skärmdump av BankID-inloggning utan bevarad bekräftelse uppfyller inte tabellens dokumentationskrav — precis den typ av brist som ligger till grund för Länsstyrelsens sanktionsbeslut. Att kräva fysiskt möte gör digital onboarding (kanal D1) omöjlig.

**Vad som krävs för att verkställa.** Välj e-signeringstjänst med BankID (Srf-partner Penneo med 25 % rabatt, Scrive, Assently eller Verified — pris **ej kontrollerat**); ta fram KYC-förklaring (syfte och art, huvudmannaförsäkran, PEP-fråga) som signeras tillsammans med uppdragsavtalet; skriv rutindokumentet med hänvisning till tabellen ovan; uppdatera riskbedömningen 2.4 D1 och 6.1 punkt 2 (stryk "videomöte som standard", ange metod och reserv), uppdragsavtalet 12.2 och Bilaga F, registerförteckningen A3 (ID-tjänst och lagringsplats för kopior = bucket `kyc`).

---

## 8. Bevarandetider för loggtabeller som inte gallras i dag

**Fråga.** Vilken bevarandetid ska gälla för `mcp_audit_log` (196 rader), `konsol_audit_logg` (90), `ai_call_log` (65), `system_error_log` (6), `platform_audit_log` (223), `download_audit_log` (2), `stripe_event_log` (0) och `bokslut_ai_suggestions` (0), med vilken rättslig grund, och ska raderingen vara fysisk eller anonymisering? `audit_log` ingår inte (behandlingshistorik enligt 5 kap. 11 § BFL, bevaras sju år).

**Verifierade fakta.**

- Kolumner enligt `schema/tables.sql` (2026-09-02): `mcp_audit_log` (user_id, company_id, tool, params jsonb, status, error), `konsol_audit_logg` (admin_user_id, admin_email, action, company_id, params jsonb), `ai_call_log` (user_id, company_id, document_id, created_at), `system_error_log` (component, message, severity, error_code, metadata jsonb, company_id), `platform_audit_log` (actor_email, actor_id, action, target, detail jsonb), `download_audit_log` (user_id, company_id, section, kind, file_count), `stripe_event_log` (event_id, type, created_at), `bokslut_ai_suggestions` (engagement_id, company_id, suggestion_type, title, summary, reasoning, risk_level, confidence, source_data jsonb, status, model, reviewed_by, reviewed_at, review_comment).
- `gallra_gdpr_loggar()` (pg_cron 03:40) gallrar i dag bara `assistent_logg`, `robo_bp_messages`, `support_ai_events`, `kivra_utskick` (24 mån) och `inbound_email_log` (12 mån) (`schema/functions.sql`).
- `konsol_audit_logg` är append-only sedan etapp 15 (trigger `konsol_audit_appendonly`, felkod `KONSOL_LOGG_APPENDONLY`); `platform_audit_log` överlever bolagsradering avsiktligt (etapp 8) och innehåller posterna om avveckling och `kyc_archived` (etapp 16). Källa: `docs/inventering.md`.
- Rättsliga utgångspunkter: lagringsminimering (art. 5.1 e GDPR) kräver en fastställd, motiverad tid per ändamål; säkerhetsloggning vilar på art. 6.1 f och art. 32; räkenskapsinformation och behandlingshistorik bevaras till och med sjunde året efter räkenskapsårets utgång (7 kap. 2 § och 5 kap. 11 § BFL); kundkännedom fem år, högst tio (5 kap. 3–4 §§ PTL, 01FS 2024:20 5 kap.); allmän preskriptionstid för fordringar och skadeståndsanspråk tio år (2 § preskriptionslagen 1981:130), vilket är den relevanta gränsen för bevisändamål.

**Förslag.**

| Tabell | Innehåll (personuppgifter) | Bevarandetid | Rättslig grund | Radering |
|---|---|---|---|---|
| `mcp_audit_log` | Användar-id, bolag, verktyg, parametrar (kan innehålla bokförings- och fritextdata), fel | **24 månader**; `params` och `error` nollställs efter 12 månader | Art. 5.1 e, 6.1 f och 32 — säkerhet, missbruksutredning, felsökning. Bokföringsändringar som MCP-anrop lett till finns redan i `audit_log` (BFL). | Tvåstegs: anonymisering av parametrar vid 12 mån, fysisk radering vid 24 mån |
| `konsol_audit_logg` | Operatörens id/e-post, åtgärd, bolag, parametrar | **10 år** | Bevis för operatörens åtgärder gentemot klient och byrå (preskriptionslagen 2 §); åtgärder som rör KYC omfattas av PTL 5 kap.; behandlingshistorik om åtgärden ändrat bokföringsdata (BFL 5 kap. 11 §) | Fysisk radering efter 10 år via sanktionerad väg — append-only-triggern behöver ett undantag för utgången bevarandetid (som `kyc_arkiv`) |
| `ai_call_log` | Användar-id, bolag, dokument-id, tidpunkt | **12 månader** | Art. 5.1 e; kvotstyrning och underlag för AI-tillägg. Blir AI-användning fakturerad räcker månadsaggregat som fakturaunderlag (BFL) — aggregera innan radering | Fysisk radering |
| `system_error_log` | Komponent, meddelande, metadata (kan innehålla fritext), bolag | **12 månader** | Art. 32 och 6.1 f — drift och incidentutredning | Fysisk radering |
| `platform_audit_log` | Plattformsadministratörens e-post/id, åtgärd, mål, detalj | **10 år** | Bevis för bolagsavveckling (kedjan till BFL 7 kap. 2 §), `kyc_archived` (PTL 5 kap. 3–4 §§), behörighetsbeslut; preskriptionslagen 2 § | Fysisk radering efter 10 år; överlever bolagsradering (avsiktligt) |
| `download_audit_log` | Användar-id, bolag, sektion, typ, antal filer | **7 år efter utgången av nedladdningsåret** | Bevis för att räkenskapsinformation lämnats ut/överlämnats (BFL 7 kap.; uppdragsavtalet 7.7 och 14) | Fysisk radering; kaskad vid bolagsradering accepteras |
| `stripe_event_log` | Händelse-id och typ (inga personuppgifter) | **24 månader** — eller ta bort tabellen om Stripe inte tas i bruk | Art. 5.1 e; dedup av webhooks. Inte bokföringsunderlag (saknar belopp och kund) | Fysisk radering |
| `bokslut_ai_suggestions` | AI-förslag med resonemang, granskare, kommentar | **7 år efter räkenskapsårets utgång** för granskade förslag; **24 månader** för aldrig granskade eller avvisade | Uppdragsdokumentation/kvalitetskontroll enligt Rex (bevarandekravet **ej verifierat**, se avsnitt 1); BFL 7 kap. 2 § när förslaget ligger till grund för bokslutsverifikation; art. 5.1 e | Fysisk radering; kaskad med bolaget först efter BFL-tiden |

Anonymisering rekommenderas inte som huvudmetod: raderna behövs inte för statistik, och fysisk radering är enklare att visa vid tillsyn. Undantaget är `mcp_audit_log`, där parametrarna är det känsliga innehållet medan raden i sig (vem, vilket verktyg, när) har ett längre säkerhetsvärde.

**Rekommendation.** **Fastställ tiderna i tabellen (12 mån drift- och AI-kvotloggar, 24 mån MCP- och Stripe-loggar med tvåstegsgallring av MCP-parametrar, 7 år nedladdnings- och granskade bokslutsförslag, 10 år plattforms- och operatörslogg), radera fysiskt, och utöka `gallra_gdpr_loggar()` med ett triggerundantag för de append-only-tabellerna.**

**Konsekvens vid fel val.** Ingen fastställd tid bryter mot art. 5.1 e och låter fritext ackumuleras; för korta tider för `platform_audit_log`/`konsol_audit_logg` raderar beviset för avvecklingar och KYC-arkivering innan preskriptionstiden löpt ut; sju år på allt gör loggarna till personuppgiftsbehandling utan ändamål.

**Vad som krävs för att verkställa.** Migration som (1) utökar `gallra_gdpr_loggar()` med de åtta tabellerna, (2) lägger nollställning av `mcp_audit_log.params/error` efter 12 mån, (3) ger `konsol_audit_appendonly` ett undantag för DELETE av rader äldre än 10 år när anropet kommer från gallringsjobbet, (4) beslutar Stripe-tabellens öde; uppdatera PUB Bilaga 1 §9 ("Loggar över AI-anrop [90] dagar" → 12 mån; lägg till MCP 24 mån), registerförteckningen A6-tabellen och Bilaga 2, samt gallringsrutinen; kör en första gallring manuellt och logga utfallet.

---

## Tillägg: Bolagsverkets register mot penningtvätt och goAML

**Bolagsverket — verifierat.** Sökning på 5591658181 i e-tjänsten Sök företagsinformation, fliken Registret mot penningtvätt (<https://foretagsinfo.bolagsverket.se/sok-foretagsinformation-web/registretmotpenningtvatt>, utan inloggning och utan avgift, 2026-09-02) visar:

- AcountX Redovisningsbyrå AB, 559165-8181 — **registrerat i registret mot penningtvätt 2024-07-03**
- Säte: Stockholms län; tillsynsmyndighet: Länsstyrelsen i Stockholms län
- Verksamhet: bokförings- och redovisningstjänster

Skatterådgivning (1 kap. 2 § första stycket 20 PTL) är **inte** registrerad. Lämnar byrån rådgivning i avsikt att påverka skattens storlek ska en ändringsanmälan göras (riskbedömningens ställningstagande 2). Avgifter: anmälan 1 300 kr, ändring 1 300 kr, avregistrering 0 kr (<https://bolagsverket.se/sjalvservice/avgifter/avgifterochpriserforovriga/avgifterforregistretmotpenningtvatt.4401.html>, uppdaterad 2026-03-06). Anmälan görs på blankett 705 som laddas upp och signeras med e-legitimation i e-tjänsten via verksamt.se (<https://bolagsverket.se/omoss/flerverksamheter/registretmotpenningtvatt.2557.html>, uppdaterad 2025-02-27).

Så kontrollerar Elias själv på två minuter: öppna adressen ovan → fliken "Registret mot penningtvätt" → skriv 5591658181 i fältet Organisationsnummer → klicka på förstoringsglaset (Enter räcker inte). Att fylla i uppdragsavtalet 12.1: "registrerad i Bolagsverkets register mot penningtvätt sedan 2024-07-03 och står under tillsyn av Länsstyrelsen i Stockholms län".

**goAML — kan inte verifieras utifrån.** Finanspolisens rapporteringsportal <https://fipogoaml.polisen.se/Home> kräver inloggning; om AcountX är registrerat syns bara inifrån. Registrering: klicka "Registrera" på portalen (registreringsformuläret ligger under /Content/#/register), registrera organisationen (org.nr, kontaktuppgifter, typ av verksamhetsutövare) och en första användare; Finanspolisen måste godkänna registreringen innan inloggning är möjlig, därefter kan byrån själv lägga till användare; manual finns på portalens Hjälp-sida (<https://fipogoamlsupport.polisen.se/Home>; polisen.se, sidan Finanspolisen granskad 2026-08-20, läst 2026-09-02). Enligt Finanspolisens äldre FAQ (2022) godkänns korrekt ifyllda registreringar inom två arbetsdagar — **ej verifierat i nuvarande material**. Rekommendation: registrera organisation och Elias som användare nu, så att en rapport enligt 4 kap. 3 § PTL kan lämnas utan dröjsmål; anteckna registreringsdatum i riskbedömningen 6.5.

---

## Ändringar i utkasten till följd av det som verifierats

1. **Standard**: "Reko" → "Rex" i PUB (1.1, 1.3 b, Bilaga 1 §9), registerförteckningen (3.3, Bilaga 2) och uppdragsavtalet (alla "[Reko/Rex]"); "Reko 140" ersätts med korrekt Rex-hänvisning efter kontroll.
2. **Systemleverantör**: registerförteckningen 3.1 → alternativ a; 6.1 rad 1 (BokPilot AB) fylls i; PUB Bilaga 2 får BokPilot AB som rad 1; uppdragsavtalet 6.1/6.12/15.5 enligt alternativ a.
3. **Supabase**: registerförteckningen 3.2 och 6.1 anger "Supabase, Inc." — ändra till Supabase Pte. Ltd (avtalspart) med Supabase, Inc. som supportbolag i USA; ange ToS v3 och DPA v1 (2026-08-01); underbiträdeslista 2026-06-01. PUB Bilaga 2 rad 1 är redan korrekt (Pte. Ltd) — stryk klammern.
4. **Anthropic**: stryk alla "DPF [verifiera]" — Anthropic finns inte i DPF-listan; ange SCC modul 3 som enda grund; skriv in att ZDR är begärd/bekräftad (datum) i PUB Bilaga 1 §7.3 och Bilaga 2 rad 2; notera att modellerna Haiku 4.5/Sonnet 5 inte är Covered Models; underbiträdeslistan är trust.anthropic.com/subprocessors (GCP/AWS/Azure "Worldwide").
5. **Resend**: DPF-status "Active – Re-certification under Review" (2026-09-02); 30 dagars logglagring är ej belagd — ändra till "enligt Resends villkor [kontrollera]" tills den bekräftats; underbiträdeslistan (22 amerikanska bolag, inkl. Anthropic PBC och Supabase Inc) arkiveras.
6. **PEP/sanktion**: fyll i UC Affärsinformation AB som källa i riskbedömningen 6.1 punkt 4, registerförteckningen A3 och 6.1.
7. **Identitetskontroll**: riskbedömningen 2.4 D1 och 6.1 punkt 2 samt ställningstagande 4: BankID-signering som standard, SPAR + vidimerad kopia som reserv, videomöte endast som skärpt åtgärd; ange e-signeringstjänst i registerförteckningen A2/A3/B6.
8. **Bevarandetider**: registerförteckningen A6-tabellen och Bilaga 2, PUB Bilaga 1 §9 enligt avsnitt 8; stryk "7 år om händelserna utgör bokföringsunderlag" för `stripe_event_log`.
9. **Penningtvättsregistrering**: uppdragsavtalet 12.1 → "sedan 2024-07-03", "Länsstyrelsen i Stockholms län"; riskbedömningen 6.11 och ställningstagande 1 kan bockas av; skatterådgivning är inte registrerad.
10. **Supabase-plan**: registerförteckningen A6 "[verifiera antal dagar på Pro-planen]" — organisationen ligger på Pro (verifierat), loggdagarna kvarstår att kontrollera i dashboarden.

## Fakta som inte kunde verifieras

- Att Elias inte är FAR-medlem (FAR:s sök kräver inloggning).
- Vilket bolag som är fakturamottagare hos Supabase, Anthropic, Resend, Cloudflare och Fly.io.
- Supabases rutin för supportåtkomst (var personalen sitter, om åtkomst kräver kundens medgivande) och innehållet i underbiträdeslistans platskolumn (PDF:en avkodades lokalt).
- Om BokPilots Anthropic-organisation har ZDR aktiverat i dag; om Anthropics EU-behandling via Bedrock/Vertex uppfyller kraven (tredjepartskällor).
- Resends faktiska lagringstid för loggar (30 dagar enligt PUB-utkastet) och utfallet av DPF-omcertifieringen.
- Roarings PEP/RCA-källa, Creditsafes, Trapets och Pliance/Verifieds priser, Penneos villkor (sida 404), Bisnode/D&B och Bolagsfakta som PEP-leverantörer, UC:s bevakning per kund.
- Rex exakta bevarandekrav för uppdragsdokumentation.
- goAML: nuvarande handläggningstid och om AcountX redan är registrerat.
- AWS DPF-status och Cloudflares (Cloudflare, Inc. är aktiv i DPF-listan för EU, Schweiz och UK per 2026-09-02, men Data Localization Suite-frågan i registerförteckningen är oförändrad).

## Källförteckning (alla lästa 2026-09-02)

**Auktorisation och bolag**
- Srf konsulterna, konsultprofil: <https://temp.srfkonsult.se/konsult/elias-makdessielias/>
- Tidningen Konsulten 2025-12-03: <https://tidningenkonsulten.se/artiklar/certifieringen-gav-nya-perspektiv-och-har-gett-okat-fortroende-hos-kunderna/>
- Srf konsulterna, sök konsult: <https://www.srfkonsult.se/for-foretag/sok-byra-konsult>; FAR, sök medlem (inloggning): <https://www.far.se/medlem/sok-far-medlem/>
- Allabolag: <https://www.allabolag.se/5591658181>, <https://www.allabolag.se/5592081219>
- Skatteverket, rättslig vägledning om mervärdesskattegrupper: <https://www4.skatteverket.se/rattsligvagledning/421198.html>

**Supabase**
- Terms of Service v3 (2026-08-01): <https://supabase.com/terms>
- DPA v1 (2026-08-01): <https://supabase.com/legal/dpa> (= /legal/customer-resources/data-processing-addendum)
- Privacy Policy: <https://supabase.com/privacy>
- Underbiträdeslista 2026-06-01: <https://supabase.com/legal/customer-resources/subprocessor-list> (PDF /legal/subprocessor-list/June-1-2026.pdf)
- Säkerhet: <https://supabase.com/security>
- Supabase MCP (organisation "Bokpilot", plan pro), läsning 2026-09-02

**Anthropic**
- Commercial Terms (2025-06-17): <https://www.anthropic.com/legal/commercial-terms>
- DPA (2025-02-24): <https://www.anthropic.com/legal/data-processing-addendum>
- Underbiträden: <https://trust.anthropic.com/subprocessors>
- API and data retention (ZDR): <https://platform.claude.com/docs/en/manage-claude/api-and-data-retention>
- Data residency: <https://platform.claude.com/docs/en/manage-claude/data-residency>
- Lagringstid för organisationsdata (uppdaterad 2026-07-01): <https://privacy.claude.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data>
- Covered Models (i kraft 2026-06-09): <https://privacy.claude.com/en/articles/15425996-data-retention-practices-for-covered-models>
- The Register 2026-09-02: <https://www.theregister.com/ai-and-ml/2026/09/02/anthropic-promises-zero-data-retention-but-customers-must-check-it-worked/5293789>
- InfoQ 2026-07 om Claude i Europa (tredjepart): <https://www.infoq.com/news/2026/07/claude-foundry-ga-europe/>

**Resend**
- Regioner: <https://resend.com/docs/dashboard/domains/regions>
- DPA (2026-08-27): <https://resend.com/legal/dpa>; Privacy Policy (2026-08-27): <https://resend.com/legal/privacy-policy>; underbiträden (2026-08-27): <https://resend.com/legal/subprocessors>
- EU-alternativ (översikter): <https://eualternative.eu/categories/transactional-email/>, <https://postscale.io/blog/eu-email-api-gdpr-comparison>, <https://nuntly.com/alternatives/resend-eu>

**Data Privacy Framework**
- Deltagarlista med sökning: <https://www.dataprivacyframework.gov/list> (sökningar: Cloudflare = aktiv; Plus Five Five/Resend = aktiv, omcertifiering under granskning; Anthropic = inga träffar; Supabase = inga träffar)

**PEP/sanktion**
- UC: <https://www.uc.se/pep-sanktionslistor>; <https://www.uc.se/kunskap-inspiration/artiklar/UCs-tjanst-for-pep-och-sanktionslistor>
- Allabolag: <https://www.allabolag.se/info/pep-och-sanktionslistor/>
- Creditsafe: <https://www.creditsafe.com/se/sv/compliance/kyc/pep-sanktionskontroll.html>
- Roaring: <https://www.roaring.io/pris>; <https://www.roaring.io/lp/pep-api-sanctions-api>; <https://developer.roaring.io/docs/apis/global-sanctions-lists-3.0>
- ComplyAdvantage: <https://complyadvantage.com/pricing/>
- Trapets: <https://www.trapets.com/solutions/screening/screening-lists>
- Verified/Pliance: <https://verified.eu/pliance>
- Blikk: <https://www.blikk.se/funktioner/kyc-aml>; Spiris: <https://www.spiris.se/redovisningsbyra/byrastod/kyc>; Björn Lundén/Due Compliance: <https://bjornlunden.com/se/juridik-och-kunskap/due-compliance/for-redovisningsbyran/>
- Srf Partners (rabatter): <https://srfkonsult.se/for-branschen/srf-partners/>

**Penningtvätt — regelverk och register**
- 01FS 2024:20 (HTML och PDF): <https://www.lansstyrelsen.se/stockholm/om-oss/om-lansstyrelsen-stockholm/lanets-forfattningssamling/forfattningar-2024/forfattningssamling-2024/2024-06-03-01fs-202420.html>
- Lag (2017:630) om åtgärder mot penningtvätt och finansiering av terrorism (ändrad t.o.m. SFS 2026:1075): <https://www.riksdagen.se/sv/dokument-och-lagar/dokument/svensk-forfattningssamling/lag-2017630-om-atgarder-mot-penningtvatt-och_sfs-2017-630/>; <https://lagen.nu/2017:630>
- Bolagsverket, registret mot penningtvätt: <https://bolagsverket.se/omoss/flerverksamheter/registretmotpenningtvatt.2557.html>; avgifter: <https://bolagsverket.se/sjalvservice/avgifter/avgifterochpriserforovriga/avgifterforregistretmotpenningtvatt.4401.html>; sök i registret: <https://foretagsinfo.bolagsverket.se/sok-foretagsinformation-web/registretmotpenningtvatt>; verksamt.se: <https://verksamt.se/bransch/hitta-tillstand/tillstand/penningtvaett-anmael-till-registret-UKR127>
- Finanspolisen: <https://polisen.se/om-polisen/polisens-arbete/finanspolisen/>; goAML: <https://fipogoaml.polisen.se/Home>; goAML support: <https://fipogoamlsupport.polisen.se/Home>

**Lokala källor**
- `docs/inventering.md` (2026-09-02), `schema/tables.sql`, `schema/constraints.sql`, `schema/functions.sql`, `supabase/functions/` (modellnamn), samt granskningspunkterna i de fyra utkasten i denna mapp.
