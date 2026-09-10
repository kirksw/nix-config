import assert from 'node:assert/strict';
import http from 'node:http';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { pathToFileURL } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
import os from 'node:os';
import test from 'node:test';
const root = process.env.MCPORTER_TOOLING_ROOT;
if (!root) throw new Error('Run through run.sh --script');
const load = (name) => import(pathToFileURL(path.join(root, 'dist', name)));
const exec = promisify(execFile);
const sessions = new Set();
let sequence = 0, deletes = 0, gets = 0, mode = 'success';
const server = http.createServer(async (req, res) => {
  if (req.method === 'DELETE') {
    deletes++;
    if (mode === 'delete-timeout') return;
    if (mode === 'delete-failure') { res.writeHead(500).end('delete failed'); return; }
    sessions.delete(req.headers['mcp-session-id']);
    res.writeHead(200).end();
    return;
  }
  if (req.method === 'GET') { gets++; res.writeHead(405).end(); return; }
  let body = '';
  for await (const chunk of req) body += chunk;
  const message = JSON.parse(body);
  if (message.method === 'initialize' && (mode === 'capacity' || sessions.size >= 20)) {
    res.writeHead(503).end('maximum HTTP MCP session capacity'); return;
  }
  if (message.id === undefined) { res.writeHead(202).end(); return; }
  let result;
  if (message.method === 'initialize') {
    const id = String(++sequence);
    sessions.add(id);
    res.setHeader('mcp-session-id', id);
    result = { protocolVersion: '2025-03-26', capabilities: { tools: {} }, serverInfo: { name: 'cleanup-fixture', version: '1' } };
  } else if (message.method === 'tools/list') {
    result = { tools: [{ name: 'ping', description: 'Fixture ping', inputSchema: { type: 'object', properties: {} } }] };
  } else {
    result = { content: [{ type: 'text', text: 'pong' }], ...(mode === 'tool-error' ? { isError: true } : {}) };
  }
  const response = mode === 'rpc-error' && message.method === 'tools/call'
    ? { jsonrpc: '2.0', id: message.id, error: { code: -32603, message: 'primary tool failure' } }
    : { jsonrpc: '2.0', id: message.id, result };
  res.setHeader('content-type', 'application/json');
  res.end(JSON.stringify(response));
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const url = `http://127.0.0.1:${server.address().port}/mcp`;
const definition = { name: 'fixture', description: 'Cleanup fixture', command: { kind: 'http', url: new URL(url) } };
const temporary = await fs.mkdtemp(path.join(os.tmpdir(), 'mcporter-tests-'));
const bundle = path.join(temporary, 'fixture.cjs');
const { generateCli } = await load('generate-cli.js');
const { createRuntime } = await load('runtime.js');
try {
  await test('generator discovery deletes its session', async () => {
    await generateCli({ serverRef: JSON.stringify(definition), runtime: 'node', bundle, minify: true });
    assert.equal(sessions.size, 0);
    assert.equal(deletes, 1);
  });
  await test('25 independent generated CLI processes never exhaust 20-session capacity', async () => {
    for (let i = 0; i < 25; i++) {
      const { stdout } = await exec(process.execPath, [bundle, 'ping'], { timeout: 10000 });
      assert.match(stdout, /pong/);
      assert.equal(sessions.size, 0);
    }
    assert.equal(deletes, 26);
  });
  for (const scenario of ['tool-error', 'rpc-error', 'delete-failure', 'delete-timeout']) {
    await test(`${scenario}: bounded cleanup preserves operation result`, async () => {
      mode = scenario;
      const before = deletes;
      const start = Date.now();
      try {
        const result = await exec(process.execPath, [bundle, 'ping'], { timeout: 10000 });
        if (scenario === 'rpc-error') assert.fail('Expected primary RPC error');
        assert.match(result.stdout, /pong/);
      } catch (error) {
        if (scenario !== 'rpc-error') throw error;
        assert.match(error.stderr, /primary tool failure/);
      }
      assert.equal(deletes, before + 1);
      assert.ok(Date.now() - start < 5000);
      if (scenario.endsWith('error')) assert.equal(sessions.size, 0);
      // The fixture deliberately rejects DELETE; local closure cannot reclaim it.
      sessions.clear();
      mode = 'success';
    });
  }
  await test('HTTP503 remains primary error without SSE fallback', async () => {
    mode = 'capacity';
    const before = gets;
    await assert.rejects(exec(process.execPath, [bundle, 'ping'], { timeout: 10000 }), error => {
      assert.match(error.stderr, /maximum HTTP MCP session capacity/);
      assert.doesNotMatch(error.stderr, /Falling back to SSE/);
      return true;
    });
    assert.equal(gets, before);
    mode = 'success';
  });
  await test('runtime.close is idempotent', async () => {
    const runtime = await createRuntime({ servers: [definition] });
    await runtime.callTool('fixture', 'ping');
    const before = deletes;
    await runtime.close();
    await runtime.close();
    assert.equal(deletes, before + 1);
    assert.equal(sessions.size, 0);
  });
  await test('termination precedes both closes and failure never skips closure', async () => {
    const { RuntimeConnectionCache } = await load('runtime/connection-cache.js');
    for (const outcome of ['success', 'throw', 'hang']) {
      const events = [];
      const logger = { warn() {} };
      const cache = new RuntimeConnectionCache(new Map(), { logger });
      const transport = {
        async terminateSession() {
          events.push('delete');
          if (outcome === 'throw') throw new Error('delete');
          if (outcome === 'hang') await new Promise(() => {});
        },
        async close() { events.push('transport.close'); },
      };
      await cache.closeContext({ transport, client: { async close() { events.push('client.close'); throw new Error('close'); } } });
      assert.deepEqual(events, ['delete', 'client.close', 'transport.close']);
    }
  });
} finally {
  server.closeAllConnections();
  await new Promise(resolve => server.close(resolve));
  await fs.rm(temporary, { recursive: true, force: true });
}
