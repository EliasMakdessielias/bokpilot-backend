// Edge Function: mcp-server
// BokPilot Claude Connector (MCP) – v0.3: Fas A (13 läsverktyg) + Fas B (skrivverktyg
// med tvåstegsbekräftelse). Se docs/MCP_CONNECTOR_DESIGN.md.
// Auth: Supabase JWT som Bearer-token (verify_jwt på). All data läses/skrivs med
// ANVÄNDARENS klient → befintlig RLS ger company-isolering. Aldrig service-role.
// Feature-gate: company_ai_features.feature_key='claude_connector' krävs per bolag.
// Spårbarhet: varje tools/call loggas i mcp_audit_log (best effort, blockerar aldrig svar).
//
// SKRIVSPÄRRAR (teknisk policy, inte bara prompt – se regelverk v1.0.0):
//  - Tvåsteg: anrop 1 validerar + returnerar engångstoken (5 min TTL, mcp_confirm_tokens).
//    Anrop 2 med token utför EXAKT den sparade payloaden – inget kan bytas ut däremellan.
//  - Balans på öret, endast aktiva ospärrade konton, datum i aktivt räkenskapsår.
//  - Idempotens: obligatorisk idempotency_key + unikt DB-index; underlag som redan är
//    bokförda avvisas. Radering/ändring finns inte – rättelse sker som omvänd verifikation.
//
// OBS skala: rapportverktygen aggregerar i minnet (tak RAD_TAK rader). Vid större bolag:
// flytta aggregeringen till Postgres-RPC:er.
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, mcp-protocol-version, mcp-session-id',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
}
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } })
const rpcResult = (id: unknown, result: unknown) => json({ jsonrpc: '2.0', id, result })
const rpcError = (id: unknown, code: number, message: string, httpStatus = 200) => json({ jsonrpc: '2.0', id, error: { code, message } }, httpStatus)

const SERVER_INFO = { name: 'bokpilot-claude-connector', version: '0.3.0' }
const PROTOCOL_VERSIONS = ['2025-06-18', '2025-03-26', '2024-11-05']
const FEATURE_KEY = 'claude_connector'
const RAD_TAK = 5000 // maxrader som hämtas för aggregering – skydd mot minnessprängning
const TOKEN_TTL_MS = 5 * 60 * 1000 // engångstoken för skrivbekräftelse: 5 minuter
const STANDARD_SERIE = 'A - Redovisning'
const r2 = (n: number) => Math.round((n + Number.EPSILON) * 100) / 100

// ---------- Verktygsdefinitioner (Fas A) ----------
const P_COMPANY = { company_id: { type: 'string', description: 'Bolagets id (hämta via lista_foretag).' } }
const P_PERIOD = {
  from_datum: { type: 'string', description: 'Från-datum ÅÅÅÅ-MM-DD, inklusive.' },
  till_datum: { type: 'string', description: 'Till-datum ÅÅÅÅ-MM-DD, inklusive.' },
}
const obj = (properties: Record<string, unknown>, required: string[] = ['company_id']) => ({ type: 'object', properties, required, additionalProperties: false })

const TOOLS = [
  {
    name: 'lista_foretag',
    description: 'Lista bolag användaren har åtkomst till i BokPilot, med räkenskapsår och om Claude-connectorn är aktiverad per bolag. Börja alltid här för att få company_id till övriga verktyg.',
    inputSchema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'sok_verifikationer',
    description: 'Sök verifikationer i ett bolag. Filtrera på datumintervall, fritext i beskrivningen, verifikationsserie eller konto. Nyaste först, max `limit` träffar.',
    inputSchema: obj({
      ...P_COMPANY, ...P_PERIOD,
      text: { type: 'string', description: 'Fritext som matchas mot verifikationens beskrivning.' },
      serie: { type: 'string', description: 'Verifikationsserie, t.ex. "A".' },
      konto: { type: 'string', description: 'Kontonummer – ger verifikationer som har minst en rad på kontot.' },
      limit: { type: 'number', description: 'Max antal träffar, 1–100. Standard 20.' },
    }),
  },
  {
    name: 'hamta_verifikation',
    description: 'Hämta en komplett verifikation med alla konteringsrader och eventuell makulerings-/rättelsekoppling.',
    inputSchema: obj({ ...P_COMPANY, verifikation_id: { type: 'string', description: 'Verifikationens id (från sok_verifikationer).' } }, ['company_id', 'verifikation_id']),
  },
  {
    name: 'hamta_huvudbok',
    description: 'Huvudbok för ett konto: ingående saldo, alla transaktioner i perioden och utgående saldo.',
    inputSchema: obj({ ...P_COMPANY, konto: { type: 'string', description: 'Kontonummer, t.ex. "1930".' }, ...P_PERIOD }, ['company_id', 'konto']),
  },
  {
    name: 'hamta_resultatrapport',
    description: 'Resultatrapport för en period: intäkter och kostnader per konto och kontoklass, samt periodens resultat.',
    inputSchema: obj({ ...P_COMPANY, ...P_PERIOD }, ['company_id', 'from_datum', 'till_datum']),
  },
  {
    name: 'hamta_balansrapport',
    description: 'Balansrapport per ett datum: tillgångar, eget kapital och skulder per konto (inkl. ingående balanser).',
    inputSchema: obj({ ...P_COMPANY, per_datum: { type: 'string', description: 'Balansdag ÅÅÅÅ-MM-DD.' } }, ['company_id', 'per_datum']),
  },
  {
    name: 'lista_kundfakturor',
    description: 'Lista kundfakturor med status och förfallodatum. Filtrera på status: alla | obetalda | forfallna | betalda.',
    inputSchema: obj({ ...P_COMPANY, status: { type: 'string', description: 'alla | obetalda | forfallna | betalda. Standard: alla.' }, ...P_PERIOD, limit: { type: 'number', description: 'Max antal, 1–100. Standard 50.' } }),
  },
  {
    name: 'lista_leverantorsfakturor',
    description: 'Lista leverantörsfakturor med betal- och bokföringsstatus. Filtrera på status: alla | obetalda | forfallna | betalda | obokforda.',
    inputSchema: obj({ ...P_COMPANY, status: { type: 'string', description: 'alla | obetalda | forfallna | betalda | obokforda. Standard: alla.' }, ...P_PERIOD, limit: { type: 'number', description: 'Max antal, 1–100. Standard 50.' } }),
  },
  {
    name: 'hamta_momsunderlag',
    description: 'Momsunderlag för en period: utgående moms (261x–263x), ingående moms (264x) och netto att betala/få tillbaka.',
    inputSchema: obj({ ...P_COMPANY, ...P_PERIOD }, ['company_id', 'from_datum', 'till_datum']),
  },
  {
    name: 'lista_underlag',
    description: 'Lista inkomna underlag (dokument) med tolknings- och bokföringsstatus. Filtrera på status: alla | otolkade | tolkade | obokforda | bokforda.',
    inputSchema: obj({ ...P_COMPANY, status: { type: 'string', description: 'alla | otolkade | tolkade | obokforda | bokforda. Standard: alla.' }, limit: { type: 'number', description: 'Max antal, 1–100. Standard 50.' } }),
  },
  {
    name: 'hamta_underlagstolkning',
    description: 'Hämta AI-tolkningen (OCR-resultatet) för ett underlag: leverantör, belopp, moms, konteringsförslag och konfidens.',
    inputSchema: obj({ ...P_COMPANY, document_id: { type: 'string', description: 'Dokumentets id (från lista_underlag).' } }, ['company_id', 'document_id']),
  },
  {
    name: 'hamta_kontoplan',
    description: 'Sök i bolagets aktiva kontoplan. Filtrera på fritext (namn/nummer) eller kontoklass (1–8).',
    inputSchema: obj({ ...P_COMPANY, soktext: { type: 'string', description: 'Fritext som matchar kontonamn eller kontonummer-prefix.' }, klass: { type: 'number', description: 'Kontoklass 1–8 (BAS första siffran).' } }),
  },
  {
    name: 'hamta_bokforingsstatus',
    description: 'Nulägesöversikt för bolaget: senaste månadskontrollen med öppna punkter, otolkade/obokförda underlag och förfallna fakturor.',
    inputSchema: obj({ ...P_COMPANY, ar: { type: 'number', description: 'År för månadskontroll. Standard: senaste.' }, manad: { type: 'number', description: 'Månad 1–12. Standard: senaste.' } }),
  },
  {
    name: 'lista_bankhandelser',
    description:
      'Lista importerade kassa-/bankhändelser (inkl. skattekontot, konto 1630). Filtrera på konto, period och om de är obokförda (saknar verifikationskoppling). Används för bankmatchning och skattekontobokföring.',
    inputSchema: obj({
      ...P_COMPANY, ...P_PERIOD,
      konto: { type: 'string', description: 'Bankkonto i BAS, t.ex. "1930" (företagskonto) eller "1630" (skattekontot).' },
      endast_obokforda: { type: 'boolean', description: 'true = endast händelser utan verifikationskoppling. Standard: true.' },
      limit: { type: 'number', description: 'Max antal, 1–200. Standard 100.' },
    }),
  },
  // ---- Fas B: skrivverktyg (tvåstegsbekräftelse) ----
  {
    name: 'foresla_kontering',
    description:
      'Föreslå kontering för ett underlag (document_id) eller en fritextbeskriven affärshändelse. Read-only – bokför inget. Förslaget granskas av användaren och bokförs sedan via skapa_verifikation.',
    inputSchema: obj({
      ...P_COMPANY,
      document_id: { type: 'string', description: 'Underlagets id (från lista_underlag) – använder AI-tolkningen.' },
      fraga: { type: 'string', description: 'Alternativ till document_id: beskriv affärshändelsen i fritext, t.ex. "kvitto från OKQ8, diesel 625 kr inkl moms, betalt med företagskort".' },
    }),
  },
  {
    name: 'skapa_verifikation',
    description:
      'Bokför en verifikation i två steg. Steg 1: anropa UTAN bekraftelse_token – servern validerar (balans, konton, räkenskapsår, idempotens) och returnerar ett förslag + engångstoken. Visa förslaget för användaren och invänta uttryckligt JA. Steg 2: anropa igen med ENDAST company_id och bekraftelse_token – den sparade payloaden bokförs exakt som föreslagen. Token gäller 5 minuter.',
    inputSchema: obj({
      ...P_COMPANY,
      datum: { type: 'string', description: 'Bokföringsdatum ÅÅÅÅ-MM-DD. Måste ligga i ett aktivt räkenskapsår.' },
      beskrivning: { type: 'string', description: 'Verifikationens beskrivning, t.ex. "OKQ8 – drivmedel".' },
      rader: {
        type: 'array',
        description: 'Konteringsrader. Summa debet måste vara exakt lika med summa kredit (på öret).',
        items: {
          type: 'object',
          properties: {
            konto: { type: 'string', description: 'Kontonummer i bolagets kontoplan.' },
            debet: { type: 'number', description: 'Debetbelopp i kr (0 om kreditrad).' },
            kredit: { type: 'number', description: 'Kreditbelopp i kr (0 om debetrad).' },
            info: { type: 'string', description: 'Valfri radtext.' },
          },
          required: ['konto', 'debet', 'kredit'],
        },
      },
      serie: { type: 'string', description: `Verifikationsserie. Standard: "${'A - Redovisning'}".` },
      kommentar: { type: 'string', description: 'Valfri kommentar på verifikationen.' },
      document_id: { type: 'string', description: 'Valfritt: underlag som ska kopplas till verifikationen. Redan bokförda underlag avvisas.' },
      idempotency_key: { type: 'string', description: 'Obligatorisk unik nyckel per affärshändelse (t.ex. "okq8-2026-07-03-625kr"). Samma nyckel kan aldrig bokföras två gånger.' },
      bekraftelse_token: { type: 'string', description: 'Steg 2: engångstoken från steg 1, efter att användaren sagt JA.' },
    }, ['company_id']),
  },
  {
    name: 'bokfor_leverantorsfaktura',
    description:
      'Bokför en leverantörsfaktura VIA RESKONTRAN (rätt flöde: supplier_invoices + L-serien, aldrig fri verifikation). Två steg: utan bekraftelse_token valideras och ett förslag + engångstoken returneras; med token utförs allt (leverantör skapas/återanvänds, fakturan registreras i reskontran, bokförs K 2440 / D 2640 / D kostnadskonto — spegelvänt för kreditfaktura — och underlaget kopplas). Ange ANTINGEN document_id (tolkat underlag i Inkorgen som inte registrerats ännu) ELLER supplier_invoice_id (redan registrerad obokförd faktura).',
    inputSchema: obj({
      ...P_COMPANY,
      document_id: { type: 'string', description: 'Tolkat leverantörsfaktura-underlag (från lista_underlag) som ska registreras och bokföras.' },
      supplier_invoice_id: { type: 'string', description: 'Befintlig OBOKFÖRD leverantörsfaktura i reskontran (från lista_leverantorsfakturor, status obokforda).' },
      kostnadskonto: { type: 'string', description: 'Valfritt: kostnadskonto (4 siffror) om tolkningen saknar/har fel konto.' },
      bekraftelse_token: { type: 'string', description: 'Steg 2: engångstoken från steg 1, efter användarens godkännande.' },
    }, ['company_id']),
  },
  {
    name: 'registrera_leverantorsfakturor',
    description:
      'Massregistrera tolkade leverantörsfaktura-underlag från Inkorgen i reskontran (supplier_invoices) UTAN att bokföra — fakturorna blir obokförda och bokförs sedan en och en av användaren i vyn Leverantörsfakturor. Redan registrerade underlag hoppas över. Filtrera valfritt på fakturadatum. Utförs direkt (skapar inga verifikationer).',
    inputSchema: obj({
      ...P_COMPANY, ...P_PERIOD,
    }),
  },
  {
    name: 'matcha_bankhandelse',
    description:
      'Matcha en utbetalning på banken mot en leverantörsfaktura vid 100 % träff (öresexakt mot fakturans restbelopp). Två steg som skapa_verifikation: utan bekraftelse_token valideras matchningen och ett förslag + engångstoken returneras; med token bokförs betalningsverifikationen (D 2440 / K bankkontot), bankhändelsen länkas och fakturan markeras betald. Utan exakt träff avvisas matchningen — den görs då manuellt i Kassa och bank.',
    inputSchema: obj({
      ...P_COMPANY,
      bank_transaction_id: { type: 'string', description: 'Bankhändelsens id (från lista_bankhandelser). Måste vara en obokförd utbetalning.' },
      supplier_invoice_id: { type: 'string', description: 'Leverantörsfakturans id (från lista_leverantorsfakturor). Måste vara bokförd och obetald.' },
      bekraftelse_token: { type: 'string', description: 'Steg 2: engångstoken från steg 1, efter användarens godkännande.' },
    }, ['company_id']),
  },
  {
    name: 'foresla_rattelse',
    description:
      'Föreslå en rättelse av en bokförd verifikation enligt BFL: originalet raderas ALDRIG – en omvänd verifikation (debet/kredit spegelvända) föreslås i stället. Read-only. Den omvända verifikationen bokförs sedan via skapa_verifikation efter användarens godkännande.',
    inputSchema: obj({ ...P_COMPANY, verifikation_id: { type: 'string', description: 'Verifikationen som ska rättas.' }, anledning: { type: 'string', description: 'Varför rättelsen görs (hamnar i beskrivningen).' } }, ['company_id', 'verifikation_id']),
  },
]

