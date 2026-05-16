---
name: opencode-bootstrap
description: Validate and converge this repository's OpenCode desired-state manifests without touching secrets or global configuration unless explicitly approved.
---

# OpenCode Bootstrap Skill

Use this skill when working in this repository to set up or verify OpenCode and related local assets.

## Workflow

1. Read `AGENTS.md` completely.
2. Read the selected profile under `manifests/profiles/`.
3. Read every manifest referenced by the profile and by `manifests/capabilities.json`.
4. Run `scripts/doctor.ps1 -Profile default` before and after changes.
5. Apply only `auto-safe` changes without approval.
6. Report `auto-with-approval`, `manual-required`, and `unsupported` items clearly.

## Safety Rules

- Do not store provider credentials in this repo.
- Do not automate `opencode auth login`.
- Do not modify PATH, shell profiles, global OpenCode config, plugins, or MCP servers without approval.
- Prefer copy-if-missing behavior unless an ownership marker proves a target is repo-managed.
