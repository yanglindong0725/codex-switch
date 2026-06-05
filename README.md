# CodexSwitcher

Switch between multiple Codex accounts from your menu bar. See rate limits at a glance. Get back to coding.

<p align="center">
  <img src="screenshot.png" width="360" alt="CodexSwitcher menu bar">
</p>

## Install

**[Download DMG](../../releases/latest)** · Unzip, drag to Applications, done.

> Requires macOS 12+ and [Codex](https://openai.com/codex) installed. Log in with `codex login` first.

## Build from source

```bash
git clone https://github.com/jieguangzhou/CodexSwitcher.git
cd CodexSwitcher
bash build.sh
open CodexSwitcher.app
```

## Add another account

Use **Add Account...** from the menu bar app. CodexSwitcher saves your current
`~/.codex/auth.json`, moves it aside, and opens Terminal to run:

```bash
codex login
```

Do not run `codex logout` when adding another account. Logging out can expire
the current token; CodexSwitcher only moves auth files so the saved account can
be switched back later.

## What it does

- **One-click account switching** from the menu bar
- **Rate limits for all accounts** — 5h and weekly usage with progress bars
- **Low quota alerts** — status bar icon changes when running low, with system notifications
- **Auto-sync** — detects new accounts after `codex login`
- **Zero config** — works out of the box, settings adjustable from the menu

## License

MIT
