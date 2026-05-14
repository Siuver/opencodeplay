# Provider/Auth Recipe

This recipe guides provider authentication and model access checks without storing secrets in this repository.

## When to Offer

- The user allows provider auth, model refresh, remote MCP OAuth, or other account-backed setup.
- A profile needs to verify that `opencode` can see expected providers or models after the user authenticates.
- The setup is online or the user already has local auth/session state prepared.

## Boundaries

- Never write tokens, API keys, OAuth state, or private provider config into this repo.
- Ask before launching any login flow or changing global/user-level auth state.
- Treat remote provider metadata, model refreshes, and remote MCP OAuth as online-dependent unless their caches are explicitly bundled.
- In offline profiles, document auth as a user action to complete later unless valid local state already exists.

## Execution Options

- Guided manual path: explain the required provider action, let the user complete it in their normal secret store or `opencode` config location, then validate.
- Session-only validation: run read-only checks that report configured auth and model visibility without persisting new credentials.
- Deferred path: record which providers, models, or MCP auth flows remain blocked by offline mode or missing credentials.

## Validation

- `opencode auth list`
- `opencode models`
- `opencode debug config`
- `opencode mcp list` when MCP auth is part of the selected setup.

## Final Report Notes

- List which providers or model sources were verified.
- List any login or OAuth steps the user intentionally deferred.
- State that no secrets were stored in this repository.
