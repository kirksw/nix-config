import type { ExtensionAPI, ProviderModelConfig } from "@earendil-works/pi-coding-agent";

const DEFAULT_BASE_URL = "https://litellm.cntd.io/v1";
const PLACEHOLDER_PREFIX = "REPLACE_WITH_";

interface LiteLlmModelInfo {
  context_window?: number | null;
  max_input_tokens?: number | null;
  max_output_tokens?: number | null;
  max_tokens?: number | null;
  supports_reasoning?: boolean | null;
  supports_vision?: boolean | null;
}

interface LiteLlmModelEntry {
  id?: string;
  model_name?: string;
  model_info?: LiteLlmModelInfo | null;
}

export interface LiteLlmProviderModel {
  id: string;
  name: string;
  reasoning: boolean;
  thinkingLevelMap?: ProviderModelConfig["thinkingLevelMap"];
  input: Array<"text" | "image">;
  cost: {
    input: number;
    output: number;
    cacheRead: number;
    cacheWrite: number;
  };
  contextWindow: number;
  maxTokens: number;
}

function isUsableCredential(value: string | undefined): value is string {
  const credential = value?.trim();
  return Boolean(credential && !credential.startsWith(PLACEHOLDER_PREFIX));
}

export function credentialsAvailable(env: Record<string, string | undefined>): boolean {
  return isUsableCredential(env.LITELLM_API_KEY)
    && isUsableCredential(env.LITELLM_CF_ACCESS_CLIENT_ID)
    && isUsableCredential(env.LITELLM_CF_ACCESS_CLIENT_SECRET);
}

function positiveInteger(value: number | null | undefined, fallback: number): number {
  return typeof value === "number" && Number.isInteger(value) && value > 0 ? value : fallback;
}

function isAstra(id: string): boolean {
  return /^(?:openai\/)?gpt-6-astra$/i.test(id);
}

function inferReasoning(id: string, metadata: boolean | null | undefined): boolean {
  if (typeof metadata === "boolean") return metadata;
  return isAstra(id) || /^(?:(?:openai\/)?gpt-5|minimax-m|glm-)/i.test(id);
}

export function toProviderModels(entries: LiteLlmModelEntry[]): LiteLlmProviderModel[] {
  const models = new Map<string, LiteLlmProviderModel>();

  for (const entry of entries) {
    const id = entry.model_name ?? entry.id;
    if (!id) continue;

    const info = entry.model_info ?? {};
    const reasoning = inferReasoning(id, info.supports_reasoning);
    models.set(id, {
      id,
      name: id,
      reasoning,
      ...(reasoning && isAstra(id) ? {
        // Astra is always-thinking; max is Responses-only, not Chat Completions.
        thinkingLevelMap: {
          off: null,
          minimal: null,
          low: "low",
          medium: "medium",
          high: "high",
          xhigh: "xhigh",
          max: null,
        },
      } : {}),
      input: info.supports_vision ? ["text", "image"] : ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      // The gateway exposes total context separately from input/output limits.
      contextWindow: positiveInteger(info.context_window, positiveInteger(info.max_input_tokens, 128_000)),
      maxTokens: positiveInteger(info.max_output_tokens ?? info.max_tokens, 16_384),
    });
  }

  return [...models.values()].sort((left, right) => left.id.localeCompare(right.id));
}

async function fetchWithTimeout(url: string, headers: Headers): Promise<Response> {
  return fetch(url, { headers, signal: AbortSignal.timeout(10_000) });
}

async function fetchModelEntries(baseUrl: string, headers: Headers): Promise<LiteLlmModelEntry[]> {
  const infoResponse = await fetchWithTimeout(`${baseUrl}/model/info`, headers);
  if (infoResponse.ok) {
    const payload = (await infoResponse.json()) as { data?: LiteLlmModelEntry[] };
    return payload.data ?? [];
  }

  const modelsResponse = await fetchWithTimeout(`${baseUrl}/models`, headers);
  if (!modelsResponse.ok) {
    throw new Error(`model discovery failed: ${modelsResponse.status} ${modelsResponse.statusText}`);
  }

  const payload = (await modelsResponse.json()) as { data?: LiteLlmModelEntry[] };
  return payload.data ?? [];
}

export default async function litellmProvider(pi: ExtensionAPI): Promise<void> {
  if (!credentialsAvailable(process.env)) return;

  const baseUrl = (process.env.LITELLM_BASE_URL ?? DEFAULT_BASE_URL).replace(/\/$/, "");
  const headers = new Headers({
    Authorization: `Bearer ${process.env.LITELLM_API_KEY}`,
    "CF-Access-Client-Id": process.env.LITELLM_CF_ACCESS_CLIENT_ID!,
    "CF-Access-Client-Secret": process.env.LITELLM_CF_ACCESS_CLIENT_SECRET!,
  });

  try {
    const models = toProviderModels(await fetchModelEntries(baseUrl, headers));
    if (models.length === 0) {
      console.error("LiteLLM provider disabled: model discovery returned no models");
      return;
    }

    pi.registerProvider("litellm", {
      name: "LiteLLM",
      baseUrl,
      api: "openai-completions",
      apiKey: "$LITELLM_API_KEY",
      authHeader: true,
      headers: {
        "CF-Access-Client-Id": "$LITELLM_CF_ACCESS_CLIENT_ID",
        "CF-Access-Client-Secret": "$LITELLM_CF_ACCESS_CLIENT_SECRET",
      },
      models,
    });
  } catch (error) {
    console.error(`LiteLLM provider disabled: ${error}`);
  }
}
