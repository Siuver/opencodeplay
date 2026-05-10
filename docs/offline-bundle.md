# Offline Bundle Guide

Use this guide on an online machine before transferring `opencodeplay` to an offline PC.

## Bundle Checklist

- Pin every enabled tool in `manifests/tools.json`.
- Download the exact artifact files into `artifacts/`.
- Record SHA-256 checksums in the manifest.
- Include license notes for vendored source or redistributed binaries.
- Run a dry run in offline mode.
- Transfer the complete repository directory to the target PC.

## Recommended Artifact Types

Prefer artifacts in this order:

1. Official release archive or binary.
2. Package-manager cache that supports offline install.
3. Source snapshot at a pinned commit.

Avoid cloning live upstream repositories during offline setup. If source is required, store a snapshot archive and document the exact commit.

For `opencode`, start with GitHub Release assets instead of source snapshots. Source builds require the Bun workspace toolchain, while release assets match the upstream installer flow and are easier to verify with SHA-256 checksums.

## opencode Artifact Candidates

- `opencode-windows-x64.zip` for normal 64-bit Windows CLI installs.
- `opencode-windows-x64-baseline.zip` for older CPUs or compatibility-first machines.
- `opencode-windows-arm64.zip` for Windows on ARM.
- `opencode-desktop-win-x64.exe` only if the desktop app is part of the bundle.

Record the release tag, target commit, source URL, SHA-256 digest, and license note for every included artifact. File size is useful external evidence when preparing a release bundle, but it is not currently a manifest field.

## Desired Plugin Candidates

- `opencode-dynamic-context-pruning` is tracked as a desired opencode companion plugin.
- Stable package: `@tarquinen/opencode-dcp` version `3.1.11` from `https://registry.npmjs.org/@tarquinen/opencode-dcp/-/opencode-dcp-3.1.11.tgz`.
- License: `AGPL-3.0-or-later`.
- Keep it disabled until the tarball checksum is recorded and an offline-safe opencode/Bun plugin cache or local plugin install flow is documented and tested.

## Dry Run

```powershell
.\scripts\bootstrap.ps1 -Mode Offline -WhatIf
```

The dry run should report all enabled tools as ready before the bundle is moved to an offline PC.

Use a real run with a disposable install root before publishing a bundle:

```powershell
.\scripts\bootstrap.ps1 -Mode Offline -InstallRoot "$env:TEMP\opencodeplay-tools"
.\scripts\validate.ps1
```

If any enabled artifact still has a placeholder checksum, the real run must fail. This is intentional and protects offline installs from unverifiable files.

Bootstrap-generated `.opencodeplay\env.ps1`, `.opencodeplay\activate-opencodeplay.ps1`, and `.opencodeplay\state.json` are local generated outputs. They should be verified during a test run, but they are not source bundle inputs and do not belong under `artifacts/`.
