# Manual Steps

This file records setup work that agents must not automate.

## Provider Authentication

Provider login is manual-required because it may involve browser OAuth, API keys, MFA, or account consent.

Run the login command yourself when needed:

```powershell
opencode auth login
```

Then verify without exposing secrets:

```powershell
opencode auth list
```

Agents may report whether a provider appears configured, but they must not copy, print, or persist credentials.

## Approval-Gated Work

Ask before any action that changes global OpenCode config, shell profiles, PATH, plugins, MCP servers, system packages, or network-installed tools.
