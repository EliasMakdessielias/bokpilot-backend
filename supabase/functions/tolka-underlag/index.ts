// Edge Function: tolka-underlag
// Tar emot ett document_id, hämtar filen, skickar den till Claude (Haiku) för
// fakturatolkning och returnerar strukturerad data + förslag på kontering.
//
// MODELLBYTE 2026-07-08: Claude Haiku 4.5 ersatte Gemini som extraktionsmodell efter
// skuggjämförelse på 24 dokument (ai_bokforing_logg): balanserad kontering 83 % mot 67 %,
// 0 mot 7 leverantörsfel (Gemini satte bl.a. kundens namn som leverantör), bättre
// konfidenskalibrering. Gemini är BORTKOPPLAD ur extraktionen (Elias beslut 2026-07-08);
// HEIC/HEIF kan inte tolkas (Claude saknar stöd) och ger ett åtgärdbart svenskt fel.
//
// QUOTA-/JOBBHANTERING (skydd mot retry-storm):
// - ai_claim_job: cooldown (document/user/company), rate limit per user/company och
//   idempotens (dubbelklick återanvänder pågående jobb i stället för att starta nytt).
// - Vid 429 från Claude: dokumentet markeras quota_limited (INTE failed) + cooldown 60 s,
//   och exakt felkropp loggas i ai_error_log (provider/modell/status/body/request id).
// - Klienten får retry_after_seconds och visar en countdown.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { getCompanyServiceState, isServiceLocked, SERVICE_PAUSED_MESSAGE } from '../_shared/serviceState.ts'
import { extractPdfTextLayer, normalizeOcrText, OCR_TEXT_MIN_LEN } from '../_shared/ocr.ts'
import { runClaudeOcr, extractionLogRow, isClaudeOcrable, CLAUDE_OCR_MODEL } from '../_shared/claudeOcr.ts'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const COOLDOWN_SECONDS = 60
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } })

function blobToBase64(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf)
  let binary = ''
  const chunk = 0x8000
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk))
  }
  return btoa(binary)
}

