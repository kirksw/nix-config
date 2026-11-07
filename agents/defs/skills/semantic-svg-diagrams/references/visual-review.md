# Render and inspect

Use an available renderer (CairoSVG helper, Inkscape, or browser SVG rendering). Do not insert the SVG into HTML as the deliverable. Render at sufficient resolution to read every label; inspect both the full composition and dense areas.

- Verify every node, group, and edge is visible and matches the model.
- Trace each connector from its source boundary to its destination; check arrow direction, marker size, and self-loops.
- Check labels against the model and ensure they are readable, editable text rather than paths.
- Check margins, long labels, multiline text, group headings, and arrowheads for clipping.
- Check crossings, accidental tangencies, and labels obscured by lines or shapes.
- Confirm group boundaries communicate membership, including shared membership.
- Keep contrast strong and text legible at the intended viewing size.

Structural checks cannot establish these visual properties. After each visual fix, rerun structural validation and render again. If the renderer is missing, report that specific limitation rather than claiming visual validation.
