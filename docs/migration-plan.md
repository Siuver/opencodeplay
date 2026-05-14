# Migration Plan

This repo is moving from a script-first bootstrap kit to a guidance-first setup framework. The goal is to make the interactive agent flow the primary experience while preserving the useful offline, checksum, and validation machinery.

## New Product Shape

- `README.md` and `docs/start-here.md` explain setup paths and profiles.
- `docs/setup-conversation.md` defines the interactive Q&A flow.
- `docs/agent-runbook.md` tells agents how to plan, execute, and validate.
- `docs/offline-bundle.md` remains the specialist guide for transferable offline bundles.
- `manifests/pinned-artifacts.json` is the optional backend catalog for automatable pinned artifacts.
- `scripts/bootstrap.ps1` and `scripts/validate.ps1` remain helper executors, not the default user experience.

## Keep

- Pinned artifact URLs and versions.
- Concrete SHA-256 checksums for real installs.
- Refusal to run real downloads/installs with placeholder checksums.
- Offline artifact cache under `artifacts/`.
- Install-root containment and archive path safety.
- Generated `.opencodeplay\env.ps1`, activation script, and state file.
- Structured validation entries as `executable` plus `args`.

## Change

- Reframe the repo as agent-guided setup, not a PowerShell installer.
- Treat user answers as the source of setup intent.
- Treat profiles and recipes as the bridge between intent and execution.
- Validate selected capabilities instead of assuming every manifest entry is part of every setup.
- Move script commands lower in the docs and invoke them only after a plan chooses them.

## Demote

- `manifests/pinned-artifacts.json`: from complete environment model to optional pinned-artifact backend.
- `scripts/bootstrap.ps1`: from primary setup experience to artifact fetch/stage helper.
- `scripts/validate.ps1`: from universal success definition to strict verifier for pinned-artifact paths.
- `docs/offline-bundle.md`: from implicit core flow to optional offline/reproducible workflow.

## Future Work

- Add profile docs under `docs/profiles/` when the initial conversation model stabilizes.
- Add recipe docs under `docs/recipes/` for CLI, desktop, DCP, local plugins, local MCP, and activation.
- Consider extending `pinned-artifacts.json` with optional interaction metadata only after the docs prove what metadata is useful.
- Make validation track-aware while retaining strict mode for offline/reproducible bundles.