// ---------- Hjälpare ----------
async function featureAktiverad(db: SupabaseClient, companyId: string): Promise<boolean> {
  const { data } = await db.from('company_ai_features').select('enabled').eq('company_id', companyId).eq('feature_key', FEATURE_KEY).maybeSingle()
  return !!data?.enabled
}

// Best effort-audit: får ALDRIG stoppa svaret till klienten.
async function audit(db: SupabaseClient, userId: string, companyId: string | null, tool: string, params: unknown, status: 'ok' | 'fel' | 'nekad', error?: string) {
  try {
    await db.from('mcp_audit_log').insert({ user_id: userId, company_id: companyId, tool, params: params ?? {}, status, error: error ? String(error).slice(0, 500) : null })
  } catch (e) {
    console.error(`mcp-server: audit-logg misslyckades: ${String((e as Error)?.message || e)}`)
  }
}

// Hämtar konteringsrader med verifikationsdata via inner join (RLS + explicit company-filter).
async function hamtaRader(db: SupabaseClient, companyId: string, filt: { konto?: string; kontoPrefix?: string[]; from?: string; till?: string }) {
  let q = db
    .from('verifikation_rows')
    .select('account_nr, account_name, debet, kredit, verifikationer!inner(id, company_id, datum, ver_serie, ver_nr, beskrivning)')
    .eq('verifikationer.company_id', companyId)
    .limit(RAD_TAK)
  if (filt.konto) q = q.eq('account_nr', filt.konto)
  if (filt.from) q = q.gte('verifikationer.datum', filt.from)
  if (filt.till) q = q.lte('verifikationer.datum', filt.till)
  const { data, error } = await q
  if (error) throw new Error(`Kunde inte läsa konteringsrader: ${error.message}`)
  let rader = (data || []) as Array<{ account_nr: string; account_name: string; debet: number; kredit: number; verifikationer: { id: string; datum: string; ver_serie: string; ver_nr: string; beskrivning: string } }>
  if (filt.kontoPrefix) rader = rader.filter((r) => filt.kontoPrefix!.some((p) => String(r.account_nr).startsWith(p)))
  if (rader.length >= RAD_TAK) throw new Error(`För många konteringsrader (>${RAD_TAK}) – begränsa perioden.`)
  return rader
}

// ---------- Verktygsimplementationer ----------
async function toolListaForetag(db: SupabaseClient) {
  const { data: companies, error } = await db.from('companies').select('id, name').order('name')
  if (error) throw new Error(`Kunde inte läsa bolag: ${error.message}`)
  const ids = (companies || []).map((c) => c.id)
  const [{ data: fy }, { data: flags }] = await Promise.all([
    db.from('fiscal_years').select('company_id, year, start_date, end_date, status').in('company_id', ids),
    db.from('company_ai_features').select('company_id, enabled').eq('feature_key', FEATURE_KEY).in('company_id', ids),
  ])
  return {
    foretag: (companies || []).map((c) => ({
      company_id: c.id,
      namn: c.name,
      claude_connector_aktiverad: !!(flags || []).find((f) => f.company_id === c.id && f.enabled),
      rakenskapsar: (fy || []).filter((f) => f.company_id === c.id).sort((a, b) => (a.year || 0) - (b.year || 0))
        .map((f) => ({ ar: f.year, start: f.start_date, slut: f.end_date, status: f.status })),
    })),
  }
}

async function toolSokVerifikationer(db: SupabaseClient, args: Record<string, unknown>) {
  const companyId = String(args.company_id)
  const lim = Math.min(Math.max(Number(args.limit) || 20, 1), 100)
  let q = db.from('verifikationer').select('id, ver_serie, ver_nr, datum, beskrivning, total_debet, status')
    .eq('company_id', companyId).order('datum', { ascending: false }).order('created_at', { ascending: false }).limit(lim)
  if (args.from_datum) q = q.gte('datum', String(args.from_datum))
  if (args.till_datum) q = q.lte('datum', String(args.till_datum))
  if (args.serie) q = q.eq('ver_serie', String(args.serie))
  if (args.text) q = q.ilike('beskrivning', `%${String(args.text)}%`)
  if (args.konto) {
    const { data: rader, error: radFel } = await db.from('verifikation_rows').select('verifikation_id').eq('account_nr', String(args.konto)).limit(2000)
    if (radFel) throw new Error(`Kunde inte filtrera på konto: ${radFel.message}`)
    const ids = [...new Set((rader || []).map((r) => r.verifikation_id))]
    if (ids.length === 0) return { verifikationer: [], antal: 0 }
    q = q.in('id', ids)
  }
  const { data, error } = await q
  if (error) throw new Error(`Sökningen misslyckades: ${error.message}`)
  return {
    verifikationer: (data || []).map((v) => ({ verifikation_id: v.id, nr: `${v.ver_serie}${v.ver_nr}`, datum: v.datum, beskrivning: v.beskrivning, belopp: v.total_debet, status: v.status })),
    antal: (data || []).length,
    obs: (data || []).length === lim ? `Träfflistan är kapad vid ${lim} – förfina sökningen eller höj limit.` : undefined,
  }
}

async function toolHamtaVerifikation(db: SupabaseClient, args: Record<string, unknown>) {
  const { data: v, error } = await db.from('verifikationer')
    .select('id, ver_serie, ver_nr, datum, beskrivning, total_debet, total_kredit, status, kommentar, makulerad_av, motverkar, rattad_av, rattar, created_at')
    .eq('company_id', String(args.company_id)).eq('id', String(args.verifikation_id)).maybeSingle()
  if (error) throw new Error(error.message)
  if (!v) throw new Error('Verifikationen hittades inte.')
  const { data: rader } = await db.from('verifikation_rows')
    .select('account_nr, account_name, debet, kredit, transaction_info, sort_order').eq('verifikation_id', v.id).order('sort_order')
  return {
    verifikation: {
      nr: `${v.ver_serie}${v.ver_nr}`, datum: v.datum, beskrivning: v.beskrivning, status: v.status,
      total_debet: v.total_debet, total_kredit: v.total_kredit, kommentar: v.kommentar,
      motverkar_verifikation: v.motverkar, rattar_verifikation: v.rattar, skapad: v.created_at,
      rader: (rader || []).map((r) => ({ konto: r.account_nr, benamning: r.account_name, debet: r.debet, kredit: r.kredit, info: r.transaction_info })),
    },
  }
}

