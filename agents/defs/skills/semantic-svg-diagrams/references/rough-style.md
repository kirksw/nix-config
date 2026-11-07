# Default hand-drawn SVG style

For new diagrams, default to Rough.js level 2 for boxes, domain boundaries, hatching, and connectors.
Keep icons as clean vector geometry outside the Rough.js input, and keep text editable.
Use level 1 for lightly rough output, level 0 for smooth geometry and regular hatching, or plain SVG for a fully clean style when requested.
Do not restyle existing diagrams unless asked.

Inspect `../assets/datamesh-reference.png` for the approved balance of rough structure and clean details.
Its editable counterpart is `../assets/datamesh-reference.svg`.
The reference was redrawn from https://www.datamesh-architecture.com/images/datamesharchitecture.png.webp and retains attribution to datamesh-architecture.com.
It illustrates style and SVG structure, not a required data mesh layout for other subjects.
Use Rough.js rather than homemade coordinate jitter, SVG noise filters, or a duplicated outline.
Rough.js varies outlines and hatching together.
Its roughness values approximate Excalidraw sloppiness, but do not promise identical output: Excalidraw also selects its own geometry and renderer settings.

## Setup

The helper requires Node.js and npm at build time only.
Skill files can reside in the read-only Nix store, so copy the helper and pinned dependency manifests to a writable temporary directory.
Do not install into the skill directory or modify generated profiles.
Resolve `SKILL_DIR` to the directory containing this skill's `SKILL.md`.

```sh
WORK_DIR=$(mktemp -d)
cp "$SKILL_DIR/scripts/"{package.json,package-lock.json,rough_svg.cjs,rough_svg.test.cjs} "$WORK_DIR/"
(cd "$WORK_DIR" && npm ci --ignore-scripts --no-audit --no-fund && npm test)
node "$WORK_DIR/rough_svg.cjs" shapes.json fragment.svg
```

The initial `npm ci` requires registry access unless packages are cached.
If dependencies are unavailable, report the limitation; do not claim homemade jitter is equivalent.
The helper uses Rough.js's generator and serializes static paths without a DOM, browser, or runtime JavaScript.

## Input

Choose level `2` unless the user requests a different style.
The helper also defaults to level `2` when `level` is omitted.
Level `0` uses smooth, single-stroke geometry and regular hatching; level `1` is lightly rough; level `2` is more irregular.
Use a fixed positive 31-bit integer seed and stable shape IDs.
The helper derives independent seeds from the global seed and each shape ID, so reordering shapes does not change their paths.

```json
{
  "level": 2,
  "seed": 42,
  "shapes": [
    {
      "id": "domain-boundary",
      "type": "ellipse",
      "args": [180, 140, 280, 220],
      "options": {
        "stroke": "#de3535",
        "strokeWidth": 2,
        "fill": "#ffcaca",
        "fillStyle": "hachure",
        "hachureAngle": -45,
        "hachureGap": 12,
        "fillWeight": 1
      }
    }
  ]
}
```

Supported geometry:

- `rectangle`: `[x, y, width, height]`.
- `ellipse`: `[centerX, centerY, width, height]`, using full dimensions rather than SVG radii.
- `circle`: `[centerX, centerY, diameter]`.
- `line`: `[x1, y1, x2, y2]`.
- `path`: `["M... Z"]`, including curves and rounded rectangles.

Options also allow `bowing`, `curveStepCount`, `disableMultiStroke`, `disableMultiStrokeFill`, and `preserveVertices`.
Colors must be literals such as `#1686d4`, `white`, or `none`, not URLs or CSS variables.
For a white card background use `fill: "white"` with `fillStyle: "solid"`.
Keep rough hatching restrained enough that text remains legible.
Keep all icons, including team figures and small details, clean by default.
Only send icon geometry through Rough.js if the user explicitly requests rough icons.

## Semantic integration

The output is a geometry fragment, not a complete semantic diagram or an automatic converter for arbitrary SVGs.
It contains presentation-only groups identified by `data-rough-shape`.
Place each generated shape group inside its existing node, edge, or group wrapper.
Keep exactly one semantic wrapper per object, and leave text as editable SVG `<text>` outside the generated geometry.
Do not add generated coordinates or renderer settings to the semantic model.
For layout-only edits, preserve the metadata payload byte-for-byte.

Generate boundaries, fills, and connectors deliberately rather than roughening every path in an existing SVG indiscriminately.
Retain existing wrapper transforms and drawing order.
For connectors, use unfilled rough paths and a local marker on the final outline path only, or draw a separate arrowhead at the intended endpoint.
Check that rough endpoints and hatch overshoot do not create false connections, clipping, or label collisions.

Keep the SVG standalone: no scripts, remote fonts, images, or references to npm packages.
Use a proportional `viewBox`, normally `width="100%"` for browser display, and `preserveAspectRatio="xMidYMid meet"`.
Run the structural validator on the assembled SVG, render it, and inspect the actual image at readable size.
If asked for levels 0, 1, and 2, compare them side by side with identical geometry, colors, and seeds.
