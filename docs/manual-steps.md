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

## Dynamic Context Pruning Plugin

The desired DCP plugin is `@tarquinen/opencode-dcp@3.1.12`. It is approval-gated because installation uses OpenCode's plugin mechanism, can involve network/Bun/npm cache activity, and may update global OpenCode plugin configuration.

Review and approve before running:

```powershell
opencode plugin @tarquinen/opencode-dcp@3.1.12 --global
```

The repo keeps project-local DCP settings in `.opencode/dcp.jsonc` with `autoUpdate` disabled. After approved installation, restart OpenCode and verify manually with `/dcp` and `/dcp context`.
