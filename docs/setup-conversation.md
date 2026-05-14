# Setup Conversation

Use this document to turn an open-ended “set up opencode” request into a concrete, user-approved plan. The goal is not to interrogate the user forever; ask concise questions that change the setup outcome.

## Conversation Principles

- Ask before making persistent machine changes.
- Do not ask about choices the repo can safely infer.
- Explain tradeoffs in plain language.
- Keep offline and checksum safety intact when downloads or artifacts are involved.
- Record unresolved items in the final report instead of hiding them.

## Fast Question Set

Ask these first when the user is available:

1. Is this machine online, offline, or using a pre-seeded offline bundle?
2. Do you want native Windows setup, WSL-focused setup, or both?
3. Do you need only the `opencode` CLI, or also desktop/plugins/MCP/local config?
4. Should setup be fastest-working or most reproducible?
5. May the setup persistently change the user PATH, or should activation stay session-only?
6. Are provider auth, model lists, remote MCP OAuth, or package downloads allowed during setup?

## Routing

Use the answers to choose a path:

- Online + CLI only + speed preferred -> Core CLI with script-assisted staging or direct guided steps. Any automated download/install still needs a pinned URL and concrete SHA-256; direct guided steps are for already-installed tools, manual configuration, or documented recipes.
- Offline/pre-seeded + reproducibility preferred -> Offline Core and `docs/offline-bundle.md`.
- Compatibility concern -> Compatibility Baseline, but enable the baseline artifact intentionally.
- Desktop requested -> Full Workstation with desktop recipe; treat GUI validation as manual unless automation is added.
- Plugins/MCP requested -> Full Workstation; prefer local plugin/MCP definitions for offline-safe setups.

## Plan Reflection Template

Before execution, reflect the plan like this:

```text
I will set this up as: <profile>.
I will use: <native Windows/WSL/both>.
I will install or stage: <capabilities>.
I will avoid: <network/persistent PATH/auth/etc.>
I will validate with: <commands/checks>.
Items that may need later user action: <auth/plugin cache/MCP credentials/etc.>
```

## Configuration Boundaries

Ask before touching these areas:

- Persistent user or machine PATH.
- Auth tokens, provider login, OAuth, or remote MCP credentials.
- Global package-manager state.
- Existing `.opencode`, shell profiles, editor settings, or private config.

Do not ask before safe reads, dry runs, checksum verification, or session-only activation.

## Final Report Template

End with:

- Profile selected and why.
- Capabilities configured.
- Helper scripts or commands run.
- Validation results.
- Anything intentionally skipped.
- Next user action, especially auth or offline artifact preparation.
