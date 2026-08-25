// Edge Function: annual-report-ai (Steg 2C-3)
// Kontrollerat AI-stöd som formulerar TEXTUTKAST för förvaltningsberättelse och noter i K2-årsredovisningsutkastet.
// Läser begränsad kontext via RPC, frågar Claude med STRIKT JSON-schema, validerar tillåtna sektioner och sparar
// via RPC (server-side validering). AI ändrar ALDRIG siffror, RR/BR eller status, godkänner ALDRIG sektioner och
// hittar ALDRIG på noter, ställda säkerheter eller eventualförpliktelser. Alla texter markeras ai_generated + requires_review.
// AI-modell: Claude Haiku 4.5 sedan 2026-07-22 (Gemini-avvecklingen, _shared/claudeChat.ts).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { claudeChat, CLAUDE_HAIKU, ClaudeChatError } from '../_shared/claudeChat.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } })

const PROMPT_VERSION = 'ar-text-1'
const ALLOWED = ['forvaltningsberattelse', 'noter']

const SYSTEM = `Du skriver TEXTUTKAST till en svensk K2-årsredovisning (mindre aktiebolag) i BokPilot.
Du får ENDAST formulera text för: förvaltningsberättelse (forvaltningsberattelse) och noter (noter).

REGLER (följ alltid):
- Skriv på professionell, saklig svenska anpassad för årsredovisning. Håll texten kort och korrekt.
- Använd ENDAST kända uppgifter från den givna kontexten. Hitta ALDRIG på något.
- Skapa ALDRIG nya siffror och ändra ALDRIG resultaträkning eller balansräkning.
- Hitta ALDRIG på jämförelsetal, noter, ställda säkerheter eller eventualförpliktelser. Om källa saknas: skriv exakt "Uppgift saknas. Kräver manuell granskning."
- Dra inga juridiska slutsatser utan underlag. Skriv ALDRIG att årsredovisningen är godkänd eller att styrelse/revisor undertecknat.
- Markera osäkerhet tydligt. Texten är ett UTKAST som en behörig redovisningskonsult måste granska och godkänna.
- I source_summary: ange kort vilka delar av kontexten texten bygger på.

Returnera JSON enligt schemat: en lista 'sections'. section_key ska vara 'forvaltningsberattelse' eller 'noter'.`

const SCHEMA = {
  type: 'object',
  properties: {
    sections: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          section_key: { type: 'string' },
          content: { type: 'string' },
          source_summary: { type: 'string' },
        },
        required: ['section_key', 'content'],
      },
    },
  },
  required: ['sections'],
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

    const { draft_id } = await req.json()
    if (!draft_id) return json({ error: 'draft_id krävs' }, 400)

    // Kontext + auktorisering (admin) sker i RPC. Fel (behörighet/lås) propageras som tydligt meddelande.
    const { data: ctx, error: ctxErr } = await userClient.rpc('annual_report_ai_context', { p_draft: draft_id })
    if (ctxErr) return json({ error: ctxErr.message?.replace(/^.*?:\s*/, '') || 'Kunde inte läsa kontext', code: ctxErr.code }, ctxErr.code === '42501' ? 403 : 400)

    const prompt = `KONTEXT (JSON):\n${JSON.stringify(ctx).slice(0, 16000)}\n\nSkriv textutkast för förvaltningsberättelse och noter.`

    let r
    try {
      r = await claudeChat({ apiKey: ANTHROPIC_API_KEY, model: CLAUDE_HAIKU, system: SYSTEM, prompt, jsonSchema: SCHEMA, maxTokens: 4000, temperature: 0.2 })
    } catch (aiErr) {
      const e = aiErr as ClaudeChatError
      console.error(`annual-report-ai: Claude-fel: ${String(e?.message || aiErr)}`)
      return json({ error: e?.transient ? 'AI är tillfälligt upptagen (kvot/hög last). Försök igen om en stund.' : 'AI kunde inte generera text just nu.' }, e?.transient ? 503 : 502)
    }

    let parsed: any = {}
    try { parsed = JSON.parse(r.text) } catch { return json({ error: 'AI gav ogiltigt svar (kunde inte tolkas). Inget sparades.' }, 502) }
    const raw = Array.isArray(parsed?.sections) ? parsed.sections : []
    // Validera: endast tillåtna sektioner, content krävs. Bygg payload med källsammanfattning.
    const sections = raw
      .filter((s: any) => ALLOWED.includes(s?.section_key) && typeof s?.content === 'string' && s.content.trim() !== '')
      .map((s: any) => ({
        section_key: s.section_key,
        content: s.content,
        source_summary: { kalla: 'claude', summary: String(s.source_summary || '').slice(0, 1000) },
      }))
    if (sections.length === 0) return json({ ok: true, updated: 0, note: 'Inga tillåtna textutkast genererades.' })

    // Spara via RPC (validerar strikt server-side, auktoriserar admin, sätter ai_generated/requires_review, loggar audit).
    const { data: updated, error: saveErr } = await userClient.rpc('annual_report_save_ai_texts', {
      p_draft: draft_id, p_payload: { model: CLAUDE_HAIKU, prompt_version: PROMPT_VERSION, sections },
    })
    if (saveErr) return json({ error: saveErr.message?.replace(/^.*?:\s*/, '') || 'Kunde inte spara text', code: saveErr.code }, saveErr.code === '42501' ? 403 : 400)
    return json({ ok: true, updated: updated ?? 0 })
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
