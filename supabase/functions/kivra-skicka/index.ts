// Kivra-utskick: skickar kundfakturor och lönespecifikationer till mottagarnas Kivra
// via Kivras Tenant API (avsändarsidan – mottagarsidan sköts av kivra-sync).
//
// PDF:erna renderas SERVER-SIDA med pdf-lib (husmönstret från annual-report-pdf) från
// bokföringsdatat – ingen klientgenerering, samma dokument oavsett enhet.
//
// KÄLLLÄGEN (edge-secret KIVRA_MODE – delas med kivra-sync):
//   mock     – renderar PDF:en och loggar utskicket, men skickar INGET till Kivra.
//              UI:t visar tydligt "förhandsläge". Standard tills avsändaravtal finns.
//   sandbox  – sender.sandbox-api.kivra.com (kräver KIVRA_CLIENT_ID/SECRET + KIVRA_TENANT_KEY)
//   prod     – sender.api.kivra.com (kräver avsändaravtal med Kivra; betalas per försändelse)
//
// Tenant API (v2): POST /v2/tenant/{tenantKey}/content med mottagare (vat_number | ssn |
// email – Kivra matchar i den ordningen), subject, type och parts (PDF, base64).
// Lönespecar skickas med retain=true (letter.salary får väntas in upp till 390 dagar om
// mottagaren ännu inte har Kivra). Kivra har inbyggd dubblettspärr på hela payloaden.
//
// Operationer (POST, user-JWT + medlemskontroll):
//   { company_id, op: 'skicka-faktura',    invoice_id } → skickar EN kundfaktura
//   { company_id, op: 'skicka-lonespecar', run_id }     → skickar ALLA lönebesked i körningen
// Allt loggas i kivra_utskick (mottagare maskerad – personnummer aldrig i klartext).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { PDFDocument, StandardFonts, rgb } from 'https://esm.sh/pdf-lib@1.17.1'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })
}

