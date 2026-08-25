// Byråstödets nattliga jobb: genererar uppdragsuppgifter (rullande horisont) enligt
// deadline-motorn och markerar försenade uppgifter. Se docs/byrastod/02-deadline-regelverk.md.
//
// KÖRMODELL (kivra-sync-mönstret): pg_cron anropar funktionen varje natt (04:10) med den
// interna nyckeln (interna_nycklar, namn='byrastod_cron'). Byråmedlem kan även trigga
// manuellt med user-JWT (används av E2E-test och en ev. framtida "Uppdatera nu"-knapp).
//
// REGELKÄLLA: deadline_regel-tabellen (data, aldrig hårdkodade datum) tolkat av den
// delade motorn i ../_shared/deadlines.js — samma kod som vitest-testas i frontenden.
//
// HORISONT: periodbaserade uppgifter (moms månad/kvartal, AGI, löpande) genereras för
// perioder som slutar inom 90 dagar; årsbaserade (helårsmoms, bokslut, ÅR, INK) för
// räkenskapsår/beskattningsår som slutat eller slutar inom 90 dagar (max 540 dagar bakåt).
//
// Skrivningar: upsert med ignoreDuplicates på (uppdrag_id, period_start) — dubbel-
// generering är omöjlig; manuella justeringar/klarmarkeringar skrivs aldrig över.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import {
  beraknaDeadline, perioder, periodEtikett, momsperiodTillFrekvens, addDagar,
} from '../_shared/deadlines.js'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-byrastod-cron-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } })

const idag = () => new Date().toISOString().slice(0, 10)

type Regel = { uppgiftstyp: string; bolagsform: string | null; variant: string | null; parametrar: Record<string, unknown> }

