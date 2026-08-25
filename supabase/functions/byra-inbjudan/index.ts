// Edge Function: byra-inbjudan
// Byrå-admin bjuder in klientens EGEN användare till klientbolaget med valda
// funktionsmoduler (Byråstöd C2). Inbjudan skickas med Supabase Auth-mallen
// "Invite user" (svensk, via Resend-SMTP:n); användaren förgodkänns
// (app_metadata.approved) så beta-grinden inte stoppar klientanvändare.
// Modulerna lagras på kopplingen (user_companies.moduler; null = alla).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } })

const TILLATNA_MODULER = ['bokforing', 'fakturering', 'lon', 'moms', 'rapporter']

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

    const { byra_klient_id, epost, moduler } = await req.json()
    const epostRen = String(epost || '').trim().toLowerCase()
    if (!byra_klient_id) return json({ error: 'byra_klient_id saknas' }, 400)
    if (!epostRen.includes('@')) return json({ error: 'Giltig e-postadress krävs' }, 400)
    // moduler: null = alla funktioner; annars validerad dellista.
    let modulLista: string[] | null = null
    if (Array.isArray(moduler)) {
      modulLista = moduler.filter((m: unknown) => TILLATNA_MODULER.includes(String(m)))
      if (modulLista.length === 0) return json({ error: 'Välj minst en funktion (eller alla)' }, 400)
    }

    const db = createClient(SUPABASE_URL, SERVICE)

    // Klientkopplingen + att anroparen är ADMIN i just den byrån.
    const { data: bk } = await db.from('byra_klient')
      .select('id, byra_bolag_id, klient_bolag_id, status').eq('id', byra_klient_id).maybeSingle()
    if (!bk) return json({ error: 'Klientkopplingen hittades inte' }, 404)
    // Uppdrag avslutas genom att status ändras – kopplingen raderas aldrig. Utan
    // den här kontrollen kunde en byrå vars uppdrag avslutats fortfarande bjuda
    // in sig själv och därmed ge sig permanent åtkomst till f.d. klientens bolag.
    if (bk.status !== 'aktiv') {
      return json({ error: 'Klientuppdraget är inte aktivt. Aktivera uppdraget innan du bjuder in användare.' }, 403)
    }
    const { data: bolag } = await db.from('companies').select('id, name').in('id', [bk.byra_bolag_id, bk.klient_bolag_id])
    const klientNamn = (bolag || []).find(b => b.id === bk.klient_bolag_id)?.name || 'ert bolag'
    const byraNamn = (bolag || []).find(b => b.id === bk.byra_bolag_id)?.name || 'er redovisningsbyrå'
    const { data: medlemskap } = await db.from('byra_medlemskap')
      .select('roll, aktiv').eq('byra_bolag_id', bk.byra_bolag_id).eq('anvandare_id', user.id).maybeSingle()
    if (!medlemskap?.aktiv || medlemskap.roll !== 'admin') {
      return json({ error: 'Endast byråns administratör får bjuda in klientanvändare' }, 403)
    }

    // Bjud in (skapar användaren + skickar svenska Invite-mallen). Finns adressen
    // redan kopplas den befintliga användaren i stället.
    let userId: string | null = null
    let epost_status = 'inbjudan_skickad'
    const { data: invited, error: invFel } = await db.auth.admin.inviteUserByEmail(epostRen, {
      redirectTo: 'https://app.bokpilot.se/?valjlosenord=1',
    })
    if (!invFel && invited?.user) {
      userId = invited.user.id
    } else {
      const befintlig = await hittaAnvandare(db, epostRen)
      if (befintlig) { userId = befintlig.id; epost_status = 'anvandare_fanns_kopplad' }
    }
    if (!userId) return json({ error: 'Kunde inte bjuda in: ' + (invFel?.message || 'okänt fel') }, 400)

    // Kopplingen med modulvalet FÖRST (upsert: ny inbjudan uppdaterar modulerna) —
    // förgodkännandet sätts efter lyckad koppling, annars lämnas ett föräldralöst
    // förgodkänt konto som passerar beta-grinden. Misslyckas kopplingen för en
    // nyskapad användare städas kontot bort (länken i mejlet blir då ogiltig).
    const { error: kopplFel } = await db.from('user_companies').upsert(
      { user_id: userId, company_id: bk.klient_bolag_id, role: 'member', email: epostRen, moduler: modulLista },
      { onConflict: 'user_id,company_id' },
    )
    if (kopplFel) {
      if (epost_status === 'inbjudan_skickad') await db.auth.admin.deleteUser(userId).catch(() => {})
      return json({ error: 'Kunde inte koppla användaren: ' + kopplFel.message }, 400)
    }
    await db.auth.admin.updateUserById(userId, { app_metadata: { approved: true } })

    // Befintlig användare får inget Supabase-invitemejl — skicka info via Resend
    // (Elias 2026-07-14: man ska alltid få veta att man blivit inbjuden). Best-effort.
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
            subject: `Du har fått åtkomst till ${klientNamn} i BokPilot`,
            text: [
              'Hej!',
              '',
              `${byraNamn} har gett dig åtkomst till ${klientNamn} i BokPilot.`,
              '',
              'Logga in på https://app.bokpilot.se med ditt befintliga konto så hittar du',
              'bolaget i bolagsväljaren.',
              '',
              'Hälsningar,',
              'BokPilot',
            ].join('\n'),
          }),
        }).catch(() => null)
        if (resp && !resp.ok) console.error(`byra-inbjudan: Resend HTTP ${resp.status}`)
        else if (resp?.ok) epost_status = 'anvandare_fanns_kopplad_mejl_skickat'
      }
    }

    return json({ ok: true, epost_status, moduler: modulLista })
  } catch (err) {
    console.error(`byra-inbjudan: ${String((err as Error)?.message || err)}`)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
