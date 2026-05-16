---
name: opencode-bootstrap
description: Follow this repository's desired-state manifests to validate and safely converge an OpenCode environment.
---

# OpenCode Bootstrap

Use this skill when working from this repository to validate or converge the declared OpenCode environment.

## Workflow

1. Read `AGENTS.md` first.
2. Read the selected profile under `manifests/profiles/`.
3. Read every manifest referenced by the profile and `manifests/capabilities.json`.
4. Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\doctor.ps1 -Profile default`.
5. Execute only `auto-safe` actions. Ask before `auto-with-approval`. Report `manual-required` and `unsupported` items.

## Safety

- Never store credentials in this repo.
- Treat provider login as manual-required.
- Treat plugin, MCP, network install, global config, shell profile, and PATH changes as approval-gated.
- Run doctor again after any change.
