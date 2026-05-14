# Desktop App Recipe

This recipe covers the optional `opencode` desktop installer.

## When to Offer

- The user explicitly wants a desktop app.
- The target machine supports the desktop runtime expectations.

## Current Status

The Windows x64 desktop installer is pinned but disabled in the pinned-artifact backend. Enable it intentionally only when the selected profile includes desktop setup.

## Validation

- Confirm the installer was staged.
- Treat GUI launch and desktop runtime checks as manual validation unless browser/GUI automation is added later.
