#!/usr/bin/env bash
# Herder hook: SessionStart
set -euo pipefail

SOCKET="/tmp/herder.sock"
INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TIMESTAMP=$(date +%s)

[[ -z "$SESSION_ID" ]] || [[ -z "$CWD" ]] && exit 0

# Detect terminal info for window activation
TTY=$(tty 2>/dev/null || echo "")
PPID_VAL=$(ps -o ppid= -p $$ 2>/dev/null | tr -d ' ')
# Walk up the process tree to find the terminal app
TERMINAL_PID=""
TERMINAL_APP=""
PID_CHECK="$PPID_VAL"
for i in $(seq 1 10); do
  [[ -z "$PID_CHECK" ]] || [[ "$PID_CHECK" == "1" ]] && break
  APP_NAME=$(ps -o comm= -p "$PID_CHECK" 2>/dev/null || echo "")
  case "$APP_NAME" in
    *Warp*|*warp*)
      TERMINAL_PID="$PID_CHECK"
      TERMINAL_APP="warp"
      break
      ;;
    *iTerm*|*iterm*)
      TERMINAL_PID="$PID_CHECK"
      TERMINAL_APP="iterm2"
      break
      ;;
    *Terminal*)
      TERMINAL_PID="$PID_CHECK"
      TERMINAL_APP="terminal"
      break
      ;;
    *code*|*Code*)
      TERMINAL_PID="$PID_CHECK"
      TERMINAL_APP="vscode"
      break
      ;;
    *cursor*|*Cursor*)
      TERMINAL_PID="$PID_CHECK"
      TERMINAL_APP="cursor"
      break
      ;;
  esac
  PID_CHECK=$(ps -o ppid= -p "$PID_CHECK" 2>/dev/null | tr -d ' ')
done

MESSAGE=$(jq -n \
  --arg event "session_start" \
  --arg session_id "$SESSION_ID" \
  --arg cwd "$CWD" \
  --arg tty "$TTY" \
  --arg terminal_pid "${TERMINAL_PID:-}" \
  --arg terminal_app "${TERMINAL_APP:-}" \
  --argjson timestamp "$TIMESTAMP" \
  '{event: $event, session_id: $session_id, cwd: $cwd, tty: $tty, terminal_pid: $terminal_pid, terminal_app: $terminal_app, timestamp: $timestamp}')

if [[ -S "$SOCKET" ]]; then
  echo "$MESSAGE" | timeout 1 socat - UNIX-CONNECT:"$SOCKET" 2>/dev/null || true
fi

exit 0
