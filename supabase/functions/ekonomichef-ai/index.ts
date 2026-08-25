// Edge Function: ekonomichef-ai
// Tar emot periodens nyckeltal + jämförelse mot föregående period och skriver
// en ekonomichefs-rapport på svenska. Beslutsstöd – inga ändringar görs.
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
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const ANON = Deno.env.get('SUPABASE_ANON_KEY')!
    const userClient = createClient(SUPABASE_URL, ANON, { global: { headers: { Authorization: req.headers.get('Authorization') || '' } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Ej inloggad' }, 401)

    const body = await req.json()
    const prompt = `Du är en erfaren svensk ekonomichef (CFO). Skriv en kort, professionell men lättläst månadsrapport till företagsledningen för ${body.foretag || 'företaget'}, period ${body.periodLabel}.

Underlag (belopp i kronor, JSON):
${JSON.stringify(body).slice(0, 9000)}

Skriv på svenska med dessa rubriker (vanlig text, ingen markdown-stjärnformatering):
Sammanfattning – 2–3 meningar om läget och resultatet.
Resultat & marginal – kommentera resultat och rörelsemarginal samt förändring mot föregående period (procent/kronor).
Intäkter & kostnader – lyft de största posterna och tydliga avvikelser mot föregående period.
Likviditet – kommentera likvida medel samt obetalda kund- och leverantörsfakturor.
Att bevaka – 2–4 konkreta punkter/rekommendationer.

Var konkret och använd siffrorna. Max ca 250 ord. Avsluta med en rad: "Detta är ett AI-genererat beslutsstöd – stäm av med din redovisningskonsult."`

    let r
    try {
      r = await claudeChat({ apiKey: ANTHROPIC_API_KEY, model: CLAUDE_HAIKU, prompt, maxTokens: 2000, temperature: 0.4 })
    } catch (aiErr) {
      const e = aiErr as ClaudeChatError
      console.error(`ekonomichef-ai: Claude-fel: ${String(e?.message || aiErr)}`)
      return json({ error: e?.transient
        ? 'AI-tjänsten är tillfälligt upptagen. Försök igen om en stund.'
        : 'AI-tjänsten kunde inte svara just nu.' }, e?.transient ? 503 : 502)
    }
    const rapport = r.text || ''
    return json({ ok: true, rapport })
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
