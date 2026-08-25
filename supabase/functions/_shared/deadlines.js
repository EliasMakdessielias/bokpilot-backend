// Deadline-motorn för Byråstödet — ren, datadriven datumlogik utan I/O.
// Delas av frontend (re-export i src/lib/deadlines.js, vitest-testad) och
// edge-funktionen byrastod-jobb. Reglerna kommer som parametrar (jsonb-kolumnen
// deadline_regel.parametrar) — ALDRIG hårdkodade datum (se docs/byrastod/02-deadline-regelverk.md).
//
// Alla datum är ISO-strängar 'YYYY-MM-DD' (UTC). Regeltyper (parametrar.typ):
//   dag_i_manad                — moms månad/kvartal, AGI: dag D i månaden P månader efter
//                                periodens slut, med undantagsmånader (jan/aug → 17:e).
//   grupp_efter_bokslutsmanad  — helårsmoms (AB), INK2: fast datum per bokslutsmånadsgrupp.
//   fast_datum_per_ar          — INK1 (och helårsmoms EF): fast datum året efter
//                                beskattningsåret; byråanstånd byter datum.
//   dagar_efter_period         — löpande bokföring (BFL 5 kap): periodens slut + N dagar.
//   manader_efter_bokslut      — årsredovisning: bokslutsdatum + N månader (månadsslut bevaras).
//   bokslut_revisionsstart     — bokslut med revisionsplikt: revisionsstart − N dagar.
//   bokslut_internt_sla        — bokslut utan revisionsplikt: basdeadline (ÅR/INK) − N dagar.
//
// Myndighetsdatum helgförskjuts framåt (parametrar.helgforskjut = true); interna
// datum (bokslut, löpande bokföring) lämnas exakta.

import { forskjutTillVardag } from './helgdagar.js'

const tillDatum = iso => new Date(iso + 'T00:00:00Z')
const tillIso = d => d.toISOString().slice(0, 10)
const pad = n => String(n).padStart(2, '0')

export function addDagar(iso, n) {
  const d = tillDatum(iso)
  d.setUTCDate(d.getUTCDate() + n)
  return tillIso(d)
}

export function sistaDagenIManad(ar, manad) {
  return tillIso(new Date(Date.UTC(ar, manad, 0))) // dag 0 i nästa månad = sista i denna
}

// Månadsaddition som bevarar månadsslut: 2026-06-30 + 7 mån = 2027-01-31 (Bolagsverkets
// "inom sju månader" räknas till motsvarande månadsskifte), 2026-01-15 + 1 = 2026-02-15.
export function addManader(iso, n) {
  const d = tillDatum(iso)
  const ar = d.getUTCFullYear(), manad = d.getUTCMonth() + 1, dag = d.getUTCDate()
  const arSistaDagen = iso === sistaDagenIManad(ar, manad)
  const malManad0 = manad - 1 + n
  const malAr = ar + Math.floor(malManad0 / 12)
  const mal = (malManad0 % 12 + 12) % 12 + 1
  const sista = sistaDagenIManad(malAr, mal)
  if (arSistaDagen) return sista
  const malDag = Math.min(dag, Number(sista.slice(8, 10)))
  return `${malAr}-${pad(mal)}-${pad(malDag)}`
}

// ── Uppdragstyper och frekvenser ─────────────────────────────────────────

export const UPPDRAGSTYPER = [
  'lopande_bokforing', 'momsdeklaration', 'lon_agi', 'bokslut', 'arsredovisning', 'inkomstdeklaration',
]

// companies.momsperiod (fritext, se MOMSPERIODER i src/lib/foretag.js) → regelfrekvens.
export function momsperiodTillFrekvens(momsperiod) {
  const t = String(momsperiod || '').trim()
  if (!t || t === 'Redovisar ej moms') return null
  if (t === 'Årsvis') return 'ar'
  if (/kvartal/i.test(t)) return 'kvartal'
  if (/26/.test(t)) return 'manad26'
  if (/månad|manad|12/i.test(t)) return 'manad12'
  return null
}

// Kalenderperioder (månad/kvartal) vars slut ligger i [franIso, tillIso].
export function perioder(frekvens, franIso, tillIso) {
  const steg = frekvens === 'kvartal' ? 3 : 1
  const ut = []
  let ar = Number(franIso.slice(0, 4))
  let manad = frekvens === 'kvartal' ? 1 : 1
  // börja året före fran för att inte missa perioder vars slut ligger strax efter fran
  ar -= 1
  while (true) {
    const slut = sistaDagenIManad(ar, manad + steg - 1)
    if (slut > tillIso) break
    if (slut >= franIso) {
      ut.push({ start: `${ar}-${pad(manad)}-01`, slut })
    }
    manad += steg
    if (manad > 12) { manad -= 12; ar += 1 }
  }
  return ut
}

