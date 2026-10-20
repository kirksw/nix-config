# Diagnose a configuration or profile

1. Read `../references/source-of-truth.md` and `../references/layout.md` to identify the declarative source and generated runtime path.
2. For profile selection, base-scoped credentials, or sessions, read `../references/bases-and-profiles.md`. Compare `agents/pi-profiles.nix` and the launcher in `modules/home/programs/ai-agents.nix` with the active profile.
3. For Nix errors, read `../references/failure-triage.md` and reproduce at the smallest relevant target before changing code.
4. Inspect generated files to explain active state, but edit source and follow `validate-and-sync.md` to persist a fix.
