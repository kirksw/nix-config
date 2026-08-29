import assert from "node:assert/strict";
import test from "node:test";

import litellmProvider, { credentialsAvailable, toProviderModels } from "./index.ts";

const CREDENTIAL_NAMES = [
  "LITELLM_API_KEY",
  "LITELLM_CF_ACCESS_CLIENT_ID",
  "LITELLM_CF_ACCESS_CLIENT_SECRET",
];

async function withCredentialEnvironment(values, callback) {
  const original = Object.fromEntries(CREDENTIAL_NAMES.map((name) => [name, process.env[name]]));
  Object.assign(process.env, values);
  try {
    await callback();
  } finally {
    for (const name of CREDENTIAL_NAMES) {
      if (original[name] === undefined) delete process.env[name];
      else process.env[name] = original[name];
    }
  }
}

test("credentialsAvailable rejects missing and replacement values", () => {
  assert.equal(credentialsAvailable({}), false);
  assert.equal(credentialsAvailable({
    LITELLM_API_KEY: "  REPLACE_WITH_LITELLM_API_KEY  ",
    LITELLM_CF_ACCESS_CLIENT_ID: "client-id",
    LITELLM_CF_ACCESS_CLIENT_SECRET: "client-secret",
  }), false);
  assert.equal(credentialsAvailable({
    LITELLM_API_KEY: "api-key",
    LITELLM_CF_ACCESS_CLIENT_ID: "client-id",
    LITELLM_CF_ACCESS_CLIENT_SECRET: "client-secret",
  }), true);
});

test("toProviderModels maps metadata, defaults, and duplicate IDs", () => {
  assert.deepEqual(toProviderModels([
    {
      model_name: "minimax-m3",
      model_info: {
        max_input_tokens: 1_000_000,
        max_output_tokens: 128_000,
        supports_reasoning: true,
        supports_vision: true,
      },
    },
    { id: "openai/gpt-5.6-sol" },
    { id: "openai/gpt-5.6-sol", model_info: { max_input_tokens: 272_000, max_tokens: 32_768 } },
    {},
  ]), [
    {
      id: "minimax-m3",
      name: "minimax-m3",
      reasoning: true,
      input: ["text", "image"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 1_000_000,
      maxTokens: 128_000,
    },
    {
      id: "openai/gpt-5.6-sol",
      name: "openai/gpt-5.6-sol",
      reasoning: true,
      input: ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 272_000,
      maxTokens: 32_768,
    },
  ]);
});

test("placeholder credentials disable discovery", async () => {
  const originalFetch = globalThis.fetch;
  let fetchCount = 0;
  globalThis.fetch = async () => {
    fetchCount += 1;
    throw new Error("unexpected fetch");
  };

  try {
    await withCredentialEnvironment({
      LITELLM_API_KEY: "REPLACE_WITH_LITELLM_API_KEY",
      LITELLM_CF_ACCESS_CLIENT_ID: "client-id",
      LITELLM_CF_ACCESS_CLIENT_SECRET: "client-secret",
    }, async () => {
      await litellmProvider({ registerProvider: () => assert.fail("unexpected registration") });
    });
    assert.equal(fetchCount, 0);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("discovery falls back to models and registers dual authentication", async () => {
  const originalFetch = globalThis.fetch;
  const requests = [];
  let registration;
  globalThis.fetch = async (url, init) => {
    requests.push({ url, init });
    if (String(url).endsWith("/model/info")) {
      return new Response("forbidden", { status: 403, statusText: "Forbidden" });
    }
    return Response.json({ data: [{ id: "gpt-5.6-sol" }] });
  };

  try {
    await withCredentialEnvironment({
      LITELLM_API_KEY: "api-key",
      LITELLM_CF_ACCESS_CLIENT_ID: "client-id",
      LITELLM_CF_ACCESS_CLIENT_SECRET: "client-secret",
    }, async () => {
      await litellmProvider({
        registerProvider(name, config) {
          registration = { name, config };
        },
      });
    });
  } finally {
    globalThis.fetch = originalFetch;
  }

  assert.equal(requests.length, 2);
  assert.equal(requests[0].init.headers.get("Authorization"), "Bearer api-key");
  assert.equal(requests[0].init.headers.get("CF-Access-Client-Id"), "client-id");
  assert.equal(requests[0].init.headers.get("CF-Access-Client-Secret"), "client-secret");
  assert.equal(registration.name, "litellm");
  assert.equal(registration.config.apiKey, "$LITELLM_API_KEY");
  assert.equal(registration.config.headers["CF-Access-Client-Id"], "$LITELLM_CF_ACCESS_CLIENT_ID");
  assert.equal(registration.config.headers["CF-Access-Client-Secret"], "$LITELLM_CF_ACCESS_CLIENT_SECRET");
  assert.equal(registration.config.models[0].id, "gpt-5.6-sol");
  assert.equal(registration.config.models[0].reasoning, true);
});
