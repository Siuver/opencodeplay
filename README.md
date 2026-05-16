# OpenCode Environment Bootstrap Blueprint

This repo defines an agent-led OpenCode environment setup. The intended interaction is:

1. Clone the repo.
2. Tell an agent to follow the repo instructions.
3. Let the agent detect the machine state, converge it toward the declared desired state, verify the result, and report anything that still needs human action.

The repo should behave like a control plane, not like a long checklist. Prose explains intent; manifests declare desired state; scripts perform idempotent changes; `doctor` verifies the result.

## Agent Quickstart

When an agent starts from this repo, it should follow this sequence:

1. Read `AGENTS.md` for execution rules and safety boundaries.
2. Read `manifests/profiles/default.json` or the profile named by the user.
3. Read every path in the profile's `manifest_refs` list.
4. Resolve capability IDs through `manifests/capabilities.json`; do not infer manifest names from capability names.
5. Detect the local machine facts: OS, shell, package managers, network access, admin rights, WSL/native preference, and existing OpenCode installation.
6. Produce a short plan that separates actions into `auto-safe`, `auto-with-approval`, `manual-required`, and `unsupported`.
7. Run `scripts/bootstrap` only for allowed automatic actions.
8. Run `scripts/doctor` after every setup or update attempt.
9. Report changed items, skipped items, verification results, and manual follow-ups.

## Primary Commands

The currently implemented verification entrypoint is:

```powershell
.\scripts\doctor.ps1 -Profile default
```

The planned convergence entrypoints are `scripts/bootstrap.ps1` for setup and `scripts/upgrade.ps1` for managed updates. Until those exist, agents must not infer setup actions from prose alone; they should use `scripts/doctor.ps1` to validate manifests and report blocked/manual work.

Equivalent shell scripts may be added later for WSL/Linux/macOS:

```sh
./scripts/bootstrap.sh --profile default
./scripts/doctor.sh --profile default
./scripts/upgrade.sh --profile default
```

Avoid making agents infer setup from scattered docs. If a setup path matters, make it reachable through one of these commands and represent the desired state in manifests.

## Desired-State Rule

For every declared tool or capability, the agent applies this convergence rule:

- Missing and enabled: install.
- Present but below policy: update.
- Present and acceptable: skip.
- Present but misconfigured: repair if safe.
- Sensitive or persistent global change: ask unless pre-approved.
- Unsupported on this machine/profile: skip with reason.

## Automation Classes

Every item in a manifest must declare one automation class:

- `auto-safe`: safe to run without asking, such as local verification, repo-local config sync, or installing into repo-owned/cache-owned paths.
- `auto-with-approval`: requires explicit approval, such as editing PATH, writing shell profiles, installing global packages, or changing system config.
- `manual-required`: cannot be automated safely, such as provider login, API key entry, or GUI confirmation.
- `unsupported`: intentionally declared but not currently implemented for this platform/profile.

This classification is what prevents agents from confusing "can be done" with "should be done automatically".

## Source Of Truth

- `AGENTS.md`: how agents must behave.
- `manifests/profiles/*.json`: which capabilities are in scope.
- `manifests/capabilities.json`: mapping from capability ids to concrete manifest files.
- `manifests/tools.json`: tool installation/update/verification policy.
- `manifests/opencode.json`: OpenCode-specific config, skills, agents, commands, plugins, and MCP policy.
- `scripts/bootstrap.*`: converge desired state.
- `scripts/doctor.*`: verify desired state.
- `scripts/upgrade.*`: update existing managed state.
- `docs/manual-steps.md`: auth and other human-only steps.

## OpenCode-Specific Guidance

OpenCode should be treated as both a managed tool and the agent runtime being customized.

The repo should declare:

- how to detect OpenCode, usually `opencode --version`;
- how to install it when missing, using official install paths for the target OS;
- how to update it when present, preferably `opencode upgrade` or the original package manager;
- where repo-local OpenCode assets live, such as `.opencode/agents`, `.opencode/skills`, `.opencode/plugins`, `.opencode/commands`, and `.opencode/tools`;
- which auth steps are manual-only;
- which plugin/MCP steps require network, Bun, or user approval.

Do not store provider credentials or API keys in this repo. Authentication steps belong in `docs/manual-steps.md` and verification should report whether auth is pending.

## Done Definition

A setup run is complete only when:

1. `scripts/doctor` passes for all `auto-safe` and approved `auto-with-approval` items.
2. The final report lists all installed, updated, skipped, repaired, failed, and manual-required items.
3. No secrets were written to git-tracked files.
4. Any persistent user or system change is explicitly reported.
5. The agent can explain how to rerun `bootstrap`, `doctor`, and `upgrade` safely.
