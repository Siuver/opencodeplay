# Proposed Repository Structure

This structure makes the repo predictable for both humans and agents. Keep policy, desired state, execution, and local machine data separate.

```text
README.md
AGENTS.md

docs/
  philosophy.md
  safety.md
  manual-steps.md
  troubleshooting.md
  decisions.md

manifests/
  tools.json
  tools.example.json
  opencode.json
  opencode.example.json
  capabilities.json
  capabilities.schema.json
  tools.schema.json
  profile.schema.json
  opencode.schema.json
  profiles/
    default.json
    minimal.json
    full.json
    offline.json

scripts/
  bootstrap.ps1
  doctor.ps1
  upgrade.ps1
  bootstrap.sh
  doctor.sh
  upgrade.sh
  lib/
    detect.ps1
    detect.sh
    install.ps1
    install.sh
    update.ps1
    update.sh
    verify.ps1
    verify.sh
    manifest.ps1
    manifest.sh

templates/
  opencode/
    opencode.json
    agents/
    skills/
    plugins/
    commands/
    tools/
  shell/
    powershell-profile.snippet.ps1
    bashrc.snippet.sh

artifacts/
  README.md

local/
  README.md
  overrides.example.json

reports/
  README.md
```

## Top-Level Files

### `README.md`

The short control tower. It should say what this repo is, which command to run, how to choose a profile, and what the agent must report. It should not contain every install branch.

### `AGENTS.md`

The durable execution contract. It tells agents how to behave in this repo: safety classes, verification requirements, approval boundaries, and final report format.

## `docs/`

Use docs for human context and manual-only procedures.

- `philosophy.md`: why the repo is manifest-first and idempotent.
- `safety.md`: supply-chain, secrets, PATH, global writes, and rollback policy.
- `manual-steps.md`: auth login, provider keys, GUI checks, and any browser-based flow.
- `troubleshooting.md`: known failures and recovery instructions.
- `decisions.md`: design records for package managers, OpenCode install method, offline policy, and platform support.

Docs can guide, but they should not be the only source of required state.

## `manifests/`

This is the real source of truth.

- `tools.json`: CLI/tool desired state, detect/install/update/verify policy.
- `opencode.json`: OpenCode-specific desired state, including agents, skills, plugins, MCP, commands, and config locations.
- `capabilities.json`: higher-level capabilities that may depend on multiple tools, such as "xhs publishing" or "browser automation".
- `profiles/*.json`: selects which tools and capabilities apply for a setup mode.
- `*.schema.json`: validates manifest shape so agents and CI can catch mistakes early.

Keep manifests declarative. If a command becomes complex, move the implementation into `scripts/lib/` and reference it by id.

## `scripts/`

Scripts are actuators. They should be small orchestration layers over shared library functions.

- `bootstrap`: install missing items and repair safe drift.
- `doctor`: verify current state and produce machine-readable results.
- `upgrade`: update existing managed items according to policy.
- `lib/detect`: OS, shell, package manager, network, admin rights, tool versions.
- `lib/install`: install implementations by method.
- `lib/update`: update implementations by method.
- `lib/verify`: assertion helpers.
- `lib/manifest`: load, validate, and resolve profile manifests.

Scripts must be idempotent. Rerunning `bootstrap` should converge or skip; it should not duplicate config or repeatedly append PATH entries.

## `templates/`

Templates are desired config payloads, not logic.

- `templates/opencode/opencode.json`: repo-preferred OpenCode config template.
- `templates/opencode/agents/`: custom agent markdown files.
- `templates/opencode/skills/`: `SKILL.md` bundles.
- `templates/opencode/plugins/`: local plugin files.
- `templates/opencode/commands/`: command definitions.
- `templates/opencode/tools/`: custom tool definitions.
- `templates/shell/`: shell snippets that can be linked or copied only with approval.

Keep secrets out of templates.

## `artifacts/`

Offline cache for pinned installers, archives, and checksummed bundles. The directory should be ignored except for `README.md` and optional placeholder files.

Rules:

- every artifact must be declared in a manifest;
- every artifact must have a checksum before real use;
- no `latest` aliases for offline mode;
- missing offline artifacts are blockers, not warnings.

## Ownership Markers

Agents need proof before they can treat a directory as repo-owned. For OpenCode asset sync, use this marker inside a managed target directory:

```text
<target>/.opencode-bootstrap-owned.json
```

Without a marker, agents may copy missing files but must not delete, replace, or rewrite existing user files unless the user approves.

## `local/`

Untracked local machine overrides. Use this for host-specific choices that should not be committed.

Examples:

- preferred profile;
- package manager preference;
- install directories;
- user-approved persistent changes;
- private model/provider choices without secrets.

Commit only examples and README files here.

## `reports/`

Optional ignored output from `doctor`, `bootstrap`, or `upgrade`. Reports are useful for agents because they preserve exact verification evidence without relying on conversational memory.

Recommended outputs:

- `reports/last-bootstrap.json`
- `reports/last-doctor.json`
- `reports/last-upgrade.json`

## Minimum Viable Version

If implementing incrementally, start with this subset:

```text
README.md
AGENTS.md
docs/manual-steps.md
manifests/tools.json
manifests/profiles/default.json
manifests/schemas/tools.schema.json
scripts/bootstrap.ps1
scripts/doctor.ps1
scripts/upgrade.ps1
templates/opencode/
```

That is enough for a Windows-first OpenCode setup loop while leaving room for WSL/Linux/macOS later.
