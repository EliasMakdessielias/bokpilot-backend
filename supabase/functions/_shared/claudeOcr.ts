// Claude-extraktion (Anthropic API) – PRIMÄR extraktionsmodell sedan 2026-07-08.
// Startade som skuggspår till Gemini enligt briefingens beslut 2 ("migrera på data,
// inte känsla"); efter jämförelse på 24 dokument (balans 83 % mot 67 %, 0 mot 7
// leverantörsfel) kopplades Gemini bort ur extraktionen och Claude tog över.
//
// Prompten (buildOcrPrompt) och schemat (OCR_SCHEMA) delas via _shared/ocr.ts.
// Transporten är Claudes Messages API med structured outputs (output_config.format =
// json_schema, kräver additionalProperties:false på alla objekt) och underlag som
// document-/image-block. Rå HTTP (inte SDK) medvetet: håller edge-bundeln fri från
// extra beroenden.
//
// Dataminimering (policy): endast underlagets base64 + kontoplan + ev. OCR-textlager skickas
// till Anthropic – aldrig KYC-data, historik eller kunddata utöver själva underlaget.
import { buildOcrPrompt, OCR_SCHEMA, OCR_PROMPT_VERSION, OCR_TEXT_MIN_LEN, OCR_TEXT_MAX_LEN } from './ocr.ts'

export const CLAUDE_OCR_MODEL = 'claude-haiku-4-5'

// MIME-typer Claude kan läsa. OBS: heic/heif stöds INTE – anroparen gate:ar med
// isClaudeOcrable() och ger användaren ett åtgärdbart fel (tolka-underlag) eller
// hoppar över tolkningen (inbound-email).
const CLAUDE_PDF = 'application/pdf'
const CLAUDE_IMAGES = ['image/jpeg', 'image/png', 'image/gif', 'image/webp']
export function isClaudeOcrable(mimeType: string): boolean {
  const ct = String(mimeType || '').toLowerCase()
  return ct === CLAUDE_PDF || CLAUDE_IMAGES.includes(ct)
}

// Structured outputs kräver (1) additionalProperties:false på VARJE objekt och
// (2) max 24 VALFRIA fält totalt. OCR_SCHEMA har ~45 valfria → vi gör ALLA fält
// obligatoriska i Claude-varianten (0 valfria). Modellen fyller då tomma strängar/
// nollor där data saknas – harmlöst för jämförelsen och deterministiskt.
// Härleds ur OCR_SCHEMA så att prompt och schema alltid delar EN källa.
function toClaudeSchema(node: unknown): unknown {
  if (Array.isArray(node)) return node.map(toClaudeSchema)
  if (node && typeof node === 'object') {
    const out: Record<string, unknown> = {}
    for (const [k, v] of Object.entries(node as Record<string, unknown>)) out[k] = toClaudeSchema(v)
    if ((out as { type?: string }).type === 'object' && out.properties && typeof out.properties === 'object') {
      out.additionalProperties = false
      out.required = Object.keys(out.properties as Record<string, unknown>)
    }
    return out
  }
  return node
}
const CLAUDE_OCR_SCHEMA = toClaudeSchema(OCR_SCHEMA)

