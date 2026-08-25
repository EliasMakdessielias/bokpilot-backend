// Edge Function: granska-ai
// Tar emot resultatet av bokföringsgranskningen (endast antal/belopp – inga
// person- eller kunduppgifter) och returnerar en prioriterad åtgärdsanalys på
// svenska enligt bokföringslagen och god redovisningssed.
// AI-modell: Claude Haiku 4.5 sedan 2026-07-22 (Gemini-avvecklingen, _shared/claudeChat.ts).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { claudeChat, CLAUDE_HAIKU, ClaudeChatError } from '../_shared/claudeChat.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')
    if (!ANTHROPIC_API_KEY) throw new Error('ANTHROPIC_API_KEY saknas')

    // Verifiera inloggning
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const ANON = Deno.env.get('SUPABASE_ANON_KEY')!
    const userClient = createClient(SUPABASE_URL, ANON, { global: { headers: { Authorization: req.headers.get('Authorization') || '' } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Ej inloggad' }, 401)

    const body = await req.json()
    const fynd = Array.isArray(body?.fynd) ? body.fynd : []

    const prompt = `Du är en svensk auktoriserad redovisningskonsult. Nedan är resultatet av en automatisk granskning av ett företags bokföring för perioden ${body?.period?.from} – ${body?.period?.tom} (${body?.antalVerifikationer || 0} verifikationer).

Fynd (allvarsgrad, titel, antal, beskrivning):
${fynd.map((f: Record<string, unknown>) => `- [${f.allvar}] ${f.titel} (${f.antal} st): ${f.detalj}`).join('\n') || '- Inga avvikelser hittades.'}

Skriv en kort, konkret åtgärdsplan på svenska:
1. Sammanfatta läget i 1–2 meningar.
2. Lista åtgärderna i prioritetsordning (allvarligast först), med hänvisning till bokföringslagen (BFL) eller god redovisningssed där det är relevant.
3. Var konkret och praktisk. Max ca 200 ord. Påminn kort om att en människa måste granska och godkänna – inget bokförs automatiskt.
Använd ren text (inga markdown-rubriker), gärna numrerad lista.`

    let r
    try {
      r = await claudeChat({ apiKey: ANTHROPIC_API_KEY, model: CLAUDE_HAIKU, prompt, maxTokens: 1500, temperature: 0.3 })
    } catch (aiErr) {
      const e = aiErr as ClaudeChatError
      console.error(`granska-ai: Claude-fel: ${String(e?.message || aiErr)}`)
      return json({ error: e?.transient
        ? 'AI-tjänsten är tillfälligt upptagen. Försök igen om en stund.'
        : 'AI-tjänsten kunde inte svara just nu.' }, e?.transient ? 503 : 502)
    }
    const analys = r.text || ''
    return json({ ok: true, analys })
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
