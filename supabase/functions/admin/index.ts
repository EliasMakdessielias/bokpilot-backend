// Edge Function: admin — plattformsadmin-hantering (lista konton, aktivera, stäng av, radera).
// Endast plattformsadmins (e-post i platform_admins) får anropa.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

    // Verifiera anropare
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Ej inloggad' }, 401)

    const admin = createClient(SUPABASE_URL, SERVICE_KEY)
    // [SÄKERHET] eq mot gemener — inte ilike. Med ilike tolkas adressen som ett
    // LIKE-mönster, så en registrerad adress som innehåller % eller _ kunde
    // matcha en annan admins rad.
    const { data: pa } = await admin.from('platform_admins').select('email').eq('email', (user.email || '').toLowerCase())
    if (!pa || !pa.length) return json({ error: 'Ingen åtkomst' }, 403)

    const { action, company_id, suspended, user_id } = await req.json()

    if (action === 'list') {
      const { data: list } = await admin.auth.admin.listUsers({ perPage: 1000 })
      const users = (list?.users || []).map(u => ({
        id: u.id, email: u.email, created_at: u.created_at,
        last_sign_in_at: u.last_sign_in_at, confirmed: !!u.email_confirmed_at,
        approved: !!(u.app_metadata && u.app_metadata.approved),
      }))
      const [{ data: companies }, { data: members }, { data: vers }] = await Promise.all([
        admin.from('companies').select('id, name, org_nr, created_at, suspended'),
        admin.from('user_companies').select('user_id, company_id, email, role'),
        admin.from('verifikationer').select('company_id'),
      ])
      const verCounts: Record<string, number> = {}
      ;(vers || []).forEach(v => { verCounts[v.company_id] = (verCounts[v.company_id] || 0) + 1 })
      return json({ ok: true, users, companies: companies || [], members: members || [], verCounts })
    }

    // Godkänn/stäng av på ANVÄNDARNIVÅ: sätter flagga på kontot + togglar alla deras företag.
    if (action === 'activate' || action === 'deactivate') {
      if (!user_id) return json({ error: 'user_id saknas' }, 400)
      const approved = action === 'activate'
      await admin.auth.admin.updateUserById(user_id, { app_metadata: { approved } })
      const { data: ucs } = await admin.from('user_companies').select('company_id').eq('user_id', user_id)
      for (const uc of ucs || []) {
        await admin.from('companies').update({ suspended: !approved }).eq('id', uc.company_id)
      }
      return json({ ok: true })
    }

    // (kvar för bakåtkompabilitet)
    if (action === 'set_suspended') {
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      const { error } = await admin.from('companies').update({ suspended: !!suspended }).eq('id', company_id)
      if (error) return json({ error: error.message }, 400)
      return json({ ok: true })
    }

    if (action === 'delete_user') {
      if (!user_id) return json({ error: 'user_id saknas' }, 400)
      if (user_id === user.id) return json({ error: 'Du kan inte radera dig själv' }, 400)

      // Bolag där användaren är ENDA medlemmen. Delade bolag rörs aldrig.
      const { data: ucs, error: ucsFel } = await admin.from('user_companies').select('company_id').eq('user_id', user_id)
      if (ucsFel) return json({ error: 'Kunde inte läsa användarens bolag: ' + ucsFel.message }, 400)

      const ensamma: string[] = []
      for (const uc of ucs || []) {
        const { count, error: cFel } = await admin.from('user_companies')
          .select('id', { count: 'exact', head: true }).eq('company_id', uc.company_id)
        if (cFel) return json({ error: 'Kunde inte räkna medlemmar: ' + cFel.message }, 400)
        if ((count || 0) <= 1) ensamma.push(uc.company_id)
      }

      // [BFL 7 kap. 2 §] Räkenskapsinformation ska bevaras i sju år. Ett bolag som
      // har bokföring får därför varken raderas eller lämnas utan någon användare
      // som kommer åt det. Tidigare raderades bolaget rakt av – och om
      // BFL-triggern stoppade raderingen ignorerades felet, auth-kontot togs bort
      // ändå, och materialet blev kvar utan att någon kunde nå det.
      const blockerade: Array<{ company_id: string; namn: string; orsak: string }> = []
      for (const cid of ensamma) {
        const rakenskap = [
          ['verifikationer', 'bokförda verifikationer'],
          ['supplier_invoices', 'leverantörsfakturor'],
          ['invoices', 'kundfakturor'],
          ['bank_transactions', 'bankhändelser'],
          ['lonekorningar', 'lönekörningar'],
        ] as const
        for (const [tabell, text] of rakenskap) {
          const { count, error: rFel } = await admin.from(tabell)
            .select('id', { count: 'exact', head: true }).eq('company_id', cid)
          if (rFel) return json({ error: `Kunde inte kontrollera ${tabell}: ${rFel.message}` }, 400)
          if ((count || 0) > 0) {
            const { data: c } = await admin.from('companies').select('name').eq('id', cid).maybeSingle()
            blockerade.push({ company_id: cid, namn: c?.name || cid, orsak: `har ${count} ${text}` })
            break
          }
        }
      }

      if (blockerade.length) {
        return json({
          error: 'Användaren kan inte raderas: hen är ensam medlem i bolag som har räkenskapsinformation. '
            + 'Den måste bevaras i sju år (BFL 7 kap. 2 §). Gör en arkivexport och/eller koppla en annan '
            + 'användare till bolaget innan kontot tas bort.',
          blockerade,
        }, 409)
      }

      // Bolagen saknar räkenskapsinformation och kan tas bort. Storage kaskaderar
      // INTE från databasen, så filerna måste bort explicit – annars ligger de kvar
      // utan referens, vilket är motsatsen till radering enligt GDPR art. 17.
      for (const cid of ensamma) {
        const { data: docs } = await admin.from('documents').select('storage_path').eq('company_id', cid)
        const underlag = (docs || []).map(d => d.storage_path).filter(Boolean) as string[]
        if (underlag.length) {
          const { error: sFel } = await admin.storage.from('underlag').remove(underlag)
          if (sFel) return json({ error: 'Kunde inte radera underlagsfiler: ' + sFel.message }, 400)
        }

        const { data: arkiv } = await admin.from('arkiv_filer').select('storage_path').eq('company_id', cid)
        const arkivvagar = (arkiv || []).map(a => a.storage_path).filter(Boolean) as string[]
        if (arkivvagar.length) {
          const { error: aFel } = await admin.storage.from('arkiv').remove(arkivvagar)
          if (aFel) return json({ error: 'Kunde inte radera arkivfiler: ' + aFel.message }, 400)
        }

        const { error: cFel } = await admin.from('companies').delete().eq('id', cid)
        if (cFel) return json({ error: `Bolaget kunde inte raderas (${cFel.message}). Användaren har INTE tagits bort.` }, 400)
      }

      const { error } = await admin.auth.admin.deleteUser(user_id)
      if (error) return json({ error: error.message }, 400)
      return json({ ok: true, raderade_bolag: ensamma.length })
    }

    return json({ error: 'Okänd action' }, 400)
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