export async function runClaudeOcr(
  // 90s timeout: första anropet med nytt schema betalar engångskompilering (cachas 24h),
  // och PDF-vision på flera sidor tar tid.
  { apiKey, base64, mimeType, kontoplan, timeoutMs = 90000, ocrText = null, pageCount = null, sourceType = null }:
  { apiKey: string; base64: string; mimeType: string; kontoplan: string; timeoutMs?: number; ocrText?: string | null; pageCount?: number | null; sourceType?: 'pdf' | 'image' | null },
): Promise<any> {
  if (!isClaudeOcrable(mimeType)) {
    const err = new Error(`Claude stöder inte mimetypen ${mimeType}`) as Error & { unsupported?: boolean }
    err.unsupported = true
    throw err
  }

  // Promptupplägg: prompt + (ev.) OCR-textlager som primär källa + underlaget.
  let text = buildOcrPrompt(kontoplan)
  if (ocrText && ocrText.trim().length >= OCR_TEXT_MIN_LEN) {
    text += '\n\nOCR-TEXT (extraherad ur dokumentets textlager):\n'
      + 'Använd texten nedan som PRIMÄR källa för datum, totalsumma, moms, OCR-nummer, fakturanummer, org.nr, '
      + 'leverantör, betalningsuppgifter och rader. Använd bilden/PDF:en som stöd när texten är otydlig eller '
      + 'saknar layoutinformation. Om OCR-texten och bilden motsäger varandra: välj det mest sannolika värdet '
      + 'och sätt LÄGRE falt_sakerhet (under 0.8) för de berörda fälten.\n"""\n'
      + ocrText.slice(0, OCR_TEXT_MAX_LEN) + '\n"""'
  }

  const underlagsBlock = mimeType.toLowerCase() === CLAUDE_PDF
    ? { type: 'document', source: { type: 'base64', media_type: CLAUDE_PDF, data: base64 } }
    : { type: 'image', source: { type: 'base64', media_type: mimeType.toLowerCase(), data: base64 } }

  const body = JSON.stringify({
    model: CLAUDE_OCR_MODEL,
    max_tokens: 8000,
    output_config: { format: { type: 'json_schema', schema: CLAUDE_OCR_SCHEMA } },
    messages: [{ role: 'user', content: [underlagsBlock, { type: 'text', text }] }],
  })

  const ctrl = new AbortController()
  const timer = setTimeout(() => ctrl.abort(), timeoutMs)
  const t0 = Date.now()
  let resp: Response
  try {
    resp = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-api-key': apiKey, 'anthropic-version': '2023-06-01' },
      body,
      signal: ctrl.signal,
    })
  } catch (e) {
    const err = new Error(`Claude nätverksfel/timeout: ${String((e as Error)?.message || e)}`) as Error & { status?: number }
    err.status = 0
    throw err
  } finally {
    clearTimeout(timer)
  }

  if (!resp.ok) {
    const bodyText = (await resp.text().catch(() => '')).slice(0, 800)
    const err = new Error(`Claude-fel (${resp.status}): ${bodyText.slice(0, 200)}`) as Error & { status?: number; body?: string; requestId?: string | null }
    err.status = resp.status
    err.body = bodyText
    err.requestId = resp.headers.get('request-id')
    throw err
  }

  const cj = await resp.json().catch(() => null)
  if (cj?.stop_reason === 'refusal') throw new Error('Claude avböjde begäran (refusal)')
  const textBlock = Array.isArray(cj?.content) ? cj.content.find((b: any) => b?.type === 'text') : null
  if (!textBlock?.text) throw new Error(`Tomt svar från Claude (stop_reason: ${cj?.stop_reason || 'okänd'})`)
  if (cj.stop_reason === 'max_tokens') throw new Error('Claude-svaret kapades (max_tokens) – ofullständig JSON')

  const parsed = JSON.parse(textBlock.text)
  parsed._meta = {
    model: CLAUDE_OCR_MODEL,
    promptVersion: OCR_PROMPT_VERSION,
    extractedAt: new Date().toISOString(),
    hasOcrLayer: !!(ocrText && ocrText.trim().length >= OCR_TEXT_MIN_LEN),
    ocrLength: ocrText ? Math.min(ocrText.length, OCR_TEXT_MAX_LEN) : 0,
    pageCount: Number.isFinite(pageCount as number) ? pageCount : null,
    sourceType: sourceType || (mimeType.includes('pdf') ? 'pdf' : 'image'),
    durationMs: Date.now() - t0,
    inputTokens: cj?.usage?.input_tokens ?? null,
    outputTokens: cj?.usage?.output_tokens ?? null,
  }
  return parsed
}

// ── Jämförelse-/auditlogg ──
// Sammanfattar ett extraktionsresultat till en rad i ai_bokforing_logg så att modeller
// kan jämföras med SQL: konfidens = LÄGSTA falt_sakerhet bland kritiska fält (svagaste
// länken avgör granskningsbehovet), balans = summa debet == summa kredit (på öret).
// applied=true när resultatet faktiskt visats/använts (primär tolkning), false för skuggkörningar.
export function extractionLogRow(result: any, companyId: string, documentId: string, model: string, applied = false) {
  const fs = result?.falt_sakerhet || {}
  const vardena = Object.values(fs).filter((v) => typeof v === 'number') as number[]
  const konfidens = vardena.length ? Math.min(...vardena) : null
  const rader = Array.isArray(result?.konteringsrader) ? result.konteringsrader : []
  const oren = (n: unknown) => Math.round((Number(n) || 0) * 100)
  const sumD = rader.reduce((s: number, r: any) => s + oren(r?.debet), 0)
  const sumK = rader.reduce((s: number, r: any) => s + oren(r?.kredit), 0)
  const balans = rader.length > 0 && sumD === sumK
  return {
    company_id: companyId,
    document_id: documentId,
    kind: 'extraktion',
    svar: `typ=${result?.typ || '?'} lev=${String(result?.leverantor || '?').slice(0, 40)} belopp=${result?.belopp_inkl_moms ?? '?'} balans=${balans ? 'ok' : 'OBALANS'} rader=${rader.length} tid=${result?._meta?.durationMs ?? '?'}ms`,
    konteringsforslag: rader,
    konfidens,
    kraver_manuell_granskning: konfidens === null || konfidens < 0.8 || !balans,
    regelverk_version: OCR_PROMPT_VERSION,
    model,
    applied,
  }
}
