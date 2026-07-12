# Core Beliefs

**Status:** Active

**Last verified:** 2026-07-09

- The repository is the system of record. Decisions needed to maintain it must be discoverable here.
- Give agents and contributors a map, then progressively disclose detail through focused documents.
- Declarative Nix configuration is the source of truth; generated local configuration is disposable output.
- Encode stable invariants in checks when practical; documentation explains intent and remediation.
- Prefer small, composable modules and explicit host wiring over implicit or duplicated behavior.
- Plans and ADRs preserve context: plans record execution, while ADRs record durable decisions.
- Documentation changes with the system it describes, and stale guidance is treated as a defect.
- Secrets never enter the knowledge store in plaintext.
