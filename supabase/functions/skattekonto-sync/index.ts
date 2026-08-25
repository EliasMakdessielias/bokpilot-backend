// Skattekonto-synk mot Skatteverkets API (Skattekonto via API).
//
// Hämtar skattekontots saldo och transaktioner och importerar dem som bankhändelser
// på konto 1630 – därifrån tar det befintliga skattekonto-regelverket (Kassa och bank →
// Skattekonto) över: matchning på transaktionstext och bokföring mot fasta motkonton.
//
// KÄLLLÄGEN (edge-secret SKV_MODE):
//   mock   – Skatteverkets exempeldata ur API-definitionen (RAML). Ingen nätverkstrafik.
//            Används tills API-nycklar finns. UI:t visar tydligt att det är testdata.
//   enkel  – Enkel testtjänst (mockup): api.test.skatteverket.se/enkeltesttjanst, v1.
//   test   – Komplett testtjänst (sandbox): via SKV-gatewayn (Node på Fly.io, fly/skv-gateway/)
//            som bär organisationslegitimationen/mTLS över TLS 1.2 och sköter CCG-token.
//            Kräver edge-secrets SKV_GATEWAY_URL + SKV_GATEWAY_NYCKEL.
//   prod   – Driftsatt tjänst: samma gateway med SKV_MILJO=prod. Kräver avtal med
//            Skatteverket och att kunden registrerat oss som ombud (Skattekonto, läsbehörighet).
//
// Operationer (POST, user-JWT + medlemskontroll):
//   { company_id, op: 'preview' } → { lage, saldo, transaktioner, kommande, nya_antal }
//   { company_id, op: 'import' }  → som preview + skriver NYA rader till bank_transactions
//                                   (konto 1630, status 'unmatched', dedup på datum+text+belopp).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SKATTEKONTO = '1630'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })
}

// Skatteverkets exempelrespons (RAML examples/transaktionerResponse.json + saldoResponse.json),
// datumskiftad till innevarande år så flödet går att demonstrera. Markeras lage='mock' i svaret.
function mockData() {
  const y = new Date().getFullYear()
  return {
    saldo: { saldoSkatteverket: -14487, rantaSkatteverket: -12, senastUppdaterad: new Date().toISOString(), nastaAvstamningsdatum: `${y}-08-05` },
    transaktioner: {
      tidigareTransaktioner: [
        { transaktionsdatum: `${y}-04-16`, transaktionstext: 'Inbetalning bokförd 260412', beloppSkatteverket: 1292 },
        { transaktionsdatum: `${y}-04-16`, transaktionstext: 'Debiterad preliminärskatt', beloppSkatteverket: -1292 },
        { transaktionsdatum: `${y}-04-16`, transaktionstext: 'Inbetalning bokförd 260411', beloppSkatteverket: 5402 },
        { transaktionsdatum: `${y}-04-16`, transaktionstext: 'Avdragen skatt mars ' + y, beloppSkatteverket: -3000 },
        { transaktionsdatum: `${y}-04-16`, transaktionstext: 'Arbetsgivaravgift mars ' + y, beloppSkatteverket: -2402 },
        { transaktionsdatum: `${y}-05-13`, transaktionstext: 'Moms februari ' + y, beloppSkatteverket: -4100 },
        { transaktionsdatum: `${y}-06-02`, transaktionstext: 'Intäktsränta', beloppSkatteverket: 4 },
      ],
      kommandeTransaktioner: [
        { transaktionsdatum: `${y}-07-13`, forfallodatum: `${y}-07-13`, transaktionstext: 'Debiterad preliminärskatt', beloppSkatteverket: -1292 },
      ],
    },
  }
}

