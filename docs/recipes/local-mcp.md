# Local MCP Recipe

This recipe covers local MCP definitions for an `opencode` workstation.

## Preferred Shape

- Prefer local MCP server definitions for offline core setups.
- Keep remote MCP OAuth and hosted dependencies out of offline profiles unless explicitly allowed by the user.
- Document any local server executable, arguments, expected files, and validation command.

## Guardrails

- Do not commit credentials, OAuth tokens, or private endpoint secrets.
- Ask before modifying existing user MCP config.
- Validate only the MCP definitions that were actually configured.