async function toolHamtaHuvudbok(db: SupabaseClient, args: Record<string, unknown>) {
  const companyId = String(args.company_id)
  const konto = String(args.konto)
  const { data: acc } = await db.from('accounts').select('account_nr, name, opening_balance').eq('company_id', companyId).eq('account_nr', konto).maybeSingle()
  const ib0 = Number(acc?.opening_balance) || 0
  // Ingående saldo = kontots IB + alla rader före from_datum.
  const fore = args.from_datum ? await hamtaRader(db, companyId, { konto, till: undefined, from: undefined }) : []
  const foreRader = args.from_datum ? fore.filter((r) => r.verifikationer.datum < String(args.from_datum)) : []
  const ib = r2(ib0 + foreRader.reduce((s, r) => s + (Number(r.debet) || 0) - (Number(r.kredit) || 0), 0))
  const rader = (args.from_datum ? fore.filter((r) => r.verifikationer.datum >= String(args.from_datum)) : await hamtaRader(db, companyId, { konto }))
    .filter((r) => !args.till_datum || r.verifikationer.datum <= String(args.till_datum))
    .sort((a, b) => a.verifikationer.datum.localeCompare(b.verifikationer.datum))
  let lopande = ib
  const transaktioner = rader.map((r) => {
    lopande = r2(lopande + (Number(r.debet) || 0) - (Number(r.kredit) || 0))
    return { datum: r.verifikationer.datum, ver: `${r.verifikationer.ver_serie}${r.verifikationer.ver_nr}`, beskrivning: r.verifikationer.beskrivning, debet: r.debet, kredit: r.kredit, saldo: lopande }
  })
  return { konto, benamning: acc?.name || rader[0]?.account_name || null, ingaende_saldo: ib, transaktioner, utgaende_saldo: lopande, antal: transaktioner.length }
}

function grupperaKonton(rader: Array<{ account_nr: string; account_name: string; debet: number; kredit: number }>, tecken: 1 | -1) {
  const perKonto = new Map<string, { namn: string; belopp: number }>()
  for (const r of rader) {
    const e = perKonto.get(r.account_nr) || { namn: r.account_name, belopp: 0 }
    e.belopp = r2(e.belopp + tecken * ((Number(r.kredit) || 0) - (Number(r.debet) || 0)))
    perKonto.set(r.account_nr, e)
  }
  return [...perKonto.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([konto, e]) => ({ konto, benamning: e.namn, belopp: e.belopp })).filter((k) => k.belopp !== 0)
}

async function toolResultatrapport(db: SupabaseClient, args: Record<string, unknown>) {
  const rader = await hamtaRader(db, String(args.company_id), { from: String(args.from_datum), till: String(args.till_datum) })
  const klass = (r: { account_nr: string }) => String(r.account_nr)[0]
  const intakter = grupperaKonton(rader.filter((r) => klass(r) === '3'), 1)
  const kostnader = grupperaKonton(rader.filter((r) => '4567'.includes(klass(r))), -1)
  const finansiellt = grupperaKonton(rader.filter((r) => klass(r) === '8'), 1)
  const sInt = r2(intakter.reduce((s, k) => s + k.belopp, 0))
  const sKost = r2(kostnader.reduce((s, k) => s + k.belopp, 0))
  const sFin = r2(finansiellt.reduce((s, k) => s + k.belopp, 0))
  return {
    period: { from: args.from_datum, till: args.till_datum },
    intakter, summa_intakter: sInt,
    kostnader, summa_kostnader: sKost,
    finansiella_poster: finansiellt, summa_finansiellt: sFin,
    resultat: r2(sInt - sKost + sFin),
  }
}

async function toolBalansrapport(db: SupabaseClient, args: Record<string, unknown>) {
  const companyId = String(args.company_id)
  const perDatum = String(args.per_datum)
  const [rader, { data: konton }] = await Promise.all([
    hamtaRader(db, companyId, { till: perDatum }),
    db.from('accounts').select('account_nr, name, opening_balance').eq('company_id', companyId).eq('is_active', true).neq('opening_balance', 0),
  ])
  const saldo = new Map<string, { namn: string; belopp: number }>()
  for (const k of konton || []) {
    if ('12'.includes(String(k.account_nr)[0])) saldo.set(k.account_nr, { namn: k.name, belopp: Number(k.opening_balance) || 0 })
  }
  for (const r of rader) {
    const first = String(r.account_nr)[0]
    if (!'12'.includes(first)) continue
    const e = saldo.get(r.account_nr) || { namn: r.account_name, belopp: 0 }
    e.belopp = r2(e.belopp + (Number(r.debet) || 0) - (Number(r.kredit) || 0))
    saldo.set(r.account_nr, e)
  }
  const rad = [...saldo.entries()].sort(([a], [b]) => a.localeCompare(b)).map(([konto, e]) => ({ konto, benamning: e.namn, belopp: e.belopp })).filter((k) => k.belopp !== 0)
  const tillgangar = rad.filter((k) => k.konto[0] === '1')
  const ekSkulder = rad.filter((k) => k.konto[0] === '2').map((k) => ({ ...k, belopp: r2(-k.belopp) }))
  return {
    per_datum: perDatum,
    tillgangar, summa_tillgangar: r2(tillgangar.reduce((s, k) => s + k.belopp, 0)),
    eget_kapital_och_skulder: ekSkulder, summa_eget_kapital_och_skulder: r2(ekSkulder.reduce((s, k) => s + k.belopp, 0)),
    obs: 'Beräknat resultat ingår inte som egen rad – differens mellan summorna motsvarar periodens resultat.',
  }
}

async function toolListaKundfakturor(db: SupabaseClient, args: Record<string, unknown>) {
  const lim = Math.min(Math.max(Number(args.limit) || 50, 1), 100)
  const idag = new Date().toISOString().slice(0, 10)
  let q = db.from('invoices').select('id, invoice_nr, invoice_date, due_date, total_amount, status, customers(name)')
    .eq('company_id', String(args.company_id)).order('invoice_date', { ascending: false }).limit(lim)
  if (args.from_datum) q = q.gte('invoice_date', String(args.from_datum))
  if (args.till_datum) q = q.lte('invoice_date', String(args.till_datum))
  const status = String(args.status || 'alla')
  if (status === 'betalda') q = q.in('status', ['paid', 'betald'])
  if (status === 'obetalda' || status === 'forfallna') q = q.not('status', 'in', '("paid","betald","makulerad","cancelled")')
  if (status === 'forfallna') q = q.lt('due_date', idag)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  return {
    kundfakturor: (data || []).map((f) => ({
      faktura_id: f.id, fakturanr: f.invoice_nr, kund: (f.customers as { name?: string } | null)?.name || null,
      fakturadatum: f.invoice_date, forfallodatum: f.due_date, belopp: f.total_amount, status: f.status,
      forfallen: f.due_date < idag && !['paid', 'betald'].includes(String(f.status)),
    })),
    antal: (data || []).length,
  }
}

async function toolListaLeverantorsfakturor(db: SupabaseClient, args: Record<string, unknown>) {
  const lim = Math.min(Math.max(Number(args.limit) || 50, 1), 100)
  const idag = new Date().toISOString().slice(0, 10)
  let q = db.from('supplier_invoices')
    .select('id, invoice_nr, invoice_date, due_date, total_amount, paid_amount, paid_date, status, bokford, makulerad, kreditfaktura, suppliers(name)')
    .eq('company_id', String(args.company_id)).order('invoice_date', { ascending: false }).limit(lim)
  if (args.from_datum) q = q.gte('invoice_date', String(args.from_datum))
  if (args.till_datum) q = q.lte('invoice_date', String(args.till_datum))
  const status = String(args.status || 'alla')
  if (status === 'betalda') q = q.not('paid_date', 'is', null)
  if (status === 'obetalda' || status === 'forfallna') q = q.is('paid_date', null).eq('makulerad', false)
  if (status === 'forfallna') q = q.lt('due_date', idag)
  if (status === 'obokforda') q = q.eq('bokford', false).eq('makulerad', false)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  return {
    leverantorsfakturor: (data || []).map((f) => ({
      faktura_id: f.id, fakturanr: f.invoice_nr, leverantor: (f.suppliers as { name?: string } | null)?.name || null,
      fakturadatum: f.invoice_date, forfallodatum: f.due_date, belopp: f.total_amount,
      betald: !!f.paid_date, betaldatum: f.paid_date, bokford: f.bokford, makulerad: f.makulerad, kreditfaktura: f.kreditfaktura,
      forfallen: !f.paid_date && !f.makulerad && f.due_date < idag,
    })),
    antal: (data || []).length,
  }
}

async function toolMomsunderlag(db: SupabaseClient, args: Record<string, unknown>) {
  const rader = await hamtaRader(db, String(args.company_id), { from: String(args.from_datum), till: String(args.till_datum), kontoPrefix: ['261', '262', '263', '264', '265'] })
  const utg = grupperaKonton(rader.filter((r) => ['261', '262', '263'].some((p) => String(r.account_nr).startsWith(p))), 1)
  const ing = grupperaKonton(rader.filter((r) => String(r.account_nr).startsWith('264')), -1)
  const redov = grupperaKonton(rader.filter((r) => String(r.account_nr).startsWith('265')), 1)
  const sUtg = r2(utg.reduce((s, k) => s + k.belopp, 0))
  const sIng = r2(ing.reduce((s, k) => s + k.belopp, 0))
  return {
    period: { from: args.from_datum, till: args.till_datum },
    utgaende_moms: utg, summa_utgaende: sUtg,
    ingaende_moms: ing, summa_ingaende: sIng,
    momsredovisningskonto_265x: redov,
    netto: r2(sUtg - sIng),
    tolkning: sUtg - sIng >= 0 ? 'Netto att betala till Skatteverket.' : 'Netto att få tillbaka från Skatteverket.',
    obs: 'Underlag ur bokföringen – inte en färdig momsdeklaration. Omvänd skattskyldighet/EU-handel kräver manuell kontroll.',
  }
}

async function toolListaUnderlag(db: SupabaseClient, args: Record<string, unknown>) {
  const lim = Math.min(Math.max(Number(args.limit) || 50, 1), 100)
  let q = db.from('documents').select('id, file_name, kategori, source, status, ai_status, tolkad, confidence, verifikation_id, received_at, created_at')
    .eq('company_id', String(args.company_id)).is('raderad_at', null).order('created_at', { ascending: false }).limit(lim)
  const status = String(args.status || 'alla')
  if (status === 'otolkade') q = q.eq('tolkad', false)
  if (status === 'tolkade') q = q.eq('tolkad', true)
  if (status === 'obokforda') q = q.is('verifikation_id', null)
  if (status === 'bokforda') q = q.not('verifikation_id', 'is', null)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  return {
    underlag: (data || []).map((d) => ({
      document_id: d.id, filnamn: d.file_name, kategori: d.kategori, kalla: d.source,
      tolkad: d.tolkad, ai_status: d.ai_status, konfidens: d.confidence,
      bokford: !!d.verifikation_id, mottagen: d.received_at || d.created_at,
    })),
    antal: (data || []).length,
  }
}

async function toolUnderlagstolkning(db: SupabaseClient, args: Record<string, unknown>) {
  const { data: d, error } = await db.from('documents').select('id, file_name, kategori, tolkad, tolkning, confidence, ai_status, verifikation_id')
    .eq('company_id', String(args.company_id)).eq('id', String(args.document_id)).maybeSingle()
  if (error) throw new Error(error.message)
  if (!d) throw new Error('Underlaget hittades inte.')
  return {
    document_id: d.id, filnamn: d.file_name, kategori: d.kategori, tolkad: d.tolkad,
    konfidens: d.confidence, ai_status: d.ai_status, bokford: !!d.verifikation_id,
    tolkning: d.tolkning ? JSON.parse(JSON.stringify(d.tolkning).slice(0, 20000)) : null,
  }
}

