// Edge Function: konsol — BokPilot operatörskonsol (admin.bokpilot.se).
// Konsolens frontend har ALDRIG en nyckel som läser andra bolags data;
// varje anrop går genom denna funktion som:
//   1. verifierar att anroparen finns i platform_admins
//   2. hämtar/ändrar data med service role
//   3. loggar känsliga åtgärder i konsol_audit_logg (append-only)
// Bor i repot bokpilot-admin (INTE i kundappens repo) men deployas till
// samma Supabase-projekt: supabase functions deploy konsol --project-ref vzeqvapebkbapwflozbi --use-api
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

// Kundmejl vid ansökningsbeslut (godkänd/avvisad). Best-effort via Resend —
// beslutet i databasen är sanningskällan; mejlfel stoppar ALDRIG hanteringen.
// bokpilot.se är domänverifierad hos Resend (eu-west-1) sedan 2026-07-14.
async function skickaMejl(till: string, amne: string, text: string): Promise<boolean> {
  const nyckel = Deno.env.get('RESEND_API_KEY')
  if (!nyckel || !till) return false
  try {
    const resp = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${nyckel}` },
      body: JSON.stringify({
        from: Deno.env.get('NOTIS_FRAN') || 'BokPilot <notiser@bokpilot.se>',
        reply_to: 'admin@bokpilot.se',
        to: [till], subject: amne, text,
      }),
    })
    if (!resp.ok) console.error(`konsol skickaMejl: Resend HTTP ${resp.status}: ${(await resp.text().catch(() => '')).slice(0, 200)}`)
    return resp.ok
  } catch (e) {
    console.error(`konsol skickaMejl: ${String((e as Error)?.message || e)}`)
    return false
  }
}

const ABONNEMANG = ['testperiod', 'aktiv', 'pausad']
const ANTECKNING_TYPER = ['allmant', 'support', 'uppfoljning']
const DAG = 86400000
const SUPPORT_SIDSTORLEK = 25
const SUPPORT_SAMTYCKE_MEDDELANDE = 'Kunden har inte beviljat supportåtkomst. Be kunden aktivera Supportåtkomst i BokPilot under Inställningar.'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

    // 1. Verifiera anroparen (JWT) och plattformsadmin-medlemskap.
    const authHeader = req.headers.get('Authorization') || ''
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'Ej inloggad' }, 401)

    const db = createClient(SUPABASE_URL, SERVICE_KEY)
    const { data: pa } = await db.from('platform_admins').select('email').ilike('email', user.email!)
    if (!pa || !pa.length) return json({ error: 'Ingen åtkomst' }, 403)

    const body = await req.json()
    const action = body?.action as string

    const logg = async (act: string, company_id: string | null, params: Record<string, unknown> = {}) => {
      const { error } = await db.from('konsol_audit_logg').insert({
        admin_user_id: user.id, admin_email: user.email, action: act, company_id, params,
      })
      if (error) throw new Error('Kunde inte logga åtgärden: ' + error.message)
    }

    const kravSupportSamtycke = async (company_id: string) => {
      const { data, error } = await db.from('konsol_support_samtycken')
        .select('giltig_till, beviljad_av_email')
        .eq('company_id', company_id)
        .is('aterkallad_at', null)
        .gt('giltig_till', new Date().toISOString())
        .order('giltig_till', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (error) return json({ error: 'Kunde inte kontrollera supportåtkomst: ' + error.message }, 500)
      if (!data) {
        await logg('support_nekad_samtycke', company_id, {})
        return json({ error: SUPPORT_SAMTYCKE_MEDDELANDE }, 403)
      }
      return null
    }

    // Senaste inloggning per användare (auth.users nås bara via admin-API:t).
    const hamtaInloggningar = async () => {
      const { data: list } = await db.auth.admin.listUsers({ perPage: 1000 })
      const map: Record<string, string | null> = {}
      for (const u of list?.users || []) map[u.id] = u.last_sign_in_at || null
      return map
    }

    if (action === 'vem_ar_jag') {
      return json({ ok: true, admin: true, email: user.email })
    }

    if (action === 'oversikt') {
      const [{ count: kunderTotalt }, { data: nya }, { data: members }, { count: verTotalt }] = await Promise.all([
        db.from('companies').select('id', { count: 'exact', head: true }),
        db.from('companies').select('id').gte('created_at', new Date(Date.now() - 7 * DAG).toISOString()),
        db.from('user_companies').select('user_id, company_id'),
        db.from('verifikationer').select('id', { count: 'exact', head: true }),
      ])
      const inloggning = await hamtaInloggningar()
      const grans = Date.now() - 30 * DAG
      const aktiva = new Set<string>()
      for (const m of members || []) {
        const senast = inloggning[m.user_id]
        if (senast && new Date(senast).getTime() >= grans) aktiva.add(m.company_id)
      }
      return json({
        ok: true,
        kunder_totalt: kunderTotalt || 0,
        nya_veckan: (nya || []).length,
        aktiva_30d: aktiva.size,
        verifikationer_totalt: verTotalt || 0,
      })
    }

    if (action === 'kundlista') {
      const [{ data: companies }, { data: members }, { data: vers }] = await Promise.all([
        db.from('companies').select('id, name, org_nr, created_at, abonnemang_status, service_state, archive_number'),
        db.from('user_companies').select('user_id, company_id, email, role'),
        db.from('verifikationer').select('company_id'),
      ])
      const inloggning = await hamtaInloggningar()
      const verAntal: Record<string, number> = {}
      for (const v of vers || []) verAntal[v.company_id] = (verAntal[v.company_id] || 0) + 1

      const kunder = (companies || []).map(c => {
        const egna = (members || []).filter(m => m.company_id === c.id)
        const adminMedlem = egna.find(m => m.role === 'admin') || egna[0]
        let senaste: string | null = null
        for (const m of egna) {
          const s = inloggning[m.user_id]
          if (s && (!senaste || s > senaste)) senaste = s
        }
        return {
          id: c.id, name: c.name, org_nr: c.org_nr, created_at: c.created_at,
          abonnemang_status: c.abonnemang_status, service_state: c.service_state,
          archive_number: c.archive_number,
          kontakt: adminMedlem?.email || null,
          antal_anvandare: egna.length,
          antal_verifikationer: verAntal[c.id] || 0,
          senaste_aktivitet: senaste,
        }
      }).sort((a, b) => (b.created_at || '').localeCompare(a.created_at || ''))
      return json({ ok: true, kunder })
    }

    if (action === 'kundkort') {
      const company_id = body?.company_id as string
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      const { data: kund } = await db.from('companies')
        .select('id, name, org_nr, created_at, abonnemang_status, service_state, archive_number')
        .eq('id', company_id).maybeSingle()
      if (!kund) return json({ error: 'Kunden hittades inte' }, 404)

      const [{ data: egna }, inloggning] = await Promise.all([
        db.from('user_companies').select('user_id, email, role, created_at').eq('company_id', company_id),
        hamtaInloggningar(),
      ])
      const medlemmar = (egna || []).map(m => ({
        email: m.email, role: m.role, created_at: m.created_at,
        last_sign_in_at: inloggning[m.user_id] || null,
      }))

      const [{ count: antalVer }, { data: senasteVer }, { count: antalUnderlag }, { count: antalFakturor }] = await Promise.all([
        db.from('verifikationer').select('id', { count: 'exact', head: true }).eq('company_id', company_id),
        db.from('verifikationer').select('datum').eq('company_id', company_id).order('datum', { ascending: false }).limit(1),
        db.from('documents').select('id', { count: 'exact', head: true }).eq('company_id', company_id),
        db.from('invoices').select('id', { count: 'exact', head: true }).eq('company_id', company_id),
      ])

      return json({
        ok: true, kund, medlemmar,
        stats: {
          antal_verifikationer: antalVer || 0,
          senaste_verifikation: senasteVer?.[0]?.datum || null,
          antal_underlag: antalUnderlag || 0,
          antal_fakturor: antalFakturor || 0,
        },
      })
    }

    if (action === 'skapa_kund') {
      const namn = (body?.namn || '').trim()
      const org_nr = (body?.org_nr || '').trim() || null
      const epost = (body?.epost || '').trim().toLowerCase()
      if (!namn) return json({ error: 'Bolagsnamn saknas' }, 400)
      if (!epost || !epost.includes('@')) return json({ error: 'Giltig e-postadress krävs' }, 400)

      // Bolaget skapas AKTIVT (suspended=false) med status testperiod — konsolens
      // "Lägg till kund" ÄR den manuella registreringen tills självregistrering finns.
      const { data: kund, error: bolagsFel } = await db.from('companies')
        .insert({ name: namn, org_nr, suspended: false, abonnemang_status: 'testperiod' })
        .select().single()
      if (bolagsFel) return json({ error: 'Kunde inte skapa bolaget: ' + bolagsFel.message }, 400)

      // Bjud in ägaren via e-post (?valjlosenord=1: nya användaren väljer lösenord
      // innan appen visas). Finns användaren redan kopplas den direkt.
      let epost_status = 'inbjudan_skickad'
      let userId: string | null = null
      const { data: invited, error: invFel } = await db.auth.admin.inviteUserByEmail(epost, {
        redirectTo: 'https://app.bokpilot.se/?valjlosenord=1',
      })
      if (!invFel && invited?.user) {
        userId = invited.user.id
      } else {
        const { data: list } = await db.auth.admin.listUsers({ perPage: 1000 })
        const befintlig = (list?.users || []).find(u => (u.email || '').toLowerCase() === epost)
        if (befintlig) { userId = befintlig.id; epost_status = 'anvandare_fanns_kopplad' }
      }
      if (!userId) {
        // Bolaget finns men inbjudan misslyckades — rulla tillbaka så inget halvfärdigt lämnas.
        await db.from('companies').delete().eq('id', kund.id)
        return json({ error: 'Kunde inte bjuda in användaren: ' + (invFel?.message || 'okänt fel') }, 400)
      }

      await db.auth.admin.updateUserById(userId, { app_metadata: { approved: true } })
      const { error: kopplFel } = await db.from('user_companies')
        .insert({ user_id: userId, company_id: kund.id, role: 'admin', email: epost })
      if (kopplFel) {
        await db.from('companies').delete().eq('id', kund.id)
        return json({ error: 'Kunde inte koppla användaren: ' + kopplFel.message }, 400)
      }

      await logg('skapa_kund', kund.id, { namn, org_nr, epost, epost_status })
      return json({ ok: true, kund, epost_status })
    }

    if (action === 'satt_status') {
      const company_id = body?.company_id as string
      const status = body?.abonnemang_status as string
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      if (!ABONNEMANG.includes(status)) return json({ error: 'Ogiltig abonnemangsstatus' }, 400)
      const { error } = await db.from('companies').update({ abonnemang_status: status }).eq('id', company_id)
      if (error) return json({ error: error.message }, 400)
      await logg('satt_status', company_id, { abonnemang_status: status })
      return json({ ok: true })
    }

    // Beta-ansökningar: registreringen i kundappen skapar en väntande ansökan
    // (beta_ansokningar) och ett pausat bolag. Godkännande här är DET som
    // släpper in kunden: suspended -> false + testperiod + approved-flagga.
    if (action === 'ansokningslista') {
      const { data: ansokningar, error } = await db.from('beta_ansokningar')
        .select('id, company_id, epost, bolagsnamn, org_nr, meddelande, status, hanterad_av_email, hanterad_at, avvisad_orsak, created_at')
        .order('created_at', { ascending: false }).limit(200)
      if (error) return json({ error: 'Kunde inte hämta ansökningar: ' + error.message }, 400)
      return json({ ok: true, ansokningar: ansokningar || [] })
    }

    if (action === 'godkann_ansokan') {
      const ansokan_id = body?.ansokan_id as string
      if (!ansokan_id) return json({ error: 'ansokan_id saknas' }, 400)
      const { data: ans } = await db.from('beta_ansokningar').select('*').eq('id', ansokan_id).maybeSingle()
      if (!ans) return json({ error: 'Ansökan hittades inte' }, 404)
      if (ans.status !== 'vantar') return json({ error: 'Ansökan är redan hanterad' }, 400)

      // Aktivera bolaget. Ansökan markeras hanterad SIST — misslyckas ett steg
      // kan godkännandet köras om utan att kunden fastnar halvvägs.
      if (ans.company_id) {
        const { error: bolagsFel } = await db.from('companies')
          .update({ suspended: false, abonnemang_status: 'testperiod' }).eq('id', ans.company_id)
        if (bolagsFel) return json({ error: 'Kunde inte aktivera bolaget: ' + bolagsFel.message }, 400)
      }
      await db.auth.admin.updateUserById(ans.user_id, { app_metadata: { approved: true } })
      const { error: ansFel } = await db.from('beta_ansokningar')
        .update({ status: 'godkand', hanterad_av_email: user.email, hanterad_at: new Date().toISOString() })
        .eq('id', ansokan_id)
      if (ansFel) return json({ error: 'Bolaget aktiverades men ansökan kunde inte markeras: ' + ansFel.message }, 400)
      await logg('ansokan_godkand', ans.company_id, { ansokan_id, epost: ans.epost })
      // Kundmejl: ansökan godkänd. Best-effort — godkännandet gäller oavsett.
      const mejlSkickat = await skickaMejl(
        ans.epost,
        'Din ansökan är godkänd – välkommen till BokPilot!',
        [
          'Hej!',
          '',
          `Ansökan för ${ans.bolagsnamn} är godkänd och kontot är nu aktivt.`,
          '',
          'Logga in på https://app.bokpilot.se så är du igång direkt.',
          'Kontot börjar med en kostnadsfri testperiod.',
          '',
          'Frågor? Svara på det här mejlet så hjälper vi dig.',
          '',
          'Välkommen!',
          'BokPilot',
        ].join('\n'),
      )
      return json({ ok: true, mejl_skickat: mejlSkickat })
    }

    if (action === 'avvisa_ansokan') {
      const ansokan_id = body?.ansokan_id as string
      const orsak = String(body?.orsak || '').trim().slice(0, 500)
      if (!ansokan_id) return json({ error: 'ansokan_id saknas' }, 400)
      const { data: ans } = await db.from('beta_ansokningar').select('*').eq('id', ansokan_id).maybeSingle()
      if (!ans) return json({ error: 'Ansökan hittades inte' }, 404)
      if (ans.status !== 'vantar') return json({ error: 'Ansökan är redan hanterad' }, 400)
      const { error } = await db.from('beta_ansokningar')
        .update({ status: 'avvisad', avvisad_orsak: orsak || null, hanterad_av_email: user.email, hanterad_at: new Date().toISOString() })
        .eq('id', ansokan_id)
      if (error) return json({ error: 'Kunde inte avvisa ansökan: ' + error.message }, 400)
      await logg('ansokan_avvisad', ans.company_id, { ansokan_id, epost: ans.epost, har_orsak: Boolean(orsak) })
      // Kundmejl: ansökan avvisad (med ev. orsak). Best-effort.
      const mejlSkickat = await skickaMejl(
        ans.epost,
        'Angående din ansökan till BokPilot',
        [
          'Hej!',
          '',
          `Tack för din ansökan för ${ans.bolagsnamn}. Vi kan tyvärr inte godkänna den just nu.`,
          ...(orsak ? ['', `Orsak: ${orsak}`] : []),
          '',
          'Har du frågor eller vill komplettera? Svara på det här mejlet.',
          '',
          'Vänliga hälsningar,',
          'BokPilot',
        ].join('\n'),
      )
      return json({ ok: true, mejl_skickat: mejlSkickat })
    }

    // Rex-livscykel: stegstatus per bolag (konsol_livscykel_steg) + spegling av
    // kundens KYC-status från appens KYC/AML-modul. Stegdefinitionerna bor i
    // frontendens src/lib/livscykel.js.
    if (action === 'livscykel') {
      const company_id = body?.company_id as string
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      const [stegRes, kycRes] = await Promise.all([
        db.from('konsol_livscykel_steg').select('steg_key, status, notering, uppdaterad_av_email, updated_at').eq('company_id', company_id),
        db.from('kyc_assessments').select('status, riskklass, giltig_till, beslutad_at').eq('company_id', company_id).order('created_at', { ascending: false }).limit(1),
      ])
      if (stegRes.error) return json({ error: 'Kunde inte hämta livscykeln: ' + stegRes.error.message }, 400)
      return json({ ok: true, steg: stegRes.data || [], kyc: kycRes.data?.[0] || null })
    }

    if (action === 'satt_livscykelsteg') {
      const company_id = body?.company_id as string
      const steg_key = String(body?.steg_key || '')
      const status = body?.status as string
      const notering = String(body?.notering || '').trim().slice(0, 2000)
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      if (!/^[a-z_]{2,40}$/.test(steg_key)) return json({ error: 'Ogiltigt steg' }, 400)
      if (!['ej_paborjad', 'pagar', 'klar', 'ej_relevant'].includes(status)) return json({ error: 'Ogiltig stegstatus' }, 400)
      const { error } = await db.from('konsol_livscykel_steg').upsert(
        { company_id, steg_key, status, notering: notering || null, uppdaterad_av_email: user.email, updated_at: new Date().toISOString() },
        { onConflict: 'company_id,steg_key' },
      )
      if (error) return json({ error: 'Kunde inte spara steget: ' + error.message }, 400)
      await logg('livscykel_steg', company_id, { steg_key, status, har_notering: Boolean(notering) })
      return json({ ok: true })
    }

    if (action === 'kundanteckningar') {
      const company_id = body?.company_id as string
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      const { data: anteckningar, error } = await db.from('konsol_kundanteckningar')
        .select('id, typ, innehall, skapad_av_email, created_at')
        .eq('company_id', company_id)
        .order('created_at', { ascending: false })
      if (error) return json({ error: 'Kunde inte hämta anteckningar: ' + error.message }, 400)
      return json({ ok: true, anteckningar: anteckningar || [] })
    }

    if (action === 'skapa_anteckning') {
      const company_id = body?.company_id as string
      const typ = body?.typ as string
      const innehall = (body?.innehall || '').trim()
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      if (!ANTECKNING_TYPER.includes(typ)) return json({ error: 'Ogiltig typ av anteckning' }, 400)
      if (!innehall || innehall.length > 4000) return json({ error: 'Anteckningen måste vara mellan 1 och 4 000 tecken' }, 400)

      const { error } = await db.from('konsol_kundanteckningar').insert({
        company_id, typ, innehall, skapad_av_user_id: user.id, skapad_av_email: user.email,
      })
      if (error) return json({ error: 'Kunde inte spara anteckningen: ' + error.message }, 400)
      await logg('anteckning_skapa', company_id, { typ, antal_tecken: innehall.length })
      return json({ ok: true })
    }

    if (action === 'kundhistorik') {
      const company_id = body?.company_id as string
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      // Parametrar kan innehålla kontaktuppgifter och lämnas därför aldrig ut här.
      const { data: handelser, error } = await db.from('konsol_audit_logg')
        .select('id, action, admin_email, created_at')
        .eq('company_id', company_id)
        .order('created_at', { ascending: false })
        .limit(100)
      if (error) return json({ error: 'Kunde inte hämta kundhistoriken: ' + error.message }, 400)
      return json({ ok: true, handelser: handelser || [] })
    }

    if (action === 'kundprofil') {
      const company_id = body?.company_id as string
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      const { data, error } = await db.from('konsol_kundprofiler').select('kundtyp, prisplan, manadspris_ore, testperiod_manader, rabatt_procent, rabatt_tom, ansvarig, uppfoljning_datum').eq('company_id', company_id).maybeSingle()
      if (error) return json({ error: 'Kunde inte hämta kundprofilen: ' + error.message }, 400)
      return json({ ok: true, profil: data || { kundtyp: 'foretag', prisplan: 'start', manadspris_ore: 4900, testperiod_manader: 1, rabatt_procent: 0, rabatt_tom: null, ansvarig: '', uppfoljning_datum: null } })
    }

    if (action === 'spara_kundprofil') {
      const company_id = body?.company_id as string
      const kundtyp = body?.kundtyp as string
      const prisplan = body?.prisplan as string
      const manadspris_ore = Number(body?.manadspris_ore)
      const testperiod_manader = Number(body?.testperiod_manader)
      const rabatt_procent = Number(body?.rabatt_procent)
      const rabatt_tom = body?.rabatt_tom || null
      const ansvarig = String(body?.ansvarig || '').trim()
      const uppfoljning_datum = body?.uppfoljning_datum || null
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      if (!['foretag', 'redovisningsbyra', 'partner'].includes(kundtyp)) return json({ error: 'Ogiltig kundtyp' }, 400)
      if (!['start', 'standard', 'pro', 'byra'].includes(prisplan) || !Number.isInteger(manadspris_ore) || manadspris_ore < 0) return json({ error: 'Ogiltig prisplan eller månadsavgift' }, 400)
      if (![1, 2, 3, 6].includes(testperiod_manader) || !Number.isInteger(rabatt_procent) || rabatt_procent < 0 || rabatt_procent > 100) return json({ error: 'Ogiltig testperiod eller rabatt' }, 400)
      const { error } = await db.from('konsol_kundprofiler').upsert({ company_id, kundtyp, prisplan, manadspris_ore, testperiod_manader, rabatt_procent, rabatt_tom, ansvarig: ansvarig || null, uppfoljning_datum, updated_at: new Date().toISOString(), updated_by_email: user.email })
      if (error) return json({ error: 'Kunde inte spara kundprofilen: ' + error.message }, 400)
      await logg('kundprofil_spara', company_id, { kundtyp, prisplan, manadspris_ore, testperiod_manader, rabatt_procent, rabatt_tom, har_ansvarig: Boolean(ansvarig), har_uppfoljning: Boolean(uppfoljning_datum) })
      return json({ ok: true })
    }

    if (action === 'betalhistorik') {
      const company_id = body?.company_id as string
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      const { data, error } = await db.from('konsol_abonnemangsfakturor').select('id, fakturadatum, forfallodatum, belopp_ore, status, betald_datum').eq('company_id', company_id).order('fakturadatum', { ascending: false })
      if (error) return json({ error: 'Kunde inte hämta betalhistoriken: ' + error.message }, 400)
      return json({ ok: true, fakturor: data || [] })
    }

    if (action === 'faktureringsoversikt') {
      const [{ data: profiler }, { data: fakturor }] = await Promise.all([
        db.from('konsol_kundprofiler').select('manadspris_ore'),
        db.from('konsol_abonnemangsfakturor').select('belopp_ore, status'),
      ])
      const manadsintakt_ore = (profiler || []).reduce((sum, profil) => sum + (profil.manadspris_ore || 0), 0)
      const fakturerat_ore = (fakturor || []).reduce((sum, faktura) => sum + (faktura.belopp_ore || 0), 0)
      const betalt_ore = (fakturor || []).filter(f => f.status === 'betald').reduce((sum, faktura) => sum + (faktura.belopp_ore || 0), 0)
      return json({ ok: true, manadsintakt_ore, fakturerat_ore, betalt_ore })
    }

    if (action === 'obetalda_abonnemangsfakturor') {
      const [{ data, error }, { data: medlemmar }, { data: paminnelser }, { data: profiler }] = await Promise.all([
        db.from('konsol_abonnemangsfakturor').select('id, company_id, fakturadatum, forfallodatum, belopp_ore, status, companies(name)').neq('status', 'betald').order('forfallodatum', { ascending: true }),
        db.from('user_companies').select('company_id, email, role'),
        db.from('konsol_audit_logg').select('created_at, params').eq('action', 'abonnemangspaminnelse_skickad').order('created_at', { ascending: false }),
        db.from('konsol_kundprofiler').select('company_id, ansvarig, uppfoljning_datum'),
      ])
      if (error) return json({ error: 'Kunde inte hämta obetalda fakturor: ' + error.message }, 400)
      const paminnelseInfo = new Map<string, { senaste: string, antal: number }>()
      const profilPerBolag = new Map((profiler || []).map(p => [p.company_id, p]))
      for (const p of paminnelser || []) { const fakturaId = p.params?.faktura_id as string | undefined; if (fakturaId) { const befintlig = paminnelseInfo.get(fakturaId); paminnelseInfo.set(fakturaId, { senaste: befintlig?.senaste || p.created_at, antal: (befintlig?.antal || 0) + 1 }) } }
      return json({ ok: true, fakturor: (data || []).map((f: any) => { const egna = (medlemmar || []).filter(m => m.company_id === f.company_id); const kontakt = egna.find(m => m.role === 'admin') || egna[0]; const paminnelse = paminnelseInfo.get(f.id); const profil = profilPerBolag.get(f.company_id) as { ansvarig?: string, uppfoljning_datum?: string } | undefined; return { ...f, company_name: f.companies?.name || 'Okänd kund', kontakt: kontakt?.email || null, senast_pamind_at: paminnelse?.senaste || null, paminnelse_antal: paminnelse?.antal || 0, ansvarig: profil?.ansvarig || null, uppfoljning_datum: profil?.uppfoljning_datum || null } }) })
    }

    if (action === 'faktureringsunderlag') {
      const [{ data: companies }, { data: profiler }] = await Promise.all([
        db.from('companies').select('id, name').eq('abonnemang_status', 'aktiv'),
        db.from('konsol_kundprofiler').select('company_id, prisplan, manadspris_ore'),
      ])
      const profilPerBolag = new Map((profiler || []).map(p => [p.company_id, p]))
      const kunder = (companies || []).map(c => {
        const profil = profilPerBolag.get(c.id) as { prisplan?: string, manadspris_ore?: number } | undefined
        return { company_id: c.id, company_name: c.name, prisplan: profil?.prisplan || 'start', manadspris_ore: profil?.manadspris_ore || 4900 }
      }).sort((a, b) => a.company_name.localeCompare(b.company_name, 'sv'))
      return json({ ok: true, kunder, totalt_ore: kunder.reduce((sum, kund) => sum + kund.manadspris_ore, 0) })
    }

    if (action === 'registrera_abonnemangsfaktura') {
      const company_id = body?.company_id as string
      const belopp_ore = Number(body?.belopp_ore); const fakturadatum = body?.fakturadatum; const forfallodatum = body?.forfallodatum
      if (!company_id || !fakturadatum || !forfallodatum || !Number.isInteger(belopp_ore) || belopp_ore < 0) return json({ error: 'Fyll i giltigt fakturadatum, förfallodatum och belopp' }, 400)
      const { error } = await db.from('konsol_abonnemangsfakturor').insert({ company_id, belopp_ore, fakturadatum, forfallodatum, skapad_av_email: user.email })
      if (error) return json({ error: 'Kunde inte registrera fakturan: ' + error.message }, 400)
      await logg('abonnemangsfaktura_skapa', company_id, { belopp_ore })
      return json({ ok: true })
    }

    if (action === 'markera_abonnemangsfaktura_betald') {
      const id = body?.faktura_id as string
      if (!id) return json({ error: 'faktura_id saknas' }, 400)
      const { data, error } = await db.from('konsol_abonnemangsfakturor').update({ status: 'betald', betald_datum: new Date().toISOString().slice(0, 10) }).eq('id', id).select('company_id').single()
      if (error) return json({ error: 'Kunde inte markera fakturan som betald: ' + error.message }, 400)
      await logg('abonnemangsfaktura_betald', data.company_id, {})
      return json({ ok: true })
    }

    if (action === 'logga_abonnemangspaminnelse') {
      const id = body?.faktura_id as string
      if (!id) return json({ error: 'faktura_id saknas' }, 400)
      const { data, error } = await db.from('konsol_abonnemangsfakturor').select('company_id').eq('id', id).single()
      if (error) return json({ error: 'Kunde inte logga påminnelsen: ' + error.message }, 400)
      await logg('abonnemangspaminnelse_skickad', data.company_id, { faktura_id: id })
      return json({ ok: true })
    }

    if (action === 'arendelista') {
      const { data: arenden, error } = await db.from('konsol_arenden')
        .select('id, company_id, rubrik, beskrivning, status, prioritet, updated_at, companies(name)')
        .in('status', ['oppen', 'pagar', 'vantar_pa_kund']).order('updated_at', { ascending: false })
      if (error) return json({ error: 'Kunde inte hämta ärenden: ' + error.message }, 400)
      return json({ ok: true, arenden: (arenden || []).map((a: any) => ({ ...a, company_name: a.companies?.name || 'Okänd kund' })) })
    }

    if (action === 'skapa_arende') {
      const company_id = body?.company_id as string
      const rubrik = String(body?.rubrik || '').trim()
      const beskrivning = String(body?.beskrivning || '').trim()
      const prioritet = body?.prioritet as string
      if (!company_id) return json({ error: 'Välj en kund' }, 400)
      if (!rubrik || rubrik.length > 200) return json({ error: 'Rubriken måste vara mellan 1 och 200 tecken' }, 400)
      if (beskrivning.length > 4000) return json({ error: 'Beskrivningen får vara högst 4 000 tecken' }, 400)
      if (!['lag', 'normal', 'hog'].includes(prioritet)) return json({ error: 'Ogiltig prioritet' }, 400)
      const { error } = await db.from('konsol_arenden').insert({ company_id, rubrik, beskrivning: beskrivning || null, prioritet, skapad_av_email: user.email })
      if (error) return json({ error: 'Kunde inte skapa ärendet: ' + error.message }, 400)
      await logg('arende_skapa', company_id, { prioritet })
      return json({ ok: true })
    }

    if (action === 'satt_arendestatus') {
      const id = body?.arende_id as string
      const status = body?.status as string
      if (!id) return json({ error: 'arende_id saknas' }, 400)
      if (!['oppen', 'pagar', 'vantar_pa_kund', 'lost'].includes(status)) return json({ error: 'Ogiltig ärendestatus' }, 400)
      const { data: arende, error } = await db.from('konsol_arenden').update({ status, updated_at: new Date().toISOString() }).eq('id', id).select('company_id').single()
      if (error) return json({ error: 'Kunde inte uppdatera ärendet: ' + error.message }, 400)
      await logg('arende_status', arende.company_id, { status })
      return json({ ok: true })
    }

    if (action === 'support_samtycke_status') {
      const company_id = body?.company_id as string
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      const { data, error } = await db.from('konsol_support_samtycken')
        .select('giltig_till, beviljad_av_email')
        .eq('company_id', company_id)
        .is('aterkallad_at', null)
        .gt('giltig_till', new Date().toISOString())
        .order('giltig_till', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (error) return json({ error: 'Kunde inte hämta supportåtkomst: ' + error.message }, 400)
      return json({ ok: true, beviljat: Boolean(data), giltig_till: data?.giltig_till || null, beviljad_av_email: data?.beviljad_av_email || null })
    }

    if (action === 'support_data') {
      const company_id = body?.company_id as string
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      const samtyckeFel = await kravSupportSamtycke(company_id)
      if (samtyckeFel) return samtyckeFel
      // Loggas FÖRE datahämtningen — det finns ingen väg till kundens data utan spår.
      await logg('support_oppna', company_id, {})
      const { data: kund, error: kundError } = await db.from('companies').select('id, name').eq('id', company_id).maybeSingle()
      if (kundError) return json({ error: 'Kunde inte hämta kunden: ' + kundError.message }, 400)
      if (!kund) return json({ error: 'Kunden hittades inte' }, 404)

      return json({ ok: true, kund })
    }

    if (action === 'support_resurs') {
      const company_id = body?.company_id as string
      const resurs = body?.resurs as string
      const sida = Math.max(0, Number(body?.sida) || 0)
      if (!company_id) return json({ error: 'company_id saknas' }, 400)
      const tillatnaResurser = ['verifikationer', 'leverantorsfakturor', 'kontoplan', 'kundfakturor', 'kunder', 'anstallda', 'underlag', 'bank', 'moms']
      if (!tillatnaResurser.includes(resurs)) return json({ error: 'Ogiltig supportresurs' }, 400)
      const samtyckeFel = await kravSupportSamtycke(company_id)
      if (samtyckeFel) return samtyckeFel

      // Loggas FÖRE varje specifik resurs hämtas.
      const loggAction = `support_${resurs}`
      await logg(loggAction, company_id, { sida })

      if (resurs === 'verifikationer') {
      const { data: verifikationer, error, count } = await db.from('verifikationer')
        .select('id, ver_serie, ver_nr, datum, beskrivning, status', { count: 'exact' }).eq('company_id', company_id)
        .order('datum', { ascending: false }).order('ver_nr', { ascending: false })
        .range(sida * SUPPORT_SIDSTORLEK, sida * SUPPORT_SIDSTORLEK + SUPPORT_SIDSTORLEK - 1)
      if (error) return json({ error: 'Kunde inte hämta verifikationer: ' + error.message }, 400)
      const ids = (verifikationer || []).map(v => v.id)
      // verifikation_rows saknar company_id — tenant-avgränsningen ges av att raderna
      // hämtas enbart via id:n från de company-filtrerade verifikationerna ovan.
      // Kontonummer/-namn ligger direkt på raden (account_nr/account_name), ingen accounts-join.
      const [raderRes, andringarRes] = await Promise.all([
        ids.length
          ? db.from('verifikation_rows').select('verifikation_id, account_nr, account_name, debet, kredit, transaction_info, sort_order').in('verifikation_id', ids).order('sort_order', { ascending: true })
          : Promise.resolve({ data: [], error: null }),
        ids.length
          ? db.from('verifikation_andringar').select('original_id, orsak, utford_av_epost, skapad').eq('company_id', company_id).in('original_id', ids).order('skapad', { ascending: false })
          : Promise.resolve({ data: [], error: null }),
      ])
      if (raderRes.error) return json({ error: 'Kunde inte hämta konteringsrader: ' + raderRes.error.message }, 400)
      if (andringarRes.error) return json({ error: 'Kunde inte hämta rättelsehistorik: ' + andringarRes.error.message }, 400)
      const belopp = (v: unknown) => Number(v || 0)
      const resultat = (verifikationer || []).map(v => {
        const verRader = (raderRes.data || []).filter(r => r.verifikation_id === v.id).map(r => ({
          konto: { nummer: r.account_nr, namn: r.account_name },
          debet: belopp(r.debet), kredit: belopp(r.kredit), text: r.transaction_info || null,
        }))
        const debet = verRader.reduce((sum, r) => sum + r.debet, 0)
        const kredit = verRader.reduce((sum, r) => sum + r.kredit, 0)
        return {
          id: v.id, ver_serie: v.ver_serie || 'A', ver_nr: v.ver_nr, datum: v.datum,
          beskrivning: v.beskrivning || null, status: v.status || null,
          rader: verRader, debet, kredit,
          // Jämför i ören — flyttalssummor får inte ge falskt "Obalans".
          balanserar: Math.round(debet * 100) === Math.round(kredit * 100),
          andringar: (andringarRes.data || []).filter(a => a.original_id === v.id).map(a => ({
            datum: a.skapad, beskrivning: a.orsak || 'Rättelse registrerad',
          })),
        }
      })
      return json({ ok: true, resurs, sida, totalt: count || 0, sidstorlek: SUPPORT_SIDSTORLEK, verifikationer: resultat })
      }

      if (resurs === 'leverantorsfakturor') {
        const { data, error, count } = await db.from('supplier_invoices')
          .select('id, supplier_id, invoice_nr, lopnr, ocr, invoice_date, due_date, amount_excl_vat, vat_amount, total_amount, status, paid_amount, paid_date, bokford, makulerad, kreditfaktura, kostnadskonto, verifikation_id', { count: 'exact' })
          .eq('company_id', company_id).order('invoice_date', { ascending: false })
          .range(sida * SUPPORT_SIDSTORLEK, sida * SUPPORT_SIDSTORLEK + SUPPORT_SIDSTORLEK - 1)
        if (error) return json({ error: 'Kunde inte hämta leverantörsfakturor: ' + error.message }, 400)
        const supplierIds = [...new Set((data || []).map(f => f.supplier_id).filter(Boolean))]
        const { data: suppliers, error: suppliersError } = supplierIds.length
          ? await db.from('suppliers').select('id, name').eq('company_id', company_id).in('id', supplierIds)
          : { data: [], error: null }
        if (suppliersError) return json({ error: 'Kunde inte hämta leverantörsregister: ' + suppliersError.message }, 400)
        const namnPerId = new Map((suppliers || []).map(s => [s.id, s.name]))
        return json({ ok: true, resurs, sida, totalt: count || 0, sidstorlek: SUPPORT_SIDSTORLEK, leverantorsfakturor: (data || []).map(f => ({ ...f, leverantorsnamn: namnPerId.get(f.supplier_id) || 'Okänd leverantör', ar_kreditfaktura: Boolean(f.kreditfaktura) })) })
      }

      if (resurs === 'kontoplan') {
        const { data, error, count } = await db.from('accounts')
          .select('account_nr, name, account_class, account_type, is_active, is_blocked_for_manual_booking, is_locked, locked_reason', { count: 'exact' })
          .eq('company_id', company_id).order('account_nr', { ascending: true })
          .range(sida * SUPPORT_SIDSTORLEK, sida * SUPPORT_SIDSTORLEK + SUPPORT_SIDSTORLEK - 1)
        if (error) return json({ error: 'Kunde inte hämta kontoplanen: ' + error.message }, 400)
        return json({ ok: true, resurs, sida, totalt: count || 0, sidstorlek: SUPPORT_SIDSTORLEK, konton: data || [] })
      }

      if (resurs === 'kundfakturor') {
        const { data, error, count } = await db.from('invoices')
          .select('id, customer_id, invoice_nr, invoice_date, due_date, amount_excl_vat, vat_amount, total_amount, status, typ, krediterar_id, verifikation_id', { count: 'exact' })
          .eq('company_id', company_id).order('invoice_date', { ascending: false })
          .range(sida * SUPPORT_SIDSTORLEK, sida * SUPPORT_SIDSTORLEK + SUPPORT_SIDSTORLEK - 1)
        if (error) return json({ error: 'Kunde inte hämta kundfakturor: ' + error.message }, 400)
        const invoiceIds = (data || []).map(f => f.id)
        const customerIds = [...new Set((data || []).map(f => f.customer_id).filter(Boolean))]
        const [customersResult, rowsResult] = await Promise.all([
          customerIds.length ? db.from('customers').select('id, name').eq('company_id', company_id).in('id', customerIds) : Promise.resolve({ data: [], error: null }),
          invoiceIds.length ? db.from('invoice_rows').select('invoice_id, description, quantity, unit_price, vat_rate, total, sort_order').in('invoice_id', invoiceIds).order('sort_order', { ascending: true }) : Promise.resolve({ data: [], error: null }),
        ])
        if (customersResult.error) return json({ error: 'Kunde inte hämta kundregister: ' + customersResult.error.message }, 400)
        if (rowsResult.error) return json({ error: 'Kunde inte hämta fakturarader: ' + rowsResult.error.message }, 400)
        const kundnamn = new Map((customersResult.data || []).map(c => [c.id, c.name]))
        return json({ ok: true, resurs, sida, totalt: count || 0, sidstorlek: SUPPORT_SIDSTORLEK, kundfakturor: (data || []).map(f => ({ ...f, kundnamn: kundnamn.get(f.customer_id) || 'Okänd kund', rader: (rowsResult.data || []).filter(r => r.invoice_id === f.id) })) })
      }

      if (resurs === 'kunder') {
        const { data, error, count } = await db.from('customers')
          .select('id, kund_nr, name, org_nr, contact_person, email, phone, ort, payment_terms, is_active', { count: 'exact' })
          .eq('company_id', company_id).order('name', { ascending: true })
          .range(sida * SUPPORT_SIDSTORLEK, sida * SUPPORT_SIDSTORLEK + SUPPORT_SIDSTORLEK - 1)
        if (error) return json({ error: 'Kunde inte hämta kunder: ' + error.message }, 400)
        return json({ ok: true, resurs, sida, totalt: count || 0, sidstorlek: SUPPORT_SIDSTORLEK, kunder: data || [] })
      }

      if (resurs === 'anstallda') {
        const { data, error, count } = await db.from('employees')
          .select('id, fornamn, efternamn, namn, befattning, anstallningsform, anstallningsdatum, slutdatum, is_active', { count: 'exact' })
          .eq('company_id', company_id).order('efternamn', { ascending: true }).order('fornamn', { ascending: true })
          .range(sida * SUPPORT_SIDSTORLEK, sida * SUPPORT_SIDSTORLEK + SUPPORT_SIDSTORLEK - 1)
        if (error) return json({ error: 'Kunde inte hämta anställda: ' + error.message }, 400)
        return json({ ok: true, resurs, sida, totalt: count || 0, sidstorlek: SUPPORT_SIDSTORLEK, anstallda: data || [] })
      }

      if (resurs === 'underlag') {
        const { data, error, count } = await db.from('documents')
          .select('id, file_name, mime_type, file_size, kategori, source, status, created_at, received_at, verifikation_id, email_from, email_subject', { count: 'exact' })
          .eq('company_id', company_id).order('created_at', { ascending: false })
          .range(sida * SUPPORT_SIDSTORLEK, sida * SUPPORT_SIDSTORLEK + SUPPORT_SIDSTORLEK - 1)
        if (error) return json({ error: 'Kunde inte hämta underlag: ' + error.message }, 400)
        return json({ ok: true, resurs, sida, totalt: count || 0, sidstorlek: SUPPORT_SIDSTORLEK, underlag: data || [] })
      }

      if (resurs === 'bank') {
        const [accountsResult, transactionsResult] = await Promise.all([
          db.from('bank_accounts').select('id, namn, typ, valuta, account_nr, bankgiro, aktiv, is_standard').eq('company_id', company_id).order('namn', { ascending: true }),
          db.from('bank_transactions').select('id, account_nr, datum, text, amount, status, avstamd, verifikation_id', { count: 'exact' }).eq('company_id', company_id).order('datum', { ascending: false }).range(sida * SUPPORT_SIDSTORLEK, sida * SUPPORT_SIDSTORLEK + SUPPORT_SIDSTORLEK - 1),
        ])
        if (accountsResult.error) return json({ error: 'Kunde inte hämta bankkonton: ' + accountsResult.error.message }, 400)
        if (transactionsResult.error) return json({ error: 'Kunde inte hämta banktransaktioner: ' + transactionsResult.error.message }, 400)
        return json({ ok: true, resurs, sida, totalt: transactionsResult.count || 0, sidstorlek: SUPPORT_SIDSTORLEK, bankkonton: accountsResult.data || [], transaktioner: transactionsResult.data || [] })
      }

      if (resurs === 'moms') {
        const { data, error, count } = await db.from('vat_reports')
          .select('id, year, month, period_start, period_end, status, utgaende_moms, ingaende_moms, moms_att_betala, difference, verifikation_id', { count: 'exact' })
          .eq('company_id', company_id).order('year', { ascending: false }).order('month', { ascending: false })
          .range(sida * SUPPORT_SIDSTORLEK, sida * SUPPORT_SIDSTORLEK + SUPPORT_SIDSTORLEK - 1)
        if (error) return json({ error: 'Kunde inte hämta momsrapporter: ' + error.message }, 400)
        return json({ ok: true, resurs, sida, totalt: count || 0, sidstorlek: SUPPORT_SIDSTORLEK, momsrapporter: data || [] })
      }
    }

    return json({ error: 'Okänd action' }, 400)
  } catch (e) {
    return json({ error: (e as Error).message || 'Internt fel' }, 500)
  }
})
