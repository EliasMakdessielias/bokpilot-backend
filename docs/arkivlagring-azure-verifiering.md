# Arkivlagring: verifiering av Azure Blob Storage, Sweden Central

_Underlag för beslut om permanent arkiv av räkenskapsinformation._
_Verifierat mot primärkällor 2026-08-26. Varje slutsats har genomgått ett aktivt försök till motbevisning._

---

## 1. Håller det?

Ja — men inte till 100 %, och det är viktigare än ja:et.

Funktionellt håller Azure Blob Storage i Sweden Central för ändamålet: svensk placering är belagd ur Microsofts egen dokumentation, nio års bevarandetid ryms med marginal, oföränderligheten är bekräftad och tredjepartsbedömd, materialet är åtkomligt på millisekunder om rätt lagringsnivå väljs, och kostnaden är försumbar i förhållande till allt annat i byrån.

Tre saker gör att jag inte kan skriva under på "100 %". För det första går gallringen efter bevarandetiden inte att automatisera med Azures egna standardverktyg — Microsoft skriver rakt ut att raderingsåtgärden i lifecycle-regler inte fungerar i en oföränderlig container. För det andra skyddar WORM-låset inte materialet mot att abonnemanget upphör eller att fakturan inte betalas; Microsoft säger detta uttryckligen, och exakt vad som då gäller står i Microsoft Customer Agreement, vars text inte går att hämta ur Microsofts egen publicering. För det tredje är kombinationen rclone mot en oföränderlig Azure-container odokumenterad hos båda leverantörerna, och det finns en känd teknisk kollision i den (se punkt 5).

Med de förbehållen: ja.

## 2. Sverige

Verifierat. Microsofts regionslista anger ordagrant raden "Sweden Central | Yes | [restricted] Sweden South | Gävle | Sweden | swedencentral", med kolumnrubrikerna Region / Availability zone support / Paired region / Physical location / Geography / Programmatic name. Sidan är uppdaterad 2026-07-28 (learn.microsoft.com/azure/reliability/regions-list). Geografin "Sweden" är enligt Microsoft en fast gräns för dataplacering: "Every region is contained within a single geography that serves as a fixed data residency boundary."

Redundansvalet: **geo-redundans flyttar ingen kopia ur Sverige.** Parregionen för Sweden Central är **Sweden South**, en region med begränsad åtkomst, och den ligger i geografin Sweden. Det senare är belagt i den tabell som Microsofts avtalstext (Product Terms, PrivacyandSecurityTerms) själv utpekar som auktoritet för Geo-placering: azure.microsoft.com/explore/global-infrastructure/products-by-region/table, där Sweden South förekommer i 158 rader, samtliga med geografi "Sweden". Någon anmälan enligt BFL 7 kap. 3 a § blir alltså inte aktuell oavsett redundansval. Till skillnad från t.ex. Brazil South, som är parad med South Central US, korsar Sverige-paret ingen landsgräns.

Trots det rekommenderar jag **ZRS**, inte GRS. Skälet är inte längre juridiskt utan att frågan då blir irrelevant: ZRS replikerar enbart inom Sweden Central, över tre eller fler zoner, och Microsoft rekommenderar uttryckligen ZRS "for restricting replication of data to a particular region to meet data governance requirements". Zonerna ligger enligt Microsoft inom regionen, och en zonresilient konfiguration "keeps replicas inside the regional boundary". GRS tillför ingen svensk efterlevnad, kostar mer, medför en per-GB-avgift för geo-replikering (0,02 USD/GB) och innebär att ändringar i oföränderlighetspolicyn inte synkas till sekundärregionen vid failover.

En sak att inte åberopa: EU Data Boundary. Den är en EU/EFTA-gräns, inte en svensk, och tillåter uttryckligen att data ligger i Danmark eller Finland. Det är regionsvalet som ger den svenska placeringen, ingenting annat.

## 3. Oföränderligheten

Bekräftat: en låst tidsbaserad kvarhållningspolicy gör bloben skrivskyddad och raderingsskyddad "not even by users with account administrative privileges". Intervallet är 1 till 146 000 dagar, så nio år (ca 3 287 dagar) ryms väl. Alla åtkomstnivåer och alla redundanskonfigurationer stöder oföränderlighet — Cold + ZRS + WORM är alltså en tillåten kombination. Cohasset Associates har oberoende bedömt funktionen mot SEC 17a-4(f), FINRA 4511 och CFTC 1.31 (rapportversion 2024), och Microsoft lämnar på begäran ett attesteringsbrev om WORM-oföränderlighet via Azure Support — användbart om Skatteverket eller en revisor vill ha skriftligt underlag för mervärdesskattelagens krav.

