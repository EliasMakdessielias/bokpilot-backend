// Edge Function: byra-medarbetare
// Byrå-admin bjuder in en MEDARBETARE till byrån (Byråinställningar → Medarbetare).
// Ny användare får Supabase-invitemallen (svensk, via Resend-SMTP:n) och väljer
// lösenord på byra.bokpilot.se (?valjlosenord=1 → Välj lösenord-helsidan); befintlig
// användare kopplas direkt och informeras via Resend. Medlemskapet lagras i
// byra_medlemskap (roll admin/konsult); användaren förgodkänns (app_metadata.approved).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } })

// Slår upp en befintlig användare på e-post. listUsers är paginerad — en enda
// sida på 1000 missar tyst användare i större bestånd, därav loopen.
// deno-lint-ignore no-explicit-any
async function hittaAnvandare(db: any, epost: string): Promise<{ id: string } | null> {
  for (let page = 1; page <= 50; page++) {
    const { data, error } = await db.auth.admin.listUsers({ page, perPage: 1000 })
    if (error) return null
    const traff = (data?.users || []).find((u: { email?: string }) => (u.email || '').toLowerCase() === epost)
    if (traff) return traff
    if ((data?.users || []).length < 1000) return null
  }
  return null
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const ANON = Deno.env.get('SUPABASE_ANON_KEY')!

    const userClient = createClient(SUPABASE_URL, ANON, { global: { headers: { Authorization: req.headers.get('Authorization') || '' } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Ej inloggad' }, 401)

    const { byra_bolag_id, epost, namn, roll } = await req.json()
    const epostRen = String(epost || '').trim().toLowerCase()
    const namnRen = String(namn || '').trim() || null
    const rollRen = roll === 'admin' ? 'admin' : 'konsult'
    if (!byra_bolag_id) return json({ error: 'byra_bolag_id saknas' }, 400)
    if (!epostRen.includes('@')) return json({ error: 'Giltig e-postadress krävs' }, 400)

    const db = createClient(SUPABASE_URL, SERVICE)

    // Endast byråns ADMIN får bjuda in medarbetare.
    const { data: medlemskap } = await db.from('byra_medlemskap')
      .select('roll, aktiv').eq('byra_bolag_id', byra_bolag_id).eq('anvandare_id', user.id).maybeSingle()
    if (!medlemskap?.aktiv || medlemskap.roll !== 'admin') {
      return json({ error: 'Endast byråns administratör får bjuda in medarbetare' }, 403)
    }
    const { data: byraBolag } = await db.from('companies').select('name').eq('id', byra_bolag_id).maybeSingle()
    const byraNamn = byraBolag?.name || 'er redovisningsbyrå'

    // Bjud in (skapar användaren + skickar svenska Invite-mallen). Finns adressen
    // redan kopplas den befintliga användaren i stället.
    let userId: string | null = null
    let epost_status = 'inbjudan_skickad'
    const { data: invited, error: invFel } = await db.auth.admin.inviteUserByEmail(epostRen, {
      redirectTo: 'https://byra.bokpilot.se/?valjlosenord=1',
    })
    if (!invFel && invited?.user) {
      userId = invited.user.id
    } else {
      const befintlig = await hittaAnvandare(db, epostRen)
      if (befintlig) { userId = befintlig.id; epost_status = 'anvandare_fanns_kopplad' }
    }
    if (!userId) return json({ error: 'Kunde inte bjuda in: ' + (invFel?.message || 'okänt fel') }, 400)

    // Medlemskapet FÖRST (upsert: ny inbjudan uppdaterar roll/namn och återaktiverar) —
    // förgodkännandet sätts efter lyckad koppling, annars lämnas ett föräldralöst
    // förgodkänt konto som passerar beta-grinden. Misslyckas kopplingen för en
    // nyskapad användare städas kontot bort (länken i mejlet blir då ogiltig).
    const { error: kopplFel } = await db.from('byra_medlemskap').upsert(
      { byra_bolag_id, anvandare_id: userId, roll: rollRen, namn: namnRen, epost: epostRen, aktiv: true, tillagd_av: user.id },
      { onConflict: 'byra_bolag_id,anvandare_id' },
    )
    if (kopplFel) {
      if (epost_status === 'inbjudan_skickad') await db.auth.admin.deleteUser(userId).catch(() => {})
      return json({ error: 'Kunde inte koppla medarbetaren: ' + kopplFel.message }, 400)
    }
    await db.auth.admin.updateUserById(userId, { app_metadata: { approved: true } })

    // Befintlig användare får inget Supabase-invitemejl — informera via Resend
    // (samma princip som byra-inbjudan: man ska alltid få veta). Best-effort.
    if (epost_status === 'anvandare_fanns_kopplad') {
      const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
      if (RESEND_API_KEY) {
        const resp = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${RESEND_API_KEY}` },
          body: JSON.stringify({
            from: Deno.env.get('NOTIS_FRAN') || 'BokPilot <notiser@bokpilot.se>',
            reply_to: 'admin@bokpilot.se',
            to: [epostRen],
            subject: `Du har lagts till som medarbetare hos ${byraNamn} i BokPilot Byrå`,
            text: [
              'Hej!',
              '',
              `${byraNamn} har lagt till dig som ${rollRen === 'admin' ? 'administratör' : 'konsult'} i BokPilot Byrå.`,
              '',
              'Logga in på https://byra.bokpilot.se med ditt befintliga konto så ser du',
              'byråns klienter och uppdrag.',
              '',
              'Hälsningar,',
              'BokPilot',
            ].join('\n'),
          }),
        }).catch(() => null)
        if (resp && !resp.ok) console.error(`byra-medarbetare: Resend HTTP ${resp.status}`)
        else if (resp?.ok) epost_status = 'anvandare_fanns_kopplad_mejl_skickat'
      }
    }

    return json({ ok: true, epost_status, roll: rollRen })
  } catch (err) {
    console.error(`byra-medarbetare: ${String((err as Error)?.message || err)}`)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
