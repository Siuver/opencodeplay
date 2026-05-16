# OpenCode Tool Templates

Place custom OpenCode tool definitions here when they are safe to copy into `.opencode/tools/`.

Tool templates must be declarative and must not contain secrets. Any tool that calls network services, writes outside the repo, or depends on credentials must be approval-gated in `manifests/opencode.json`.
