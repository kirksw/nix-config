# feat-agent-os-status-widget

> Compact, mode-aware Agent OS status widget.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

The Agent OS widget showed every field in a verbose, left-aligned label. It should show only relevant mode context, suppress a zero unread badge, and keep the active OS name at the right edge.

## Changes

- OS: ` OS`
- Thread: `󰭹 Thread  ·  @<thread>`
- Factory: ` Factory  ·  @<thread>  ·   <workpackage>`
- Add `󰍡 <count>` only when unread messages exist.
- Right-align `lifeOS`, `lunarOS`, or `?` to the widget width.

## Testing

```sh
node --experimental-transform-types --import ./agents/packages/pi-subagents/test/support/register-loader.mjs --test agents/targets/pi/extensions/agent-os/tests/*.test.mjs
node --experimental-transform-types --check agents/targets/pi/extensions/agent-os/index.ts
node --experimental-transform-types --check agents/targets/pi/extensions/agent-os/core/status-widget.ts
git diff --check
```

All 24 Agent OS tests passed.
