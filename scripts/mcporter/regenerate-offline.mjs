// Re-render through MCPorter's template and bundler APIs, never edit bundle text.
import fs from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
const root = process.env.MCPORTER_TOOLING_ROOT;
const load = (name) => import(pathToFileURL(path.join(root, 'dist', name)));
const { parse } = await import(pathToFileURL(path.join(root, '../acorn/dist/acorn.mjs')));
const [source, target] = process.argv.slice(2);
if (!source || !target) throw new Error('Usage: regenerate-offline.mjs SOURCE TARGET');
const text = await fs.readFile(source, 'utf8');
const metadata = JSON.parse(execFileSync(process.execPath, [source, '__mcporter_inspect'], { encoding: 'utf8' }));
const ast = parse(text, { ecmaVersion: 'latest', sourceType: 'script', allowHashBang: true });
const objects = [];
function literal(node) {
  if (node.type === 'Literal') return node.value;
  if (node.type === 'TemplateLiteral' && node.expressions.length === 0) return node.quasis[0].value.cooked;
  if (node.type === 'UnaryExpression' && node.operator === '-') return -literal(node.argument);
  if (node.type === 'ObjectExpression') return Object.fromEntries(node.properties.map(p => [p.key.name ?? p.key.value, literal(p.value)]));
  if (node.type === 'ArrayExpression') return node.elements.map(literal);
  if (node.type === 'UnaryExpression' && node.operator === '!') return !literal(node.argument);
  throw new Error('Not a static literal');
}
function visit(node) {
  if (!node || typeof node !== 'object') return;
  if (node.type === 'ObjectExpression') {
    try { objects.push(literal(node)); } catch { /* Ignore executable objects. */ }
  }
  for (const value of Object.values(node)) {
    if (Array.isArray(value)) value.forEach(visit);
    else if (value && typeof value === 'object') visit(value);
  }
}
visit(ast);
const maps = objects.filter(o => Object.keys(o).length > 20 && Object.values(o).every(v => v?.type === 'object' && v.properties));
if (maps.length !== 1) throw new Error(`Expected one embedded schema map, found ${maps.length}`);
const tools = Object.entries(maps[0]).map(([name, inputSchema]) => {
  const help = objects.find(o => o.name === name.replaceAll('_', '-') && typeof o.description === 'string');
  if (!help) throw new Error(`Missing embedded tool description: ${name}`);
  return { name, inputSchema, description: help.description };
});
const { buildToolMetadataList } = await load('cli/generate/tools.js');
const { writeTemplate } = await load('cli/generate/template.js');
const { bundleOutput } = await load('cli/generate/artifacts.js');
const template = path.resolve(`${target}.ts`);
const cleanMetadata = { ...metadata, artifact: { path: '', kind: 'template' }, invocation: { ...metadata.invocation } };
delete cleanMetadata.invocation.bundle;
try {
  await writeTemplate({ outputPath: template, runtimeScriptPath: path.resolve(target), runtimeKind: 'node', timeoutMs: metadata.invocation.timeoutMs, definition: metadata.server.definition, serverName: metadata.server.name, tools: buildToolMetadataList(tools), generator: metadata.generator, metadata: cleanMetadata });
  await bundleOutput({ sourcePath: template, runtimeKind: 'node', targetPath: path.resolve(target), minify: true, bundler: 'rolldown' });
  console.log(`Regenerated ${tools.length} embedded tools offline at ${target}`);
} finally {
  await fs.rm(template, { force: true });
}
