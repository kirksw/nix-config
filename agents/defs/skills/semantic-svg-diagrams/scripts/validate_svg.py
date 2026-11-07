#!/usr/bin/env python3
"""Validate semantic SVG structure. Does not perform visual validation."""
import argparse
from collections import Counter
import json
import math
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

NS = 'http://www.w3.org/2000/svg'
ID = re.compile(r'[A-Za-z_][A-Za-z0-9_.-]*\Z')

def validate(path):
    errors = []
    def check(ok, message):
        if not ok:
            errors.append(message)
    raw = Path(path).read_text(encoding='utf-8')
    if re.search(r'<!DOCTYPE|<!ENTITY', raw, re.I):
        return ['DTD and entity declarations are not allowed']
    try:
        root = ET.fromstring(raw)
    except ET.ParseError as exc:
        return [f'Invalid XML: {exc}']
    check(root.tag == f'{{{NS}}}svg', 'Root must be SVG in the SVG namespace')
    try:
        box = [float(x) for x in re.split(r'[\s,]+', root.get('viewBox', '').strip())]
        check(len(box) == 4 and all(math.isfinite(x) for x in box) and box[2] > 0 and box[3] > 0, 'Invalid viewBox')
    except ValueError:
        errors.append('Invalid viewBox')
    for tag in ('title', 'desc'):
        el = root.find(f'{{{NS}}}{tag}')
        check(el is not None and ''.join(el.itertext()).strip(), f'Missing {tag}')
    elements = list(root.iter())
    xml_ids = Counter(el.get('id') for el in elements if el.get('id'))
    check(all(v == 1 for v in xml_ids.values()), 'Duplicate XML IDs')
    for el in elements:
        tag = el.tag.split('}')[-1]
        check(el.tag.startswith('{'+NS+'}'), f'Non-SVG element: {tag}')
        check(tag not in ('script', 'foreignObject', 'style', 'animate', 'animateMotion', 'animateTransform', 'set', 'image'), f'Unsupported element: {tag}')
        for key, value in el.attrib.items():
            local = key.split('}')[-1]
            check(not local.lower().startswith('on'), 'Event handler not allowed')
            check(local != 'style', 'Use presentation attributes instead of style')
            if local == 'href':
                check(value.startswith('#') and value[1:] in xml_ids, f'Nonlocal or missing href: {value}')
            for ref in re.findall(r'url\(\s*[\"\']?([^\)\"\']+)[\"\']?\s*\)', value, re.I):
                ref = ref.strip()
                check(ref.startswith('#') and ref[1:] in xml_ids, f'Nonlocal or missing URL: {ref}')
    metas = [el for el in elements if el.tag == f'{{{NS}}}metadata' and el.get('id') == 'diagram-model']
    if len(metas) != 1:
        return errors + ['Expected exactly one metadata#diagram-model']
    check(bool(re.search(r'<(?:\w+:)?metadata\b[^>]*\bid=[\"\']diagram-model[\"\'][^>]*>\s*<!\[CDATA\[', raw)), 'Semantic JSON must use CDATA')
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError(f'Duplicate JSON key: {key}')
            result[key] = value
        return result
    try:
        model = json.loads(''.join(metas[0].itertext()), object_pairs_hook=pairs, parse_constant=lambda s: (_ for _ in ()).throw(ValueError(s)))
    except (ValueError, TypeError) as exc:
        return errors + [f'Invalid semantic JSON: {exc}']
    if not isinstance(model, dict):
        return errors + ['Model must be an object']
    check(model.get('schemaVersion') == '1.0', 'Unsupported schemaVersion (expected 1.0)')
    check(isinstance(model.get('title'), str) and bool(model['title'].strip()), 'Missing title')
    objects = {}
    for plural, required in [('nodes', ['id', 'label', 'type']), ('edges', ['id', 'from', 'to', 'type']), ('groups', ['id', 'label'])]:
        records = model.get(plural)
        if not isinstance(records, list):
            errors.append(f'{plural} must be an array')
            continue
        for obj in records:
            if not isinstance(obj, dict):
                errors.append(f'{plural} entry must be an object')
                continue
            for key in required:
                check(isinstance(obj.get(key), str) and bool(obj[key].strip()), f'{plural}: missing string {key}')
            sid = obj.get('id')
            if not isinstance(sid, str) or not ID.fullmatch(sid):
                errors.append(f'Invalid semantic ID: {sid!r}')
                continue
            check(sid not in objects, f'Duplicate semantic ID: {sid}')
            objects[sid] = (plural[:-1], obj)
    for sid, (kind, obj) in objects.items():
        if kind == 'edge':
            for field in ('from', 'to'):
                target = obj.get(field)
                check(isinstance(target, str) and objects.get(target, (None,))[0] == 'node', f'{sid}: {field} must reference a node')
        if kind == 'group':
            children = obj.get('children')
            if not isinstance(children, list) or not all(isinstance(c, str) for c in children):
                errors.append(f'{sid}: children must be an array of IDs')
                continue
            check(len(children) == len(set(children)), f'{sid}: duplicate children')
            for child in children:
                check(objects.get(child, (None,))[0] in ('node', 'group'), f'{sid}: invalid child {child}')
    active, done = set(), set()
    def visit(sid):
        if sid in active:
            errors.append(f'Cyclic group containment: {sid}')
            return
        if sid in done:
            return
        active.add(sid)
        children = objects[sid][1].get('children', [])
        if isinstance(children, list):
            for child in children:
                if isinstance(child, str) and objects.get(child, (None,))[0] == 'group':
                    visit(child)
        active.remove(sid)
        done.add(sid)
    for sid, (kind, _) in objects.items():
        if kind == 'group':
            visit(sid)
    counts = Counter()
    nonrendering = {'defs', 'metadata', 'symbol', 'clipPath', 'mask', 'marker', 'pattern'}
    def walk(el, hidden=False):
        hidden = hidden or el.tag.split('}')[-1] in nonrendering
        sid = el.get('data-semantic-id')
        if sid is not None:
            counts[sid] += 1
            check(sid in objects, f'Unknown rendered semantic ID: {sid}')
            check(not hidden and el.tag == f'{{{NS}}}g', f'{sid}: representation must be a visible-tree g wrapper')
            if sid in objects:
                kind, obj = objects[sid]
                check(el.get('data-kind') == kind, f'{sid}: incorrect data-kind')
                check(el.get('id') == f'{kind}-{sid}', f'{sid}: incorrect wrapper ID')
                if kind == 'edge':
                    for field in ('from', 'to'):
                        check(el.get('data-'+field) == obj.get(field), f'{sid}: data-{field} mismatch')
        elif el.get('data-kind') is not None:
            errors.append('data-kind without data-semantic-id')
        for child in el:
            walk(child, hidden)
    walk(root)
    for sid in objects:
        check(counts[sid] == 1, f'{sid}: expected one representation, found {counts[sid]}')
    return errors

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('svg', type=Path)
    args = parser.parse_args()
    try:
        failures = validate(args.svg)
    except (OSError, UnicodeError, RecursionError) as exc:
        failures = [str(exc)]
    for failure in failures:
        print('ERROR:', failure, file=sys.stderr)
    if not failures:
        print('PASS: structural checks only; render and inspect separately.')
    sys.exit(bool(failures))
