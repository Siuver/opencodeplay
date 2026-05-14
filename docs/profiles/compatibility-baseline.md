# Compatibility Baseline Profile

Use this profile only when the target Windows x64 machine needs the upstream baseline CLI build for compatibility.

## Includes

- Baseline CLI artifact selected intentionally.
- Same offline/checksum rules as the Core CLI or Offline Core profile.
- Validation focused on CLI availability.

## Decision Point

Ask why the baseline build is needed before enabling it. Normal Windows x64 machines should start with the standard Core CLI profile.

## Recipes

- `docs/recipes/opencode-cli.md`
- `docs/recipes/environment-activation.md`
