// Edge Function: bokslut-ai (Steg 2B)
// AI-granskningsstöd för AI Bokslut & Årsredovisning. Läser strukturerad kontext (checks/bilagor) via RPC,
// frågar Claude med STRIKT JSON-schema, validerar och sparar via RPC. Skriver ALDRIG bokföringsdata, skapar
// INGA verifikationer, INGA draft-justeringar och INGET K2-utkast. Förslagen kräver mänsklig granskning.
// AI-modell: Claude Haiku 4.5 sedan 2026-07-22 (Gemini-avvecklingen, _shared/claudeChat.ts).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { claudeChat, CLAUDE_HAIKU, ClaudeChatError } from '../_shared/claudeChat.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } })

const SYSTEM = `Du är ett granskningsstöd för bokslut i BokPilot (svenskt bokföringssystem, K2 för mindre aktiebolag).
Du analyserar färdiga kontrollpunkter (checks) och bokslutsbilagor och ger STRUKTURERADE granskningsförslag som
hjälper en redovisningskonsult att förstå risker, prioritera och veta vad som bör kontrolleras härnäst.

REGLER (följ alltid):
- Förklara VARFÖR en risk finns och föreslå NÄSTA MANUELLA kontroll.
- Hänvisa till relevanta checks/bilagor via deras id (related_check_id / related_attachment_id) när det går.
- Markera osäkerhet tydligt (lägre confidence) och säg när något INTE kan avgöras utifrån given data.
- Använd svensk redovisningsterminologi. Svara kort och konkret.
- Hitta ALDRIG på konton, belopp eller regler. Använd bara siffror som finns i kontexten.
- Du får ALDRIG bokföra, skapa verifikationer, ändra låsta perioder, godkänna bokslut, lämna in årsredovisning,
  ge definitiv juridisk/skatterådgivning eller skriva K2-årsredovisningstext.
- Allt du föreslår är granskningsstöd som en behörig användare måste bedöma.

Returnera JSON enligt schemat: en lista 'suggestions'. suggestion_type ska vara en av:
risk_explanation, next_action, missing_documentation, attachment_review, balance_issue, vat_issue, tax_issue,
equity_issue, payroll_issue, manual_review_required. risk_level: low/medium/high/critical. confidence: 0..1.`

const SCHEMA = {
  type: 'object',
  properties: {
    suggestions: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          suggestion_type: { type: 'string' },
          title: { type: 'string' },
          summary: { type: 'string' },
          reasoning: { type: 'string' },
          risk_level: { type: 'string' },
          confidence: { type: 'number' },
          related_check_id: { type: 'string' },
          related_attachment_id: { type: 'string' },
          suggested_next_action: { type: 'string' },
        },
        required: ['suggestion_type', 'title', 'risk_level'],
      },
    },
  },
  required: ['suggestions'],
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')
    if (!ANTHROPIC_API_KEY) throw new Error('ANTHROPIC_API_KEY saknas')
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const ANON = Deno.env.get('SUPABASE_ANON_KEY')!
    const userClient = createClient(SUPABASE_URL, ANON, { global: { headers: { Authorization: req.headers.get('Authorization') || '' } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Ej inloggad' }, 401)

    const { engagement_id } = await req.json()
    if (!engagement_id) return json({ error: 'engagement_id krävs' }, 400)

    // Kontext + auktorisering (admin) sker i RPC. Fel (behörighet/lås) propageras som tydligt meddelande.
    const { data: ctx, error: ctxErr } = await userClient.rpc('bokslut_ai_context', { p_engagement: engagement_id })
    if (ctxErr) return json({ error: ctxErr.message?.replace(/^.*?:\s*/, '') || 'Kunde inte läsa kontext', code: ctxErr.code }, ctxErr.code === '42501' ? 403 : 400)

    const prompt = `KONTEXT (JSON):\n${JSON.stringify(ctx).slice(0, 16000)}\n\nGe 3–8 prioriterade granskningsförslag.`

    let r
    try {
      r = await claudeChat({ apiKey: ANTHROPIC_API_KEY, model: CLAUDE_HAIKU, system: SYSTEM, prompt, jsonSchema: SCHEMA, maxTokens: 3000, temperature: 0.2 })
    } catch (aiErr) {
      const e = aiErr as ClaudeChatError
      console.error(`bokslut-ai: Claude-fel: ${String(e?.message || aiErr)}`)
      return json({ error: e?.transient ? 'AI är tillfälligt upptagen (kvot/hög last). Försök igen om en stund.' : 'AI kunde inte generera förslag just nu.' }, e?.transient ? 503 : 502)
    }

    let parsed: any = {}
    try { parsed = JSON.parse(r.text) } catch { return json({ error: 'AI gav ogiltigt svar (kunde inte tolkas). Inget sparades.' }, 502) }
    const items = Array.isArray(parsed?.suggestions) ? parsed.suggestions : []
    if (items.length === 0) return json({ ok: true, created: 0, note: 'Inga förslag genererades.' })

    // Spara via RPC (validerar strikt server-side, auktoriserar admin, loggar audit). Ogiltiga poster skippas.
    const { data: created, error: saveErr } = await userClient.rpc('bokslut_save_ai_suggestions', { p_engagement: engagement_id, p_items: items, p_model: CLAUDE_HAIKU })
    if (saveErr) return json({ error: saveErr.message?.replace(/^.*?:\s*/, '') || 'Kunde inte spara förslag', code: saveErr.code }, saveErr.code === '42501' ? 403 : 400)
    return json({ ok: true, created: created ?? 0 })
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
