// Kivra-synk: hämtar företagsbrevlådans innehåll via Kivras Partner API (samma
// integrationstjänst som Fortnox använder) och lägger dokumenten i BokPilots Inkorg
// med source='kivra' – de dyker upp AUTOMATISKT i Inkorgens Kivra-flik.
//
// SYNKMODELL (Fortnox-beteendet): pg_cron anropar funktionen var 10:e minut med den
// interna nyckeln (tabellen interna_nycklar, namn='kivra_cron') och importerar allt
// nytt för ALLA bolag. Ingen hämtaknapp i UI:t. I mockläge gör cron ingenting –
// exempeldata får aldrig trilla in i riktiga inkorgar automatiskt.
//
// KÄLLLÄGEN (edge-secret KIVRA_MODE):
//   mock     – exempeldata i Kivras format + minimal PDF. Standard tills partneravtal finns.
//   sandbox  – sender.sandbox-api.kivra.com (kräver KIVRA_CLIENT_ID/KIVRA_CLIENT_SECRET)
//   prod     – sender.api.kivra.com (kräver partneravtal; kunden ger åtkomst till sin
//              företagsbrevlåda i Kivras inställningar → Integrationer)
//
// Partner-API-flödet (v1): OAuth2 client credentials (POST /v1/auth, Basic-auth, 8h-token)
//   → GET /v1/partner/company?vat_number=SE{orgnr}01        (companyKey; tom = ej beviljad åtkomst)
//   → GET /v1/partner/company/{ck}/content                  (lista: key, sender_name, subject, created_at, status)
//   → GET /v1/partner/company/{ck}/content/{key}            (metadata: parts med filnycklar)
//   → GET /v1/partner/company/{ck}/content/{key}/file/{fk}/raw  (PDF-bytes)
//
// Ingångar:
//   POST + header x-kivra-cron-secret            → synka ALLA bolag (schemaläggaren)
//   POST {company_id, op:'preview'|'import'} + user-JWT → status/underhåll för ett bolag
//     (preview driver statusraden i Kivra-fliken; import finns för felsökning/testning)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const BUCKET = 'underlag'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-kivra-cron-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })
}

// Minimal giltig PDF (en A4-sida med titelrad) för mocklägets import – innehållet är
// oviktigt, poängen är att hela flödet storage→documents→visning fungerar på riktigt.
function miniPdf(titel: string): Uint8Array {
  const pdf = `%PDF-1.4
1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj
2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj
3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 595 842]/Contents 4 0 R/Resources<</Font<</F1 5 0 R>>>>>>endobj
4 0 obj<</Length 68>>stream
BT /F1 14 Tf 50 780 Td (KIVRA MOCK: ${titel.replace(/[()\\]/g, '')}) Tj ET
endstream
endobj
5 0 obj<</Type/Font/Subtype/Type1/BaseFont/Helvetica>>endobj
trailer<</Root 1 0 R>>
%%EOF`
  return new TextEncoder().encode(pdf)
}

// Kivras exempeldataformat (CompanyInbox-schemat) – typiska företagsbrev.
function mockInbox() {
  const d = (dagar: number) => new Date(Date.now() - dagar * 86400000).toISOString()
  return [
    { key: 'mock-kivra-0001', sender_name: 'Tele2 Sverige AB', subject: 'Faktura 88812345', created_at: d(2), status: 'unread' },
    { key: 'mock-kivra-0002', sender_name: 'Trygg-Hansa', subject: 'Försäkringsbesked företagsförsäkring', created_at: d(5), status: 'unread' },
    { key: 'mock-kivra-0003', sender_name: 'Bolagsverket', subject: 'Registreringsbevis', created_at: d(9), status: 'read' },
  ]
}

