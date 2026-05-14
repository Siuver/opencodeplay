# AGENTS.md

This repository is intended for long-term maintenance as an agent-operated guide for setting up an `opencode`-centered workstation, including offline and reproducible environments. Treat these instructions as the durable project contract for any LLM agent or human maintainer working in this repo.

## Project Mission

`opencodeplay` helps a user and agent choose, execute, and verify a complete `opencode` environment. It should support:

- Interactive setup conversations that collect only the decisions that affect the outcome.
- Profiles and recipes for core CLI, offline core, full workstation, compatibility builds, plugins, MCP, and activation.
- Offline-first execution paths for the core toolchain using pre-seeded artifacts when the user chooses that path.
- Online fallback only when versions, URLs, and checksums are pinned.
- Long-term maintainability through guidance docs, pinned-artifact metadata, reproducible artifacts, and validation helpers.

## Source of Truth

- User answers and the selected setup profile are the source of truth for setup intent.
- `docs/setup-conversation.md` defines the interactive question flow.
- `docs/agent-runbook.md` defines the delegated-agent workflow.
- `manifests/pinned-artifacts.json` is the optional execution backend for pinned artifact metadata: tool names, versions, source URLs, artifact names, checksums, install behavior, and validation behavior for automatable components.
- `artifacts/` is the offline cache. File names must match the pinned-artifact catalog exactly when that backend is used.
- `scripts/bootstrap.ps1` is an optional artifact fetch/stage helper.
- `scripts/validate.ps1` is an optional strict verifier for pinned-artifact staging.
- `README.md` and `docs/start-here.md` are the human and agent entrypoints.
- `docs/offline-bundle.md` explains how to prepare a transferable offline bundle.

If these files disagree, fix the disagreement instead of choosing whichever behavior is convenient.

## Maintenance Rules

- Keep the repo guidance-first: docs decide intent, pinned-artifact metadata decides reproducible execution inputs, scripts execute helper actions.
- Keep automated install/staging paths metadata-driven when they are used.
- Keep scripts idempotent. Running bootstrap or validation more than once must be safe.
- Prefer pinned release artifacts over vendored source trees.
- Vendor source only when offline rebuilds are explicitly required and documented.
- Do not use `latest` URLs for unattended setup.
- Do not invent versions, URLs, checksums, licenses, install commands, or validation commands.
- Do not add secrets, tokens, private keys, personal config, or machine-local credentials.
- Keep generated state under `.opencodeplay/` and keep it ignored by git.
- Keep large offline artifacts out of normal git history unless the maintainer explicitly chooses a private mirror or release-bundle workflow.

## Supply Chain Rules

- Every enabled real install must have a concrete SHA-256 checksum.
- Placeholder checksums are allowed only for planning with `-WhatIf`; real install/download paths must refuse them.
- Online downloads must use pinned-artifact metadata URLs and must verify SHA-256 before install.
- Validation entries must stay structured as `executable` plus `args`; do not use shell command strings.
- Install target paths must remain inside the configured install root.
- Archive extraction must reject unsafe entry paths such as rooted paths or `..` traversal.

## opencode-Specific Rules

- Prefer official `opencode` GitHub Release artifacts for offline setup.
- Use source snapshots only when there is a documented reason to bundle the Bun workspace and build dependencies.
- Windows artifact candidates include `opencode-windows-x64.zip`, `opencode-windows-x64-baseline.zip`, `opencode-windows-arm64.zip`, and optional desktop installer artifacts such as `opencode-desktop-win-x64.exe`.
- Document offline-sensitive behavior, including auto-update, model fetches, LSP downloads, npm plugins, provider packages, MCP servers, and local plugin paths.
- Prefer local plugins and local MCP definitions for the offline core. Treat npm plugins, provider package downloads, remote MCP OAuth, and model refresh as online-dependent extras unless their caches are explicitly bundled.

## Documentation Rules

- Keep README instructions honest about what is implemented now versus what still requires pinned metadata or artifacts.
- Keep the setup conversation and runbook actionable: exact questions, decision points, files to read, commands to run, failure reporting expectations.
- When adding an artifact-backed or automated installable tool, update both `manifests/pinned-artifacts.json` and the docs that explain when to offer, prepare, and validate it. For guidance-only capabilities, update the relevant docs or recipes without forcing them into the catalog.
- Include enough context for a future agent to continue while still asking high-value setup questions when choices affect the outcome.
- Favor concise, operational documentation over broad essays.

## Verification Rules

Before finishing any change that affects setup, manifests, artifacts, or docs, run the most relevant checks available:

```powershell
powershell.exe -NoProfile -Command "Get-Content -LiteralPath '.\manifests\pinned-artifacts.json' -Raw | ConvertFrom-Json | Out-Null"
.\scripts\bootstrap.ps1 -Mode Offline -WhatIf
.\scripts\validate.ps1
```

For script changes, also test the safety behavior with temporary artifacts when practical:

- Missing artifact fails clearly in offline mode.
- Placeholder checksum is tolerated only under `-WhatIf`.
- Real install fails with placeholder checksum.
- Real install succeeds with a temporary artifact and matching SHA-256 in a temporary pinned-artifacts file.
- Validation checks state/path for `stageOnly` tools.
- Temporary artifacts and `.opencodeplay/` state are cleaned up after tests.

If a check cannot be run, explain exactly why in the final report.

## Change Discipline

- Preserve existing user edits. Do not revert unrelated changes.
- Keep changes small, explicit, and reviewable.
- Update docs and scripts together when behavior changes.
- Do not commit unless the user explicitly asks.
- After significant implementation, perform a review pass focused on goal fit, script correctness, offline safety, and supply-chain risks.
