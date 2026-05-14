# opencode CLI Recipe

This recipe adds the core `opencode` command-line capability.

## When to Offer

- Always offer for an `opencode`-centered workstation.
- Use the standard Windows x64 artifact for normal native Windows setup.
- Use the baseline artifact only when compatibility is the reason.

## Execution Options

- Pinned-artifact backend: use `manifests/pinned-artifacts.json` plus `scripts/bootstrap.ps1` when reproducibility or offline transfer matters.
- Guided manual path: use existing installed `opencode` or documented user-managed installation, then validate with `opencode --version`.

## Validation

- `opencode --version`
- Optional follow-ups after real setup: `opencode debug config`, `opencode auth list`, `opencode models`, and `opencode mcp list`.
