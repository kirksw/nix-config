# Semantic graph contract — 1.0

Use nonempty strings for all required scalar fields. IDs are globally unique across nodes, edges, and groups and match `[A-Za-z_][A-Za-z0-9_.-]*`. IDs identify concepts, not positions; retain IDs when labels or layout change.

Edges are directed (`from` → `to`); both endpoints must be node IDs. Parallel edges and self-loops are allowed when meaningful. Represent undirected associations through an explicitly named edge type and explain the convention in the description.

Group children are node or group IDs, never edge IDs. Reject duplicate children, missing children, and recursive containment. Groups may be empty. A node may belong to multiple groups; use one node representation and explain shared membership visually without duplicating semantic wrappers.

Optional `layoutHints` may describe intent such as direction or rank, but must not contain pixel coordinates or SVG paths. Optional descriptive extensions are preserved on edits. Do not rename or drop unknown fields without reason.

```json
{
  "schemaVersion": "1.0",
  "title": "Event ingestion",
  "nodes": [
    {"id": "source", "label": "Source", "type": "service"},
    {"id": "stream", "label": "Stream", "type": "stream"}
  ],
  "edges": [{"id": "publishes", "from": "source", "to": "stream", "type": "publishes", "label": "Events"}],
  "groups": [{"id": "platform", "label": "Platform", "children": ["source", "stream"]}]
}
```

Put each object on a single SVG `<g>` wrapper. Group membership is semantic, not dependent on SVG DOM nesting. Edge wrapper `data-from` and `data-to` repeat semantic endpoints for consistency checks. Geometry still requires inspection.

Use `json.dumps(model, ensure_ascii=False, allow_nan=False)` to serialize. Embed using `json_text.replace(']]>', ']]]]><![CDATA[>')`. Keep XML escaping separate from JSON serialization.