Två saker måste vara avstängda: point-in-time restore och last access tracking ("This feature is incompatible with…"). NFS 3.0 och SFTP får inte vara påslaget på kontot. Archive-nivån faller på åtkomlighetskravet — offline, upp till 15 timmars rehydrering — och kan dessutom inte kombineras med ZRS.

**Går gallring att genomföra efter bevarandetiden? Ja, men bara manuellt.** Microsoft: "After a policy is locked, you can't delete it. However, you can delete the blob after the retention interval has expired." Däremot: "The delete action of a lifecycle management policy won't work with any blob in an immutable container" — formulerat utan undantag för utgången kvarhållning. Gallringen enligt GDPR art. 5.1 e måste alltså byggas som en aktiv, kalenderförd och dokumenterad rutin (Azure CLI/PowerShell eller Azure Storage Actions, som är GA i Sweden Central), inte som automatik. Har soft delete varit påslaget ligger materialet dessutom kvar hela soft delete-perioden efter raderingen.

Välj **container-level WORM med en container per räkenskapsår**. Version-level WORM ger visserligen ett absolut slutdatum per objekt och därmed noll överretention, men priset är högt: versionshantering måste vara på (kostar), funktionen kan bara aktiveras när lagringskontot skapas och aldrig stängas av, ändringar på versionsnivå revisionsloggas inte alls, och blob inventory kan inte användas i kontot. Med container-level räknas spärrtiden från varje blobs skapandetid, vilket ger upp till ungefär elva månaders överretention för material skapat sent på året. Det är en acceptabel kostnad för att behålla revisionsloggen.

## 4. Kostnaden

Priser hämtade från Azure Retail Prices API 2026-08-26. **USD är den verifierade uppgiften.** SEK-belopp nedan är indikativa — Microsoft skriver själva att API:ets icke-USD-priser är uppskattningar och att de inte stämmer mot faktura.

I dag, 27 objekt och 5,9 MB: månadskostnaden är under 0,01 SEK oavsett nivå. Det avrundas bort.

Vid 50 GB, lagring per år: Cold ZRS 2,40 USD, Cold LRS 2,16 USD, Cool ZRS 7,50 USD, Cool LRS 6,00 USD, Hot LRS 11,04 USD. Indikativt 23, 21, 73, 58 respektive 107 SEK per år.

Fullständig återläsning av hela arkivet (50 GB, 20 000 objekt): Cool LRS 0,52 USD, Cold LRS 1,70 USD — mot Archive 13,20 USD med standardprioritet och 136,50 USD med hög prioritet. Utgående trafik är fri upp till 100 GB per kalendermånad och prenumeration, så egressen blir noll. Notera att det är antalet objekt, inte volymen, som driver kostnaden i de kalla nivåerna.

Tre poster kan bli större än hela lagringskostnaden och måste beslutas medvetet: **Microsoft Defender for Storage** kostar 0,0134 USD/timme per lagringskonto, ca 117 USD/år — tjugo gånger lagringen — och slås på automatiskt för alla konton om planen aktiveras på prenumerationsnivå. **Private endpoint** på en Container Apps-miljö utlöser "Dedicated Plan Management" på 0,10 USD/timme, 876 USD/år, även på Consumption-planen. **Named encryption scopes** kostar 1,30 USD per scope och månad, så en lösning med kryptografisk separation per klient blir den dominerande kostnaden.

## 5. Vad som inte gick att verifiera

Sweden South:s fysiska ort. Microsoft publicerar geografin men inte orten, och regionen saknar egen rad i regionslistan. Saknar betydelse om ZRS väljs.

Om lifecycle-radering (eller Storage Actions DeleteBlob) börjar fungera när kvarhållningen löpt ut. Microsofts båda sidor motsäger varandra implicit och ingen behandlar kombinationen. Måste provköras.