async function toolKontoplan(db: SupabaseClient, args: Record<string, unknown>) {
  let q = db.from('accounts').select('account_nr, name, vat_code, account_class, is_blocked_for_manual_booking')
    .eq('company_id', String(args.company_id)).eq('is_active', true).order('account_nr').limit(200)
  if (args.klass) q = q.eq('account_class', Number(args.klass))
  if (args.soktext) {
    const s = String(args.soktext)
    q = /^\d+$/.test(s) ? q.like('account_nr', `${s}%`) : q.ilike('name', `%${s}%`)
  }
  const { data, error } = await q
  if (error) throw new Error(error.message)
  return {
    konton: (data || []).map((k) => ({ konto: k.account_nr, benamning: k.name, momskod: k.vat_code, klass: k.account_class, sparrad_for_manuell_bokforing: k.is_blocked_for_manual_booking })),
    antal: (data || []).length,
    obs: (data || []).length === 200 ? 'Listan är kapad vid 200 konton – förfina sökningen.' : undefined,
  }
}

async function toolBokforingsstatus(db: SupabaseClient, args: Record<string, unknown>) {
  const companyId = String(args.company_id)
  const idag = new Date().toISOString().slice(0, 10)
  let mcQ = db.from('monthly_controls').select('id, year, month, status, progress_percent, critical_count, high_count, normal_count, low_count, resolved_count, last_run_at')
    .eq('company_id', companyId).order('year', { ascending: false }).order('month', { ascending: false }).limit(1)
  if (args.ar) mcQ = mcQ.eq('year', Number(args.ar))
  if (args.manad) mcQ = mcQ.eq('month', Number(args.manad))
  const [{ data: mc }, { count: otolkade }, { count: obokforda }, { count: forfKund }, { count: forfLev }] = await Promise.all([
    mcQ.maybeSingle(),
    db.from('documents').select('id', { count: 'exact', head: true }).eq('company_id', companyId).eq('tolkad', false).is('raderad_at', null),
    db.from('documents').select('id', { count: 'exact', head: true }).eq('company_id', companyId).is('verifikation_id', null).is('raderad_at', null),
    db.from('invoices').select('id', { count: 'exact', head: true }).eq('company_id', companyId).lt('due_date', idag).not('status', 'in', '("paid","betald","makulerad","cancelled")'),
    db.from('supplier_invoices').select('id', { count: 'exact', head: true }).eq('company_id', companyId).lt('due_date', idag).is('paid_date', null).eq('makulerad', false),
  ])
  let punkter: unknown[] = []
  if (mc) {
    const { data: items } = await db.from('monthly_control_items').select('title, priority, status, module, suggested_action')
      .eq('monthly_control_id', mc.id).neq('status', 'resolved').order('priority').limit(20)
    punkter = (items || []).map((i) => ({ titel: i.title, prioritet: i.priority, status: i.status, modul: i.module, foreslagen_atgard: i.suggested_action }))
  }
  return {
    manadskontroll: mc ? { ar: mc.year, manad: mc.month, status: mc.status, klart_procent: mc.progress_percent, kritiska: mc.critical_count, hoga: mc.high_count, atgardade: mc.resolved_count, senast_kord: mc.last_run_at, oppna_punkter: punkter } : null,
    underlag: { otolkade: otolkade || 0, obokforda: obokforda || 0 },
    forfallna_kundfakturor: forfKund || 0,
    forfallna_leverantorsfakturor: forfLev || 0,
  }
}

async function toolListaBankhandelser(db: SupabaseClient, args: Record<string, unknown>) {
  const lim = Math.min(Math.max(Number(args.limit) || 100, 1), 200)
  let q = db.from('bank_transactions').select('id, account_nr, datum, text, amount, status, verifikation_id, avstamd')
    .eq('company_id', String(args.company_id)).order('datum', { ascending: false }).limit(lim)
  if (args.konto) q = q.eq('account_nr', String(args.konto))
  if (args.from_datum) q = q.gte('datum', String(args.from_datum))
  if (args.till_datum) q = q.lte('datum', String(args.till_datum))
  if (args.endast_obokforda !== false) q = q.is('verifikation_id', null)
  const { data, error } = await q
  if (error) throw new Error(error.message)
  return {
    bankhandelser: (data || []).map((t) => ({
      id: t.id, konto: t.account_nr, datum: t.datum, text: t.text, belopp: t.amount,
      bokford: !!t.verifikation_id, avstamd: t.avstamd,
    })),
    antal: (data || []).length,
    obs: 'Vid 100 % träff mot en leverantörsfakturas restbelopp kan matchningen utföras med matcha_bankhandelse; övrig matchning görs i vyn Kassa och bank.',
  }
}

// ---------- Fas B: skrivverktyg med tvåstegsbekräftelse ----------
type Ctx = { userId: string; authHeader: string; kanal?: 'assistent' | null }
type Rad = { konto: string; benamning: string; debet: number; kredit: number; info: string | null }
const oren = (n: number) => Math.round((Number(n) || 0) * 100)

// Validerar en tänkt verifikation mot alla skrivspärrar. Returnerar normaliserad payload.
async function valideraVerifikation(db: SupabaseClient, args: Record<string, unknown>) {
  const companyId = String(args.company_id)
  const datum = String(args.datum || '')
  const beskrivning = String(args.beskrivning || '').trim()
  const idempotencyKey = String(args.idempotency_key || '').trim()
  if (!/^\d{4}-\d{2}-\d{2}$/.test(datum)) throw new Error('datum krävs i formatet ÅÅÅÅ-MM-DD.')
  if (!beskrivning) throw new Error('beskrivning krävs.')
  if (!idempotencyKey) throw new Error('idempotency_key krävs – en unik nyckel per affärshändelse.')

  const raderIn = Array.isArray(args.rader) ? (args.rader as Record<string, unknown>[]) : []
  if (raderIn.length < 2) throw new Error('Minst två konteringsrader krävs.')

  // Balans på öret (regelverk §2).
  const sumDebet = raderIn.reduce((s, r) => s + oren(Number(r.debet)), 0)
  const sumKredit = raderIn.reduce((s, r) => s + oren(Number(r.kredit)), 0)
  if (sumDebet !== sumKredit) throw new Error(`Debet (${sumDebet / 100}) och kredit (${sumKredit / 100}) balanserar inte – förslaget avvisas.`)
  if (sumDebet === 0) throw new Error('Verifikationen har inga belopp.')

  // Endast aktiva, ospärrade konton i bolagets kontoplan (regelverk §3).
  const kontonr = [...new Set(raderIn.map((r) => String(r.konto).trim()))]
  const { data: konton, error: kFel } = await db.from('accounts')
    .select('account_nr, name, is_active, is_blocked_for_manual_booking')
    .eq('company_id', companyId).in('account_nr', kontonr)
  if (kFel) throw new Error(kFel.message)
  for (const nr of kontonr) {
    const k = (konton || []).find((a) => a.account_nr === nr)
    if (!k) throw new Error(`Konto ${nr} finns inte i bolagets kontoplan.`)
    if (!k.is_active) throw new Error(`Konto ${nr} (${k.name}) är inaktivt – aktivera det i BokPilot först.`)
    if (k.is_blocked_for_manual_booking) throw new Error(`Konto ${nr} (${k.name}) är spärrat för manuell bokföring.`)
  }

  // Datum i aktivt räkenskapsår.
  const { data: fy } = await db.from('fiscal_years').select('id, year, status')
    .eq('company_id', companyId).lte('start_date', datum).gte('end_date', datum).maybeSingle()
  if (!fy) throw new Error(`Datumet ${datum} ligger inte i något räkenskapsår för bolaget.`)
  if (fy.status !== 'active') throw new Error(`Räkenskapsåret ${fy.year} är inte aktivt (status: ${fy.status}) – bokföring stoppad.`)

  // Idempotens: nyckeln får inte redan vara förbrukad.
  const { data: anvand } = await db.from('mcp_confirm_tokens').select('verifikation_id, used_at')
    .eq('company_id', companyId).eq('idempotency_key', idempotencyKey).not('used_at', 'is', null).maybeSingle()
  if (anvand) throw new Error(`idempotency_key "${idempotencyKey}" är redan bokförd (verifikation ${anvand.verifikation_id}). Samma underlag bokförs aldrig två gånger.`)

  // Underlag: måste tillhöra bolaget och får inte redan vara bokfört.
  const documentId = args.document_id ? String(args.document_id) : null
  if (documentId) {
    const { data: dok } = await db.from('documents').select('id, verifikation_id, file_name')
      .eq('company_id', companyId).eq('id', documentId).maybeSingle()
    if (!dok) throw new Error('Underlaget hittades inte i bolaget.')
    if (dok.verifikation_id) throw new Error(`Underlaget "${dok.file_name}" är redan bokfört – bokförs aldrig två gånger.`)
  }

  const rader: Rad[] = raderIn.map((r) => {
    const k = (konton || []).find((a) => a.account_nr === String(r.konto).trim())!
    return { konto: k.account_nr, benamning: k.name, debet: oren(Number(r.debet)) / 100, kredit: oren(Number(r.kredit)) / 100, info: r.info ? String(r.info) : null }
  })
  return {
    company_id: companyId, datum, beskrivning,
    kommentar: args.kommentar ? String(args.kommentar) : null,
    serie: String(args.serie || STANDARD_SERIE),
    rader, total: sumDebet / 100, document_id: documentId, idempotency_key: idempotencyKey,
  }
}

