// Edge Function: ansokan-notis
// Mejlnotis till operatören (Elias) när en ny beta-ansökan skapats. Best-effort:
// ansökan i beta_ansokningar är sanningskällan och konsolen visar den oavsett om
// mejlet går fram. Skickar via Resend (RESEND_API_KEY). Utan nyckel: hoppar över
// tyst. bokpilot.se är domänverifierad hos Resend (eu-west-1, 2026-07-14) —
// default-avsändaren är notiser@bokpilot.se; NOTIS_FRAN kan överstyras vid behov.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const ANON = Deno.env.get('SUPABASE_ANON_KEY')!
    const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    // Anroparen måste vara inloggad och äga ansökan — funktionen kan inte användas
    // för att skicka godtyckliga mejl eller läsa andras ansökningar.
    const userClient = createClient(SUPABASE_URL, ANON, { global: { headers: { Authorization: req.headers.get('Authorization') || '' } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Ej inloggad' }, 401)

    const { ansokan_id } = await req.json()
    if (!ansokan_id) return json({ error: 'ansokan_id saknas' }, 400)

    const db = createClient(SUPABASE_URL, SERVICE)
    const { data: ans } = await db.from('beta_ansokningar')
      .select('id, user_id, epost, bolagsnamn, org_nr, meddelande, status, created_at')
      .eq('id', ansokan_id).maybeSingle()
    if (!ans || ans.user_id !== user.id) return json({ error: 'Ansökan hittades inte' }, 404)

    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
    if (!RESEND_API_KEY) return json({ ok: true, skickat: false, orsak: 'RESEND_API_KEY saknas' })
    const till = Deno.env.get('NOTIS_EPOST') || 'admin@bokpilot.se'
    const fran = Deno.env.get('NOTIS_FRAN') || 'BokPilot <notiser@bokpilot.se>'

    const rader = [
      `Bolag: ${ans.bolagsnamn}`,
      `Org.nr: ${ans.org_nr || '—'}`,
      `E-post: ${ans.epost}`,
      `Meddelande: ${ans.meddelande || '—'}`,
      '',
      'Granska och godkänn i operatörskonsolen (Ansökningar).',
    ].join('\n')

    const resp = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${RESEND_API_KEY}` },
      body: JSON.stringify({ from: fran, to: [till], subject: `Ny beta-ansökan: ${ans.bolagsnamn}`, text: rader }),
    })
    if (!resp.ok) {
      const fel = (await resp.text().catch(() => '')).slice(0, 300)
      console.error(`ansokan-notis: Resend HTTP ${resp.status}: ${fel}`)
      return json({ ok: true, skickat: false, orsak: `Resend ${resp.status}` })
    }
    return json({ ok: true, skickat: true })
  } catch (err) {
    console.error(`ansokan-notis: ${String((err as Error)?.message || err)}`)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
