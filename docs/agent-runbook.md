# Agent Runbook

This runbook is written for an LLM agent operating on a fresh PC. The goal is to complete environment setup without asking the user for routine decisions.

## Operating Contract

- Read `README.md`, this file, `manifests/tools.json`, and the scripts before acting.
- Treat `manifests/tools.json` as the source of truth.
- Prefer offline artifacts from `artifacts/`.
- Use online downloads only when the manifest provides a pinned URL and checksum.
- Never invent versions, URLs, checksums, or install commands.
- For `opencode`, prefer pinned release archives over vendored source unless source builds are explicitly required.
- Stop only when a required offline artifact is missing and network access is unavailable.

## Setup Flow

1. Check the OS and PowerShell version.
2. Inspect `manifests/tools.json` for enabled tools.
3. For each enabled tool, verify whether the declared offline artifact exists.
4. If online access is available and an artifact is missing, let `scripts/bootstrap.ps1 -Mode Online` download only entries with concrete manifest URLs and SHA-256 checksums.
5. Verify SHA-256 checksums for all artifacts that declare a checksum.
6. Run `scripts/bootstrap.ps1 -Mode Auto`.
7. Dot-source `.opencodeplay\activate-opencodeplay.ps1` in the current PowerShell session when you need immediate `opencode` PATH access.
8. Use `scripts/bootstrap.ps1 -Mode Auto -AddToUserPath` only when the user explicitly wants persistent user PATH wiring.
9. Run `scripts/validate.ps1`.
10. Report installed tools, skipped tools, generated activation files, failures, and the exact next action for any unresolved item.

## opencode-Specific Guidance

- Preferred offline core: CLI release archive, starter config, local plugins, and optional local MCP server definitions.
- Online fallback only: package-manager installs, NPM plugins, provider package downloads, remote MCP OAuth, and model refreshes.
- Windows-first artifact candidates: `opencode-windows-x64.zip`, `opencode-windows-x64-baseline.zip`, `opencode-windows-arm64.zip`, and optional desktop installer.
- Bootstrap-generated `.opencodeplay\env.ps1` sets `OPENCODE_DISABLE_AUTOUPDATE=1`, `OPENCODE_DISABLE_MODELS_FETCH=1`, and `OPENCODE_DISABLE_LSP_DOWNLOAD=1`.
- Bootstrap-generated `.opencodeplay\activate-opencodeplay.ps1` dot-sources `env.ps1` and prepends the staged `opencode` directory to PATH for the current session.
- Useful validation commands after a real install: `opencode --version`, `opencode debug config`, `opencode auth list`, `opencode models`, and `opencode mcp list`.

## Offline Rules

In offline mode, do not try package managers, curl, winget, npm, bun, git clone, or browser downloads. Only use files already present in this repository.

If setup cannot continue, report a table with:

- Tool name.
- Expected artifact file.
- Expected version.
- Where the artifact should be placed.
- Manifest field that needs to be updated.

## Online Rules

In online mode, downloads must be pinned and verifiable. If a manifest entry lacks a concrete `source.url` or `artifact.sha256`, treat that entry as not ready for unattended setup. Do not bypass checksum failures.

## Validation Rules

Validation succeeds only when every enabled tool either:

- Runs its declared validation command successfully, or
- Is explicitly marked as `stageOnly`, appears in `.opencodeplay/state.json`, and has an existing staged target path.

After bootstrap has written `.opencodeplay/state.json`, validation also expects generated `.opencodeplay\env.ps1` and `.opencodeplay\activate-opencodeplay.ps1` to exist.

Validation commands must stay structured in the manifest as `executable` plus `args`. Do not replace them with shell strings.
