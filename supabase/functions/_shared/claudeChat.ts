// Delad Claude-chatt-transport (Anthropic Messages API) för BokPilots AI-textflöden.
// Ersatte Gemini 2026-07-22 (Gemini-avvecklingen): assistent-ai, ekonomichef-ai, granska-ai,
// bokfor-ai, manadskontroll-ai, bokslut-ai, annual-report-ai, support-ai (Haiku 4.5) och
// robo-bp-chat (Sonnet 5). Samma transportprincip som claudeOcr.ts: rå HTTP (ingen SDK,
// håller edge-bundeln fri från beroenden) och structured outputs via output_config.format.
//
// Dataminimering (policy): endast den kontext respektive flöde redan skickade till AI
// (sammanställningar, kontrollpunkter, handboksutdrag) går till Anthropic – inga secrets,
// ingen rå persondata utöver flödets egen kontext.

export const CLAUDE_HAIKU = 'claude-haiku-4-5'
export const CLAUDE_SONNET = 'claude-sonnet-5'

// Structured outputs kräver additionalProperties:false på VARJE objekt. Till skillnad från
// claudeOcr:s toClaudeSchema rör vi INTE required-listorna – chattflödenas scheman har få
// valfria fält (långt under gränsen 24) och valfriheten är semantiskt viktig (t.ex. tomt
// konteringsforslag vid ren frågeställning).
export function withStrictObjects(node: unknown): unknown {
  if (Array.isArray(node)) return node.map(withStrictObjects)
  if (node && typeof node === 'object') {
    const out: Record<string, unknown> = {}
    for (const [k, v] of Object.entries(node as Record<string, unknown>)) out[k] = withStrictObjects(v)
    if ((out as { type?: string }).type === 'object' && out.properties && typeof out.properties === 'object') {
      out.additionalProperties = false
    }
    return out
  }
  return node
}

// status 0 = nätverksfel/timeout. transient styr anroparens val av 503 (försök igen) vs 502.
export class ClaudeChatError extends Error {
  status: number
  transient: boolean
  constructor(message: string, status: number) {
    super(message)
    this.status = status
    this.transient = status === 0 || status === 429 || status === 500 || status === 503 || status === 529
  }
}

// Ett chattanrop → svarstext (garanterat schemaenlig JSON-text när jsonSchema anges).
// Omförsök: max 2 försök totalt, endast vid transienta fel (429/5xx/nätverk), kort backoff.
export async function claudeChat(
  { apiKey, model, prompt, system = null, jsonSchema = null, maxTokens = 2048, temperature = 0.2, timeoutMs = 60000 }:
  { apiKey: string; model: string; prompt: string; system?: string | null; jsonSchema?: unknown | null; maxTokens?: number; temperature?: number; timeoutMs?: number },
): Promise<{ text: string; model: string; inputTokens: number | null; outputTokens: number | null }> {
  const body = JSON.stringify({
    model,
    max_tokens: maxTokens,
    temperature,
    ...(system ? { system } : {}),
    ...(jsonSchema ? { output_config: { format: { type: 'json_schema', schema: withStrictObjects(jsonSchema) } } } : {}),
    messages: [{ role: 'user', content: [{ type: 'text', text: prompt }] }],
  })

  let lastErr: ClaudeChatError = new ClaudeChatError('Claude svarade inte', 0)
  for (let attempt = 0; attempt < 2; attempt++) {
    if (attempt > 0) await new Promise((r) => setTimeout(r, 800))

    const ctrl = new AbortController()
    const timer = setTimeout(() => ctrl.abort(), timeoutMs)
    let resp: Response
    try {
      resp = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-api-key': apiKey, 'anthropic-version': '2023-06-01' },
        body,
        signal: ctrl.signal,
      })
    } catch (e) {
      lastErr = new ClaudeChatError(`Claude nätverksfel/timeout: ${String((e as Error)?.message || e)}`, 0)
      continue
    } finally {
      clearTimeout(timer)
    }

    if (!resp.ok) {
      const t = (await resp.text().catch(() => '')).slice(0, 600)
      lastErr = new ClaudeChatError(`Claude-fel (${resp.status}): ${t.slice(0, 200)}`, resp.status)
      if (!lastErr.transient) break
      continue
    }

    const cj = await resp.json().catch(() => null)
    if (cj?.stop_reason === 'refusal') throw new ClaudeChatError('Claude avböjde begäran (refusal)', 400)
    const textBlock = Array.isArray(cj?.content) ? cj.content.find((b: { type?: string }) => b?.type === 'text') : null
    if (!textBlock?.text) throw new ClaudeChatError(`Tomt svar från Claude (stop_reason: ${cj?.stop_reason || 'okänd'})`, 502)
    if (cj.stop_reason === 'max_tokens') throw new ClaudeChatError('Claude-svaret kapades (max_tokens) – ofullständigt', 502)

    return {
      text: textBlock.text as string,
      model,
      inputTokens: cj?.usage?.input_tokens ?? null,
      outputTokens: cj?.usage?.output_tokens ?? null,
    }
  }
  throw lastErr
}
