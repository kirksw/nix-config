# Local wrapper compatibility patch

Pinned upstream: `pi-herdr-agents` 1.7.0 from the npm release tarball.
The Nix package applies `wrapper-overrides.patch`; generated installations are never patched in place.

The patch forwards `NIX_AGENTS_PROFILE` and `PI_CODING_AGENT_SESSION_DIR` into fresh, fork/worktree, handoff, and resumed launch shells.
An explicit session directory is used directly, matching Pi's override semantics rather than appending an encoded working directory.
Without the override, upstream session-directory behavior is unchanged.

The outer Pi wrapper preserves explicit directories.
A final executable bridge restores the config override after the upstream Nix wrapper assigns its profile directory.
`pix` clears inherited directory overrides when selecting a profile.

Validation:

```sh
nix build .#pi-herdr-agents --no-link
nix build .#checks.aarch64-darwin.pi-herdr-agents-extension-load --no-link
python3 scripts/check-pi-wrapper-chain.py /nix/store/...-pi/bin/pi /nix/store/...-pix/bin/pix
```

Package checks exercise generated fresh, fork/isolated, and resumed commands through a shell probe, including paths with spaces and quotes and fallback behavior.
The built wrapper-chain check exercises the inner wrapper and final bridge without credentials or model calls.
Activation of the changed macOS wrapper requires the normal Darwin switch; syncing agent packages alone does not replace installed executables.
