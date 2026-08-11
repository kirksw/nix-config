---
name: bladebro
description: Use Bladebro's native Pi browser tools to inspect and interact with web pages.
---

# Bladebro

Bladebro is installed as a native Pi extension and provides `act`, `see`, `state`, `run`, and `vision` browser tools.
Use the registered tools directly; do not install the npm package or start `bladebro mcp` yourself.

Start with `see` to inspect the current page and its element references before acting.
Use `act` for navigation, clicks, typing, and batch interactions.
Use `vision` only when page structure is insufficient.

Get explicit user confirmation before logging in, submitting forms, sending messages, making purchases, downloading files, or otherwise causing external side effects.
