# Review Lenses And Output Shape

## Minimum lenses

Stress-test each world against these lenses:

1. **Architecture** — what gets simpler, what gets more coupled, what becomes awkward?
2. **Migration** — how would you get there incrementally, and what breaks during the move?
3. **Operations** — what becomes harder to maintain, debug, or explain later?
4. **Security / trust** — do boundaries disappear, credentials merge, or blast radius expand?
5. **Human workflow** — what changes for day-to-day usage, habits, and team separation?
6. **Reversibility** — how hard is it to back out if the experiment disappoints?

Add domain-specific lenses when the topic needs them.

## Output shape

```md
# What-if: <topic>

## Baseline
- Current world:
- Changed constraint(s):
- Invariants:

## Alternative worlds

### World 1 — <name>
- Shape:
- Implementation outline:
- Benefits:
- Costs:
- Failure modes:

### World 2 — <name>
- Shape:
- Implementation outline:
- Benefits:
- Costs:
- Failure modes:

## Adversarial review
- Biggest hidden risk:
- Most likely migration trap:
- Boundary or trust concern:
- Operational burden:
- Reversibility:

## Recommendation
- Best fit now:
- Most interesting future bet:
- Keep current world because:
- Trigger to revisit later:
```

## Quality bar

A good answer should let the user decide whether the new world is worth pursuing, not just admire the idea.
