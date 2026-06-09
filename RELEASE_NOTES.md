# Codex Switch v2.1.0

Reliability release for safer multi-account persistence during add-account and switch flows.

## Changes

- Added a single-instance lock so debug and installed copies cannot write the Codex auth files at the same time.
- Reworked account sync to match by both email and account ID, and to write account files atomically.
- Added login-completion polling plus debounced auth-file watching so new logins are not missed.
- Added temp-directory tests for account persistence, invalid auth handling, and instance locking.

## Install

Download `Codex-Switch-v2.1.0.dmg`, open it, and copy `Codex Switch.app` to Applications.

This release is not signed or notarized with an Apple Developer account. macOS may require manually allowing the app in System Settings the first time it is opened.

## License

MIT. This project is based on `jieguangzhou/CodexSwitcher`, also licensed under MIT.
