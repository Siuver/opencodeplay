# Full Workstation Profile

Use this profile when the user wants more than the core CLI: desktop app, local plugins, local MCP definitions, provider setup guidance, or future companion plugins.

## Includes As Chosen

- Core CLI setup.
- Desktop installer staging when requested.
- Local plugin guidance.
- Local MCP guidance.
- Provider/auth checklist without storing secrets in the repo.
- DCP plugin planning only until checksum and offline cache behavior are proven.

## Guardrails

- Keep secrets, tokens, OAuth state, and private provider config out of the repository.
- Prefer local plugin and local MCP paths for offline-safe environments.
- Treat package-manager downloads as online-dependent unless a cache strategy is documented.

## Recipes

- `docs/recipes/opencode-cli.md`
- `docs/recipes/desktop-app.md`
- `docs/recipes/local-plugins.md`
- `docs/recipes/local-mcp.md`
- `docs/recipes/provider-auth.md`
- `docs/recipes/dcp-plugin.md`
- `docs/recipes/environment-activation.md`
