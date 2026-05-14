# Core CLI Profile

Use this profile when the user wants a practical native Windows `opencode` CLI setup with the smallest useful surface area.

## Includes

- `opencode` CLI staged or installed for the selected shell.
- Session activation guidance.
- Optional offline-safe environment defaults when the user wants local/reproducible behavior.
- Validation with `opencode --version` or the pinned-artifact verifier when the backend is used.

## Does Not Include By Default

- Desktop app.
- Plugin installation.
- MCP server setup.
- Provider auth or remote OAuth.
- Persistent PATH changes unless the user explicitly chooses them.

## Recipes

- `docs/recipes/opencode-cli.md`
- `docs/recipes/environment-activation.md`