async function toolSkapaVerifikation(db: SupabaseClient, args: Record<string, unknown>, ctx: Ctx) {
  const companyId = String(args.company_id)

  // ---- Steg 2: bekräftelse – utför den SPARADE payloaden ----
  if (args.bekraftelse_token) {
    const { data: token } = await db.from('mcp_confirm_tokens').select('*')
      .eq('id', String(args.bekraftelse_token)).eq('user_id', ctx.userId)
      .eq('company_id', companyId).eq('tool', 'skapa_verifikation').maybeSingle()
    if (!token) throw new Error('Ogiltig bekräftelsetoken.')
    if (token.used_at) throw new Error(`Token redan förbrukad – verifikation ${token.verifikation_id} är redan bokförd.`)
    if (new Date(token.expires_at) < new Date()) throw new Error('Bekräftelsetoken har gått ut (5 min). Kör steg 1 igen.')

    const p = token.payload as Awaited<ReturnType<typeof valideraVerifikation>>
    // Om-validera precis före bokföring (läget kan ha ändrats sedan steg 1).
    await valideraVerifikation(db, { ...p, rader: p.rader })

    // Atomisk bokföring (RPC bokfor_verifikation, supabase/bfl_skydd.sql): header + rader
    // i EN transaktion – inga halvfärdiga verifikationer, obruten nummerserie (BFL 5:5-7).
    // p_created_by sätts explicit eftersom connectorn kör med service-roll (auth.uid() = null).
    const { data: ver, error: verFel } = await db.rpc('bokfor_verifikation', {
      p_company_id: companyId, p_serie: p.serie, p_datum: p.datum,
      p_beskrivning: p.beskrivning,
      p_rader: p.rader.map((r, i) => ({
        account_nr: r.konto, account_name: r.benamning,
        debet: r.debet, kredit: r.kredit, transaction_info: r.info, sort_order: i,
      })),
      p_motpart: null, p_created_by: ctx.userId, p_source: ctx.kanal === 'assistent' ? 'ai' : 'mcp',
      p_kommentar: p.kommentar || null,
    })
    if (verFel || !ver) throw new Error(`Bokföringen misslyckades: ${verFel?.message || 'okänt fel'}`)
    if (p.document_id) await db.from('documents').update({ verifikation_id: ver.id }).eq('id', p.document_id)

    // Förbruka token – unikt index på (company_id, idempotency_key) stoppar racedubbletter.
    const { error: tokFel } = await db.from('mcp_confirm_tokens')
      .update({ used_at: new Date().toISOString(), verifikation_id: ver.id }).eq('id', token.id)
    if (tokFel) console.error(`mcp-server: kunde inte förbruka token ${token.id}: ${tokFel.message}`)

    return {
      bokford: true, verifikation_id: ver.id, nr: `${ver.ver_serie} ${ver.ver_nr}`,
      datum: p.datum, beskrivning: p.beskrivning, total: p.total,
      underlag_kopplat: !!p.document_id,
      kvitto: `Verifikation ${ver.ver_nr} bokförd (${p.total} kr, ${p.rader.length} rader).`,
    }
  }

  // ---- Steg 1: validera och skapa förslag + engångstoken ----
  const payload = await valideraVerifikation(db, args)
  const { data: token, error: tFel } = await db.from('mcp_confirm_tokens').insert({
    user_id: ctx.userId, company_id: companyId, tool: 'skapa_verifikation',
    payload, idempotency_key: payload.idempotency_key,
    expires_at: new Date(Date.now() + TOKEN_TTL_MS).toISOString(),
  }).select('id, expires_at').single()
  if (tFel) throw new Error(`Kunde inte skapa bekräftelsetoken: ${tFel.message}`)

  return {
    bokford: false,
    forslag: {
      datum: payload.datum, serie: payload.serie, beskrivning: payload.beskrivning,
      rader: payload.rader, total: payload.total, underlag: payload.document_id,
    },
    bekraftelse_token: token.id,
    giltig_till: token.expires_at,
    instruktion: 'VISA förslaget för användaren och invänta ett uttryckligt JA. Bekräfta sedan genom att anropa skapa_verifikation igen med ENDAST company_id och bekraftelse_token. Bokför ALDRIG utan användarens godkännande.',
  }
}

// ---- Leverantörsfaktura via RESKONTRAN (rätt flöde, aldrig fri verifikation) ----
// Speglar appens NyLeverantorsfaktura/bokforLeverantorsfaktura EXAKT: supplier_invoices-
// posten bär reskontran, bokföringen görs i L-serien (K 2440 / D 2640 / D kostnadskonto,
// spegelvänt för kreditfaktura), fakturan länkas till verifikationen och underlaget följer med.
const magnitud = (v: unknown) => {
  const n = parseFloat(String(v ?? '').replace(/[−‒–—―]/g, '-').replace(/\s/g, '').replace(',', '.'))
  return isNaN(n) ? 0 : Math.abs(Math.round((n + Number.EPSILON) * 100) / 100)
}
const KREDIT_ORD = ['kreditfaktura', 'kreditnota', 'kreditering', 'krediteras', 'credit invoice', 'credit note', 'att erhålla']

async function valideraLevfaktura(db: SupabaseClient, companyId: string, args: { document_id?: string | null; supplier_invoice_id?: string | null; kostnadskonto?: string | null }) {
  // ---- Befintlig obokförd reskontrapost ----
  if (args.supplier_invoice_id) {
    const { data: inv } = await db.from('supplier_invoices')
      .select('id, invoice_nr, invoice_date, total_amount, vat_amount, kostnadskonto, bokford, verifikation_id, makulerad, kreditfaktura, document_id, suppliers(name)')
      .eq('company_id', companyId).eq('id', String(args.supplier_invoice_id)).maybeSingle()
    if (!inv) throw new Error('Leverantörsfakturan hittades inte.')
    if (inv.makulerad) throw new Error('Fakturan är makulerad.')
    if (inv.bokford || inv.verifikation_id) throw new Error('Fakturan är redan bokförd.')
    const total = magnitud(inv.total_amount), moms = magnitud(inv.vat_amount)
    const netto = Math.round((total - moms) * 100) / 100
    const kk = String(args.kostnadskonto || inv.kostnadskonto || '').trim()
    if (!(total > 0) || netto < 0) throw new Error('Fakturans belopp går inte att kontera (total/moms saknas eller är orimliga).')
    if (!/^\d{4}$/.test(kk)) throw new Error('Kostnadskonto saknas — ange kostnadskonto (4 siffror).')
    return await byggLevPayload(db, companyId, {
      lage: 'befintlig' as const, supplier_invoice_id: inv.id, document_id: inv.document_id || null,
      leverantorsnamn: (inv.suppliers as { name?: string } | null)?.name || '', org_nr: null,
      fakturanr: inv.invoice_nr, ocr: null, datum: inv.invoice_date, forfallodatum: null,
      kredit: !!inv.kreditfaktura, total, moms, netto, kostnadskonto: kk,
    })
  }

  // ---- Nytt: tolkat underlag i Inkorgen → registrera + bokför ----
  if (!args.document_id) throw new Error('Ange document_id (tolkat underlag) eller supplier_invoice_id (obokförd reskontrapost).')
  const { data: dok } = await db.from('documents').select('id, file_name, kategori, tolkad, tolkning, verifikation_id')
    .eq('company_id', companyId).eq('id', String(args.document_id)).is('raderad_at', null).maybeSingle()
  if (!dok) throw new Error('Underlaget hittades inte.')
  if (dok.verifikation_id) throw new Error('Underlaget är redan bokfört.')
  // Dubblettskydd: finns redan en reskontrapost för underlaget används DEN.
  const { data: bef } = await db.from('supplier_invoices').select('id, bokford').eq('company_id', companyId).eq('document_id', dok.id).maybeSingle()
  if (bef?.bokford) throw new Error('Underlaget är redan registrerat och bokfört i reskontran.')
  if (bef) return valideraLevfaktura(db, companyId, { supplier_invoice_id: bef.id, kostnadskonto: args.kostnadskonto })
  if (!dok.tolkad || !dok.tolkning) throw new Error('Underlaget är inte tolkat ännu — tolka det i Inkorgen först.')

  const t = dok.tolkning as Record<string, unknown>
  const leverantorsnamn = String(t.leverantor || '').trim()
  if (!leverantorsnamn) throw new Error(`Tolkningen av "${dok.file_name}" saknar leverantör — komplettera via Skapa faktura i Inkorgen.`)
  // Säljare-vs-köpare-spärren: eget bolag får aldrig bli leverantör (vanligt AI-fel).
  const { data: eget } = await db.from('companies').select('name, org_nr').eq('id', companyId).maybeSingle()
  const siffror = (v: unknown) => String(v || '').replace(/\D/g, '')
  if (siffror(t.org_nr) && siffror(eget?.org_nr) && siffror(t.org_nr) === siffror(eget?.org_nr)) {
    throw new Error('Tolkningen pekar ut det egna bolaget som leverantör — granska underlaget manuellt i Inkorgen.')
  }
  const textblock = [t.beskrivning, t.typ, t.fakturatyp, t.invoice_type].filter(Boolean).map(String).join(' ').toLowerCase()
  const kredit = t.kreditfaktura === true || t.is_credit_invoice === true ||
    String(t.invoice_type || '').toLowerCase() === 'credit' ||
    KREDIT_ORD.some((o) => textblock.includes(o)) ||
    parseFloat(String(t.belopp_inkl_moms ?? '').replace(/[−‒–—―]/g, '-').replace(/\s/g, '').replace(',', '.')) < 0
  const total = magnitud(t.belopp_inkl_moms ?? t.total)
  const moms = magnitud(t.moms_belopp ?? t.moms)
  const netto = Math.round((total - moms) * 100) / 100
  if (!(total > 0) || netto < 0) throw new Error('Tolkningen saknar användbara belopp — granska underlaget i Inkorgen.')
  const datum = String(t.fakturadatum || '')
  if (!/^\d{4}-\d{2}-\d{2}$/.test(datum)) throw new Error('Tolkningen saknar fakturadatum — komplettera via Skapa faktura i Inkorgen.')

  // Kostnadskonto: argument > tolkningens kostnadsrad > 4000.
  let kk = String(args.kostnadskonto || '').trim()
  if (!kk) {
    const rader = Array.isArray(t.konteringsrader) ? (t.konteringsrader as Record<string, unknown>[]) : []
    const kostnadsrad = rader.find((r) => { const nr = String(r.konto || ''); return /^\d{4}$/.test(nr) && !/^244/.test(nr) && !/^264/.test(nr) && nr !== '3740' })
    kk = String(kostnadsrad?.konto || '4000')
  }
  if (!/^\d{4}$/.test(kk)) throw new Error('Ogiltigt kostnadskonto — ange 4 siffror.')

  return await byggLevPayload(db, companyId, {
    lage: 'ny' as const, supplier_invoice_id: null, document_id: dok.id,
    leverantorsnamn, org_nr: t.org_nr ? String(t.org_nr) : null,
    fakturanr: t.fakturanummer ? String(t.fakturanummer) : null,
    ocr: (t.ocr_nummer || t.ocr) ? String(t.ocr_nummer || t.ocr) : null,
    datum, forfallodatum: /^\d{4}-\d{2}-\d{2}$/.test(String(t.forfallodatum || '')) ? String(t.forfallodatum) : null,
    kredit, total, moms, netto, kostnadskonto: kk,
  })
}