// ── Deadlineberäkning ──────────────────────────────────────────────────

const medHelg = (iso, parametrar) => (parametrar.helgforskjut ? forskjutTillVardag(iso) : iso)

// ctx: { periodSlut?, bokslutsdatum?, beskattningsar?, byraanstand?, revisionsstart?, basDeadline? }
// Returnerar ISO-datum, eller null när obligatoriskt underlag saknas (t.ex. revisionsstart).
export function beraknaDeadline(parametrar, ctx = {}) {
  const p = parametrar || {}
  switch (p.typ) {
    case 'dag_i_manad': {
      // periodSlut + manad_forskjutning månader; dag D, undantag per kalendermånad.
      const bas = addManader(ctx.periodSlut, p.manad_forskjutning)
      const ar = Number(bas.slice(0, 4)), manad = Number(bas.slice(5, 7))
      const undantag = (p.undantag || []).find(u => u.manad === manad)
      const dag = undantag ? undantag.dag : p.dag
      return medHelg(`${ar}-${pad(manad)}-${pad(dag)}`, p)
    }
    case 'grupp_efter_bokslutsmanad': {
      // bokslutsdatum → grupp {fran, till, manad, dag, ar_offset}.
      const bokAr = Number(ctx.bokslutsdatum.slice(0, 4))
      const bokManad = Number(ctx.bokslutsdatum.slice(5, 7))
      const grupp = (p.grupper || []).find(g => bokManad >= g.fran && bokManad <= g.till)
      if (!grupp) return null
      return medHelg(`${bokAr + (grupp.ar_offset || 0)}-${pad(grupp.manad)}-${pad(grupp.dag)}`, p)
    }
    case 'fast_datum_per_ar': {
      // beskattningsar (kalenderår) → fast datum året efter; byråanstånd byter datum.
      const val = ctx.byraanstand && p.byraanstand ? p.byraanstand : p.ordinarie
      return medHelg(`${ctx.beskattningsar + 1}-${pad(val.manad)}-${pad(val.dag)}`, p)
    }
    case 'dagar_efter_period':
      return medHelg(addDagar(ctx.periodSlut, p.dagar), p)
    case 'manader_efter_bokslut':
      return medHelg(addManader(ctx.bokslutsdatum, p.manader), p)
    case 'bokslut_revisionsstart':
      return ctx.revisionsstart ? addDagar(ctx.revisionsstart, -p.dagar_fore) : null
    case 'bokslut_internt_sla':
      return ctx.basDeadline ? addDagar(ctx.basDeadline, -p.dagar_fore) : null
    default:
      throw new Error(`okänd deadlineregeltyp: ${p.typ}`)
  }
}

// Periodetikett för uppgiftslistan/Min vecka: "Moms jan 2026", "AGI dec 2026", "Kv 4 2026" …
const MANADER = ['jan', 'feb', 'mar', 'apr', 'maj', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec']
export function periodEtikett(uppdragstyp, periodStart, periodSlut) {
  const ar = periodSlut.slice(0, 4)
  const m1 = Number(periodStart.slice(5, 7)), m2 = Number(periodSlut.slice(5, 7))
  if (uppdragstyp === 'momsdeklaration' && m2 - m1 === 2) return `Moms kv ${Math.ceil(m2 / 3)} ${ar}`
  if (uppdragstyp === 'momsdeklaration' && m1 === 1 && m2 === 12) return `Moms helår ${ar}`
  if (uppdragstyp === 'momsdeklaration') return `Moms ${MANADER[m2 - 1]} ${ar}`
  if (uppdragstyp === 'lon_agi') return `AGI ${MANADER[m2 - 1]} ${ar}`
  if (uppdragstyp === 'lopande_bokforing') {
    if (m1 === m2) return `Bokföring ${MANADER[m2 - 1]} ${ar}`
    if (m2 - m1 === 2) return `Bokföring kv ${Math.ceil(m2 / 3)} ${ar}`
    return `Bokföring ${periodStart.slice(0, 4)}/${ar}`
  }
  if (uppdragstyp === 'bokslut') return `Bokslut ${periodStart.slice(0, 4)}${periodStart.slice(0, 4) !== ar ? '/' + ar.slice(2) : ''}`
  if (uppdragstyp === 'arsredovisning') return `Årsredovisning ${periodStart.slice(0, 4)}${periodStart.slice(0, 4) !== ar ? '/' + ar.slice(2) : ''}`
  if (uppdragstyp === 'inkomstdeklaration') return `Inkomstdeklaration ${ar}`
  return `${periodStart} – ${periodSlut}`
}
