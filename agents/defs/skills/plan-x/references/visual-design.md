# Visual Design

The plan operates on two complementary visual layers. Master both to produce documents that feel like professionally designed strategy briefs rather than generated pages.

## Layer 1 — Editorial Illustration (GPT Image)

Editorial illustrations exist to improve engagement, create atmosphere, establish visual identity, and communicate conceptual mental models.

These are intentionally artistic.

Examples include:

- Hero cover artwork
- Architectural blueprints
- Exploded isometric systems
- Mission control rooms
- Factory metaphors
- City maps
- Ecosystem illustrations
- Product concept art

Editorial illustrations answer:

> "What does this concept feel like?"

They should never communicate quantitative information. They should never replace analytical diagrams. They should reinforce the narrative.

These illustrations use GPT Image and remain one of the signature characteristics of the plan.

---

## Layer 2 — Analytical Visualizations

Analytical visualizations exist to reveal information hidden within evidence.

These are deterministic transformations of data.

They answer:

> "What is actually happening?"

Examples include:

- Dependency DAGs
- Dependency Structure Matrices (DSM)
- Sankey diagrams
- Timelines
- Critical paths
- Gantt charts
- Heatmaps
- Risk matrices
- Ownership matrices
- Treemaps
- Flame graphs
- Sequence diagrams
- State diagrams
- Network graphs
- Scatter plots
- Time series
- Histograms

These should be generated programmatically using HTML, SVG, Mermaid, Graphviz, D3, Vega-Lite, ECharts, PlantUML or equivalent technologies.

Do not generate analytical diagrams with GPT Image.

---

## Transformation Rule

Every analytical visualization must satisfy ALL of the following:

- deterministic
- evidence-derived
- mechanically renderable
- reveals hidden structure
- materially improves understanding

If it fails any of these criteria, omit it.

---

## Illustration Rule

Editorial illustrations should complement analytical content rather than duplicate it.

Avoid generic AI art. Instead, ground every illustration in the plan itself.

For example:

Instead of:

> "A futuristic city"

Generate:

> "A futuristic city whose districts represent the platform's bounded contexts, connected by glowing event streams matching the actual architecture described in this plan."

Instead of:

> "A mountain representing technical debt"

Generate:

> "A detailed engineering workshop where overloaded machinery corresponds to the highest-risk components identified in the accompanying risk analysis."

The illustration should reinforce the reader's mental model without pretending to be evidence.

---

## Visualization Planning Phase

Before rendering any plan section, perform an internal visualization planning step.

For each section determine:

- What question is the reader trying to answer?
- What evidence exists?
- Is there hidden structure?
- What analytical transformation best exposes that structure?
- Would an editorial illustration improve comprehension?
- Which renderer should produce each artifact?

Only then render the section.

---

## Section Composition

Each major section should follow a consistent editorial rhythm.

1. Editorial Illustration (optional)
2. Executive Summary
3. Analytical Visualizations (when appropriate)
4. Evidence
5. Insights
6. Recommendations

The illustration introduces the section. The analytical visualizations prove the findings. The text interprets the results.

---

## Visual Hierarchy

Do not overwhelm the reader with graphics.

Prefer:

- one outstanding illustration

paired with

- one or two excellent analytical diagrams

rather than many mediocre graphics.

Every visual element must earn its place.

---

## Renderer Selection

Choose renderers based on the nature of the information.

Use GPT Image for:

- conceptual artwork
- hero imagery
- section dividers
- mental models
- narrative scenes
- editorial visuals

Use deterministic renderers for:

- architecture
- dependencies
- timelines
- statistics
- flows
- metrics
- risks
- ownership
- execution plans
- comparisons

---

## Interpretation

Never present a visualization without explaining it.

Every analytical visualization should include:

- Purpose
- Key Findings
- Implications
- Recommended Actions

Do not describe what is visually obvious. Explain why it matters.

---

## Visual Continuity

The plan should feel like a single professionally designed publication rather than a collection of independently generated pages.

Maintain a consistent visual language throughout the entire document.

### Editorial Consistency

All GPT Image illustrations should share a common artistic identity.

Maintain consistency in:

- artistic style
- perspective
- lighting
- colour palette
- composition
- typography (where applicable)
- iconography
- visual metaphors
- rendering quality

The reader should immediately recognise every illustration as belonging to the same plan.

Avoid changing styles between sections unless explicitly requested.

---

### Analytical Consistency

All analytical visualizations should appear as part of the same design system.

Maintain consistency in:

- typography
- spacing
- sizing
- margins
- legends
- axis styling
- iconography
- colour usage
- line weights
- border treatments
- interaction patterns (where applicable)

The analytical layer should feel cohesive regardless of which renderer produced the visualization.

---

### Semantic Consistency

Assign visual meaning once and reuse it consistently throughout the plan.

For example:

- colours represent the same domains throughout the plan
- risk levels always use the same visual encoding
- component categories always share the same icons
- ownership groups retain the same colours
- architecture layers retain the same visual identity
- execution stages use consistent styling

Never change the visual meaning of colours, icons, or symbols between sections.

---

### Narrative Continuity

Editorial illustrations should evolve alongside the narrative.

Rather than producing unrelated artwork for each section, create a coherent visual story.

For example:

Cover
→ Mission Control exterior

Architecture
→ Internal systems blueprint

Execution
→ Operations floor

Delivery
→ Launch sequence

Results
→ Mission accomplished

Each illustration should feel like another chapter of the same story.

---

### Layout Continuity

Maintain consistent page rhythm throughout the plan.

Each major section should generally follow:

1. Editorial illustration (optional)
2. Executive summary
3. Analytical visualization(s)
4. Evidence
5. Key insights
6. Recommendations

Readers should quickly learn where to find each type of information.

---

### Progressive Disclosure

Introduce information from abstract to concrete.

Follow this progression whenever appropriate:

Concept
→ Illustration

Structure
→ Analytical visualization

Evidence
→ Data

Interpretation
→ Insights

Action
→ Recommendations

This creates a natural storytelling flow that gradually increases information density.

---

### Design System Mindset

Treat the plan as a product rather than a generated document.

Every visual element should belong to a shared design system.

When introducing a new visualization or illustration, ask:

- Does it match the existing visual language?
- Does it reinforce the plan's identity?
- Will it feel familiar to the reader?
- Does it improve the narrative?

If not, redesign or omit it.

The finished plan should feel like it was designed by a single multidisciplinary team — combining editorial design, information visualization, and technical architecture — rather than assembled from unrelated AI outputs.
