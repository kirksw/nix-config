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
    { id: "openai/gpt-6-astra" },
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
    {
      id: "openai/gpt-6-astra",
      name: "openai/gpt-6-astra",
      reasoning: true,
      thinkingLevelMap: {
        off: null,
        minimal: null,
        low: "low",
        medium: "medium",
        high: "high",
        xhigh: "xhigh",
        max: null,
      },
      input: ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: 128_000,
      maxTokens: 16_384,
    },
  ]);
});

for (const id of ["gpt-6-astra", "openai/gpt-6-astra", "OPENAI/GPT-6-ASTRA"]) {
  test(`${id} reasoning respects metadata and maps only Chat Completions levels`, () => {
    for (const supports_reasoning of [undefined, null, true, false]) {
      const [model] = toProviderModels([{ id, model_info: { supports_reasoning } }]);
      assert.equal(model.reasoning, supports_reasoning !== false);
      if (supports_reasoning === false) {
        assert.equal(Object.hasOwn(model, "thinkingLevelMap"), false);
      } else {
        assert.deepEqual(model.thinkingLevelMap, {
          off: null,
          minimal: null,
          low: "low",
          medium: "medium",
          high: "high",
          xhigh: "xhigh",
          max: null,
        });
      }
    }
  });
}

test("other models retain inference and never receive Astra's map", () => {
  const cases = [
    ["gpt-5.6-sol", true],
    ["openai/gpt-5.6-sol", true],
    ["gpt-5.6-terra", true],
    ["openai/gpt-5.6-luna", true],
    ["minimax-m3", true],
    ["glm-5.2", true],
    ["gpt-4o", false],
    ["unknown", false],
    ["gpt-6", false],
    ["openai/gpt-6", false],
    ["gpt-6-other", false],
    ["openai/gpt-6-other", false],
    ["gpt-6-astra-preview", false],
    ["openai/gpt-6-astra-preview", false],
    ["gpt-6-astral", false],
    ["other/gpt-6-astra", false],
  ];
  for (const [id, inferred] of cases) {
    for (const supports_reasoning of [undefined, null, true, false]) {
      const [model] = toProviderModels([{ id, model_info: { supports_reasoning } }]);
      assert.deepEqual(model, {
        id,
        name: id,
        reasoning: supports_reasoning ?? inferred,
        input: ["text"],
        cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
        contextWindow: 128_000,
        maxTokens: 16_384,
      }, `${id}: supports_reasoning=${supports_reasoning}`);
    }
  }
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
    return Response.json({ data: [
      { id: "gpt-5.6-sol" },
      { id: "gpt-6-astra" },
      { id: "openai/gpt-6-astra" },
    ] });
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
  assert.equal(registration.config.api, "openai-completions");
  assert.equal(registration.config.apiKey, "$LITELLM_API_KEY");
  assert.equal(registration.config.headers["CF-Access-Client-Id"], "$LITELLM_CF_ACCESS_CLIENT_ID");
  assert.equal(registration.config.headers["CF-Access-Client-Secret"], "$LITELLM_CF_ACCESS_CLIENT_SECRET");
  assert.equal(registration.config.models[0].id, "gpt-5.6-sol");
  assert.equal(registration.config.models[0].reasoning, true);
  assert.equal(Object.hasOwn(registration.config.models[0], "thinkingLevelMap"), false);
  for (const model of registration.config.models.slice(1)) {
    assert.equal(model.reasoning, true);
    assert.equal(model.thinkingLevelMap.xhigh, "xhigh");
    assert.equal(model.thinkingLevelMap.max, null);
  }
});

for (const supports_reasoning of [true, false]) {
  test(`model/info registers Astra with explicit reasoning=${supports_reasoning}`, async () => {
    const originalFetch = globalThis.fetch;
    const entries = ["gpt-6-astra", "openai/gpt-6-astra"].map((model_name) => ({
      model_name,
      model_info: { supports_reasoning },
    }));
    let registration;
    let fetchCount = 0;
    globalThis.fetch = async (url) => {
      fetchCount += 1;
      assert.ok(String(url).endsWith("/model/info"));
      return Response.json({ data: entries });
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
    assert.equal(fetchCount, 1);
    assert.equal(registration.name, "litellm");
    assert.equal(registration.config.api, "openai-completions");
    assert.deepEqual(registration.config.models, toProviderModels(entries));
    for (const model of registration.config.models) {
      assert.equal(model.reasoning, supports_reasoning);
      assert.equal(Object.hasOwn(model, "thinkingLevelMap"), supports_reasoning);
    }
  });
}