// Gemensam svans: kontovakter, räkenskapsår, serie och konteringsrader (spegel av levfakturaRader).
async function byggLevPayload(db: SupabaseClient, companyId: string, p: {
  lage: 'ny' | 'befintlig'; supplier_invoice_id: string | null; document_id: string | null
  leverantorsnamn: string; org_nr: string | null; fakturanr: string | null; ocr: string | null
  datum: string; forfallodatum: string | null; kredit: boolean; total: number; moms: number; netto: number; kostnadskonto: string
}) {
  const kontonr = ['2440', ...(p.moms > 0.005 ? ['2640'] : []), p.kostnadskonto]
  const { data: konton } = await db.from('accounts')
    .select('account_nr, name, is_active, is_blocked_for_manual_booking')
    .eq('company_id', companyId).in('account_nr', kontonr)
  for (const nr of kontonr) {
    const k = (konton || []).find((a) => a.account_nr === nr)
    if (!k) throw new Error(`Konto ${nr} finns inte i bolagets kontoplan — ange ett annat kostnadskonto.`)
    if (!k.is_active) throw new Error(`Konto ${nr} (${k.name}) är inaktivt — aktivera det eller välj annat konto.`)
    if (k.is_blocked_for_manual_booking) throw new Error(`Konto ${nr} (${k.name}) är spärrat för manuell bokföring.`)
  }
  const namn = (nr: string) => (konton || []).find((a) => a.account_nr === nr)?.name || nr

  const { data: fy } = await db.from('fiscal_years').select('year, status')
    .eq('company_id', companyId).lte('start_date', p.datum).gte('end_date', p.datum).maybeSingle()
  if (!fy) throw new Error(`Fakturadatumet ${p.datum} ligger inte i något räkenskapsår.`)
  if (fy.status !== 'active') throw new Error(`Räkenskapsåret ${fy.year} är inte aktivt — bokföring stoppad.`)

  const { data: bolag } = await db.from('companies').select('settings').eq('id', companyId).maybeSingle()
  const serie = String((bolag?.settings as { serier?: Record<string, string> } | null)?.serier?.leverantorsfakturor || 'L - Leverantörsfakturor')

  // K 2440 total / D 2640 moms / D kostnadskonto netto — spegelvänt för kreditfaktura.
  const rader = p.kredit
    ? [
      { konto: '2440', benamning: namn('2440'), debet: p.total, kredit: 0, info: null },
      ...(p.moms > 0.005 ? [{ konto: '2640', benamning: namn('2640'), debet: 0, kredit: p.moms, info: null }] : []),
      { konto: p.kostnadskonto, benamning: namn(p.kostnadskonto), debet: 0, kredit: p.netto, info: null },
    ]
    : [
      { konto: '2440', benamning: namn('2440'), debet: 0, kredit: p.total, info: null },
      ...(p.moms > 0.005 ? [{ konto: '2640', benamning: namn('2640'), debet: p.moms, kredit: 0, info: null }] : []),
      { konto: p.kostnadskonto, benamning: namn(p.kostnadskonto), debet: p.netto, kredit: 0, info: null },
    ]
  return {
    ...p, company_id: companyId, serie, rader,
    beskrivning: `${p.kredit ? 'Lev.kreditfaktura' : 'Lev.faktura'} ${p.leverantorsnamn} ${p.fakturanr || ''}`.trim().slice(0, 200),
    idempotency_key: `levfakt-${p.document_id || p.supplier_invoice_id}`,
  }
}

// Registrerar reskontraposten (leverantör find-or-create + supplier_invoice, OBOKFÖRD).
// Delas av bokfor_leverantorsfaktura (steg 2) och registrera_leverantorsfakturor.
async function registreraReskontrapost(db: SupabaseClient, companyId: string, p: Awaited<ReturnType<typeof valideraLevfaktura>>, userId: string): Promise<string> {
  const { data: leverantorer } = await db.from('suppliers').select('id, name, org_nr').eq('company_id', companyId).limit(1000)
  const siffror = (v: unknown) => String(v || '').replace(/\D/g, '')
  let supplier = (leverantorer || []).find((s) =>
    (p.org_nr && siffror(s.org_nr) && siffror(s.org_nr) === siffror(p.org_nr)) ||
    String(s.name || '').trim().toLowerCase() === p.leverantorsnamn.toLowerCase())
  if (!supplier) {
    const { data: ny, error: sFel } = await db.from('suppliers')
      .insert({ company_id: companyId, name: p.leverantorsnamn, org_nr: p.org_nr }).select('id, name, org_nr').single()
    if (sFel || !ny) throw new Error(`Leverantören kunde inte skapas: ${sFel?.message || 'okänt fel'}`)
    supplier = ny
  }
  const tecken = p.kredit ? -1 : 1
  const { data: inv, error: iFel } = await db.from('supplier_invoices').insert({
    company_id: companyId, supplier_id: supplier.id, invoice_nr: p.fakturanr, ocr: p.ocr,
    invoice_date: p.datum, due_date: p.forfallodatum,
    amount_excl_vat: tecken * p.netto, vat_amount: tecken * p.moms, total_amount: tecken * p.total,
    kostnadskonto: p.kostnadskonto, status: 'unpaid', kreditfaktura: p.kredit,
    document_id: p.document_id, created_by: userId,
  }).select('id').single()
  if (iFel || !inv) throw new Error(`Fakturan kunde inte registreras i reskontran: ${iFel?.message || 'okänt fel'}`)
  return inv.id
}

// Massregistrering: alla tolkade leverantörsfaktura-underlag → obokförda reskontraposter.
// Bokför INGET — användaren bokför sedan en och en i vyn Leverantörssfakturor. Direkt
// utförande (ingen tvåstegstoken): inga verifikationer skapas och dubblettskyddet i
// valideraLevfaktura hoppar redan registrerade underlag.
async function toolRegistreraLevfakturor(db: SupabaseClient, args: Record<string, unknown>, ctx: Ctx) {
  const companyId = String(args.company_id)
  // OBS: även otolkade underlag tas med — de kan inte registreras, men de ska
  // RAPPORTERAS som hoppade (tyst bortfiltrering döljer att inkorgen inte är klar).
  const { data: dokument, error } = await db.from('documents')
    .select('id, file_name, tolkad, tolkning, verifikation_id')
    .eq('company_id', companyId).eq('kategori', 'leverantorsfaktura')
    .is('verifikation_id', null).is('raderad_at', null).order('created_at').limit(100)
  if (error) throw new Error(error.message)

  const poster: Array<Record<string, unknown>> = []
  let registrerade = 0
  for (const dok of dokument || []) {
    const datum = String((dok.tolkning as Record<string, unknown> | null)?.fakturadatum || '')
    if (args.from_datum && datum && datum < String(args.from_datum)) continue
    if (args.till_datum && datum && datum > String(args.till_datum)) continue
    try {
      const p = await valideraLevfaktura(db, companyId, { document_id: dok.id })
      if (p.lage === 'befintlig') {
        poster.push({ dokument: dok.file_name, status: 'hoppad', orsak: 'Redan registrerad i reskontran (obokförd).' })
        continue
      }
      await registreraReskontrapost(db, companyId, p, ctx.userId)
      registrerade++
      poster.push({
        dokument: dok.file_name, status: 'registrerad',
        leverantor: p.leverantorsnamn, fakturanr: p.fakturanr, fakturadatum: p.datum,
        forfallodatum: p.forfallodatum, belopp: (p.kredit ? -1 : 1) * p.total, kreditfaktura: p.kredit,
      })
    } catch (e) {
      poster.push({ dokument: dok.file_name, status: 'hoppad', orsak: String((e as Error)?.message || e) })
    }
  }
  return {
    registrerade, hoppade: poster.filter((r) => r.status === 'hoppad').length, poster,
    instruktion: 'Fakturorna är registrerade OBOKFÖRDA i reskontran. Användaren bokför dem en och en i vyn Leverantörsfakturor — bokför inget härifrån om användaren inte uttryckligen ber om det. Underlag som hoppades för att de inte är tolkade: be användaren tolka dem i Inkorgen (markera + Tolka markerade) och köra om registreringen.',
  }
}

async function toolBokforLevfaktura(db: SupabaseClient, args: Record<string, unknown>, ctx: Ctx) {
  const companyId = String(args.company_id)

  // ---- Steg 2: bekräftelse — registrera i reskontran och bokför ----
  if (args.bekraftelse_token) {
    const { data: token } = await db.from('mcp_confirm_tokens').select('*')
      .eq('id', String(args.bekraftelse_token)).eq('user_id', ctx.userId)
      .eq('company_id', companyId).eq('tool', 'bokfor_leverantorsfaktura').maybeSingle()
    if (!token) throw new Error('Ogiltig bekräftelsetoken.')
    if (token.used_at) throw new Error('Token redan förbrukad — fakturan är redan bokförd.')
    if (new Date(token.expires_at) < new Date()) throw new Error('Bekräftelsetoken har gått ut (5 min). Kör steg 1 igen.')

    const sparad = token.payload as Awaited<ReturnType<typeof valideraLevfaktura>>
    // Om-validera precis före utförandet (underlag/faktura kan ha ändrats).
    const p = await valideraLevfaktura(db, companyId, {
      document_id: sparad.document_id, supplier_invoice_id: sparad.supplier_invoice_id,
      kostnadskonto: sparad.kostnadskonto,
    })

    // Reskontraposten: återanvänd befintlig eller skapa leverantör + faktura (appens invPayload).
    let invId = p.supplier_invoice_id
    if (!invId) invId = await registreraReskontrapost(db, companyId, p, ctx.userId)

    const { data: ver, error: verFel } = await db.rpc('bokfor_verifikation', {
      p_company_id: companyId, p_serie: p.serie, p_datum: p.datum,
      p_beskrivning: p.beskrivning,
      p_rader: p.rader.map((r, i) => ({
        account_nr: r.konto, account_name: r.benamning,
        debet: r.debet, kredit: r.kredit, transaction_info: r.info, sort_order: i,
      })),
      p_motpart: p.leverantorsnamn || null, p_created_by: ctx.userId, p_source: ctx.kanal === 'assistent' ? 'ai' : 'mcp',
      p_kommentar: null,
    })
    if (verFel || !ver) throw new Error(`Bokföringen misslyckades: ${verFel?.message || 'okänt fel'}`)

    // Fakturan MÅSTE länkas — annars dubbelbokför nästa försök; vid fel återställs verifikationen.
    const { error: linkFel } = await db.from('supplier_invoices')
      .update({ bokford: true, verifikation_id: ver.id }).eq('id', invId)
    if (linkFel) {
      const rensad = await db.rpc('radera_senaste_verifikation', { p_ver_id: ver.id }).then((r) => !r.error, () => false)
      if (!rensad) await db.rpc('makulera_verifikation', { p_ver_id: ver.id, p_orsak: 'Automatisk återställning: fakturan kunde inte markeras som bokförd' }).then(() => {}, () => {})
      throw new Error(`Fakturan kunde inte markeras som bokförd (${linkFel.message}) — verifikationen återställdes, försök igen.`)
    }
    // Underlags- och AI-loggkoppling (best effort — bokföringen står på egna ben).
    if (p.document_id) {
      await db.from('documents').update({ verifikation_id: ver.id }).eq('id', p.document_id).is('verifikation_id', null).then(() => {}, () => {})
      await db.from('ai_bokforing_logg').update({ verifikation_id: ver.id })
        .eq('document_id', p.document_id).is('verifikation_id', null).eq('applied', true).then(() => {}, () => {})
    }
    await db.from('mcp_confirm_tokens')
      .update({ used_at: new Date().toISOString(), verifikation_id: ver.id }).eq('id', token.id).then(() => {}, () => {})

    return {
      bokford: true, verifikation_id: ver.id, nr: `${ver.ver_serie} ${ver.ver_nr}`, supplier_invoice_id: invId,
      kvitto: `${p.beskrivning} bokförd via reskontran (${p.total.toFixed(2)} kr) — verifikation ${ver.ver_nr}${p.document_id ? ', underlaget kopplat' : ''}.`,
    }
  }

  // ---- Steg 1: validera och skapa förslag + engångstoken ----
  const payload = await valideraLevfaktura(db, companyId, {
    document_id: args.document_id ? String(args.document_id) : null,
    supplier_invoice_id: args.supplier_invoice_id ? String(args.supplier_invoice_id) : null,
    kostnadskonto: args.kostnadskonto ? String(args.kostnadskonto) : null,
  })
  const { data: token, error: tFel } = await db.from('mcp_confirm_tokens').insert({
    user_id: ctx.userId, company_id: companyId, tool: 'bokfor_leverantorsfaktura',
    payload, idempotency_key: payload.idempotency_key,
    expires_at: new Date(Date.now() + TOKEN_TTL_MS).toISOString(),
  }).select('id, expires_at').single()
  if (tFel) throw new Error(`Kunde inte skapa bekräftelsetoken: ${tFel.message}`)

  return {
    bokford: false,
    forslag: {
      typ: 'leverantorsfaktura', datum: payload.datum, serie: payload.serie, beskrivning: payload.beskrivning,
      rader: payload.rader, total: payload.total,
      faktura: { fakturanr: payload.fakturanr, leverantor: payload.leverantorsnamn, forfallodatum: payload.forfallodatum, kreditfaktura: payload.kredit, lage: payload.lage },
    },
    bekraftelse_token: token.id,
    giltig_till: token.expires_at,
    instruktion: 'VISA förslaget för användaren och invänta godkännande. Bekräfta sedan med ENDAST company_id och bekraftelse_token. Bokför ALDRIG utan användarens godkännande.',
  }
}

