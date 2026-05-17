# Dynamic Context Pruning Plugin

Desired package: `@tarquinen/opencode-dcp@3.1.12`

Install only after approval:

```powershell
opencode plugin @tarquinen/opencode-dcp@3.1.12 --global
```

This plugin is approval-gated because it can use network/Bun/npm cache activity, update global OpenCode plugin configuration, register `/dcp`, expose a `compress` tool, and change effective OpenCode permissions. Keep project-local settings in `.opencode/dcp.jsonc` with `autoUpdate` disabled.
