# feat-pi-mcp-adapter-profiles

> Add pi-mcp-adapter to every Pi profile package set.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`npm:pi-mcp-adapter` was only included in the work Pi settings. The request is to make it available to all Pi profiles.

## Plan

### Scope

- `agents/base-settings.nix`
- `flake.nix`

### Approach

1. Move `npm:pi-mcp-adapter@2.8.0` into the shared Pi package list.
2. Add it to factory Pi package refs so factory profiles also receive it.
3. Remove the work-only duplicate and update the factory package assertion.
4. Run lightweight validation.

### Risks

- Factory profile package assertions must stay in sync with `piFactoryPackageRefs`.

## Testing

Commands run to validate:

```sh
./scripts/check-structure.sh
nix flake check --no-build
nix run .#sync-agents
```

Additional generated-profile check:

```sh
python3 - <<'PY'
import json, pathlib
for p in sorted((pathlib.Path.home()/'.config/nix-agents/pi/bases').glob('*/profiles/*/settings.json')):
    if not p.exists():
        print(f'{p}: missing target')
        continue
    data=json.load(open(p))
    print(f'{p}: {"npm:pi-mcp-adapter@2.8.0" in data.get("packages", [])}')
PY
```

## Summary

### What changed

- Added `npm:pi-mcp-adapter@2.8.0` to shared Pi profile packages.
- Added `npm:pi-mcp-adapter@2.8.0` to factory Pi package refs.
- Removed the work-only duplicate package append.
- Updated the factory package assertion in `flake.nix`.

### What was tested

- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- `nix run .#sync-agents`
- Verified generated personal/work/work-factory profile settings include `npm:pi-mcp-adapter@2.8.0`.

### Follow-up

- None.
