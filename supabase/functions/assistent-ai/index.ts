// Edge Function: assistent-ai
// Svarar på frågor om företagets bokföring utifrån en sammanställning (context)
// som byggs i klienten. Read-only – inga ändringar görs.
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

    const { question, context, history } = await req.json()
    if (!question) throw new Error('Ingen fråga')

    const hist = Array.isArray(history) ? history.slice(-6).map((m: { role: string; text: string }) => `${m.role === 'user' ? 'Användare' : 'Assistent'}: ${m.text}`).join('\n') : ''

    const prompt = `Du är en svensk bokföringsassistent i appen BokPilot. Svara på användarens fråga ENDAST utifrån JSON-datan nedan (företagets egna bokföringsdata för aktuell period).

Regler:
- Svara kortfattat, konkret och vänligt på svenska. Ange belopp i kronor (t.ex. 12 500 kr).
- Använd bara siffror som finns i datan. Räkna gärna (summor, differenser) men hitta inte på.
- Om uppgiften saknas i datan: säg det kort och föreslå var i appen man hittar den.
- Du är READ-ONLY och kan inte bokföra eller ändra något – påminn om det bara om användaren ber dig göra en ändring.
- Ge inte bindande skatte-/juridisk rådgivning; hänvisa vid behov till redovisningskonsult.
- Punktlista eller korta stycken. Max ca 150 ord.

DATA (JSON):
${JSON.stringify(context).slice(0, 12000)}

${hist ? 'Tidigare konversation:\n' + hist + '\n' : ''}Fråga: ${question}`

    let r
    try {
      r = await claudeChat({ apiKey: ANTHROPIC_API_KEY, model: CLAUDE_HAIKU, prompt, maxTokens: 1500, temperature: 0.2 })
    } catch (aiErr) {
      const e = aiErr as ClaudeChatError
      console.error(`assistent-ai: Claude-fel: ${String(e?.message || aiErr)}`)
      return json({ error: e?.transient
        ? 'AI-tjänsten är tillfälligt upptagen. Försök igen om en stund.'
        : 'AI-tjänsten kunde inte svara just nu.' }, e?.transient ? 503 : 502)
    }
    const svar = r.text || 'Jag kunde inte svara just nu.'
    return json({ ok: true, svar })
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
