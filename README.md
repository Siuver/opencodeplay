# opencodeplay

`opencodeplay` is a guidance-first workspace setup kit for building an `opencode`-centered environment with an agent. The main product is the conversation, plan, and runbook that help the user decide what kind of workstation they want; scripts and pinned-artifact metadata are optional execution helpers for paths that need reproducible staging.

The repo supports four setup styles:

- **Guided setup:** an agent asks focused questions, chooses a profile, and applies only the relevant recipes.
- **Delegated setup:** the user hands the repo to an agent and expects an interactive but efficient setup session.
- **Offline/reproducible setup:** artifacts are pre-seeded, checksums are verified, and scripts provide deterministic staging.
- **Pinned-artifact execution:** maintainers can still run the existing bootstrap and validation helpers when the chosen plan needs reproducible artifact staging.

## Current Status

The core Windows x64 `opencode` CLI is pinned in `manifests/pinned-artifacts.json` and can be cached under `artifacts/` for offline installs. Optional baseline and desktop entries are pinned but disabled by default. `opencode-dynamic-context-pruning` is tracked as a desired companion plugin, but remains disabled until its npm tarball checksum and offline plugin-cache strategy are verified.

Real install or download runs still refuse placeholder checksums. `-WhatIf` is the only mode that tolerates placeholders for planning.

## Start Here

If a human or agent is setting up a machine, start with these docs in order:

1. `docs/start-here.md` - choose the setup path and profile.
2. `docs/setup-conversation.md` - ask the user the questions that shape the plan.
3. `docs/agent-runbook.md` - execute the chosen plan safely.
4. `docs/offline-bundle.md` - use only when preparing or consuming an offline bundle.

The short agent handoff prompt is:

```text
You are setting up an opencode-centered workstation using this local opencodeplay repo. Start with README.md, docs/start-here.md, docs/setup-conversation.md, and docs/agent-runbook.md. Ask concise setup questions before executing. Use manifests/pinned-artifacts.json only as the optional execution backend for pinned artifact metadata. Use scripts/bootstrap.ps1 and scripts/validate.ps1 as helper executors when the selected profile calls for reproducible artifact staging. Do not invent versions, URLs, checksums, install commands, secrets, or credentials.
```

## Desired End State

After a successful guided setup, the target PC should have the capabilities the user actually chose, such as:

- `opencode` CLI installed or staged and available for the selected shell/session.
- Offline-safe environment defaults when the user chooses local/reproducible behavior.
- Optional desktop, baseline, plugin, MCP, or local configuration guidance when selected.
- A clear report of what was configured, what still needs user action, and how to validate it.
- Reproducible artifact records when the setup path requires offline transfer or strict provenance.

Success is not always “every pinned artifact validates.” Success means the selected profile validates and unresolved choices are explicitly reported.

## Repository Layout

```text
opencodeplay/
  README.md                    # Human and agent entrypoint
  artifacts/                   # Offline cache; place pinned archives/binaries here
  docs/
    start-here.md              # Guide-first orientation and path selection
    setup-conversation.md      # Interactive Q&A for choosing a setup profile
    agent-runbook.md           # Agent workflow for planning, execution, validation
    migration-plan.md          # Current refactor direction and keep/change assessment
    offline-bundle.md          # Optional reproducible/offline packaging guide
    profiles/                  # Outcome profiles chosen from the setup conversation
    recipes/                   # Capability recipes composed by profiles
  manifests/
    pinned-artifacts.json      # Optional backend catalog for pinned artifacts
  scripts/
    bootstrap.ps1              # Optional artifact fetch/stage helper
    validate.ps1               # Optional strict verifier for pinned-artifact staging
```

## Setup Paths

### Guided setup

Use this when the user wants the agent to make the setup feel personal and useful instead of blindly running scripts.

1. Read `docs/start-here.md`.
2. Ask the questions in `docs/setup-conversation.md`.
3. Select a profile and explain the plan in plain English.
4. Execute only the relevant recipes and helper commands.
5. Validate the selected capabilities.

### Delegated agent setup

Use this when the user says “set this machine up for me.” The agent should still ask high-value questions about connectivity, native Windows vs WSL, CLI vs desktop, plugins/MCP, PATH persistence, and auth/config boundaries before taking action.

See `docs/agent-runbook.md`.

### Offline/reproducible setup

Use this when the target machine is offline, the setup must be transferable, or provenance matters more than speed.

See `docs/offline-bundle.md`.

### Pinned-artifact execution

Use this only after the selected plan calls for reproducible pinned-artifact staging.

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\bootstrap.ps1 -Mode Auto
.\scripts\validate.ps1
```

Useful helper options:

```powershell
.\scripts\bootstrap.ps1 -Mode Offline
.\scripts\bootstrap.ps1 -Mode Online
.\scripts\bootstrap.ps1 -Mode Offline -WhatIf
.\scripts\bootstrap.ps1 -InstallRoot "$env:USERPROFILE\.opencodeplay\tools"
.\scripts\bootstrap.ps1 -Mode Offline -AddToUserPath
```

Bootstrap writes `.opencodeplay\env.ps1` with offline defaults for `OPENCODE_DISABLE_AUTOUPDATE`, `OPENCODE_DISABLE_MODELS_FETCH`, and `OPENCODE_DISABLE_LSP_DOWNLOAD`. It also writes `.opencodeplay\activate-opencodeplay.ps1`; dot-source it to apply the defaults and prepend staged `opencode` to PATH for the current PowerShell session:

```powershell
. .\.opencodeplay\activate-opencodeplay.ps1
opencode --version
```

Use `-AddToUserPath` only when the user explicitly wants persistent user PATH wiring. Open a new terminal after using that option.

## Capability Strategy

Prefer capabilities and recipes over a single flat tool list:

- **Core CLI:** official `opencode` release artifact, staged or installed for the selected shell.
- **Compatibility CLI:** baseline artifact only when the target PC needs it.
- **Desktop app:** optional Windows desktop installer, staged separately from CLI validation.
- **Plugins and MCP:** prefer local plugins and local MCP definitions for offline-safe setups.
- **DCP plugin:** desired, pinned as a disabled candidate until checksum and offline cache behavior are proven.

`manifests/pinned-artifacts.json` is the optional backend catalog for pinned artifact metadata. It is not the setup model; user answers, profiles, and recipes decide what should happen.

## Maintainer Rules

- Keep the repo guidance-first: docs define intent, pinned-artifact metadata defines reproducible execution inputs, scripts execute helper actions.
- Keep automated install paths metadata-driven when they are used.
- Do not add unpinned online install commands.
- Do not invent versions, URLs, checksums, licenses, install commands, or validation commands.
- Do not commit secrets, tokens, private SSH keys, or machine-local config.
- Preserve offline/checksum safety even when the default user experience is interactive.