// ---- Bankmatchning (Spiris-/Fortnox-modellen): endast 100 % träff får utföras ----
// Validerar matchningen och bygger betalningspayloaden. Speglar appens bookMatch/
// betalaFaktura i KassaBank.jsx EXAKT: D 2440 / K bankkontot i utbetalningsserien,
// bankhändelsen länkas, fakturan markeras betald (paid_amount = total, betalning_ver_id).
async function valideraMatchning(db: SupabaseClient, companyId: string, txId: string, invId: string) {
  const { data: tx } = await db.from('bank_transactions')
    .select('id, account_nr, datum, text, amount, verifikation_id')
    .eq('company_id', companyId).eq('id', txId).maybeSingle()
  if (!tx) throw new Error('Bankhändelsen hittades inte.')
  if (tx.verifikation_id) throw new Error('Bankhändelsen är redan bokförd/matchad.')
  if (Number(tx.amount) >= 0) throw new Error('Bankhändelsen är en insättning – leverantörsbetalningar är utbetalningar (negativt belopp).')

  const { data: inv } = await db.from('supplier_invoices')
    .select('id, invoice_nr, total_amount, paid_amount, paid_date, bokford, makulerad, kreditfaktura, suppliers(name)')
    .eq('company_id', companyId).eq('id', invId).maybeSingle()
  if (!inv) throw new Error('Leverantörsfakturan hittades inte.')
  if (inv.makulerad) throw new Error('Fakturan är makulerad.')
  if (inv.kreditfaktura) throw new Error('Kreditfakturor matchas inte som utbetalningar – hanteras i Kassa och bank.')
  if (!inv.bokford) throw new Error('Fakturan är inte bokförd i reskontran ännu – bokför den först.')
  if (inv.paid_date) throw new Error('Fakturan är redan markerad som betald.')

  const rest = Math.round(((Number(inv.total_amount) || 0) - (Number(inv.paid_amount) || 0)) * 100)
  const betalt = Math.round(Math.abs(Number(tx.amount)) * 100)
  if (rest !== betalt) {
    throw new Error(`Ingen 100 % träff: bankhändelsen är ${(betalt / 100).toFixed(2)} kr men fakturans restbelopp ${(rest / 100).toFixed(2)} kr. Matchningen görs i så fall manuellt i Kassa och bank.`)
  }

  // Konton måste finnas, vara aktiva och ospärrade (samma vakt som valideraVerifikation).
  const kontonr = ['2440', String(tx.account_nr)]
  const { data: konton } = await db.from('accounts')
    .select('account_nr, name, is_active, is_blocked_for_manual_booking')
    .eq('company_id', companyId).in('account_nr', kontonr)
  for (const nr of kontonr) {
    const k = (konton || []).find((a) => a.account_nr === nr)
    if (!k) throw new Error(`Konto ${nr} finns inte i bolagets kontoplan.`)
    if (!k.is_active) throw new Error(`Konto ${nr} (${k.name}) är inaktivt.`)
    if (k.is_blocked_for_manual_booking) throw new Error(`Konto ${nr} (${k.name}) är spärrat för manuell bokföring.`)
  }
  const namn = (nr: string) => (konton || []).find((a) => a.account_nr === nr)?.name || nr

  // Datum i aktivt räkenskapsår (betalningen bokförs på bankhändelsens datum).
  const { data: fy } = await db.from('fiscal_years').select('year, status')
    .eq('company_id', companyId).lte('start_date', tx.datum).gte('end_date', tx.datum).maybeSingle()
  if (!fy) throw new Error(`Bankhändelsens datum ${tx.datum} ligger inte i något räkenskapsår.`)
  if (fy.status !== 'active') throw new Error(`Räkenskapsåret ${fy.year} är inte aktivt – bokföring stoppad.`)

  // Utbetalningsserien enligt bolagets inställningar (spegel av src/lib/serier.js).
  const { data: bolag } = await db.from('companies').select('settings').eq('id', companyId).maybeSingle()
  const serie = String((bolag?.settings as { serier?: Record<string, string> } | null)?.serier?.utbetalningar || 'U - Utbetalningar')

  const leverantor = (inv.suppliers as { name?: string } | null)?.name || null
  const belopp = betalt / 100
  return {
    company_id: companyId,
    bank_transaction_id: tx.id, supplier_invoice_id: inv.id,
    datum: tx.datum, serie,
    beskrivning: `Betalning av leverantörsfaktura ${inv.invoice_nr || ''} ${leverantor || ''}`.trim().slice(0, 200),
    motpart: leverantor,
    total: belopp, paid_amount_efter: Number(inv.total_amount) || 0,
    rader: [
      { konto: '2440', benamning: namn('2440'), debet: belopp, kredit: 0, info: null },
      { konto: String(tx.account_nr), benamning: namn(String(tx.account_nr)), debet: 0, kredit: belopp, info: null },
    ],
    faktura: { fakturanr: inv.invoice_nr, leverantor },
    bankhandelse: { datum: tx.datum, text: tx.text, belopp: Number(tx.amount) },
    idempotency_key: `bankmatch-${tx.id}`,
  }
}

async function toolMatchaBankhandelse(db: SupabaseClient, args: Record<string, unknown>, ctx: Ctx) {
  const companyId = String(args.company_id)

  // ---- Steg 2: bekräftelse – utför den SPARADE matchningen ----
  if (args.bekraftelse_token) {
    const { data: token } = await db.from('mcp_confirm_tokens').select('*')
      .eq('id', String(args.bekraftelse_token)).eq('user_id', ctx.userId)
      .eq('company_id', companyId).eq('tool', 'matcha_bankhandelse').maybeSingle()
    if (!token) throw new Error('Ogiltig bekräftelsetoken.')
    if (token.used_at) throw new Error('Token redan förbrukad – matchningen är redan utförd.')
    if (new Date(token.expires_at) < new Date()) throw new Error('Bekräftelsetoken har gått ut (5 min). Kör steg 1 igen.')

    const p = token.payload as Awaited<ReturnType<typeof valideraMatchning>>
    // Om-validera precis före utförandet (händelsen/fakturan kan ha ändrats).
    const farsk = await valideraMatchning(db, companyId, p.bank_transaction_id, p.supplier_invoice_id)

    const { data: ver, error: verFel } = await db.rpc('bokfor_verifikation', {
      p_company_id: companyId, p_serie: farsk.serie, p_datum: farsk.datum,
      p_beskrivning: farsk.beskrivning,
      p_rader: farsk.rader.map((r, i) => ({
        account_nr: r.konto, account_name: r.benamning,
        debet: r.debet, kredit: r.kredit, transaction_info: r.info, sort_order: i,
      })),
      p_motpart: farsk.motpart, p_created_by: ctx.userId, p_source: ctx.kanal === 'assistent' ? 'ai' : 'mcp',
      p_kommentar: null,
    })
    if (verFel || !ver) throw new Error(`Betalningen kunde inte bokföras: ${verFel?.message || 'okänt fel'}`)

    // Efterled 1: länka bankhändelsen. Misslyckas det ÅTERSTÄLLS verifikationen
    // (annars dubbelbokför nästa försök) — samma mönster som aterstallVerifikation.
    const { error: txFel } = await db.from('bank_transactions')
      .update({ status: 'booked', verifikation_id: ver.id }).eq('id', farsk.bank_transaction_id)
    if (txFel) {
      const rensad = await db.rpc('radera_senaste_verifikation', { p_ver_id: ver.id })
        .then((r) => !r.error, () => false)
      if (!rensad) await db.rpc('makulera_verifikation', { p_ver_id: ver.id, p_orsak: 'Automatisk återställning: bankhändelsen kunde inte länkas' }).then(() => {}, () => {})
      throw new Error(`Bankhändelsen kunde inte länkas (${txFel.message}) – betalningsverifikationen återställdes, försök igen.`)
    }
    // Efterled 2: markera fakturan betald (best effort – bokföringen och länken består).
    const { error: invFel } = await db.from('supplier_invoices')
      .update({ status: 'paid', paid_amount: farsk.paid_amount_efter, paid_date: farsk.datum, betalning_ver_id: ver.id })
      .eq('id', farsk.supplier_invoice_id)

    await db.from('mcp_confirm_tokens')
      .update({ used_at: new Date().toISOString(), verifikation_id: ver.id }).eq('id', token.id)
      .then(() => {}, () => {})

    return {
      bokford: true, verifikation_id: ver.id, nr: `${ver.ver_serie} ${ver.ver_nr}`,
      kvitto: `Matchad: ${farsk.beskrivning} (${farsk.total.toFixed(2)} kr) – verifikation ${ver.ver_nr}, bankhändelsen länkad${invFel ? ', men fakturan kunde inte markeras betald: ' + invFel.message : ' och fakturan markerad betald'}.`,
    }
  }

  // ---- Steg 1: validera 100 %-träffen och skapa förslag + engångstoken ----
  if (!args.bank_transaction_id || !args.supplier_invoice_id) throw new Error('bank_transaction_id och supplier_invoice_id krävs.')
  const payload = await valideraMatchning(db, companyId, String(args.bank_transaction_id), String(args.supplier_invoice_id))
  const { data: token, error: tFel } = await db.from('mcp_confirm_tokens').insert({
    user_id: ctx.userId, company_id: companyId, tool: 'matcha_bankhandelse',
    payload, idempotency_key: payload.idempotency_key,
    expires_at: new Date(Date.now() + TOKEN_TTL_MS).toISOString(),
  }).select('id, expires_at').single()
  if (tFel) throw new Error(`Kunde inte skapa bekräftelsetoken: ${tFel.message}`)

  return {
    bokford: false,
    forslag: {
      typ: 'matchning', datum: payload.datum, serie: payload.serie, beskrivning: payload.beskrivning,
      rader: payload.rader, total: payload.total,
      faktura: payload.faktura, bankhandelse: payload.bankhandelse,
    },
    bekraftelse_token: token.id,
    giltig_till: token.expires_at,
    instruktion: 'VISA matchningen för användaren och invänta godkännande. Bekräfta sedan med ENDAST company_id och bekraftelse_token. Matcha ALDRIG utan användarens godkännande.',
  }
}

