# Doctor

Validate the selected profile and report any blocked or manual-required work.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\doctor.ps1 -Profile default
```

Use `-Json` for machine-readable output and `-OutputPath <repo-relative-path>` to save a report inside the repository.
