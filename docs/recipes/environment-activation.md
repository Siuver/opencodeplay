# Environment Activation Recipe

This recipe explains session activation and offline-safe defaults.

## Capability

- Apply environment defaults that reduce unexpected network behavior.
- Put the staged `opencode` directory on PATH for the current PowerShell session.

## Helper Output

The pinned-artifact helper writes:

- `.opencodeplay\env.ps1`
- `.opencodeplay\activate-opencodeplay.ps1`
- `.opencodeplay\state.json`

## Usage

```powershell
. .\.opencodeplay\activate-opencodeplay.ps1
opencode --version
```

Use persistent PATH changes only when the user explicitly chooses them.