async function toolForeslaRattelse(db: SupabaseClient, args: Record<string, unknown>) {
  const companyId = String(args.company_id)
  const { data: v } = await db.from('verifikationer').select('id, ver_serie, ver_nr, datum, beskrivning, status')
    .eq('company_id', companyId).eq('id', String(args.verifikation_id)).maybeSingle()
  if (!v) throw new Error('Verifikationen hittades inte.')
  if (v.status !== 'aktiv') throw new Error(`Verifikationen har status "${v.status}" och kan inte rättas.`)
  const { data: rader } = await db.from('verifikation_rows').select('account_nr, account_name, debet, kredit').eq('verifikation_id', v.id).order('sort_order')
  const anledning = String(args.anledning || 'rättelse')
  return {
    original: { verifikation_id: v.id, nr: `${v.ver_serie} ${v.ver_nr}`, datum: v.datum, beskrivning: v.beskrivning },
    princip: 'BFL: originalet raderas aldrig. Rättelse = omvänd verifikation som nollställer originalet, därefter bokförs ev. korrekt verifikation separat.',
    omvand_verifikation: {
      beskrivning: `Rättelse av ${v.ver_nr}: ${anledning}`,
      rader: (rader || []).map((r) => ({ konto: r.account_nr, debet: r.kredit, kredit: r.debet })),
    },
    instruktion: 'Granska med användaren och bokför den omvända verifikationen via skapa_verifikation (två steg med bekräftelse).',
  }
}

async function toolForeslaKontering(db: SupabaseClient, args: Record<string, unknown>, ctx: Ctx) {
  const companyId = String(args.company_id)

  // Väg 1: underlag med AI-tolkning från tolka-underlag.
  if (args.document_id) {
    const { data: dok } = await db.from('documents').select('id, file_name, tolkad, tolkning, confidence, verifikation_id')
      .eq('company_id', companyId).eq('id', String(args.document_id)).is('raderad_at', null).maybeSingle()
    if (!dok) throw new Error('Underlaget hittades inte.')
    if (dok.verifikation_id) throw new Error('Underlaget är redan bokfört.')
    const t = (dok.tolkning || {}) as Record<string, unknown>
    const rader = Array.isArray(t.konteringsrader) ? t.konteringsrader : []
    if (!dok.tolkad || rader.length === 0) throw new Error('Underlaget saknar AI-tolkning med konteringsförslag – tolka det i BokPilot först.')
    return {
      kalla: 'tolka-underlag (AI-tolkning av underlaget)',
      underlag: { document_id: dok.id, filnamn: dok.file_name, leverantor: t.leverantor ?? null, belopp_inkl_moms: t.belopp_inkl_moms ?? null, moms_belopp: t.moms_belopp ?? null, fakturadatum: t.fakturadatum ?? null },
      konteringsforslag: rader,
      konfidens: dok.confidence,
      instruktion: 'Granska förslaget med användaren och bokför sedan via skapa_verifikation (skicka med document_id så kopplas underlaget).',
    }
  }

  // Väg 2: fritext → bokfor-ai (samma regelverk v1.0.0 som appens kunskapschatt).
  const fraga = String(args.fraga || '').trim()
  if (!fraga) throw new Error('Ange document_id eller fraga.')
  const { data: konton } = await db.from('accounts').select('account_nr, name')
    .eq('company_id', companyId).eq('is_active', true).order('account_nr').limit(400)
  const kontoplan = (konton || []).map((k) => `${k.account_nr} ${k.name}`).join('\n')
  const resp = await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/bokfor-ai`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: ctx.authHeader },
    body: JSON.stringify({ kind: 'verifikation', fraga, kontoplan }),
  })
  const ai = await resp.json()
  if (!resp.ok || ai.error) throw new Error(`Konteringsförslaget kunde inte tas fram: ${ai.error || resp.status}`)
  return {
    kalla: `bokfor-ai (${ai.model}, regelverk v${ai.regelverkVersion})`,
    svar: ai.svar,
    konteringsforslag: ai.konteringsforslag || [],
    konfidens: ai.konfidens,
    kraver_manuell_granskning: ai.kraver_manuell_granskning,
    regelstod: ai.regelstod,
    instruktion: 'Granska förslaget med användaren och bokför sedan via skapa_verifikation.',
  }
}

const TOOL_IMPL: Record<string, (db: SupabaseClient, args: Record<string, unknown>, ctx: Ctx) => Promise<unknown>> = {
  lista_foretag: (db) => toolListaForetag(db),
  sok_verifikationer: toolSokVerifikationer,
  hamta_verifikation: toolHamtaVerifikation,
  hamta_huvudbok: toolHamtaHuvudbok,
  hamta_resultatrapport: toolResultatrapport,
  hamta_balansrapport: toolBalansrapport,
  lista_kundfakturor: toolListaKundfakturor,
  lista_leverantorsfakturor: toolListaLeverantorsfakturor,
  hamta_momsunderlag: toolMomsunderlag,
  lista_underlag: toolListaUnderlag,
  hamta_underlagstolkning: toolUnderlagstolkning,
  hamta_kontoplan: toolKontoplan,
  hamta_bokforingsstatus: toolBokforingsstatus,
  lista_bankhandelser: toolListaBankhandelser,
  foresla_kontering: toolForeslaKontering,
  skapa_verifikation: toolSkapaVerifikation,
  registrera_leverantorsfakturor: toolRegistreraLevfakturor,
  bokfor_leverantorsfaktura: toolBokforLevfaktura,
  matcha_bankhandelse: toolMatchaBankhandelse,
  foresla_rattelse: toolForeslaRattelse,
}

// ---------- MCP/JSON-RPC-hantering ----------
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  // Ingen SSE-ström i v0.x – klienter som öppnar GET får 405 och kör ren POST i stället.
  if (req.method !== 'POST') return new Response(null, { status: 405, headers: cors })

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
  const ANON = Deno.env.get('SUPABASE_ANON_KEY')!
  const db = createClient(SUPABASE_URL, ANON, { global: { headers: { Authorization: req.headers.get('Authorization') || '' } } })
  const { data: { user } } = await db.auth.getUser()
  if (!user) return rpcError(null, -32001, 'Ej inloggad – Supabase JWT krävs som Bearer-token.', 401)

  // Assistentkanalen: appens inbyggda bokföringsassistent (edge bokforingsassistent)
  // återanvänder connectorns verktyg. Kanal-headern kräver den interna nyckeln
  // (interna_nycklar 'assistent_kanal' – lämnar aldrig serversidan) och ger:
  //  - ingen claude_connector-gate (assistenten är en kärnfunktion, inte en connector)
  //  - p_source 'ai' i stället för 'mcp' vid bokföring (AI-transparensen i audit).
  // Utan giltig nyckel ignoreras headern helt (vanlig MCP-behandling).
  let kanal: 'assistent' | null = null
  if (req.headers.get('x-bokpilot-kanal') === 'assistent') {
    const service = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const { data: nyckel } = await service.from('interna_nycklar').select('varde').eq('namn', 'assistent_kanal').maybeSingle()
    if (nyckel?.varde && req.headers.get('x-assistent-nyckel') === nyckel.varde) kanal = 'assistent'
  }

  let msg: { jsonrpc?: string; method?: string; params?: Record<string, unknown>; id?: unknown }
  try {
    msg = await req.json()
  } catch {
    return rpcError(null, -32700, 'Ogiltig JSON.', 400)
  }
  if (Array.isArray(msg)) return rpcError(null, -32600, 'Batch-anrop stöds inte.', 400)

  const { method, params, id } = msg
  // Notiser (utan id) kvitteras utan innehåll.
  if (id === undefined || id === null || String(method || '').startsWith('notifications/')) {
    return new Response(null, { status: 202, headers: cors })
  }

  try {
    switch (method) {
      case 'initialize': {
        const begard = String(params?.protocolVersion || '')
        return rpcResult(id, {
          protocolVersion: PROTOCOL_VERSIONS.includes(begard) ? begard : PROTOCOL_VERSIONS[0],
          capabilities: { tools: {} },
          serverInfo: SERVER_INFO,
          instructions:
            'BokPilot Claude Connector. Börja med lista_foretag för att få company_id. Läsverktygen är fria att använda. Skrivande verktyg (skapa_verifikation) kräver TVÅ steg: först ett förslag med engångstoken, sedan – EFTER att användaren uttryckligen sagt JA – en bekräftelse med token. Bokför aldrig utan användarens godkännande. Radering finns inte; rättelse sker som omvänd verifikation via foresla_rattelse.',
        })
      }
      case 'ping':
        return rpcResult(id, {})
      case 'tools/list':
        return rpcResult(id, { tools: TOOLS })
      case 'tools/call': {
        const namn = String(params?.name || '')
        const args = (params?.arguments || {}) as Record<string, unknown>
        const companyId = typeof args.company_id === 'string' ? args.company_id : null
        const impl = TOOL_IMPL[namn]
        if (!impl) return rpcError(id, -32602, `Okänt verktyg: ${namn}`)
        if (namn !== 'lista_foretag' && !companyId) {
          return rpcResult(id, { content: [{ type: 'text', text: 'company_id krävs – hämta via lista_foretag.' }], isError: true })
        }
        // Feature-gate för alla bolagsbundna verktyg (gäller ej assistentkanalen).
        if (companyId && kanal !== 'assistent' && !(await featureAktiverad(db, companyId))) {
          await audit(db, user.id, companyId, namn, args, 'nekad', 'claude_connector ej aktiverad')
          return rpcResult(id, { content: [{ type: 'text', text: 'Claude-connectorn är inte aktiverad för detta bolag. Kontakta BokPilot för aktivering.' }], isError: true })
        }
        const data = await impl(db, args, { userId: user.id, authHeader: req.headers.get('Authorization') || '', kanal })
        await audit(db, user.id, companyId, namn, args, 'ok')
        return rpcResult(id, { content: [{ type: 'text', text: JSON.stringify(data) }], structuredContent: data, isError: false })
      }
      default:
        return rpcError(id, -32601, `Okänd metod: ${method}`)
    }
  } catch (err) {
    const fel = String((err as Error)?.message || err)
    console.error(`mcp-server: fel i ${method}/${String((params as Record<string, unknown>)?.name || '')}: ${fel}`)
    if (method === 'tools/call') {
      await audit(db, user.id, (params?.arguments as Record<string, unknown>)?.company_id as string || null, String(params?.name || ''), params?.arguments, 'fel', fel)
      return rpcResult(id, { content: [{ type: 'text', text: `Fel: ${fel}` }], isError: true })
    }
    return rpcError(id, -32603, fel)
  }
})
