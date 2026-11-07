'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { render } = require('./rough_svg.cjs');
const shape = { id: 'example', type: 'ellipse', args: [180, 140, 280, 220],
  options: { stroke: '#de3535', fill: '#ffbbbb', hachureGap: 12 } };

test('omitted level defaults to 2; cleaner explicit levels remain available', () => {
  assert.equal(render({ shapes: [shape] }), render({ level: 2, shapes: [shape] }));
  assert.notEqual(render({ shapes: [shape] }), render({ level: 0, shapes: [shape] }));
  assert.notEqual(render({ shapes: [shape] }), render({ level: 1, shapes: [shape] }));
});

test('all levels are deterministic, distinct, and static', () => {
  const outputs = [0, 1, 2].map((level) => {
    const input = { level, seed: 42, shapes: [shape] };
    const output = render(input);
    assert.equal(output, render(input));
    assert.match(output, /<path d="/);
    assert.doesNotMatch(output, /<script|<image|<style|href=|NaN|Infinity/);
    return output;
  });
  assert.equal(new Set(outputs).size, 3);
  assert.notEqual(outputs[0].split('<path')[1], outputs[1].split('<path')[1]);
});

test('shape seeds do not depend on order; changing seed changes paths', () => {
  const other = { id: 'box', type: 'rectangle', args: [10, 20, 200, 100] };
  const get = (shapes) => render({ shapes }).match(/<g data-rough-shape="example">[\s\S]*?<\/g>/)[0];
  assert.equal(get([shape, other]), get([other, shape]));
  assert.notEqual(render({ seed: 1, shapes: [shape] }), render({ seed: 2, shapes: [shape] }));
});

test('supported geometry and solid fills', () => {
  for (const [type, args] of Object.entries({ rectangle: [0, 0, 100, 50], ellipse: [50, 50, 80, 60],
    circle: [50, 50, 60], line: [0, 0, 100, 50], path: ['M10 10 L90 10 Q100 50 90 90 Z'] })) {
    assert.match(render({ shapes: [{ id: type, type, args, options: { fill: 'white', fillStyle: 'solid' } }] }), /<path/);
  }
});

test('reject invalid level, seed, geometry, options, colors, and duplicate IDs', () => {
  for (const input of [
    { level: 3 }, { seed: 0 }, { seed: 1.5 }, { shapes: [] },
    { shapes: [shape, shape] },
    { shapes: [{ ...shape, args: [0, 0, -1, 20] }] },
    { shapes: [{ ...shape, args: [NaN, 0, 10, 20] }] },
    { shapes: [{ ...shape, type: 'constructor' }] },
    { shapes: [{ ...shape, options: { seed: 0 } }] },
    { shapes: [{ ...shape, options: { fill: 'url(https://example.org)' } }] },
    { shapes: [{ ...shape, options: { hachureGap: 0 } }] },
    { shapes: [{ ...shape, type: 'path', args: ['<script/>'] }] },
  ]) assert.throws(() => render({ shapes: [shape], ...input }));
});
