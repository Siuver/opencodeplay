# Agent Runbook

This runbook is for an LLM agent helping a user set up an `opencode`-centered workstation. The goal is to guide the setup through a short conversation, choose the right profile, execute the relevant helper steps, and report the result clearly.

## Operating Contract

- Read `README.md`, `docs/start-here.md`, `docs/setup-conversation.md`, and this file before changing setup behavior. Read `manifests/pinned-artifacts.json` only when the selected path needs reproducible artifact staging.
- Treat the user's answers as the source of setup intent.
- Treat `manifests/pinned-artifacts.json` as the optional backend catalog for pinned artifact metadata.
- Use `scripts/bootstrap.ps1` and `scripts/validate.ps1` as helper executors when the selected plan needs pinned-artifact staging.
- Prefer offline artifacts from `artifacts/` when the user chooses offline or reproducible setup.
- Use online downloads only when the pinned-artifact backend provides a pinned URL and concrete SHA-256 checksum.
- Never invent versions, URLs, checksums, licenses, install commands, validation commands, secrets, or credentials.

## Flow

1. Read the entry docs and inspect the target machine constraints.
2. Ask the fast question set from `docs/setup-conversation.md` unless the answers are already known.
3. Select a profile: Core CLI, Offline Core, Full Workstation, or Compatibility Baseline.
4. Reflect the plan back to the user in plain English before persistent changes.
5. Execute only the setup steps that match the selected profile.
6. Use scripts only for pinned artifacts and reproducible staging when the chosen profile calls for them.
7. Validate the selected capabilities.
8. Report what is ready, what was skipped, and what still needs user action.

## When to Ask

Ask concise questions when an answer changes the setup:

- Native Windows, WSL, or both.
- Online, offline, or pre-seeded bundle.
- CLI only, desktop, plugins, MCP, or full workstation.
- Fastest-working setup or reproducible setup.
- Session-only activation or persistent PATH update.
- Whether auth, OAuth, model refresh, or package-manager downloads are allowed.

Do not ask about safe reads, dry runs, checksum verification, or non-persistent inspection.

## Script-Assisted Path

Use this path when the chosen profile maps to enabled pinned artifacts.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\bootstrap.ps1 -Mode Auto
.\scripts\validate.ps1
```

Use `-Mode Offline` when the user selected an offline bundle. Use `-WhatIf` to inspect readiness without writing install state. Use `-AddToUserPath` only when the user explicitly allows persistent PATH changes.

After bootstrap, dot-source the activation helper only when immediate session access is useful:

```powershell
. .\.opencodeplay\activate-opencodeplay.ps1
opencode --version
```

## opencode Guidance

- Preferred native Windows core: pinned CLI release archive from the artifact catalog.
- Compatibility build: use the baseline artifact only when the target PC needs it.
- Desktop app: optional and separate from CLI readiness.
- Offline-safe extras: local plugins and local MCP definitions.
- Online-dependent extras: NPM plugins, provider package downloads, remote MCP OAuth, and model refreshes unless their caches are bundled.
- Desired DCP companion: `@tarquinen/opencode-dcp` version `3.1.11`; keep disabled until its checksum and offline plugin-cache/install path are tested.

## Offline Rules

In offline mode, do not try package managers, curl, winget, npm, bun, git clone, browser downloads, remote provider auth, or remote MCP OAuth. Only use files already present in this repository.

If setup cannot continue, report:

- Capability or tool name.
- Expected artifact file.
- Expected version.
- Where the artifact should be placed.
- Pinned-artifact field or doc recipe that needs to be updated.

## Validation Rules

Validation should match the selected profile:

- For pinned-artifact staging, run `scripts/validate.ps1` and report failures exactly.
- For session activation, run `opencode --version` after dot-sourcing the activation script.
- For desktop setup, report whether the installer was staged and what manual GUI validation remains.
- For plugins/MCP/auth, validate only what was configured and list what requires later user action.

Strict pinned-artifact validation succeeds only when every enabled catalog entry either runs its declared validation command successfully, or is marked `stageOnly`, appears in `.opencodeplay/state.json`, and has an existing staged target path.
