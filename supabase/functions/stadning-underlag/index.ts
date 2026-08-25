// Edge Function: stadning-underlag
// Raderar ett bolags underlagsfiler FYSISKT ur storage (bucket "underlag") via
// Storage-API:t — direkta SQL-deleter mot storage.objects lämnar filkropparna
// föräldralösa i backenden, därför denna väg. Används vid bolagsradering
// (operatörsstädning) — anropas från databasen med intern nyckel
// (interna_nycklar, namn 'stadning_underlag'; kivra-/cron-mönstret: nyckeln
// genereras i databasen och lämnar den aldrig).
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { 'Content-Type': 'application/json' } })
const UUID_PREFIX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i

Deno.serve(async (req) => {
  try {
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const db = createClient(SUPABASE_URL, SERVICE)

    const { data: nyckel } = await db.from('interna_nycklar').select('varde').eq('namn', 'stadning_underlag').maybeSingle()
    if (!nyckel?.varde || req.headers.get('x-stadning-secret') !== nyckel.varde) {
      return json({ error: 'Ogiltig nyckel' }, 403)
    }

    // prefixer = bolags-id:n (mappnamn i bucketen). Endast rena uuid:n accepteras
    // — skyddar mot att en felformad prefix sveper hela bucketen.
    const { prefixer } = await req.json()
    if (!Array.isArray(prefixer) || prefixer.length === 0) return json({ error: 'prefixer saknas' }, 400)
    const ogiltiga = prefixer.filter((p: unknown) => !UUID_PREFIX.test(String(p)))
    if (ogiltiga.length > 0) return json({ error: 'Ogiltiga prefix: ' + ogiltiga.join(', ') }, 400)

    // Tömmer en mapp rekursivt: list() är inte rekursiv — undermappar (id=null,
    // t.ex. logotyp/) töms först, sedan raderas mappens egna filer. Pagineras
    // tills mappen är tom (list ger max 1000 per anrop).
    // deno-lint-ignore no-explicit-any
    async function tomMapp(klient: any, mapp: string): Promise<{ raderade: number; fel: string[] }> {
      let raderade = 0
      const fel: string[] = []
      for (let varv = 0; varv < 50; varv++) {
        const { data: poster, error: listFel } = await klient.storage.from('underlag').list(mapp, { limit: 1000 })
        if (listFel) { fel.push(`${mapp}: ${listFel.message}`); break }
        for (const undermapp of (poster || []).filter((p: { id?: string }) => !p.id)) {
          const res = await tomMapp(klient, `${mapp}/${undermapp.name}`)
          raderade += res.raderade
          fel.push(...res.fel)
        }
        const filer = (poster || []).filter((p: { id?: string }) => p.id).map((p: { name: string }) => `${mapp}/${p.name}`)
        if (filer.length === 0) break
        const { error: remFel } = await klient.storage.from('underlag').remove(filer)
        if (remFel) { fel.push(`${mapp}: ${remFel.message}`); break }
        raderade += filer.length
      }
      return { raderade, fel }
    }

    let raderade = 0
    const fel: string[] = []
    for (const prefix of prefixer as string[]) {
      const res = await tomMapp(db, prefix)
      raderade += res.raderade
      fel.push(...res.fel)
    }
    return json({ ok: fel.length === 0, raderade, fel })
  } catch (err) {
    console.error(`stadning-underlag: ${String((err as Error)?.message || err)}`)
    return json({ error: String((err as Error)?.message || err) }, 400)
  }
})
