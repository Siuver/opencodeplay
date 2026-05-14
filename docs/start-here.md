# Start Here

This repo helps an agent and user design an `opencode` workstation before running setup commands. Start by choosing the setup path, then use the conversation guide to collect the few answers that change the plan.

## The Rule

Conversation decides intent. Profiles decide scope. Recipes explain capabilities. The pinned-artifact backend and scripts execute only the reproducible parts of the chosen plan.

## Choose a Path

| Path | Use when | Primary docs | Helper commands |
| --- | --- | --- | --- |
| Guided setup | The user is present and wants a tailored setup | `docs/setup-conversation.md`, `docs/agent-runbook.md` | Optional |
| Delegated setup | The user wants an agent to drive setup with minimal back-and-forth | `docs/agent-runbook.md` | Optional |
| Offline/reproducible setup | The target machine is offline or must be transferable | `docs/offline-bundle.md` | `scripts/bootstrap.ps1`, `scripts/validate.ps1` |
| Pinned-artifact execution | The desired profile maps directly to pinned artifacts | `manifests/pinned-artifacts.json`, script help output | `scripts/bootstrap.ps1`, `scripts/validate.ps1` |

## Initial Profiles

### Core CLI

Choose this for a normal Windows x64 machine where the goal is to get the `opencode` CLI staged and usable. The reproducible helper path uses the pinned `opencode` artifact.

### Offline Core

Choose this when artifacts are already present or the setup must be moved to an offline machine. This profile uses the same core CLI capability but treats checksums, artifact names, and dry runs as mandatory.

### Full Workstation

Choose this when the user wants more than the CLI: desktop app, local plugins, local MCP definitions, provider setup guidance, or future companion plugins. Some capabilities may remain planned until pinned artifacts and cache behavior are verified.

### Compatibility Baseline

Choose this only when the target Windows x64 machine needs the upstream baseline build for compatibility. The baseline artifact is disabled by default in the pinned-artifact backend and should be enabled intentionally.

## Agent Starting Checklist

Before executing anything, collect these facts:

- Target OS and whether WSL is allowed or preferred.
- Online, offline, or hybrid connectivity.
- CLI-only, desktop, or richer workstation scope.
- Whether reproducibility or speed matters more.
- Whether persistent PATH changes are allowed.
- Whether plugins, MCP servers, provider auth, or local-only defaults are desired.

Then summarize the chosen path and run only the relevant setup steps.
