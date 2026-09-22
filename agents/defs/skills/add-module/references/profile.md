# Profile Wizard

Profiles live in `agents/pi-profiles.nix` under the `profiles` attrset.

Ask for:

1. `name`
2. `base`: which base owns credentials, authentication, sessions, and settings
3. `skills`: skill names, or an empty list for every defined skill
4. optional `tierMapping`: ordered model chains per tier

Emit this block:

```nix
profiles.<name> = {
  base = "<base>";
  skills = [ <skills> ];
  tierMapping = { <tierMapping> };
};
```

Explain that the `base` field decides three things: which `settings.json`, `models.json`,
`mcporter.json`, and `env` the profile links, which provider credentials the `pi` wrapper
exports, and which commit identity it sets.

Bases are defined in the same file:

```nix
bases.<name> = {
  providers = [ <provider-name> ];
  git = { userName = "…"; userEmail = "…"; signingKey = "…"; };
};
```

Providers are defined in the `providers` attrset, which maps a `credentialRef` environment
variable to the `envVar` that Pi reads.

A new profile needs one wrapper change: add its name to the profile-to-base `case` in
`modules/home/programs/ai-agents.nix` and to the matching assertion in
`scripts/check-pi-experimental-launchers.py`.
