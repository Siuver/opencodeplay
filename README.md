# opencodeplay

`opencodeplay` is a hybrid new-PC bootstrap kit for setting up an agent-ready development environment centered on [opencode](https://github.com/anomalyco/opencode). It is designed to work in two situations:

- **Online mode:** fetch pinned tools from their upstream sources.
- **Offline mode:** install from pre-seeded files under `artifacts/`.
- **Auto mode:** prefer offline artifacts when present, then fall back to online sources.

The repository is intentionally agent-friendly: the README explains the desired end state, `manifests/tools.json` declares what to install, and `scripts/bootstrap.ps1` provides a single entrypoint that a human or LLM agent can run repeatedly.

## Current Status

The core Windows x64 `opencode` CLI is pinned in `manifests/tools.json` and can be cached under `artifacts/` for offline installs. Optional baseline and desktop entries are documented and pinned but disabled by default. Real install or download runs refuse placeholder checksums; `-WhatIf` is the only mode that tolerates placeholders for planning.

## Desired End State

After a successful run, the target PC should have:

- `opencode` installed or staged in the configured install root.
- Required companion tools installed or staged from the same manifest.
- Generated offline-safe environment defaults and a session activation script under `.opencodeplay/`.
- A local record of what was installed under `.opencodeplay/state.json`.
- Validation commands passing for every enabled manifest entry.

## Repository Layout

```text
opencodeplay/
  README.md                    # Human and agent entrypoint
  artifacts/                   # Offline cache; place pinned archives/binaries here
  docs/
    agent-runbook.md           # Detailed instructions for delegated LLM setup
    offline-bundle.md          # How to prepare and verify an offline bundle
  manifests/
    tools.json                 # Source of truth for tools, versions, artifacts, checksums
  scripts/
    bootstrap.ps1              # Idempotent installer/stager
    validate.ps1               # Validation wrapper
```

## Quick Start

Run from a PowerShell terminal at the repository root:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\bootstrap.ps1 -Mode Auto
.\scripts\validate.ps1
```

The quick start succeeds only after the enabled manifest entries have concrete artifact names, URLs, and checksums. Until then, use `-WhatIf` to inspect the setup plan safely.

Useful options:

```powershell
.\scripts\bootstrap.ps1 -Mode Offline
.\scripts\bootstrap.ps1 -Mode Online
.\scripts\bootstrap.ps1 -InstallRoot "$env:USERPROFILE\.opencodeplay\tools"
.\scripts\bootstrap.ps1 -Mode Offline -AddToUserPath
```

Bootstrap always writes `.opencodeplay\env.ps1` with offline defaults for `OPENCODE_DISABLE_AUTOUPDATE`, `OPENCODE_DISABLE_MODELS_FETCH`, and `OPENCODE_DISABLE_LSP_DOWNLOAD`. It also writes `.opencodeplay\activate-opencodeplay.ps1`; dot-source it to apply the offline defaults and prepend staged `opencode` to PATH for the current PowerShell session:

```powershell
. .\.opencodeplay\activate-opencodeplay.ps1
opencode --version
```

Use `-AddToUserPath` only when you want bootstrap to persistently prepend the staged `opencode` directory to the Windows user PATH. Open a new terminal after using that option.

## Agent Prompt

Paste this to an LLM agent when setting up a new PC:

```text
You are setting up this PC using the local opencodeplay repository. Read README.md, docs/agent-runbook.md, manifests/tools.json, and scripts/bootstrap.ps1. Do not guess missing versions or checksums. Prefer offline artifacts in artifacts/. If required artifacts are missing and the PC is online, download only pinned sources from the manifest, verify SHA-256 checksums, then run scripts/bootstrap.ps1 -Mode Auto and scripts/validate.ps1. If the PC is offline and required artifacts are missing, stop with a precise list of missing files.
```

## Hybrid Strategy

`opencodeplay` should not blindly vendor entire upstream repositories unless there is a specific offline reason. Prefer this order:

1. **Pinned release artifacts** for tools that publish stable binaries or archives.
2. **Package-manager caches** when the tool is normally installed through a package ecosystem.
3. **Vendored source snapshots** only when building from source offline is necessary.

For `opencode`, prefer official GitHub Releases artifacts over source snapshots. Upstream source is a Bun workspace, so source-first offline setup requires bundling Bun and build dependencies too. For Windows, useful release channels include CLI archives such as `opencode-windows-x64.zip`, `opencode-windows-x64-baseline.zip`, and `opencode-windows-arm64.zip`; desktop installers use names such as `opencode-desktop-win-x64.exe` and are separate optional artifacts.

Every vendored or cached item should have:

- Upstream URL.
- Version or commit.
- License note.
- SHA-256 checksum.
- Validation command.
- Update instructions.

## Preparing an Offline Bundle

1. On an online machine, confirm every enabled `manifests/tools.json` entry has real pinned values.
2. Either download each enabled artifact into `artifacts/` using the exact manifest file names, or run `.\scripts\bootstrap.ps1 -Mode Online -WhatIf` to confirm the pinned download plan.
3. Run `Get-FileHash -Algorithm SHA256 artifacts\<file>` and copy each hash into the manifest when artifacts are downloaded manually.
4. Run `.\scripts\bootstrap.ps1 -Mode Offline -WhatIf` to verify that all offline inputs exist.
5. Run `.\scripts\bootstrap.ps1 -Mode Offline` and `.\scripts\validate.ps1` on a test machine or disposable install root.
6. Package the repository directory, including `artifacts/`, for transfer to the offline PC.

## Offline opencode Notes

- Upstream recommends WSL for the best Windows experience; native Windows artifacts are still useful for quick bootstrap.
- Bootstrap generates `.opencodeplay\env.ps1` to disable dynamic network behavior with `OPENCODE_DISABLE_AUTOUPDATE`, `OPENCODE_DISABLE_MODELS_FETCH`, and `OPENCODE_DISABLE_LSP_DOWNLOAD`.
- Prefer local plugins under `.opencode/plugins/` or the user config plugin directory. NPM plugins and provider packages may trigger Bun/package downloads unless their caches are also pre-staged.
- Useful validation commands after a real install are `opencode --version`, `opencode debug config`, `opencode auth list`, `opencode models`, and `opencode mcp list`.
- Use `opencode --pure` when diagnosing packaged plugin or configuration problems.

## Maintainer Rules

- Keep `manifests/tools.json` as the source of truth.
- Keep bootstrap scripts idempotent; running them twice should be safe.
- Do not add unpinned online install commands to the README.
- Keep validation entries structured as `executable` plus `args`; do not add shell command strings.
- Do not commit secrets, tokens, private SSH keys, or machine-local config.
- Prefer small, explicit manifests over large undocumented vendored trees.
