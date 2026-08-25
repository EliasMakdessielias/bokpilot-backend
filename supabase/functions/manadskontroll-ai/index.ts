// Edge Function: manadskontroll-ai
// AI-stöd för Månadskontroll. Förklarar varför en kontrollpunkt uppstod, föreslår hur den löses,
// föreslår arbetsordning, sammanfattar månadens risker och skapar checklista för månadsavslut.
// Strikta gränser: stänger ALDRIG punkter, bokför ALDRIG, ignorerar ALDRIG differenser, ger INGEN
// definitiv juridisk/skatterådgivning, och flaggar alltid när mänsklig granskning krävs.
// AI-modell: Claude Haiku 4.5 sedan 2026-07-22 (Gemini-avvecklingen, _shared/claudeChat.ts).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { claudeChat, CLAUDE_HAIKU, ClaudeChatError } from '../_shared/claudeChat.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } })

const SYSTEM = `Du är BokPilots assistent för Månadskontroll (svenskt bokföringssystem). Du hjälper användaren
att förstå och åtgärda kontrollpunkter inför månadsavslut. Svara kort, konkret och på svenska.

REGLER (följ alltid):
- Förklara VARFÖR en kontrollpunkt uppstod och HUR den åtgärdas, steg för steg.
- Hänvisa till var i appen åtgärden görs (Inkorg, Bokföring, Leverantörsfakturor, Kundfakturor,
  Kassa & bank, Moms, Lön).
- Du får ALDRIG stänga eller markera kontrollpunkter som lösta automatiskt – användaren gör det själv.
- Du får ALDRIG bokföra eller föreslå att något bokförs utan att användaren granskar och bekräftar.
- Ignorera ALDRIG differenser (t.ex. obalans eller momsavvikelse) – de måste utredas.
- Ge INTE definitiv juridisk eller skatterådgivning. Håll dig på generell nivå och hänvisa till
  redovisningskonsult vid behov.
- Flagga TYDLIGT när något kräver mänsklig granskning (särskilt kritiska punkter, obalans, moms,
  ej avstämd bank, ej bokförd lön, förfallna fakturor).
- Hitta aldrig på regler eller funktioner. Är du osäker: säg det och föreslå manuell kontroll.`

const SCHEMA = {
  type: 'object',
  properties: { svar: { type: 'string', description: 'Kort, konkret svar på svenska enligt reglerna.' } },
  required: ['svar'],
}

function buildPrompt(mode: string, item: any, items: any[]): string {
  const one = (it: any) => `- [${it?.priority}] ${it?.module}: ${it?.title}${it?.description ? ' – ' + it.description : ''}`
  if (mode === 'summary') {
    return `Sammanfatta månadens risker utifrån följande öppna kontrollpunkter. Lyft de viktigaste först,
gruppera per allvarlighetsgrad och nämn vad som kräver mänsklig granskning.\n\nPunkter:\n${(items || []).map(one).join('\n') || '(inga öppna punkter)'}`
  }
  if (mode === 'checklist') {
    return `Skapa en kort, prioriterad checklista för månadsavslut utifrån följande öppna kontrollpunkter.
Ange i vilken ordning användaren bör arbeta (kritiskt först) och vad som måste granskas manuellt.\n\nPunkter:\n${(items || []).map(one).join('\n') || '(inga öppna punkter)'}`
  }
  if (mode === 'order') {
    return `Föreslå i vilken ordning användaren bör åtgärda följande öppna kontrollpunkter och varför.\n\nPunkter:\n${(items || []).map(one).join('\n') || '(inga öppna punkter)'}`
  }
  // explain (default)
  return `Förklara varför följande kontrollpunkt uppstod och hur den åtgärdas steg för steg.
Avsluta med om den kräver mänsklig granskning.\n\nKontrollpunkt:
Modul: ${item?.module}
Prioritet: ${item?.priority}
Titel: ${item?.title}
Beskrivning: ${item?.description || '—'}
Föreslagen åtgärd: ${item?.suggested_action || '—'}
Regel: ${item?.rule_key || '—'}
Data: ${JSON.stringify(item?.source_data || {}).slice(0, 800)}`
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

    const { mode = 'explain', item, items, user_context } = await req.json()
    const ctx = user_context ? `ANVÄNDARE: ${[user_context.company, user_context.role].filter(Boolean).join(' · ')}` : ''
    const prompt = `${ctx}\n\n${buildPrompt(mode, item, items)}`

    let r
    try {
      r = await claudeChat({ apiKey: ANTHROPIC_API_KEY, model: CLAUDE_HAIKU, system: SYSTEM, prompt, jsonSchema: SCHEMA, maxTokens: 1500, temperature: 0.2 })
    } catch (aiErr) {
      const e = aiErr as ClaudeChatError
      console.error(`manadskontroll-ai: Claude-fel: ${String(e?.message || aiErr)}`)
      return json({ error: e?.transient ? 'AI är tillfälligt upptagen. Försök igen om en stund.' : 'AI kunde inte svara just nu.' }, e?.transient ? 503 : 502)
    }
    let parsed: any = {}
    try { parsed = JSON.parse(r.text) } catch { parsed = { svar: r.text || '' } }
    return json({ ok: true, svar: parsed.svar || 'Inget svar.' })
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
