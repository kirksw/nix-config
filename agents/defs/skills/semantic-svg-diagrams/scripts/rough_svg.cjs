#!/usr/bin/env node
'use strict';

// Generate geometry only: callers retain ownership of text and semantic wrappers.
const fs = require('node:fs');
const { createHash } = require('node:crypto');
const rough = require('roughjs/bundled/rough.cjs.js');

const arities = { rectangle: 4, ellipse: 4, circle: 3, line: 4, path: 1 };
const optionNames = new Set([
  'stroke', 'strokeWidth', 'fill', 'fillStyle', 'fillWeight', 'hachureAngle',
  'hachureGap', 'bowing', 'curveStepCount', 'disableMultiStroke',
  'disableMultiStrokeFill', 'preserveVertices',
]);
const fillStyles = new Set(['hachure', 'solid', 'zigzag', 'cross-hatch', 'dots', 'dashed', 'zigzag-line']);
const escape = (s) => String(s).replace(/[&<>"']/g, (c) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;',
})[c]);
function requireThat(ok, message) { if (!ok) throw new Error(message); }

function render(input) {
  requireThat(input && typeof input === 'object' && !Array.isArray(input), 'Expected an object');
  const { level = 2, seed = 1, shapes } = input;
  requireThat([0, 1, 2].includes(level), 'level must be 0, 1, or 2');
  requireThat(Number.isInteger(seed) && seed > 0 && seed <= 2147483647, 'seed must be a positive 31-bit integer');
  requireThat(Array.isArray(shapes) && shapes.length > 0, 'shapes must be a nonempty array');
  const ids = new Set();
  const generator = rough.generator();
  const rendered = shapes.map((shape) => {
    requireThat(shape && typeof shape === 'object', 'Invalid shape');
    const { id, type, args, options = {} } = shape;
    requireThat(typeof id === 'string' && /^[A-Za-z_][A-Za-z0-9_.-]*$/.test(id) && !ids.has(id), 'Shape IDs must be valid and unique');
    ids.add(id);
    requireThat(Object.hasOwn(arities, type) && Array.isArray(args) && args.length === arities[type], `Invalid geometry for ${id}`);
    if (type === 'path') {
      requireThat(typeof args[0] === 'string' && /^[Mm]/.test(args[0]) && !/[^MmZzLlHhVvCcSsQqTtAa0-9eE+.,\s-]/.test(args[0]), `Invalid path for ${id}`);
    } else {
      requireThat(args.every(Number.isFinite), `Coordinates must be finite for ${id}`);
      if (['rectangle', 'ellipse', 'circle'].includes(type)) {
        requireThat(args.slice(2).every((n) => n > 0), `Dimensions must be positive for ${id}`);
      }
    }
    requireThat(options && typeof options === 'object' && !Array.isArray(options), `Invalid options for ${id}`);
    for (const [key, value] of Object.entries(options)) {
      requireThat(optionNames.has(key), `Unsupported option: ${key}`);
      if (['stroke', 'fill'].includes(key)) {
        requireThat(typeof value === 'string' && /^(?:none|#[0-9a-fA-F]{3,8}|[a-zA-Z]+)$/.test(value), `Use a literal color for ${key}`);
      } else if (key === 'fillStyle') {
        requireThat(fillStyles.has(value), 'Unsupported fillStyle');
      } else if (['disableMultiStroke', 'disableMultiStrokeFill', 'preserveVertices'].includes(key)) {
        requireThat(typeof value === 'boolean', `${key} must be boolean`);
      } else {
        requireThat(Number.isFinite(value), `${key} must be finite`);
        if (key !== 'hachureAngle') requireThat(value >= 0, `${key} must be nonnegative`);
        if (['hachureGap', 'curveStepCount'].includes(key)) requireThat(value > 0, `${key} must be positive`);
      }
    }
    // Stable per-shape seeds keep existing geometry unchanged when shapes are reordered.
    const shapeSeed = createHash('sha256').update(`${seed}:${id}`).digest().readUInt32BE(0) % 2147483646 + 1;
    const settings = { stroke: '#111', strokeWidth: 2, fillStyle: 'hachure', ...options,
      roughness: level, seed: shapeSeed };
    if (level === 0) {
      settings.disableMultiStroke = true;
      settings.disableMultiStrokeFill = true;
    }
    const drawable = generator[type](...args, settings);
    const paths = generator.toPaths(drawable).map((p) => {
      requireThat(!/NaN|Infinity/.test(p.d), `Nonfinite generated geometry for ${id}`);
      return `<path d="${escape(p.d)}" stroke="${escape(p.stroke || 'none')}" stroke-width="${escape(p.strokeWidth || 0)}" fill="${escape(p.fill || 'none')}" stroke-linecap="round" stroke-linejoin="round"/>`;
    }).join('\n');
    return `<g data-rough-shape="${escape(id)}">\n${paths}\n</g>`;
  });
  return `<g xmlns="http://www.w3.org/2000/svg" data-roughness="${level}" data-rough-seed="${seed}">\n${rendered.join('\n')}\n</g>\n`;
}

if (require.main === module) {
  try {
    const [, , input, output] = process.argv;
    requireThat(input && output && process.argv.length === 4, 'Usage: node rough_svg.cjs shapes.json fragment.svg');
    requireThat(require('node:path').resolve(input) !== require('node:path').resolve(output), 'Input and output must differ');
    const svg = render(JSON.parse(fs.readFileSync(input, 'utf8')));
    fs.writeFileSync(output, svg);
    console.log(`Generated ${output}; embed inside semantic wrappers, validate, render, and inspect.`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
module.exports = { render };
