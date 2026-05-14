# Local Plugins Recipe

This recipe covers offline-safe plugin strategy.

## Preferred Shape

- Use local plugin files under `.opencode/plugins/` or the user's opencode config plugin directory.
- Document plugin source, version, license, and validation notes.
- Avoid package-manager plugin installs in offline profiles unless the cache is bundled and tested.

## Guardrails

- Do not store secrets or personal config in this repo.
- Do not use `latest` for unattended plugin setup.
- Keep online-only plugin steps separate from offline-safe recipes.
