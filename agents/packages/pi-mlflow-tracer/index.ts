import * as mlflow from "mlflow-tracing";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

let currentAgentSpan: mlflow.LiveSpan | undefined;
let llmSpan: mlflow.LiveSpan | undefined;
const toolSpans = new Map<string, mlflow.LiveSpan>();

function installCloudflareAccessHeaders(trackingUri: string): () => void {
  const clientId = process.env.CF_ACCESS_CLIENT_ID;
  const clientSecret = process.env.CF_ACCESS_CLIENT_SECRET;

  if (
    !clientId
    || !clientSecret
    || clientId.startsWith("REPLACE_WITH_")
    || clientSecret.startsWith("REPLACE_WITH_")
  ) {
    throw new Error("valid CF_ACCESS_CLIENT_ID and CF_ACCESS_CLIENT_SECRET values are required");
  }

  const trackingOrigin = new URL(trackingUri).origin;
  const originalFetch = globalThis.fetch;
  const authenticatedFetch: typeof fetch = async (input, init) => {
    const requestUrl = input instanceof Request ? input.url : input.toString();
    if (new URL(requestUrl).origin !== trackingOrigin) {
      return originalFetch(input, init);
    }

    const headers = new Headers(input instanceof Request ? input.headers : init?.headers);
    headers.set("CF-Access-Client-Id", clientId);
    headers.set("CF-Access-Client-Secret", clientSecret);
    return originalFetch(input, { ...init, headers });
  };

  globalThis.fetch = authenticatedFetch;
  return () => {
    if (globalThis.fetch === authenticatedFetch) {
      globalThis.fetch = originalFetch;
    }
  };
}

export default async function (pi: ExtensionAPI) {
  const trackingUri = process.env.MLFLOW_TRACKING_URI;
  const experimentName = process.env.MLFLOW_EXPERIMENT_NAME;

  if (!trackingUri || (!process.env.MLFLOW_EXPERIMENT_ID && !experimentName)) {
    return;
  }

  let removeCloudflareAccessHeaders: (() => void) | undefined;
  try {
    removeCloudflareAccessHeaders = installCloudflareAccessHeaders(trackingUri);
  } catch (error) {
    console.error(`MLflow tracer disabled: ${error}`);
    return;
  }

  let experimentId = process.env.MLFLOW_EXPERIMENT_ID;
  if (!experimentId && experimentName) {
    try {
      const response = await fetch(
        `${trackingUri}/api/2.0/mlflow/experiments/get-by-name?experiment_name=${encodeURIComponent(experimentName)}`,
      );
      if (response.ok) {
        const data = (await response.json()) as { experiment?: { experiment_id?: string } };
        experimentId = data.experiment?.experiment_id;
      }

      if (!experimentId) {
        const response = await fetch(`${trackingUri}/api/2.0/mlflow/experiments/create`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ name: experimentName }),
        });
        if (!response.ok) {
          throw new Error(`failed to create experiment: ${response.status} ${response.statusText}`);
        }
        const data = (await response.json()) as { experiment_id: string };
        experimentId = data.experiment_id;
      }
    } catch (error) {
      removeCloudflareAccessHeaders();
      console.error(`MLflow tracer disabled: ${error}`);
      return;
    }
  }

  if (!experimentId) {
    removeCloudflareAccessHeaders();
    console.error("MLflow tracer disabled: no experiment ID resolved");
    return;
  }

  mlflow.init({ trackingUri, experimentId });

  pi.on("agent_start", () => {
    currentAgentSpan = mlflow.startSpan({ name: "pi_agent_run", spanType: mlflow.SpanType.AGENT });
  });

  pi.on("agent_end", async (event) => {
    if (currentAgentSpan) {
      currentAgentSpan.end({ outputs: event.messages });
      currentAgentSpan = undefined;
    }
    await mlflow.flushTraces();
  });

  pi.on("before_provider_request", (event) => {
    llmSpan = mlflow.startSpan({
      name: "llm_call",
      spanType: mlflow.SpanType.LLM,
      parent: currentAgentSpan,
      inputs: event.payload,
    });
  });

  pi.on("after_provider_response", (event) => {
    if (llmSpan) {
      llmSpan.end({
        status: event.status === 200 ? mlflow.SpanStatusCode.OK : mlflow.SpanStatusCode.ERROR,
      });
      llmSpan = undefined;
    }
  });

  pi.on("tool_execution_start", (event) => {
    const span = mlflow.startSpan({
      name: `tool_${event.toolName}`,
      spanType: mlflow.SpanType.TOOL,
      parent: currentAgentSpan,
      inputs: event.args,
    });
    toolSpans.set(event.toolCallId, span);
  });

  pi.on("tool_execution_end", (event) => {
    const span = toolSpans.get(event.toolCallId);
    if (span) {
      span.end({
        outputs: event.result,
        status: event.isError ? mlflow.SpanStatusCode.ERROR : mlflow.SpanStatusCode.OK,
      });
      toolSpans.delete(event.toolCallId);
    }
  });

  pi.on("session_shutdown", async () => {
    await mlflow.flushTraces();
    removeCloudflareAccessHeaders?.();
  });
}
