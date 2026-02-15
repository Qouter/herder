# Herder 🐑

**A macOS menu bar app that shows how many Claude Code agents are running and which ones need your attention.**

## Install

```bash
brew tap qouter/tap
brew install herder
herder open
```

### Prerequisites

- macOS 13+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

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
herder status            # Check configuration
herder install-hooks     # Install/reinstall Claude Code hooks
herder uninstall-hooks   # Remove hooks
```

## Uninstall

```bash
herder uninstall-hooks
brew uninstall herder
```

## License

MIT
