# Herder 🐑

**A macOS menu bar app that monitors your Claude Code agents — see who's working and who needs you.**

<p align="center">
  <code>🤖 3 | ⏳ 1</code>
</p>

Running multiple Claude Code sessions across terminals? Herder sits in your menu bar and tells you at a glance:

- **How many agents** are currently active
- **Which ones are waiting** for your input (including plan review prompts)
- **What they last said** — so you know what needs attention
- **Current git branch** per agent
- **One click** to jump to any agent's terminal

No network calls. No API keys. No dependencies. Everything stays on your machine.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Qouter/herder/main/install.sh | bash
```

One command. Installs the app, CLI, and Claude Code hooks. Works on any Mac — no Xcode, Homebrew, or extra tools required.

> **First launch:** If macOS blocks the app, the installer handles it automatically. If needed: `xattr -c ~/.herder/Herder.app`

## How it works

Herder uses [Claude Code hooks](https://docs.anthropic.com/en/docs/claude-code/hooks) to track agent lifecycle events. Four lightweight scripts fire on `SessionStart`, `SessionEnd`, `Stop`, and `UserPromptSubmit`, sending JSON messages to a local Unix domain socket.

On top of hooks, a **transcript monitor** polls active session transcripts every 5 seconds to catch cases hooks can't — like plan review prompts, permission requests, or any time Claude is waiting for input without triggering a Stop event.

```
Claude Code hooks → /tmp/herder.sock → Herder.app
  (python3)          (Unix socket)      (SwiftUI)

Transcript polling → idle detection → menu bar update
  (every 5s)          (10s stale)
```

## Menu bar

When no agents are running, you see a simple `🤖` icon. As agents start, live counters appear:

| State | Menu bar |
|-------|----------|
| No agents | `🤖` |
| 3 agents, all working | `🤖 3` |
| 3 agents, 1 waiting | `🤖 3 \| ⏳ 1` |

Click to open the popover:

```
┌──────────────────────────────────────┐
│  Herder 🐑                   v0.6.4 │
├──────────────────────────────────────┤
│                                      │
│  🟢 ~/Dev/diga_core                  │
│     🔀 hey-836-recover-sales         │
│     Working...               [Open]  │
│     12m                              │
│                                      │
│  🟡 ~/Dev/frontend                   │
│     🔀 feat/new-dashboard            │
│     "¿Cuál de estas mejoras..."      │
│     Waiting for you          [Open]  │
│     45m                              │
│                                      │
├──────────────────────────────────────┤
│  2 active · 1 waiting         Quit   │
└──────────────────────────────────────┘
```

- **🟢 Green** = agent is working
- **🟡 Orange** = agent is waiting for your input
- **🔀 branch** = current git branch
- **[Open]** = jump to the agent's terminal (detects Warp, iTerm2, VS Code, Cursor, Terminal.app)

> **Note:** Only sessions started after Herder is running will appear. Existing sessions need to be restarted to be tracked.

## Commands

```bash
herder open              # Launch the app
herder update            # Update to latest version
herder status            # Check installation & hooks
herder install-hooks     # Install/reinstall Claude Code hooks
herder uninstall-hooks   # Remove hooks from Claude Code
herder uninstall         # Remove everything
herder version           # Show installed version
```

## Update

```bash
herder update
```

Downloads the latest release from GitHub and replaces the app in-place. No cache issues, no brew update needed.

## Architecture

```
~/.herder/
├── Herder.app           # SwiftUI menu bar app (universal binary)
├── hooks/               # Claude Code hook scripts (python3)
│   ├── on-session-start.sh
│   ├── on-session-end.sh
│   ├── on-stop.sh
│   └── on-prompt.sh
└── VERSION

/usr/local/bin/herder    # CLI wrapper (bash)
/tmp/herder.sock         # Unix domain socket (runtime)
```

**Hooks** are registered in `~/.claude/settings.json` as async hooks — they never block Claude Code.

**Transcript monitor** reads `.git/HEAD` for branch info and watches `~/.claude/projects/` for transcript changes to detect idle states that hooks miss.

**Zero dependencies** — hooks use only Python 3 (ships with macOS). The app is a pre-built universal binary (arm64 + x86_64).

## How idle detection works

Herder uses two complementary strategies:

1. **Hook-based:** The `Stop` hook fires when Claude finishes a turn and returns to the prompt. This catches most cases.

2. **Transcript polling:** Every 5 seconds, Herder checks active transcripts. If the last entry is from the assistant and the file hasn't changed in 10+ seconds, the agent is marked as idle. This catches plan review prompts, permission dialogs, and multi-choice questions that don't trigger the Stop hook.

## Prerequisites

- macOS 13+ (Ventura or later)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- Python 3 (included with macOS)

## Uninstall

```bash
herder uninstall
```

Removes the app, CLI, and hooks cleanly.

## Roadmap

- [ ] Detect existing sessions on app launch
- [ ] Notification sound / system notification when an agent goes idle
- [ ] Keyboard shortcut to open the popover
- [ ] Navigate to exact Warp tab (blocked by Warp's lack of Accessibility API)
- [ ] Show project name (from package.json, Cargo.toml, etc.)
- [ ] Launch at Login toggle

## Contributing

PRs welcome. The app builds with Swift 5.9+ / Xcode 15+. GitHub Actions handles release builds automatically on version tags.

```bash
# Local build
cd app && swift build

# Tag a release
git tag v0.x.x && git push origin main --tags
```

## License

MIT
