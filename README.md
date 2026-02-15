# Herder 🐑

**A macOS menu bar app that shows how many Claude Code agents are running and which ones need your attention.**

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Qouter/herder/main/install.sh | bash
```

That's it. One command installs the app, CLI, and Claude Code hooks.

### Or via Homebrew

```bash
brew tap qouter/tap && brew install herder
```

## How it works

Two numbers in your menu bar:

```
🤖 3 | ⏳ 1
```

- **3** — agents running
- **1** — agents waiting for your input

Click to see each agent, what it last said, and jump to its terminal.

Uses [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) to track agent lifecycle. No network calls, everything local.

## Commands

```bash
herder open              # Launch the app
herder update            # Update to latest version
herder status            # Check configuration
herder install-hooks     # Install/reinstall Claude Code hooks
herder uninstall-hooks   # Remove hooks
herder uninstall         # Remove everything
```

## Update

```bash
herder update
```

That's it. Downloads the latest release, replaces the app, done.

## Uninstall

```bash
herder uninstall
```

## License

MIT
