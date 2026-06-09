# Codex Switch v2.0

Interaction-focused release for safer account switching and a more refined popover workflow.

## Changes

- Added a two-step account switching flow: clicking an account now opens a confirmation panel instead of switching immediately.
- Highlighted the pending account selection and added explicit cancel/switch actions to reduce accidental switches.
- Adjusted the menu bar popover anchor so the panel sits closer to the menu bar.
- Kept the underlying account persistence path unchanged; this release changes when switching is triggered, not how account files are written.

## Install

Download `Codex-Switch-v2.0.dmg`, open it, and copy `Codex Switch.app` to Applications.

This release is not signed or notarized with an Apple Developer account. macOS may require manually allowing the app in System Settings the first time it is opened.

## License

MIT. This project is based on `jieguangzhou/CodexSwitcher`, also licensed under MIT.
