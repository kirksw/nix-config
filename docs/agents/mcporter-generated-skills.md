# MCPorter generated skills

Generated work-MCP wrappers are refreshed explicitly.
They are not generated during Nix evaluation, builds, or agent configuration synchronization because schema discovery requires live network access and may require OAuth.

## Refresh

```sh
nix run .#update-mcp-skills
nix run .#sync-agents
```

The refresh command reads the generated Pi work MCPorter configuration and emits a wrapper for every configured work server.
It does not store credentials in generated artifacts.

## Validation

Before accepting a refresh:

1. Run the generated artifact's `__mcporter_inspect` command or the typed-client metadata check.
2. Run a narrow read-only smoke test through the profile-installed `work-mcp` runner.
3. Confirm that post-OAuth tool discovery uses the expected transport and does not silently fall back to an incompatible transport.
4. Run `./scripts/check-structure.sh`, `git diff --check`, and `nix flake check --no-build --option eval-cache false`.

## Generator limitations

MCPorter `generate-cli` can fail when an MCP schema has a non-identifier field name.
Use its deterministic `emit-ts --mode client` fallback in that case.
The shared runner exposes its generated methods with JSON arguments and still bounds output before it reaches Context Mode.
