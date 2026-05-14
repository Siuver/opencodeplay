# Offline Core Profile

Use this profile when the target machine is offline, mostly offline, or must be set up from a transferable bundle.

## Includes

- Core CLI capability from a pre-seeded artifact.
- Strict artifact filename and SHA-256 matching.
- Offline-safe environment defaults.
- Dry-run and validation steps for the pinned-artifact backend.

## Rules

- Do not use package managers, browser downloads, remote auth, model refreshes, or remote MCP OAuth on the target machine.
- If an artifact is missing, report the expected filename and where to place it.
- If a checksum is missing or placeholder-only, stop before a real install.

## Recipes

- `docs/recipes/opencode-cli.md`
- `docs/recipes/environment-activation.md`
- `docs/offline-bundle.md`
