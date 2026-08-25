// Svenska allmänna helgdagar och helgförskjutning — ren datumlogik utan I/O.
// Delas av frontend (via re-export i src/lib/helgdagar.js, vitest-testad) och
// edge-funktionen byrastod-jobb. Datum är ISO-strängar 'YYYY-MM-DD', beräknade i UTC.
//
// Skatteverkets/Bolagsverkets regel: infaller ett förfallodatum på lördag, söndag
// eller allmän helgdag flyttas det till närmast följande vardag.
// Midsommar-/jul-/nyårsafton är INTE allmänna helgdagar (afton-dagar); avvikelser i
// myndigheternas årslistor fångas av referenstabellerna (deadline_regel-lagret).

const MS_PER_DAG = 86400000
const tillDatum = iso => new Date(iso + 'T00:00:00Z')
const tillIso = d => d.toISOString().slice(0, 10)

export function addDagar(iso, n) {
  return tillIso(new Date(tillDatum(iso).getTime() + n * MS_PER_DAG))
}

// Påskdagen enligt Butchers algoritm (gregoriansk kalender).
export function paskdagen(ar) {
  const a = ar % 19, b = Math.floor(ar / 100), c = ar % 100
  const d = Math.floor(b / 4), e = b % 4, f = Math.floor((b + 8) / 25)
  const g = Math.floor((b - f + 1) / 3), h = (19 * a + b - d - g + 15) % 30
  const i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7
  const m = Math.floor((a + 11 * h + 22 * l) / 451)
  const manad = Math.floor((h + l - 7 * m + 114) / 31)
  const dag = ((h + l - 7 * m + 114) % 31) + 1
  return `${ar}-${String(manad).padStart(2, '0')}-${String(dag).padStart(2, '0')}`
}

// Första lördagen i intervallet [franIso, tillIso] (för midsommardagen/alla helgons dag).
function lordagIIntervall(ar, franMd, tillMd) {
  let d = `${ar}-${franMd}`
  const slut = `${ar}-${tillMd}`
  while (d <= slut) {
    if (tillDatum(d).getUTCDay() === 6) return d
    d = addDagar(d, 1)
  }
  return d // nås aldrig — intervallen är 7 dagar
}

const cache = new Map()

// Samtliga allmänna helgdagar för ett år, som Set av ISO-strängar.
export function helgdagar(ar) {
  if (cache.has(ar)) return cache.get(ar)
  const pask = paskdagen(ar)
  const set = new Set([
    `${ar}-01-01`,            // nyårsdagen
    `${ar}-01-06`,            // trettondedag jul
    addDagar(pask, -2),       // långfredagen
    pask,                     // påskdagen
    addDagar(pask, 1),        // annandag påsk
    `${ar}-05-01`,            // första maj
    addDagar(pask, 39),       // Kristi himmelsfärdsdag
    addDagar(pask, 49),       // pingstdagen
    `${ar}-06-06`,            // nationaldagen
    lordagIIntervall(ar, '06-20', '06-26'), // midsommardagen
    lordagIIntervall(ar, '10-31', '11-06'), // alla helgons dag
    `${ar}-12-25`,            // juldagen
    `${ar}-12-26`,            // annandag jul
  ])
  cache.set(ar, set)
  return set
}

export const arHelg = iso => {
  const dag = tillDatum(iso).getUTCDay()
  return dag === 0 || dag === 6
}

export const arHelgdag = iso => helgdagar(Number(iso.slice(0, 4))).has(iso)

export const arVardag = iso => !arHelg(iso) && !arHelgdag(iso)

// Lör/sön/helgdag → närmast följande vardag; vardagar returneras oförändrade.
export function forskjutTillVardag(iso) {
  let d = iso
  while (!arVardag(d)) d = addDagar(d, 1)
  return d
}
