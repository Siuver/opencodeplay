# Agent Execution Contract

This repo is a desired-state control plane for setting up OpenCode and related tools. Agents must converge the machine toward the declared state while protecting user data, secrets, and global configuration.

## Prime Directive

Read the manifests, detect reality, make only allowed changes, verify everything, and report exactly what changed.

Do not treat prose as permission to perform risky actions. Use the automation class on each manifest item.

## Required Startup Sequence

1. Read this file completely.
2. Read the selected profile under `manifests/profiles/`.
3. Read every manifest referenced by that profile and by `manifests/capabilities.json`.
4. Detect OS, shell, package managers, network access, admin rights, existing tool versions, and existing OpenCode config locations.
5. Build a plan grouped by automation class: `auto-safe`, `auto-with-approval`, `manual-required`, and `unsupported`.
6. Execute only `auto-safe` items and user-approved `auto-with-approval` items.
7. Run `scripts/doctor` after changes.
8. Produce the final report.

## Automation Classes

### `auto-safe`

Allowed without asking:

- read files and manifests;
- run detection commands;
- run verification commands;
- create repo-local generated state;
- copy or sync repo-local templates into repo-owned locations;
- install or update tools only when the manifest explicitly marks the method as safe for this platform and the action does not require network, admin, global config, shell profile, PATH, plugin dependency, or MCP changes.

### `auto-with-approval`

Ask before doing:

- modifying PATH;
- changing shell profiles;
- installing system-wide packages;
- changing global OpenCode config;
- enabling background services;
- using network for install, update, plugin, or MCP work;
- installing plugins that download dependencies;
- writing outside the repo or approved config/cache locations.

### `manual-required`

Never automate directly:

- provider login;
- API key entry;
- browser OAuth steps;
- desktop GUI confirmation;
- MFA, captcha, or account consent;
- anything that would reveal or persist a secret.

For manual-required items, print exact instructions and verification commands.

### `unsupported`

Skip and report with reason. Do not invent support for undeclared platforms or tools.

## Convergence Rules

For every enabled manifest item:

1. If missing, install when allowed.
2. If present and version is acceptable, skip.
3. If present and stale, update when allowed.
4. If present but misconfigured, repair when safe.
5. If blocked by approval, auth, network, platform, or missing artifact, report the blocker.

Prefer update over reinstall. Never uninstall or replace a user-managed tool unless the manifest explicitly allows it and the user approves.

## OpenCode Rules

- Detect OpenCode with the manifest command, usually `opencode --version`.
- Prefer the documented OpenCode updater or the original package manager when updating.
- Keep repo-local OpenCode assets under `.opencode/` or the target declared by the manifest.
- Use plural OpenCode config directories: `agents`, `skills`, `plugins`, `commands`, `tools`, `themes`.
- Do not write provider credentials to git-tracked files.
- Treat `opencode auth login` and provider setup as manual-required unless the user explicitly performs the interactive step.
- Verify custom agents, skills, and plugins by checking file placement and, when possible, OpenCode discovery behavior.

## Ownership Rules

`sync-owned` is allowed only when the target directory contains a repo ownership marker or a manifest-managed file list.

Required marker path for a sync-owned directory:

```text
<target>/.opencode-bootstrap-owned.json
```

If no marker exists, agents may copy missing files but must not delete, replace, or rewrite existing files without approval.

## Manifest Rules

- Do not invent versions, checksums, URLs, package names, or install methods.
- Do not use `latest` for offline or pinned artifacts.
- Every downloaded artifact must have a checksum unless the manifest marks the item as non-pinned and online-only.
- Every install/update command must have a matching verify command.
- Disabled items stay disabled unless the user asks to enable them.

## Secret Handling

Forbidden:

- committing secrets;
- writing secrets into templates;
- printing secrets in logs or reports;
- copying credentials between machines;
- storing provider auth in this repo.

Allowed:

- checking whether auth appears configured;
- telling the user which login command to run;
- marking auth as pending in reports.

## Verification Requirements

After any change, run the most specific verification available:

1. `scripts/doctor` for the selected profile.
2. Tool-specific version commands.
3. Config file existence and schema checks.
4. OpenCode discovery checks where available.

Do not claim success without verification evidence.

## Final Report Format

End with a concise report containing:

- profile used;
- machine facts detected;
- installed items;
- updated items;
- skipped acceptable items;
- repaired items;
- failed or blocked items;
- manual-required items;
- verification commands and results;
- persistent changes made.

If nothing changed, say so and still report verification results.

## Recovery Rules

- If an install/update fails, diagnose before retrying.
- Do not repeatedly run the same failing command without changing the cause.
- Do not delete user files to make validation pass.
- Do not reset git state unless the user explicitly asks.
- If a manifest is ambiguous, prefer a safe skip with a clear report over guessing.
