# feat-pi-minimal-mode-all-profiles

> Ensure Pi minimal-mode extension is present in every Pi profile, including factory profiles.

## Status

- [x] Plan
- [x] Implement
- [x] Test
- [x] Complete

## Context

`minimal-mode` exists under `agents/targets/pi/extensions/minimal-mode/` and is present in normal generated Pi profiles, but factory profile directories were not being refreshed by `sync-agents`.

## Plan

### Scope

- `flake/apps.nix`
- `flake.nix`

### Approach

1. Make `sync-agents` sync factory Pi profiles as well as normal Pi profiles.
2. Add a factory-profile check for `extensions/minimal-mode/index.ts`.
3. Run lightweight validation and sync.

### Risks

- Factory profiles should still keep agents and skills empty.

## Testing

Commands run to validate:

```sh
nix run .#sync-agents
./scripts/check-structure.sh
nix flake check --no-build
python3 - <<'PY'
import pathlib
base = pathlib.Path.home()/'.config/nix-agents/pi/bases'
missing=[]
for settings in sorted(base.glob('*/profiles/*/settings.json')):
    if not settings.exists():
        continue
    profile_dir = settings.parent
    ok = (profile_dir/'extensions/minimal-mode/index.ts').exists()
    print(f'{profile_dir}: {ok}')
    if not ok: missing.append(str(profile_dir))
if missing: raise SystemExit('missing minimal-mode: '+', '.join(missing))
PY
```

## Summary

### What changed

- `sync-agents` now syncs Pi factory profiles (`home-factory`, `work-factory`) in addition to normal Pi profiles.
- Factory profile checks now assert `extensions/minimal-mode/index.ts` exists.

### What was tested

- `nix run .#sync-agents`
- `./scripts/check-structure.sh`
- `nix flake check --no-build`
- Verified every generated Pi profile with `settings.json` has `extensions/minimal-mode/index.ts`.

### Follow-up

- None.