const kr = (n: unknown) => (Number(n) || 0).toLocaleString('sv-SE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
// Maskera identifierare för loggen: personnummer visar bara födelseår/månad, orgnr visar allt utom sista 4.
function maskera(id: string): string {
  const s = String(id || '').replace(/\D/g, '')
  if (s.length >= 10) return `${s.slice(0, 6)}**-****`
  return id ? `${String(id).slice(0, 4)}…` : 'okänd'
}

// ── PDF-rendering (pdf-lib): enkel, ren svensk layout. WinAnsi klarar å/ä/ö. ──
async function fakturaPdf(bolag: any, faktura: any, kund: any, rader: any[]): Promise<Uint8Array> {
  const doc = await PDFDocument.create()
  const page = doc.addPage([595, 842])
  const font = await doc.embedFont(StandardFonts.Helvetica)
  const bold = await doc.embedFont(StandardFonts.HelveticaBold)
  const grå = rgb(0.45, 0.45, 0.45)
  let y = 790
  const rad = (t: string, x: number, size = 10, f = font, färg = rgb(0, 0, 0)) => page.drawText(t, { x, y, size, font: f, color: färg })

  rad(bolag?.name || 'BokPilot', 50, 16, bold); y -= 16
  if (bolag?.org_nr) { rad(`Org.nr ${bolag.org_nr}`, 50, 9, font, grå); y -= 24 } else y -= 24
  rad(`FAKTURA ${faktura.invoice_nr || ''}`, 50, 20, bold); y -= 30

  rad('Fakturamottagare', 50, 9, font, grå); rad('Fakturadatum', 330, 9, font, grå); rad('Förfallodatum', 460, 9, font, grå); y -= 14
  rad(kund?.name || '–', 50, 11, bold); rad(String(faktura.invoice_date || ''), 330, 11); rad(String(faktura.due_date || ''), 460, 11); y -= 14
  if (kund?.org_nr) { rad(String(kund.org_nr), 50, 9, font, grå) }
  y -= 30

  rad('Beskrivning', 50, 9, bold); rad('Antal', 330, 9, bold); rad('À-pris', 400, 9, bold); rad('Belopp', 480, 9, bold); y -= 6
  page.drawLine({ start: { x: 50, y }, end: { x: 545, y }, thickness: 0.5, color: grå }); y -= 16
  for (const r of rader) {
    rad(String(r.description || '').slice(0, 55), 50, 10)
    rad(String(r.quantity ?? ''), 330, 10)
    rad(kr(r.unit_price), 400, 10)
    rad(kr(r.total), 480, 10)
    y -= 16
    if (y < 160) break
  }
  y -= 6
  page.drawLine({ start: { x: 50, y }, end: { x: 545, y }, thickness: 0.5, color: grå }); y -= 18
  rad('Netto', 400, 10, font, grå); rad(kr(faktura.amount_excl_vat), 480, 10); y -= 14
  rad('Moms', 400, 10, font, grå); rad(kr(faktura.vat_amount), 480, 10); y -= 16
  rad('Att betala', 400, 12, bold); rad(`${kr(faktura.total_amount)} kr`, 480, 12, bold); y -= 30
  if (faktura.message) { rad(String(faktura.message).slice(0, 90), 50, 9, font, grå); y -= 14 }
  rad('Skickad digitalt via Kivra från BokPilot.', 50, 8, font, grå)
  return await doc.save()
}

async function lonespecPdf(bolag: any, korning: any, b: any): Promise<Uint8Array> {
  const doc = await PDFDocument.create()
  const page = doc.addPage([595, 842])
  const font = await doc.embedFont(StandardFonts.Helvetica)
  const bold = await doc.embedFont(StandardFonts.HelveticaBold)
  const grå = rgb(0.45, 0.45, 0.45)
  let y = 790
  const rad = (t: string, x: number, size = 10, f = font, färg = rgb(0, 0, 0)) => page.drawText(t, { x, y, size, font: f, color: färg })

  rad(bolag?.name || 'BokPilot', 50, 16, bold); y -= 16
  if (bolag?.org_nr) { rad(`Org.nr ${bolag.org_nr}`, 50, 9, font, grå) }
  y -= 26
  rad('LÖNEBESKED', 50, 20, bold); y -= 18
  const period = korning?.period || [korning?.ar, korning?.manad && String(korning.manad).padStart(2, '0')].filter(Boolean).join('-') || ''
  if (period) { rad(`Period: ${period}`, 50, 10, font, grå) }
  y -= 28

  rad(b.namn || '', 50, 12, bold); y -= 14
  if (b.personnummer) { rad(maskera(b.personnummer), 50, 9, font, grå) }
  y -= 26

  page.drawLine({ start: { x: 50, y }, end: { x: 545, y }, thickness: 0.5, color: grå }); y -= 18
  rad('Bruttolön', 50, 11); rad(`${kr(b.bruttolon)} kr`, 460, 11); y -= 16
  for (const t of (Array.isArray(b.tillagg) ? b.tillagg : [])) {
    rad(String(t.namn || t.typ || 'Tillägg').slice(0, 50), 50, 10, font, grå)
    rad(`${kr(t.belopp)} kr`, 460, 10)
    y -= 14
  }
  rad('Skatteavdrag', 50, 11); rad(`-${kr(b.skatteavdrag)} kr`, 460, 11); y -= 20
  page.drawLine({ start: { x: 50, y }, end: { x: 545, y }, thickness: 0.5, color: grå }); y -= 18
  rad('Nettolön att utbetala', 50, 12, bold); rad(`${kr(b.nettolon)} kr`, 460, 12, bold); y -= 24
  if (b.skattetabell) { rad(`Skattetabell ${b.skattetabell}:${b.skattekolumn || 1}`, 50, 8, font, grå); y -= 12 }
  rad('Skickad digitalt via Kivra från BokPilot.', 50, 8, font, grå)
  return await doc.save()
}

// ── Kivra Tenant API ──
async function kivraToken(bas: string): Promise<string> {
  const id = Deno.env.get('KIVRA_CLIENT_ID') || ''
  const secret = Deno.env.get('KIVRA_CLIENT_SECRET') || ''
  if (!id || !secret) throw new Error('KIVRA_CLIENT_ID/KIVRA_CLIENT_SECRET saknas i edge-secrets')
  const resp = await fetch(`${bas}/v1/auth`, {
    method: 'POST',
    headers: { Authorization: `Basic ${btoa(`${id}:${secret}`)}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=client_credentials',
  })
  if (!resp.ok) throw new Error(`Kivra auth misslyckades (${resp.status})`)
  return (await resp.json()).access_token
}

function tillBase64(bytes: Uint8Array): string {
  let bin = ''
  const chunk = 0x8000
  for (let i = 0; i < bytes.length; i += chunk) bin += String.fromCharCode(...bytes.subarray(i, i + chunk))
  return btoa(bin)
}

// Skicka ETT innehåll. I mock: rendera + logga, skicka inget. Returnerar content-key (eller null i mock).
async function skickaTillKivra(mode: string, mottagare: { vat_number?: string; ssn?: string }, subject: string, typ: 'invoice' | 'letter.salary', pdf: Uint8Array, retain: boolean): Promise<string | null> {
  if (mode === 'mock') return null
  const bas = mode === 'prod' ? 'https://sender.api.kivra.com' : 'https://sender.sandbox-api.kivra.com'
  const tenantKey = Deno.env.get('KIVRA_TENANT_KEY') || ''
  if (!tenantKey) throw new Error('KIVRA_TENANT_KEY saknas i edge-secrets')
  const token = await kivraToken(bas)
  const body: Record<string, unknown> = {
    ...mottagare,
    subject,
    type: typ,
    generated_at: new Date().toISOString(),
    parts: [{ name: `${subject.replace(/[^\w åäöÅÄÖ.-]+/g, '').slice(0, 60)}.pdf`, data: tillBase64(pdf), content_type: 'application/pdf' }],
  }
  if (retain) body.retain = true
  const resp = await fetch(`${bas}/v2/tenant/${tenantKey}/content`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!resp.ok) throw new Error(`Kivra content (${resp.status}): ${(await resp.text()).slice(0, 200)}`)
  const j = await resp.json().catch(() => ({}))
  return j.key || j.content_key || 'skickad'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
  const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
  const admin = createClient(SUPABASE_URL, SERVICE_KEY)
  const mode = (Deno.env.get('KIVRA_MODE') || 'mock').toLowerCase()

  try {
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'ej inloggad' }, 401)

    const { company_id, op, invoice_id, run_id } = await req.json().catch(() => ({}))
    if (!company_id) return json({ error: 'company_id saknas' }, 400)
    const { data: medlem } = await admin.from('user_companies').select('user_id')
      .eq('user_id', user.id).eq('company_id', company_id).maybeSingle()
    if (!medlem) return json({ error: 'ingen behörighet till bolaget' }, 403)

    const { data: bolag } = await admin.from('companies').select('name, org_nr').eq('id', company_id).single()

    // Loggrad i kivra_utskick (skrivs alltid – även misslyckanden, för spårbarhet).
    const logga = async (typ: string, referens_id: string, mottagare: string, amne: string, key: string | null, fel?: string) => {
      await admin.from('kivra_utskick').insert({
        company_id, typ, referens_id, mottagare, amne, lage: mode,
        kivra_content_key: key, status: fel ? 'misslyckad' : 'skickad', fel: fel || null, skickad_av: user.id,
      })
    }

    if (op === 'skicka-faktura') {
      if (!invoice_id) return json({ error: 'invoice_id saknas' }, 400)
      const { data: faktura } = await admin.from('invoices').select('*, customers(*)')
        .eq('id', invoice_id).eq('company_id', company_id).single()
      if (!faktura) return json({ error: 'fakturan hittades inte' }, 404)
      const { data: rader } = await admin.from('invoice_rows').select('*').eq('invoice_id', invoice_id).order('sort_order')
      const kund = faktura.customers
      const orgnr = String(kund?.org_nr || '').replace(/\D/g, '')
      if (!orgnr) return json({ error: 'kunden saknar organisations-/personnummer – kan inte matchas mot Kivra' }, 400)
      // Företag matchas via VAT-nummer, privatperson (12 siffror som börjar 19/20) via ssn.
      const mottagare = /^(19|20)\d{10}$/.test(orgnr) ? { ssn: orgnr } : { vat_number: `SE${orgnr.slice(-10)}01` }

      const amne = `Faktura ${faktura.invoice_nr || ''} från ${bolag?.name || ''}`.trim()
      const pdf = await fakturaPdf(bolag, faktura, kund, rader || [])
      try {
        const key = await skickaTillKivra(mode, mottagare, amne, 'invoice', pdf, false)
        await logga('faktura', invoice_id, `${kund?.name || ''} (${maskera(orgnr)})`, amne, key)
        return json({ ok: true, lage: mode, skickade: 1, amne, mock: mode === 'mock' || undefined })
      } catch (e) {
        const fel = String((e as Error)?.message || e)
        await logga('faktura', invoice_id, `${kund?.name || ''} (${maskera(orgnr)})`, amne, null, fel)
        return json({ error: fel }, 502)
      }
    }

    if (op === 'skicka-lonespecar') {
      if (!run_id) return json({ error: 'run_id saknas' }, 400)
      const { data: korning } = await admin.from('lonekorningar').select('*').eq('id', run_id).eq('company_id', company_id).single()
      if (!korning) return json({ error: 'lönekörningen hittades inte' }, 404)
      const { data: besked } = await admin.from('lonebesked').select('*').eq('run_id', run_id).order('sort_order')

      // Hoppa över redan skickade (dubbelklicksskydd utöver Kivras egen dubblettspärr).
      const { data: redan } = await admin.from('kivra_utskick').select('referens_id')
        .eq('company_id', company_id).eq('typ', 'lonespec').eq('status', 'skickad')
      const skickadeIds = new Set((redan || []).map((r: any) => r.referens_id))

      let skickade = 0, hoppade = 0
      const fel: string[] = []
      for (const b of besked || []) {
        if (skickadeIds.has(b.id)) { hoppade++; continue }
        const pnr = String(b.personnummer || '').replace(/\D/g, '')
        const amne = `Lönebesked från ${bolag?.name || ''}`.trim()
        if (pnr.length < 10) { fel.push(`${b.namn}: personnummer saknas`); await logga('lonespec', b.id, b.namn || 'okänd', amne, null, 'personnummer saknas'); continue }
        const ssn = pnr.length === 10 ? `19${pnr}` : pnr   // 12-siffrigt krävs; 10-siffrigt antas 19xx (granskas i skarpt läge)
        try {
          const pdfBytes = await lonespecPdf(bolag, korning, b)
          const key = await skickaTillKivra(mode, { ssn }, amne, 'letter.salary', pdfBytes, true)
          await logga('lonespec', b.id, `${b.namn || ''} (${maskera(pnr)})`, amne, key)
          skickade++
        } catch (e) {
          const f = String((e as Error)?.message || e)
          fel.push(`${b.namn}: ${f}`)
          await logga('lonespec', b.id, `${b.namn || ''} (${maskera(pnr)})`, amne, null, f)
        }
      }
      return json({ ok: true, lage: mode, skickade, hoppade, fel: fel.length ? fel : undefined, mock: mode === 'mock' || undefined })
    }

    return json({ error: 'okänd operation' }, 400)
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 500)
  }
})