// OAuth2 CCG mot Kivra (token giltig 8h – hämtas per körning, enkelt och stateless).
async function kivraToken(bas: string): Promise<string> {
  const id = Deno.env.get('KIVRA_CLIENT_ID') || ''
  const secret = Deno.env.get('KIVRA_CLIENT_SECRET') || ''
  if (!id || !secret) throw new Error('KIVRA_CLIENT_ID/KIVRA_CLIENT_SECRET saknas i edge-secrets')
  const resp = await fetch(`${bas}/v1/auth`, {
    method: 'POST',
    headers: { Authorization: `Basic ${btoa(`${id}:${secret}`)}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: 'grant_type=client_credentials',
  })
  if (!resp.ok) throw new Error(`Kivra auth misslyckades (${resp.status}): ${(await resp.text()).slice(0, 200)}`)
  return (await resp.json()).access_token
}

// Synka ETT bolag: lista brevlådan, importera nytt (op='import') eller bara beskriv (op='preview').
async function synka(admin: any, mode: string, company_id: string, op: string) {
  const bas = mode === 'prod' ? 'https://sender.api.kivra.com' : 'https://sender.sandbox-api.kivra.com'

  const { data: bolag } = await admin.from('companies').select('org_nr').eq('id', company_id).single()
  const orgnr10 = String(bolag?.org_nr || '').replace(/\D/g, '').slice(-10)
  const vat = orgnr10.length === 10 ? `SE${orgnr10}01` : null

  let ansluten = false
  let inbox: { key: string; sender_name: string; subject: string; created_at: string; status: string }[] = []
  let token = ''
  let companyKey = ''
  if (mode === 'mock') {
    ansluten = true
    inbox = mockInbox()
  } else {
    if (!vat) return { ansluten: false, vat: null, antal: 0, nya_antal: 0, importerade: 0, poster: [] }
    token = await kivraToken(bas)
    const hdr = { Authorization: `Bearer ${token}` }
    const find = await fetch(`${bas}/v1/partner/company?vat_number=${vat}`, { headers: hdr })
    if (!find.ok) throw new Error(`Kivra find company (${find.status}): ${(await find.text()).slice(0, 200)}`)
    const fj = await find.json().catch(() => null)
    companyKey = fj?.key || (Array.isArray(fj) ? fj[0]?.key : '') || ''
    ansluten = !!companyKey
    if (ansluten) {
      const list = await fetch(`${bas}/v1/partner/company/${companyKey}/content`, { headers: hdr })
      if (!list.ok) throw new Error(`Kivra content list (${list.status}): ${(await list.text()).slice(0, 200)}`)
      inbox = await list.json()
    }
  }

  // Dedup: redan importerat innehåll (inbound_message_id = 'kivra:{contentKey}').
  const { data: befintliga } = await admin.from('documents')
    .select('inbound_message_id').eq('company_id', company_id).eq('source', 'kivra')
  const finns = new Set((befintliga || []).map((b: any) => b.inbound_message_id))
  const nya = inbox.filter(c => !finns.has(`kivra:${c.key}`))

  let importerade = 0
  const fel: string[] = []
  if (op === 'import' && nya.length) {
    for (const c of nya) {
      try {
        let bytes: Uint8Array
        let filnamn = `${(c.subject || 'kivra-dokument').replace(/[^\w.\-åäöÅÄÖ ]+/g, '').trim().slice(0, 60) || 'kivra-dokument'}.pdf`
        if (mode === 'mock') {
          bytes = miniPdf(c.subject)
        } else {
          const hdr = { Authorization: `Bearer ${token}` }
          const meta = await fetch(`${bas}/v1/partner/company/${companyKey}/content/${c.key}`, { headers: hdr })
          if (!meta.ok) throw new Error(`metadata ${meta.status}`)
          const mj = await meta.json()
          const del = (mj.parts || []).find((p: any) => (p.content_type || '').includes('pdf') && p.key) || (mj.parts || []).find((p: any) => p.key)
          if (!del) throw new Error('ingen fil i innehållet')
          if (del.name) filnamn = del.name
          const fil = await fetch(`${bas}/v1/partner/company/${companyKey}/content/${c.key}/file/${del.key}/raw`, { headers: hdr })
          if (!fil.ok) throw new Error(`fil ${fil.status}`)
          bytes = new Uint8Array(await fil.arrayBuffer())
        }
        const safe = filnamn.replace(/[^\w.\-]+/g, '_')
        const path = `${company_id}/${crypto.randomUUID()}-${safe}`
        const up = await admin.storage.from(BUCKET).upload(path, bytes, { contentType: 'application/pdf', upsert: false })
        if (up.error) throw new Error('storage: ' + up.error.message)

        // Grov kategori på ämnesraden – AI-tolkningen förfinar när användaren tolkar.
        const amne = (c.subject || '').toLowerCase()
        const kategori = /faktura|invoice/.test(amne) ? 'leverantorsfaktura'
          : /avtal|kontrakt|agreement/.test(amne) ? 'avtal' : 'dokument'
        const { error: insErr } = await admin.from('documents').insert({
          company_id, source: 'kivra',
          email_from: c.sender_name || 'Kivra', email_subject: c.subject || null,
          received_at: c.created_at || new Date().toISOString(),
          inbound_message_id: `kivra:${c.key}`,
          storage_path: path, file_name: filnamn, mime_type: 'application/pdf', file_size: bytes.length,
          kategori, confidence: 0.6, status: 'classified', tolkad: false,
        })
        if (insErr) throw new Error('documents: ' + insErr.message)
        importerade++
        // Markera som läst hos Kivra (endast riktiga lägen; best-effort).
        if (mode !== 'mock') {
          try { await fetch(`${bas}/v1/partner/company/${companyKey}/content/${c.key}/view`, { method: 'POST', headers: { Authorization: `Bearer ${token}` } }) } catch { /* noop */ }
        }
      } catch (e) {
        fel.push(`${c.subject || c.key}: ${String((e as Error)?.message || e)}`)
      }
    }
  }

  return {
    ansluten, vat, antal: inbox.length, nya_antal: nya.length, importerade,
    fel: fel.length ? fel : undefined,
    poster: inbox.slice(0, 50).map(c => ({
      avsandare: c.sender_name, amne: c.subject, mottaget: c.created_at,
      ny: !finns.has(`kivra:${c.key}`),
    })),
  }
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
    // ── CRON-INGÅNG: schemalagd bakgrundssynk för ALLA bolag ──
    const cronSecret = req.headers.get('x-kivra-cron-secret')
    if (cronSecret) {
      const { data: nyckel } = await admin.from('interna_nycklar').select('varde').eq('namn', 'kivra_cron').maybeSingle()
      if (!nyckel?.varde || nyckel.varde !== cronSecret) return json({ error: 'ogiltig cron-nyckel' }, 401)
      // Mockläge synkas ALDRIG automatiskt – exempeldata hör inte hemma i riktiga inkorgar.
      if (mode === 'mock') return json({ ok: true, lage: mode, hoppade_over: 'mockläge – automatisk synk inaktiv tills partneravtal/nycklar finns' })
      const { data: alla } = await admin.from('companies').select('id')
      const resultat: unknown[] = []
      for (const b of alla || []) {
        try { resultat.push({ company_id: b.id, ...(await synka(admin, mode, b.id, 'import')) }) }
        catch (e) { resultat.push({ company_id: b.id, fel: String((e as Error)?.message || e) }) }
      }
      return json({ ok: true, lage: mode, resultat })
    }

    // ── ANVÄNDARINGÅNG: status (preview) för Kivra-flikens statusrad + import för felsökning ──
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'ej inloggad' }, 401)

    const { company_id, op = 'preview' } = await req.json().catch(() => ({}))
    if (!company_id) return json({ error: 'company_id saknas' }, 400)
    const { data: medlem } = await admin.from('user_companies').select('user_id')
      .eq('user_id', user.id).eq('company_id', company_id).maybeSingle()
    if (!medlem) return json({ error: 'ingen behörighet till bolaget' }, 403)

    const resultat = await synka(admin, mode, company_id, op)
    return json({ ok: true, lage: mode, ...resultat })
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 500)
  }
})
