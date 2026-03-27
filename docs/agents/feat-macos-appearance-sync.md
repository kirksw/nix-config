# feat-macos-appearance-sync

> Sync tmux and Neovim light/dark theme variants with the active macOS appearance.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [ ] Complete

## Context

The Darwin host currently forces macOS dark mode via `AppleInterfaceStyle = "Dark"`, which blocks
true OS-driven appearance switching. At the same time, tmux and Neovim each hardcode a dark
rose-pine variant, so they do not follow the system setting even if macOS is allowed to auto-switch.

The goal is to make tmux and Neovim follow macOS appearance changes automatically on the primary
Darwin workstation without coupling the behavior to a specific terminal emulator. This matters
because WezTerm is the primary terminal, Ghostty is a fallback, and tmux/Neovim should stay in sync
regardless of which terminal launches them.

## Plan

### Scope

Files expected to be affected:

- `hosts/darwin/work/default.nix` -- stop pinning macOS appearance to dark mode.
- `modules/home/imports.nix` -- register a new Home Manager appearance-sync module.
- `modules/home/programs/appearance-sync.nix` (new) -- own the macOS event source, state file, and
  tmux refresh hook.
- `hosts/darwin/work/home.nix` -- enable the new appearance-sync module for the Darwin home.
- `modules/home/programs/tmux.nix` -- consume the shared appearance state and reapply the
  rose-pine tmux theme dynamically.
- `config/nvim/lua/plugins/theme.lua` -- map macOS appearance state to the correct rose-pine
  variant for Neovim.
- `config/nvim/lua/config/autocmds.lua` -- reload Neovim theme when the appearance state changes.

Explicitly out of scope for this feature:

- Changing WezTerm chrome/theme behavior.
- Changing Ghostty behavior beyond preserving compatibility with its existing built-in
  `light:...,dark:...` theme support.
- Extending the same mechanism to Linux hosts.

### Approach

1. Remove the Darwin host-level `AppleInterfaceStyle = "Dark"` override so macOS can follow its own
   Auto/Light/Dark appearance settings again.
2. Add a new `homeModules.appearanceSync.enable` module under `modules/home/programs/` and wire it
   into `modules/home/imports.nix` plus `hosts/darwin/work/home.nix`.
3. In that module, create a small Darwin-only user agent that:
   - Detects the current appearance at startup.
   - Listens for macOS appearance changes via `dark-mode-notify`.
   - Writes a single shared state file such as `~/.local/state/appearance/mode` with either
     `dark` or `light`.
4. Keep the state file terminal-agnostic so new sessions opened from WezTerm or Ghostty inherit the
   correct appearance immediately, even before any live change event occurs.
5. Update tmux so it no longer hardcodes `@rose_pine_variant 'main'`. Instead, add a small helper
   that reads the shared appearance state and maps:
   - `dark -> main`
   - `light -> dawn`
6. Reapply the rose-pine tmux theme after changing the variant and trigger a live refresh for any
   running tmux server when the appearance-sync agent notices a change.
7. Update Neovim theme setup to read the same shared state and map:
   - `dark -> rose-pine main`
   - `light -> rose-pine dawn`
8. Add a Neovim reload path that applies the correct variant at startup and updates existing editor
   instances when the state file changes. Prefer a file-watch or targeted autocmd approach over
   polling or repeated shell-outs during redraw.
9. Make the feature safe on non-Darwin systems by gating the sync module to macOS and making tmux
   and Neovim fall back to their current default dark variant if the state file is absent.
10. Validate the final behavior with both cold-start and live-switch scenarios:
    - Start WezTerm, open tmux and Neovim, confirm they match the current macOS appearance.
    - Flip macOS appearance in System Settings and confirm running tmux and Neovim instances update
      without restart.

### Risks

- `dark-mode-notify` is present in the environment, but its CLI behavior is not self-describing, so
  the implementation should keep the wrapper small and verify its event semantics during testing.
- Tmux theme plugins can cache or overwrite status segments during reload, so the current
  rose-pine load order and custom `status-right` append will need careful regression testing.
- Neovim theme updates can leave stale highlight groups behind if the colorscheme is reapplied
  incompletely; the implementation should use the theme plugin's supported reload path.
- Removing the pinned Darwin appearance may be user-visible outside tmux/Neovim if macOS is
  currently expected to stay dark all the time.
- WezTerm itself is currently pinned to a dark color scheme, so tmux and Neovim may switch while
  the outer terminal UI remains dark until a separate WezTerm follow-up is implemented.

## Testing

Commands run during implementation:

```sh
./scripts/check-structure.sh
nix flake check --no-build
apps/aarch64-darwin/build lunar
XDG_STATE_HOME=/tmp/codex-nvim-state nvim --clean --headless -u NONE '+lua package.path = vim.fn.getcwd() .. "/config/nvim/lua/?.lua;" .. vim.fn.getcwd() .. "/config/nvim/lua/?/init.lua;" .. package.path; require("config.appearance"); dofile(vim.fn.getcwd() .. "/config/nvim/lua/plugins/theme.lua"); dofile(vim.fn.getcwd() .. "/config/nvim/lua/config/autocmds.lua")' +qall
```

Manual validation to record after implementation:

- Launch WezTerm and confirm a fresh tmux session matches current macOS appearance.
- Launch Neovim inside tmux and confirm the colorscheme variant matches current macOS appearance.
- Toggle macOS appearance between Light and Dark in System Settings and confirm both update live.
- Repeat the startup check in Ghostty to confirm fallback terminal compatibility.

## Summary

_Filled in after completion, before moving to `docs/agents/completed/`._

### What changed

- Pending implementation.

### What was tested

- Pending implementation.

### Follow-up

- Consider extending the same appearance state to WezTerm so terminal chrome matches tmux/Neovim.
- Add any remaining follow-up items to `docs/BACKLOG.md` with priority and effort estimate when the
  feature is completed.