// Klassificera ett OCR-fel -> {errorCode, severity}. Inga dokumentdata/secrets exponeras.
function classifyOcrError(msg: string): { errorCode: string; severity: string } {
  const m = (msg || '').toLowerCase()
  if (/anthropic_api_key|api_key saknas|api-key saknas/.test(m)) return { errorCode: 'config_missing_anthropic_key', severity: 'critical' }
  if (/\b429\b|rate limit|quota|resource_exhausted|overloaded/.test(m)) return { errorCode: 'ai_rate_limit', severity: 'warning' }
  if (/timeout|timed out|deadline|aborted/.test(m)) return { errorCode: 'ocr_timeout', severity: 'error' }
  if (/ladda ner|download|storage|hittades inte|extract/.test(m)) return { errorCode: 'file_extraction_failure', severity: 'error' }
  if (/json|parse|tomt svar|unexpected|malformed|kapades/.test(m)) return { errorCode: 'malformed_model_response', severity: 'error' }
  if (/claude|anthropic|api/.test(m)) return { errorCode: 'ai_api_failure', severity: 'error' }
  return { errorCode: 'ocr_unhandled', severity: 'error' }
}
async function reportOcrError(admin: any, errorCode: string, message: string, severity: string, metadata: Record<string, unknown> = {}, companyId: string | null = null) {
  try {
    if (!admin) return
    await admin.rpc('report_system_error', {
      p_component: 'tolka-underlag', p_message: String(message || '').slice(0, 300), p_company_id: companyId,
      p_severity: severity, p_error_code: errorCode, p_metadata: metadata, p_occurred_at: new Date().toISOString(),
    })
  } catch { /* noop */ }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors })

  let admin: any = null
  let companyId: string | null = null
  try {
    const ANTHROPIC_API_KEY = Deno.env.get('ANTHROPIC_API_KEY')
    if (!ANTHROPIC_API_KEY) throw new Error('ANTHROPIC_API_KEY saknas i Edge Function-secrets')

    const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
    const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

    const { document_id } = await req.json()
    if (!document_id) throw new Error('document_id saknas')

    const authHeader = req.headers.get('Authorization') || ''
    const bearer = authHeader.toLowerCase().startsWith('bearer ') ? authHeader.slice(7).trim() : ''
    const userClient = createClient(SUPABASE_URL, ANON_KEY, { global: { headers: { Authorization: authHeader } } })
    const { data: { user }, error: userErr } = await userClient.auth.getUser(bearer || undefined)
    if (userErr || !user) {
      return new Response(JSON.stringify({ error: 'Ej inloggad' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } })
    }

    admin = createClient(SUPABASE_URL, SERVICE_KEY)

    const { data: doc, error: docErr } = await admin.from('documents').select('*').eq('id', document_id).single()
    if (docErr || !doc) throw new Error('Underlaget hittades inte')
    companyId = doc.company_id

    const { data: member } = await admin.from('user_companies')
      .select('id').eq('user_id', user.id).eq('company_id', doc.company_id).maybeSingle()
    if (!member) return new Response(JSON.stringify({ error: 'Ingen åtkomst' }), { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } })

    const serviceState = await getCompanyServiceState(admin, companyId)
    if (isServiceLocked(serviceState)) {
      return json({ error: SERVICE_PAUSED_MESSAGE, code: 'service_locked', state: serviceState }, 403)
    }

    // Claim: cooldown + rate limit + idempotens. Förhindrar retry-storm och dubbla jobb.
    const { data: claim, error: claimErr } = await admin.rpc('ai_claim_job', {
      p_document_id: document_id, p_company_id: companyId, p_user_id: user.id,
    })
    if (claimErr) throw new Error('Kunde inte starta tolkningen: ' + (claimErr.message || 'okänt fel'))
    if (!claim?.allowed) {
      if (claim?.reason === 'not_found') throw new Error('Underlaget hittades inte')
      if (claim?.reason === 'in_progress') {
        return json({ ok: false, code: 'in_progress', job_id: claim.job_id, ai_status: 'processing',
          message: 'AI-tolkning pågår redan för detta underlag.' }, 200)
      }
      // cooldown eller rate_limited
      const sec = Number(claim?.retry_after_seconds) || COOLDOWN_SECONDS
      return json({ ok: false, code: 'quota_cooldown', reason: claim?.reason, scope: claim?.scope,
        retry_after_seconds: sec, ai_status: 'quota_limited',
        error: `AI-kvoten är tillfälligt slut. Försök igen om ${sec} sekunder.` }, 200)
    }

    // Hämta fil + kontoplan och kör OCR. All quota-/felhantering nedan.
    try {
      const { data: fileData, error: dlErr } = await admin.storage.from('underlag').download(doc.storage_path)
      if (dlErr || !fileData) throw new Error('Kunde inte ladda ner filen')
      const buf = await fileData.arrayBuffer()
      const base64 = blobToBase64(buf)
      const mimeType = doc.mime_type || 'application/pdf'
      const sourceType: 'pdf' | 'image' = mimeType.toLowerCase().includes('pdf') ? 'pdf' : 'image'

      // Claude läser PDF/JPG/PNG/GIF/WEBP men INTE HEIC/HEIF. Ge ett åtgärdbart fel i
      // stället för ett generiskt AI-fel – dokumentet är inte trasigt, formatet stöds inte.
      if (!isClaudeOcrable(mimeType)) {
        await admin.rpc('ai_finish_job', { p_document_id: document_id, p_company_id: companyId, p_status: 'failed', p_user_id: user.id, p_error: `unsupported_format: ${mimeType}` })
        return json({ ok: false, code: 'unsupported_format', ai_status: 'failed',
          error: 'Filformatet kan inte tolkas automatiskt (HEIC/HEIF stöds inte ännu). Spara om bilden som JPG eller PDF och ladda upp den igen.' }, 200)
      }

      // OCR-textlager (endast PDF): extrahera + normalisera BEST-EFFORT. Misslyckas det, eller är
      // texten för kort (scannad PDF utan textlager), fortsätter tolkningen exakt som förut via
      // bildanalys (vision-fallback). Rå text loggas aldrig – endast metadata i _meta/audit.
      let ocrText: string | null = null
      let pageCount: number | null = null
      if (sourceType === 'pdf') {
        const layer = await extractPdfTextLayer(new Uint8Array(buf))
        if (layer) {
          pageCount = layer.pageCount
          const t = normalizeOcrText(layer.text)
          if (t.length >= OCR_TEXT_MIN_LEN) ocrText = t
        }
      }

      const { data: accounts } = await admin.from('accounts')
        .select('account_nr, name').eq('company_id', doc.company_id).eq('is_active', true).order('account_nr')
      const kontoplan = (accounts || []).map((a: any) => `${a.account_nr} ${a.name}`).join('\n')

      const result = await runClaudeOcr({ apiKey: ANTHROPIC_API_KEY, base64, mimeType, kontoplan, ocrText, pageCount, sourceType })

      // Jämförelse-/auditlogg: primärmodellens tolkning loggas i ai_bokforing_logg
      // (kind='extraktion', model-kolumnen, applied=true). Får aldrig stoppa tolkningen.
      try {
        // OBS: supabase-js kastar INTE vid insert-fel – kontrollera error explicit.
        const g = await admin.from('ai_bokforing_logg').insert(extractionLogRow(result, companyId!, document_id, CLAUDE_OCR_MODEL, true))
        if (g?.error) console.error(`tolka-underlag: extraktionslogg misslyckades: ${g.error.message}`)
      } catch (e) {
        console.error(`tolka-underlag: extraktionslogg misslyckades: ${String((e as Error)?.message || e)}`)
      }

      await admin.rpc('ai_finish_job', { p_document_id: document_id, p_company_id: companyId, p_status: 'completed', p_user_id: user.id })
      try {
        await admin.rpc('record_ai_usage', { p_company_id: companyId, p_kind: 'ocr' })
        await admin.rpc('enforce_plan_limit', { p_company_id: companyId, p_metric: 'ai' })
      } catch { /* soft – får ej stoppa tolkningen */ }
      await admin.rpc('record_worker_health', { p_component: 'tolka-underlag', p_ok: true, p_error: null })
      return json({ ok: true, result, ai_status: 'completed' })
    } catch (ocrErr) {
      const e = ocrErr as Error & { quota?: boolean; status?: number; model?: string; body?: string; requestId?: string | null; calls?: number }
      const msg = String(e?.message || e)
      const quota = !!e?.quota || /\b429\b|resource_exhausted|quota|rate.?limit/i.test(msg)

      // Spara exakt felkropp för felsökning (provider/modell/status/body/request id).
      try {
        await admin.rpc('log_ai_error', {
          p_provider: 'anthropic', p_model: e?.model || CLAUDE_OCR_MODEL, p_status_code: e?.status ?? null,
          p_error_code: quota ? 'RESOURCE_EXHAUSTED' : null, p_error_body: String(e?.body || msg).slice(0, 8000),
          p_request_id: e?.requestId || null, p_attempts: e?.calls ?? null, p_kind: 'ocr',
          p_user_id: user.id, p_company_id: companyId, p_document_id: document_id,
        })
      } catch { /* loggning får ej stoppa svaret */ }

      if (quota) {
        // 429: quota_limited (INTE failed) + cooldown. Dokumentet kan tolkas igen när kvoten är tillbaka.
        await admin.rpc('ai_finish_job', { p_document_id: document_id, p_company_id: companyId, p_status: 'quota_limited', p_cooldown_seconds: COOLDOWN_SECONDS, p_user_id: user.id, p_error: 'ai_quota' })
        await reportOcrError(admin, 'ai_rate_limit', msg, 'warning', { model: e?.model, status: e?.status, requestId: e?.requestId }, companyId)
        return json({ ok: false, code: 'quota_cooldown', retry_after_seconds: COOLDOWN_SECONDS, ai_status: 'quota_limited',
          error: `AI-kvoten är tillfälligt slut. Försök igen om ${COOLDOWN_SECONDS} sekunder.` }, 200)
      }

      // Annat fel (serverfel/timeout/malformed): failed. Meddelandet antyder ALDRIG att bilden är fel.
      await admin.rpc('ai_finish_job', { p_document_id: document_id, p_company_id: companyId, p_status: 'failed', p_user_id: user.id, p_error: msg.slice(0, 500) })
      const { errorCode, severity } = classifyOcrError(msg)
      await reportOcrError(admin, errorCode, msg, severity, { model: e?.model, status: e?.status }, companyId)
      await admin.rpc('record_worker_health', { p_component: 'tolka-underlag', p_ok: false, p_error: errorCode })
      return json({ ok: false, code: 'ai_failed', ai_status: 'failed',
        error: 'AI-tjänsten kunde inte tolka underlaget just nu. Försök igen om en stund.' }, 200)
    }
  } catch (err) {
    const msg = String((err as Error)?.message || err)
    const clientErr = /document_id saknas|hittades inte|ingen åtkomst|ej inloggad/i.test(msg)
    if (!clientErr) {
      const { errorCode, severity } = classifyOcrError(msg)
      await reportOcrError(admin, errorCode, msg, severity, {}, companyId)
    }
    return json({ error: msg }, 400)
  }
})