// Välj regel: exakt bolagsform vinner över null; variant måste matcha när angiven.
function valjRegel(regler: Regel[], uppgiftstyp: string, bolagsform: string | null, variant: string | null) {
  const kandidater = regler.filter(r =>
    r.uppgiftstyp === uppgiftstyp &&
    (r.variant ?? null) === (variant ?? null) &&
    (r.bolagsform === null || r.bolagsform === bolagsform))
  return kandidater.find(r => r.bolagsform === bolagsform) || kandidater.find(r => r.bolagsform === null) || null
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
  const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!
  const admin = createClient(SUPABASE_URL, SERVICE_KEY)

  try {
    // ── Behörighet: cron-nyckel ELLER inloggad byråmedlem ──
    const cronSecret = req.headers.get('x-byrastod-cron-secret')
    if (cronSecret) {
      const { data: nyckel } = await admin.from('interna_nycklar').select('varde').eq('namn', 'byrastod_cron').maybeSingle()
      if (!nyckel?.varde || nyckel.varde !== cronSecret) return json({ error: 'ogiltig cron-nyckel' }, 401)
    } else {
      const authHeader = req.headers.get('Authorization') || ''
      const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
      const { data: { user } } = await userClient.auth.getUser()
      if (!user) return json({ error: 'ej inloggad' }, 401)
      const { data: arMedlem } = await userClient.rpc('ar_byra_medlem')
      if (!arMedlem) return json({ error: 'endast byråmedlemmar' }, 403)
    }

    // ── Underlag ──
    const [uppdragRes, reglerRes, ink2Res] = await Promise.all([
      admin.from('uppdrag')
        .select('id, byra_klient_id, byra_bolag_id, klient_bolag_id, uppdragstyp, uppdragsansvarig_anvandare_id, bokforingstakt, byraanstand_aktiv, revisionsplikt, startdatum, status, byra_klient!inner(status), companies!uppdrag_klient_bolag_id_fkey(momsperiod, foretagsform)')
        .eq('status', 'aktiv').eq('byra_klient.status', 'aktiv').limit(5000),
      admin.from('deadline_regel').select('uppgiftstyp, bolagsform, variant, parametrar')
        .or(`giltig_till.is.null,giltig_till.gte.${idag()}`).limit(1000),
      admin.from('ink2_deklarationstidpunkt').select('*').limit(1000),
    ])
    if (uppdragRes.error) throw uppdragRes.error
    const uppdragen = uppdragRes.data || []
    const regler = (reglerRes.data || []) as Regel[]
    const ink2Tabell = ink2Res.data || []

    // Räkenskapsår för berörda klientbolag.
    const klientIds = [...new Set(uppdragen.map(u => u.klient_bolag_id))]
    const { data: fyData } = klientIds.length
      ? await admin.from('fiscal_years').select('company_id, start_date, end_date').in('company_id', klientIds).limit(5000)
      : { data: [] }
    const fiscalYears = fyData || []

    const HORISONT = addDagar(idag(), 90)
    const BAKGRANS = addDagar(idag(), -540)
    const rader: Record<string, unknown>[] = []
    const hoppade: Record<string, unknown>[] = []

    for (const u of uppdragen) {
      const bolagsform = (u.companies as { foretagsform?: string } | null)?.foretagsform ?? null
      const momsperiod = (u.companies as { momsperiod?: string } | null)?.momsperiod ?? null
      const arAB = bolagsform === 'Aktiebolag'
      const arEF = bolagsform === 'Enskild näringsidkare'
      const klientFy = fiscalYears.filter(f => f.company_id === u.klient_bolag_id)
        .filter(f => f.end_date >= BAKGRANS && f.end_date <= HORISONT && f.end_date >= u.startdatum)

      const laggTill = (periodStart: string, periodSlut: string, deadline: string | null) => {
        rader.push({
          uppdrag_id: u.id, byra_bolag_id: u.byra_bolag_id, klient_bolag_id: u.klient_bolag_id,
          uppdragsansvarig_anvandare_id: u.uppdragsansvarig_anvandare_id,
          period_start: periodStart, period_slut: periodSlut,
          etikett: periodEtikett(u.uppdragstyp, periodStart, periodSlut),
          ordinarie_forfallodatum: deadline,
        })
      }

      try {
        if (u.uppdragstyp === 'momsdeklaration') {
          const frekvens = momsperiodTillFrekvens(momsperiod)
          if (!frekvens) { hoppade.push({ uppdrag: u.id, orsak: 'momsperiod saknas eller "Redovisar ej moms" — sätt momsperiod i klientbolagets inställningar' }); continue }
          if (frekvens === 'ar') {
            // Helårsmoms följer beskattningsåret: AB = räkenskapsåret, EF = kalenderåret.
            if (arEF) {
              const regel = valjRegel(regler, 'momsdeklaration', bolagsform, 'ar')
              if (!regel) { hoppade.push({ uppdrag: u.id, orsak: 'regel saknas: helårsmoms EF' }); continue }
              for (const ar of kalenderar(u.startdatum, BAKGRANS, HORISONT)) {
                laggTill(`${ar}-01-01`, `${ar}-12-31`,
                  beraknaDeadline(regel.parametrar, { beskattningsar: ar, byraanstand: u.byraanstand_aktiv }))
              }
            } else {
              const regel = valjRegel(regler, 'momsdeklaration', bolagsform, 'ar')
              if (!regel) { hoppade.push({ uppdrag: u.id, orsak: 'regel saknas: helårsmoms AB' }); continue }
              for (const fy of klientFy) {
                laggTill(fy.start_date, fy.end_date, beraknaDeadline(regel.parametrar, { bokslutsdatum: fy.end_date }))
              }
            }
          } else {
            const regel = valjRegel(regler, 'momsdeklaration', bolagsform, frekvens)
            if (!regel) { hoppade.push({ uppdrag: u.id, orsak: `regel saknas: moms ${frekvens}` }); continue }
            const frekvensPerioder = perioder(frekvens === 'kvartal' ? 'kvartal' : 'manad', u.startdatum, HORISONT)
            for (const p of frekvensPerioder) laggTill(p.start, p.slut, beraknaDeadline(regel.parametrar, { periodSlut: p.slut }))
          }
        } else if (u.uppdragstyp === 'lon_agi') {
          const regel = valjRegel(regler, 'lon_agi', bolagsform, null)
          if (!regel) { hoppade.push({ uppdrag: u.id, orsak: 'regel saknas: AGI' }); continue }
          for (const p of perioder('manad', u.startdatum, HORISONT)) {
            laggTill(p.start, p.slut, beraknaDeadline(regel.parametrar, { periodSlut: p.slut }))
          }
        } else if (u.uppdragstyp === 'lopande_bokforing') {
          // Takt 'dag' (kontantregeln) bevakas inte per dag i v1 — genereras som månad.
          const takt = u.bokforingstakt === 'kvartal' ? 'kvartal' : u.bokforingstakt === 'rakenskapsar' ? 'rakenskapsar' : 'manad'
          const regel = valjRegel(regler, 'lopande_bokforing', bolagsform, takt)
          if (!regel) { hoppade.push({ uppdrag: u.id, orsak: `regel saknas: löpande ${takt}` }); continue }
          if (takt === 'rakenskapsar') {
            for (const fy of klientFy) laggTill(fy.start_date, fy.end_date, beraknaDeadline(regel.parametrar, { periodSlut: fy.end_date }))
          } else {
            for (const p of perioder(takt, u.startdatum, HORISONT)) {
              laggTill(p.start, p.slut, beraknaDeadline(regel.parametrar, { periodSlut: p.slut }))
            }
          }
        } else if (u.uppdragstyp === 'arsredovisning') {
          if (!arAB) { hoppade.push({ uppdrag: u.id, orsak: 'årsredovisning kräver aktiebolag' }); continue }
          const regel = valjRegel(regler, 'arsredovisning', bolagsform, null)
          if (!regel) { hoppade.push({ uppdrag: u.id, orsak: 'regel saknas: årsredovisning' }); continue }
          for (const fy of klientFy) laggTill(fy.start_date, fy.end_date, beraknaDeadline(regel.parametrar, { bokslutsdatum: fy.end_date }))
        } else if (u.uppdragstyp === 'inkomstdeklaration') {
          if (arEF) {
            const regel = valjRegel(regler, 'inkomstdeklaration', bolagsform, null)
            if (!regel) { hoppade.push({ uppdrag: u.id, orsak: 'regel saknas: INK1' }); continue }
            for (const ar of kalenderar(u.startdatum, BAKGRANS, HORISONT)) {
              laggTill(`${ar}-01-01`, `${ar}-12-31`,
                beraknaDeadline(regel.parametrar, { beskattningsar: ar, byraanstand: u.byraanstand_aktiv }))
            }
          } else if (arAB) {
            const regel = valjRegel(regler, 'inkomstdeklaration', bolagsform, null)
            if (!regel) { hoppade.push({ uppdrag: u.id, orsak: 'regel saknas: INK2' }); continue }
            for (const fy of klientFy) {
              // Årligt verifierad referenstabell vinner över den beräknade regeln.
              const bokAr = Number(fy.end_date.slice(0, 4))
              const bokManad = Number(fy.end_date.slice(5, 7))
              const rad = ink2Tabell.find(t => t.bokslutsar === bokAr && bokManad >= t.bokslutsmanad_fran && bokManad <= t.bokslutsmanad_till)
              laggTill(fy.start_date, fy.end_date, rad ? rad.deadline : beraknaDeadline(regel.parametrar, { bokslutsdatum: fy.end_date }))
            }
          } else {
            hoppade.push({ uppdrag: u.id, orsak: `inkomstdeklaration stöds inte för bolagsformen ${bolagsform || '(saknas)'} i v1` })
          }
        } else if (u.uppdragstyp === 'bokslut') {
          if (u.revisionsplikt) {
            // Deadline sätts först när revisionsstart matats in (trigger räknar om) —
            // uppgiften skapas med null-datum och visas som "Väntar på revisionsdatum".
            for (const fy of klientFy) laggTill(fy.start_date, fy.end_date, null)
          } else {
            const regel = valjRegel(regler, 'bokslut', bolagsform, 'internt_sla')
            if (!regel) { hoppade.push({ uppdrag: u.id, orsak: 'regel saknas: bokslut SLA' }); continue }
            // Bas = ÅR-deadline (AB) respektive INK1-deadline (EF).
            for (const fy of klientFy) {
              let bas: string | null = null
              if (arAB) {
                const arRegel = valjRegel(regler, 'arsredovisning', 'Aktiebolag', null)
                bas = arRegel ? beraknaDeadline(arRegel.parametrar, { bokslutsdatum: fy.end_date }) : null
              } else if (arEF) {
                const inkRegel = valjRegel(regler, 'inkomstdeklaration', 'Enskild näringsidkare', null)
                bas = inkRegel ? beraknaDeadline(inkRegel.parametrar, { beskattningsar: Number(fy.end_date.slice(0, 4)), byraanstand: u.byraanstand_aktiv }) : null
              }
              if (!bas) { hoppade.push({ uppdrag: u.id, orsak: 'bokslut: basdeadline (ÅR/INK1) kunde inte beräknas' }); continue }
              laggTill(fy.start_date, fy.end_date, beraknaDeadline(regel.parametrar, { basDeadline: bas }))
            }
          }
        }
      } catch (e) {
        hoppade.push({ uppdrag: u.id, orsak: String((e as Error)?.message || e) })
      }
    }

    // ── Upsert (dubbelgenerering omöjlig; befintliga rader skrivs aldrig över) ──
    let skapade = 0
    for (let i = 0; i < rader.length; i += 500) {
      const bit = rader.slice(i, i + 500)
      const { error, count } = await admin.from('uppdragsuppgift')
        .upsert(bit, { onConflict: 'uppdrag_id,period_start', ignoreDuplicates: true, count: 'exact' })
      if (error) throw error
      skapade += count ?? 0
    }

    // ── Försenad-markering (mot justerat datum när det finns) ──
    const { data: forsenade, error: fel } = await admin.rpc('byrastod_markera_forsenade')
    if (fel) throw fel

    return json({ ok: true, kandidater: rader.length, nya_uppgifter: skapade, nya_forsenade: forsenade, hoppade })
  } catch (e) {
    console.error('byrastod-jobb:', e)
    return json({ error: String((e as Error)?.message || e) }, 500)
  }
})

// Kalenderår (EF: beskattningsår = kalenderår) vars slut ligger i fönstret.
function kalenderar(startdatum: string, bakgrans: string, horisont: string): number[] {
  const ut: number[] = []
  for (let ar = Number(bakgrans.slice(0, 4)) - 1; ar <= Number(horisont.slice(0, 4)); ar++) {
    const slut = `${ar}-12-31`
    if (slut >= bakgrans && slut <= horisont && slut >= startdatum) ut.push(ar)
  }
  return ut
}
