# EDGE Observatory code signing and TCC permissions

> How the EDGE Observatory app keeps its macOS Input Monitoring and
> Accessibility grants across rebuilds, and how to restore that setup.

## Status

- Complete and verified on `lunar` (aarch64-darwin).
- Last verified: 2026-09-16.

## Background

The EDGE Observatory is the XENEON EDGE dashboard app.

- It is built from `packages/edge-observatory/` by `scripts/build-edge-observatory.sh` and installed at `~/Applications/EDGE Observatory.app`.
- It runs under the launchd agent `org.nixos.edge-dashboard` (`modules/darwin/services/edge-dashboard.nix`, mode `observatory`).
- Its touch runtime needs the macOS **Input Monitoring** and **Accessibility** (TCC) grants to map EDGE touches to the correct display.

## The failure this document prevents

Every rebuild produces a different binary, and `codesign` with an ad-hoc
identity (`--sign -`) gives each build a fresh, meaningless signature.

macOS TCC grants are bound to the app's code-signing identity, not just its
path.

With ad-hoc signing, every rebuild therefore looks like a brand-new app:

- existing Input Monitoring and Accessibility grants stop applying,
- the touch runtime's permission checks fail, so touch clicks fall through to whichever display holds the cursor, and
- every restart re-opens the permission prompts, because the runtime calls `CGRequestListenEventAccess()` and the Accessibility prompt API when untrusted.

The visible symptom is a loop of "restart the app, re-grant permissions, lose
them again on the next rebuild", with touch mapping broken in between.

## The fix

The build script signs with a stable self-signed identity,
`EDGE Observatory Development`, instead of an ad-hoc signature.

With a real signing certificate, TCC designates trust by the certificate, so
grants survive every rebuild.

The script falls back to ad-hoc signing only when the identity is missing, so
a lost key degrades to the old behavior instead of failing the build.

The key material lives outside the repository at
`~/.config/edge-observatory/`:

- `edge-dev.key` — the private key,
- `edge-dev.pem` — the self-signed certificate (CN `EDGE Observatory Development`, code-signing EKU, valid 10 years).

**Back this directory up.**
It is deliberately not committed, because committing private keys to a
repository is never correct.
Losing it means re-granting permissions once after generating a new identity.

## Restoring the identity on a new machine

Run once, in any directory you trust:

```sh
mkdir -p ~/.config/edge-observatory
cd ~/.config/edge-observatory
openssl req -new -newkey rsa:2048 -nodes -keyout edge-dev.key -x509 -days 3650 \
  -out edge-dev.pem -subj "/CN=EDGE Observatory Development/O=kirksw/" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=codeSigning" \
  -addext "basicConstraints=critical,CA:FALSE"
security import edge-dev.key -k ~/Library/Keychains/login.keychain-db -T /usr/bin/codesign
security import edge-dev.pem -k ~/Library/Keychains/login.keychain-db
security add-trusted-cert -r trustRoot -p codeSign \
  -k ~/Library/Keychains/login.keychain-db edge-dev.pem
```

The `add-trusted-cert` step writes per-user trust settings and does not
require `sudo`.

After restoring the key, rebuild and re-enable the app's grants once:

```sh
launchctl unload "$HOME/Library/LaunchAgents/org.nixos.edge-dashboard.plist"
bash scripts/build-edge-observatory.sh
launchctl load "$HOME/Library/LaunchAgents/org.nixos.edge-dashboard.plist"
```

Then enable `EDGE Observatory` under System Settings → Privacy & Security →
Input Monitoring and → Accessibility, removing any stale duplicate entries.

## Verifying the setup

Check the signature before debugging permissions:

```sh
codesign -dv --verbose=4 "$HOME/Applications/EDGE Observatory.app" 2>&1 | grep Authority
# expected: Authority=EDGE Observatory Development
```

Check that the identity is usable:

```sh
security find-identity -v -p codesigning | grep "EDGE Observatory Development"
```

If `Authority` is missing or the identity is not listed, fix signing first;
permission problems after that are expected, not a TCC bug.

## Related

- Build and touch runtime: `scripts/build-edge-observatory.sh`, `packages/edge-observatory/EdgeObservatory.swift`, `packages/edge-observatory/TouchRuntime.m`.
- Display controls (DDC brightness, gamma color temperature) are unrelated to signing; see `packages/edge-observatory/XeneonDdc.swift` and `XeneonGamma.swift`.