Hur många gånger en låst policy på versionsnivå får förlängas — en Microsoft-sida säger obegränsat, en annan högst fem gånger. Och om effektiv retention räknas från blobbens skapandetid (översiktssidan) eller från policyns skapande (ARM-referensen). Bygg ingen rutin på någondera förrän det är testat.

Vad Microsoft Customer Agreement faktiskt säger vid utebliven betalning. PDF:ens brödtext går inte att hämta. Den ofta citerade klausulen om 30 dagars varsel, 60 dagars läkningsfrist och radering "without any retention period" kommer från MOSA, som enligt Microsofts egen villkorssats *inte* gäller när MCA är tillgängligt — och MCA är tillgängligt i Sverige. Att risken finns är belagt; dess exakta villkor är det inte.

Faktureringsvalutan. Samma Microsoft-sida anger både att Sverige faktureras i SEK och att Azure.com-direktköp i Sverige "are transacted in US dollars". Momshanteringen (svensk moms eller omvänd betalningsskyldighet) och eventuella avtalsrabatter är inte heller verifierade.

Att rclone fungerar mot Supabases S3-yta — nämns inte av någondera part. Och rclone mot en WORM-container: här finns en dokumenterad kollision. rclone lagrar modifieringstid som användarmetadata och implementerar SetModTime via Set Blob Metadata, som står på Microsofts lista över förbjudna operationer i en oföränderlig container. Så länge rclone bara skapar nya blobbar går det bra; så snart den vill uppdatera en befintlig misslyckas anropet. Kör `rclone copy` med `--immutable` och `--use-server-modtime`. Microsoft medger uttryckligen bara Put Blob för nya blobbar och nämner inte Put Block List, som rclone använder för filer över 4 MiB.

Om rclones `--azureblob-use-msi` fungerar inuti Azure Container Apps (som använder IDENTITY_ENDPOINT, inte IMDS), och om Container Apps över huvud taget finns i Sweden Central. Körs jobbet i annan region passerar räkenskapsinformationen den regionen vid varje körning.

Priserna för läsoperationer och hämtning på Cool GZRS och Cool RA-GZRS saknas i API:t. Om index tags omfattas av oföränderligheten — behandla dem som mutabel sökhjälp och lägg aldrig bevisbärande uppgifter enbart där.

## 6. Vad som återstår innan beslut

1. Provkör hela kedjan mot en **olåst** policy i ett testkonto: rclone från Supabase, en fil över 4 MiB, en omkörning mot befintlig blob, samt en gallringstest med en dags kvarhållning där både lifecycle-radering och manuell radering prövas. Lås policyn först när testet är klart — Microsoft rekommenderar inom ca 24 timmar, eftersom en olåst policy inte ger raderingsskydd.
2. Läs och arkivera den MCA-PDF som accepteras vid registreringen, särskilt avsnitten Suspension, Termination och Customer Data.
3. Säkra betalningen i nio år: fakturabetalning hellre än kort, budgetlarm med minst två mottagare, och en skriven eskaleringsrutin vid suspension. Detta är den reella bevarandrisken, inte att någon råkar radera.
4. Skaffa en oberoende andrakopia utanför Azure. Ett enda ställe är en enskild felpunkt, och Supabase-källan saknar både versionshantering och object lock.
5. Besluta medvetet om Defender for Storage — den kostar tjugo gånger lagringen och är dessutom uttryckligen undantagen från EU Data Boundary.
6. Stäng av Shared Key-auktorisering på kontot. Annars ger rollen Storage Account Contributor full dataåtkomst via listkeys, och den tänkta uppdelningen mellan policyadmin och dataadmin finns inte.
7. Sätt upp diagnostikloggning till ett separat, också skyddat, mål från dag ett. Containerns policylogg rymmer högst sju kommandon, och Microsoft lägger uttryckligen ansvaret för varaktig loggbevaring på kunden.
8. Ladda ned och arkivera lokalt: Cohasset-rapporten (2024), DPA (maj 2026) och den gällande underbiträdeslistan. Service Trust Portal håller dokument tillgängliga i minst tolv månader — i år sju finns de inte kvar.
9. Räkna ut kvarhållningstiden per räkenskapsår före låsning, inte som schablon. En låst policy kan förlängas men aldrig kortas, och högst fem gånger på containernivå.
10. Stäm av den första fakturan mot USD-listpriserna, inte mot SEK-estimaten.