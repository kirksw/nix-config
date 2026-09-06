# feat-personal-agent-profile-reconcile

> Reconcile managed personal-agent profile assets during VM boot.

## Status

- [x] Plan
- [x] Implement
- [ ] Test
- [ ] Complete

## Context

Bootstrap-only wrapper sync preserves old persistent profile assets after deployment.
The browser-only service also references skills absent from the generated profile.

## Plan

### Scope

Replace browser-only reconciliation in `hosts/nixos/ry4a/agent-microvms.nix` with complete managed-asset reconciliation.
Add running-profile verification to the microVM runbook.

### Approach

1. Validate source assets and back up existing managed assets before mutation.
2. Reconcile only agents, skills, extensions, prompts, AGENTS.md, hook-manifest, and skill-versions.json.
3. Preserve credentials, sessions, workspaces, npm packages, and user settings outside these paths.
4. Validate, deploy using remote builds, restart only personal-agent, and compare running assets with their generated source.

### Risks

Managed directories are authoritative and obsolete entries are removed after backup.
VM restart interrupts interactive sessions.
A single initial snapshot is retained under the persistent home state directory.

## Testing

- Structure, formatting, staged diff, and cache-bypassed flake checks passed.
- The initial flake check hit the previously observed invalid agent-source derivation; targeted factory-profile evaluation followed by the full check passed.
- Remote deploy-rs activation succeeded and only personal-agent was restarted.
- The running and current VM runner links match.
- Profile reconciliation returned success and the VM has no failed services.
- All seven managed asset paths match their generated source recursively.
- The persistent tier table has Astra in S and Sol/Terra/Luna in A/B/C.
- The initial backup exists.
- Review findings about unbounded backups and executable permission loss were fixed before the final deployment.
- Authentication file hashes match across the final restart.
- Settings hashes differ across the final restart, and the settings modification time matches the existing package-reconciliation service.
  Its generated source contains only the packages key and the resulting packages match that source.
  No pre-restart settings content was retained, so preservation of every other settings value cannot be independently proved.
  Common formatting-only reconstructions did not reproduce the earlier hash.
  No settings or credential values were printed during investigation.

## Summary

The reconciliation fix is deployed and the managed profile is verified.
Final preservation acceptance remains open because the earlier settings snapshot contains only a hash.
No additional settings mutation or restart was performed during follow-up investigation.
