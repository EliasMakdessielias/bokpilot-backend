// Edge Function: losenord-notis
// Säkerhetsbekräftelse när användarens lösenord har ändrats: mejl till användarens
// egen adress via Resend. Anropas av klienten direkt efter lyckat byte (medan
// sessionen ännu är giltig). Best-effort — bytet gäller oavsett om mejlet går fram.
// Kan aldrig mejla någon annan än den inloggade användaren själv.
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

    const userClient = createClient(SUPABASE_URL, ANON, { global: { headers: { Authorization: req.headers.get('Authorization') || '' } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user?.email) return json({ error: 'Ej inloggad' }, 401)

    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
    if (!RESEND_API_KEY) return json({ ok: true, skickat: false, orsak: 'RESEND_API_KEY saknas' })

    const nar = new Date().toLocaleString('sv-SE', { timeZone: 'Europe/Stockholm', dateStyle: 'long', timeStyle: 'short' })
    const resp = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${RESEND_API_KEY}` },
      body: JSON.stringify({
        from: Deno.env.get('NOTIS_FRAN') || 'BokPilot <notiser@bokpilot.se>',
        reply_to: 'admin@bokpilot.se',
        to: [user.email],
        subject: 'Ditt lösenord har ändrats – BokPilot',
        text: [
          'Hej!',
          '',
          `Lösenordet för ditt BokPilot-konto (${user.email}) ändrades ${nar}.`,
          '',
          'Var det du? Då behöver du inte göra något.',
          '',
          'Var det INTE du? Återställ ditt lösenord omedelbart via "Glömt lösenordet?"',
          'på https://app.bokpilot.se och svara på det här mejlet så hjälper vi dig.',
          '',
          'Hälsningar,',
          'BokPilot',
        ].join('\n'),
      }),
    })
    if (!resp.ok) {
      console.error(`losenord-notis: Resend HTTP ${resp.status}: ${(await resp.text().catch(() => '')).slice(0, 200)}`)
      return json({ ok: true, skickat: false, orsak: `Resend ${resp.status}` })
    }
    return json({ ok: true, skickat: true })
  } catch (err) {
    console.error(`losenord-notis: ${String((err as Error)?.message || err)}`)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