// Riktiga API-anrop (enkel/test/prod). Samma svarsformat som mock.
//
// test/prod går via SKV-GATEWAYN (Node på Fly.io, fly/skv-gateway/): den bär
// organisationslegitimationen (mTLS, TLS 1.2) som CCG-tokenflödet kräver och som
// edge-runtimen inte klarar. Gatewayn autentiseras med delad hemlighet och proxar
// svaret rakt igenom.
async function hamtaFranSkv(mode: string, orgnr: string) {
  let anropa: (op: string) => Promise<any>

  if (mode === 'enkel') {
    // Enkel testtjänst (mockup, v1) – direktanrop med API-nycklar.
    const headers: Record<string, string> = {
      Accept: 'application/json',
      client_id: Deno.env.get('SKV_CLIENT_ID') || '',
      client_secret: Deno.env.get('SKV_CLIENT_SECRET') || '',
      'SKV-client_correlationid': crypto.randomUUID(),
    }
    anropa = async (op: string) => {
      const resp = await fetch(`https://api.test.skatteverket.se/enkeltesttjanst/beskattning/skattekonto/v1/skattekonton/${orgnr}/${op}`, { headers })
      const body = await resp.text()
      if (!resp.ok) {
        const err = new Error(`Skatteverket svarade ${resp.status} på ${op}: ${body.slice(0, 200)}`) as Error & { status?: number }
        err.status = resp.status
        throw err
      }
      return JSON.parse(body)
    }
  } else {
    // Komplett testtjänst / produktion (v2) – via gatewayn.
    const gatewayUrl = (Deno.env.get('SKV_GATEWAY_URL') || '').replace(/\/+$/, '')
    const gatewayNyckel = Deno.env.get('SKV_GATEWAY_NYCKEL') || ''
    if (!gatewayUrl || !gatewayNyckel) {
      throw new Error('SKV_GATEWAY_URL/SKV_GATEWAY_NYCKEL saknas i edge-secrets – deploya gatewayn (fly/skv-gateway/README.md)')
    }
    anropa = async (op: string) => {
      const resp = await fetch(`${gatewayUrl}/beskattning/skattekonto/v2/skattekonton/${orgnr}/${op}`, {
        // scope 'ska' = Skattekonto (SKV la till det 2026-07-10; 'skahmst' räckte inte för API-anropen)
        headers: { 'x-gateway-nyckel': gatewayNyckel, 'x-skv-scope': 'ska' },
      })
      const body = await resp.text()
      if (!resp.ok) {
        const err = new Error(`Skatteverket svarade ${resp.status} på ${op}: ${body.slice(0, 200)}`) as Error & { status?: number }
        err.status = resp.status
        throw err
      }
      return JSON.parse(body)
    }
  }

  const [saldo, transaktioner] = await Promise.all([anropa('saldo'), anropa('transaktioner')])
  return { saldo, transaktioner }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
  const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
  const admin = createClient(SUPABASE_URL, SERVICE_KEY)

  try {
    // Autentisering: användarens JWT + medlemskap i bolaget (samma mönster som tolka-underlag).
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'ej inloggad' }, 401)

    const { company_id, op = 'preview' } = await req.json().catch(() => ({}))
    if (!company_id) return json({ error: 'company_id saknas' }, 400)
    const { data: medlem } = await admin.from('user_companies').select('user_id')
      .eq('user_id', user.id).eq('company_id', company_id).maybeSingle()
    if (!medlem) return json({ error: 'ingen behörighet till bolaget' }, 403)

    const mode = (Deno.env.get('SKV_MODE') || 'mock').toLowerCase()
    const { data: bolag } = await admin.from('companies').select('org_nr').eq('id', company_id).single()
    // 12-siffrigt: orgnr 5591658181 → 165591658181 (sekelsiffra 16 för juridiska personer).
    const siffror = String(bolag?.org_nr || '').replace(/\D/g, '')
    let orgnr = siffror.length === 10 ? `16${siffror}` : siffror
    // I kompletta testtjänsten har endast SKV:s TESTHUVUDMÄN data (och gatewayns Bolag A-cert
    // är ombudet). Riktiga orgnr ger 'Auktorisation saknas' där – fråga på testhuvudmannen.
    if (mode === 'test') orgnr = Deno.env.get('SKV_TEST_ORGNR') || '165781006662'

    const data = mode === 'mock' ? mockData() : await hamtaFranSkv(mode, orgnr)
    const tidigare = data.transaktioner?.tidigareTransaktioner || []
    const kommande = data.transaktioner?.kommandeTransaktioner || []

    // Dedup: transaktioner som redan finns som bankhändelser på 1630 (datum+text+belopp).
    const { data: befintliga } = await admin.from('bank_transactions')
      .select('datum, text, amount').eq('company_id', company_id).eq('account_nr', SKATTEKONTO)
    const nyckel = (d: string, t: string, a: number) => `${d}|${t}|${Math.round(a * 100)}`
    const finns = new Set((befintliga || []).map(b => nyckel(b.datum, b.text || '', Number(b.amount) || 0)))
    const nya = tidigare.filter((t: any) =>
      !finns.has(nyckel(t.transaktionsdatum, t.transaktionstext || '', Number(t.beloppSkatteverket) || 0)))

    let importerade = 0
    if (op === 'import' && nya.length) {
      const batch = crypto.randomUUID()
      const { error } = await admin.from('bank_transactions').insert(nya.map((t: any) => ({
        company_id, account_nr: SKATTEKONTO,
        datum: t.transaktionsdatum, text: t.transaktionstext,
        amount: Number(t.beloppSkatteverket) || 0, status: 'unmatched', import_batch: batch,
      })))
      if (error) throw error
      importerade = nya.length
    }

    return json({
      ok: true, lage: mode, orgnr,
      saldo: data.saldo?.saldoSkatteverket ?? null,
      ranta: data.saldo?.rantaSkatteverket ?? null,
      senast_uppdaterad: data.saldo?.senastUppdaterad ?? null,
      antal_tidigare: tidigare.length, nya_antal: nya.length, importerade,
      kommande: kommande.map((t: any) => ({ datum: t.forfallodatum || t.transaktionsdatum, text: t.transaktionstext, belopp: t.beloppSkatteverket })),
      nya: nya.slice(0, 50).map((t: any) => ({ datum: t.transaktionsdatum, text: t.transaktionstext, belopp: t.beloppSkatteverket })),
    })
  } catch (err) {
    const e = err as Error & { status?: number }
    return json({ error: String(e?.message || e), skv_status: e?.status ?? null }, 500)
  }
})
