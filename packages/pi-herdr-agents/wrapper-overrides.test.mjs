import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { execFileSync } from 'node:child_process';
import { launchPiSubagent } from './pi-extension/subagents/launch.ts';

test('fresh, isolated, fork and resumed children preserve wrapper overrides', async () => {
  const root = mkdtempSync(join(tmpdir(), 'herdr-overrides-'));
  const saved = { ...process.env };
  try {
    const config = join(root, "config with 'quotes");
    const sessions = join(root, "sessions with 'quotes");
    const project = join(root, 'project');
    mkdirSync(project);
    mkdirSync(sessions);
    const parentFile = join(sessions, 'parent.jsonl');
    writeFileSync(parentFile, JSON.stringify({ type: 'session', version: 3, id: 'parent', cwd: project }) + '\n');
    process.env.PI_CODING_AGENT_DIR = config;
    process.env.PI_CODING_AGENT_SESSION_DIR = sessions;
    process.env.NIX_AGENTS_PROFILE = 'work-browser';
    let command;
    const operations = {
      createPane: () => 'pane-test',
      createWorktree: () => { throw new Error('unexpected worktree'); },
      waitForShellReady: async () => {},
      runScript: (_surface, value, options) => { command = value; return options.scriptPath; },
      closePane: () => {},
    };
    const request = {
      kind: 'fresh', name: 'Probe', task: 'Check routing',
      parent: { cwd: project, sessionFile: parentFile, sessionId: 'parent', sessionDir: sessions, agentDir: config },
      runtimePlan: { model: 'fake/model', thinking: 'low' },
      behavior: { deniedTools: [], autoExit: true, interactive: false, sessionMode: 'standalone' },
    };
    function checkLaunch(expectedConfig, sessionFile) {
      // Execute the generated shell command with a Pi probe, not a model call.
      const output = execFileSync('bash', ['-c', `pi() { printf '%s\\n' "$PI_CODING_AGENT_DIR" "$PI_CODING_AGENT_SESSION_DIR" "$NIX_AGENTS_PROFILE" "$@"; }; ${command}`], {
        env: { PATH: process.env.PATH, HOME: root }, encoding: 'utf8',
      }).split('\n');
      assert.deepEqual(output.slice(0, 3), [expectedConfig, sessions, 'work-browser']);
      assert.equal(output[output.indexOf('--session') + 1], sessionFile);
    }
    const fresh = await launchPiSubagent(request, operations);
    assert.equal(dirname(fresh.sessionFile), sessions);
    checkLaunch(config, fresh.sessionFile);
    const isolated = join(project, '.pi', 'agent');
    mkdirSync(isolated, { recursive: true });
    const fork = await launchPiSubagent({ ...request, cwd: project, fork: true }, operations);
    assert.equal(dirname(fork.sessionFile), sessions);
    checkLaunch(isolated, fork.sessionFile);
    writeFileSync(fresh.sessionFile, JSON.stringify({ type: 'session', version: 3, id: 'child', cwd: project }) + '\n');
    await launchPiSubagent({ kind: 'resume', name: 'Resume', sessionFile: fresh.sessionFile, parent: request.parent }, operations);
    checkLaunch(config, fresh.sessionFile);
    delete process.env.PI_CODING_AGENT_SESSION_DIR;
    delete process.env.NIX_AGENTS_PROFILE;
    const defaults = await launchPiSubagent(request, operations);
    assert.ok(defaults.sessionFile.startsWith(join(config, 'sessions')));
    assert.ok(!command.includes('PI_CODING_AGENT_SESSION_DIR='));
  } finally {
    for (const key of ['PI_CODING_AGENT_DIR', 'PI_CODING_AGENT_SESSION_DIR', 'NIX_AGENTS_PROFILE']) {
      if (saved[key] === undefined) delete process.env[key]; else process.env[key] = saved[key];
    }
    rmSync(root, { recursive: true, force: true });
  }
});
