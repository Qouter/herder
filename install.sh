#!/usr/bin/env bash
# Herder installer/updater
# Usage: curl -fsSL https://raw.githubusercontent.com/Qouter/herder/main/install.sh | bash
set -euo pipefail

APP_NAME="Herder"
INSTALL_DIR="$HOME/.herder"
APP_PATH="$INSTALL_DIR/Herder.app"
HOOKS_DIR="$INSTALL_DIR/hooks"
BIN_PATH="/usr/local/bin/herder"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
REPO="Qouter/herder"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get latest release URL
echo -e "${GREEN}Herder Installer${NC}"
echo ""

LATEST_URL=$(curl -sI "https://github.com/$REPO/releases/latest" | grep -i "^location:" | sed 's/.*tag\///' | tr -d '\r\n')
if [ -z "$LATEST_URL" ]; then
  echo "Error: Could not determine latest version"
  exit 1
fi
VERSION="$LATEST_URL"
echo "Version: $VERSION"

DOWNLOAD_URL="https://github.com/$REPO/releases/download/$VERSION/Herder-macos-universal.zip"

# Check if already installed at this version
if [ -f "$INSTALL_DIR/VERSION" ]; then
  CURRENT=$(cat "$INSTALL_DIR/VERSION")
  if [ "$CURRENT" = "$VERSION" ]; then
    echo "Already up to date ($VERSION)"
    exit 0
  fi
  echo "Updating: $CURRENT → $VERSION"
else
  echo "Fresh install"
fi

# Download
echo "Downloading..."
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT
curl -fsSL "$DOWNLOAD_URL" -o "$TMP_DIR/herder.zip"

# Extract
cd "$TMP_DIR"
unzip -q herder.zip

# Find the app (handles both Herder-release/ and direct)
if [ -d "Herder-release" ]; then
  SRC_DIR="Herder-release"
else
  SRC_DIR="."
fi

# Kill running app
pkill -f "Herder.app" 2>/dev/null || true
sleep 0.5

# Install
mkdir -p "$INSTALL_DIR"
rm -rf "$APP_PATH"
cp -r "$SRC_DIR/Herder.app" "$APP_PATH"
rm -rf "$HOOKS_DIR"
cp -r "$SRC_DIR/hooks" "$HOOKS_DIR"
chmod +x "$HOOKS_DIR"/*.sh

# Remove quarantine
xattr -c "$APP_PATH" 2>/dev/null || true

# Save version
echo "$VERSION" > "$INSTALL_DIR/VERSION"

echo -e "  ${GREEN}✓${NC} App installed to $APP_PATH"

# Create CLI wrapper
cat > "$TMP_DIR/herder" << 'CLIEOF'
#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.herder"
APP_PATH="$INSTALL_DIR/Herder.app"
HOOKS_DIR="$INSTALL_DIR/hooks"
CLAUDE_DIR="$HOME/.claude"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

case "${1:-help}" in
  open)
    open "$APP_PATH"
    ;;

  update)
    curl -fsSL https://raw.githubusercontent.com/Qouter/herder/main/install.sh | bash
    ;;

  install-hooks)
    mkdir -p "$CLAUDE_DIR"
    [ -f "$SETTINGS_FILE" ] || echo '{}' > "$SETTINGS_FILE"
    python3 -c "
import json
sf = '$SETTINGS_FILE'
hd = '$HOOKS_DIR'
s = json.load(open(sf))
if 'hooks' not in s: s['hooks'] = {}
h = s['hooks']
for ev, sc in {'SessionStart':'on-session-start.sh','SessionEnd':'on-session-end.sh','Stop':'on-stop.sh','UserPromptSubmit':'on-prompt.sh'}.items():
    cmd = f'{hd}/{sc}'
    if ev not in h: h[ev] = []
    if not any('herder' in x.get('command','') for g in h[ev] for x in g.get('hooks',[])):
        h[ev].append({'hooks':[{'type':'command','command':cmd,'async':True}]})
        print(f'  ✓ {ev}')
    else:
        print(f'  ✓ {ev} (already)')
s['hooks'] = h
json.dump(s, open(sf,'w'), indent=2)
"
    echo "✓ Hooks installed"
    ;;

  uninstall-hooks)
    [ -f "$SETTINGS_FILE" ] || { echo "No settings.json"; exit 0; }
    python3 -c "
import json
sf = '$SETTINGS_FILE'
s = json.load(open(sf))
h = s.get('hooks', {})
for e in ['SessionStart','SessionEnd','Stop','UserPromptSubmit']:
    if e in h:
        h[e] = [g for g in h[e] if not any('herder' in x.get('command','') for x in g.get('hooks',[]))]
        if not h[e]: del h[e]
s['hooks'] = h
json.dump(s, open(sf,'w'), indent=2)
print('✓ Hooks removed')
"
    ;;

  uninstall)
    echo "Uninstalling Herder..."
    "$0" uninstall-hooks 2>/dev/null || true
    pkill -f "Herder.app" 2>/dev/null || true
    rm -rf "$INSTALL_DIR"
    rm -f /usr/local/bin/herder
    echo "✓ Herder uninstalled"
    ;;

  status)
    echo "Herder Status"
    echo "============="
    if [ -f "$INSTALL_DIR/VERSION" ]; then
      echo "Version: $(cat "$INSTALL_DIR/VERSION")"
    fi
    if pgrep -f "Herder.app" > /dev/null 2>&1; then
      echo "App:     ✓ Running"
    else
      echo "App:     ○ Not running"
    fi
    if [ -f "$SETTINGS_FILE" ]; then
      COUNT=$(python3 -c "
import json
s=json.load(open('$SETTINGS_FILE'))
print(sum(1 for e in ['SessionStart','SessionEnd','Stop','UserPromptSubmit'] if e in s.get('hooks',{}) for g in s['hooks'][e] for h in g.get('hooks',[]) if 'herder' in h.get('command','')))
" 2>/dev/null || echo 0)
      echo "Hooks:   $COUNT/4"
    else
      echo "Hooks:   not installed"
    fi
    ;;

  version)
    if [ -f "$INSTALL_DIR/VERSION" ]; then
      cat "$INSTALL_DIR/VERSION"
    else
      echo "not installed"
    fi
    ;;

  *)
    echo "Herder 🐑 — Claude Code agent monitor"
    echo ""
    echo "  herder open              Launch the app"
    echo "  herder update            Update to latest version"
    echo "  herder status            Check configuration"
    echo "  herder install-hooks     Install Claude Code hooks"
    echo "  herder uninstall-hooks   Remove hooks"
    echo "  herder uninstall         Remove everything"
    echo "  herder version           Show version"
    ;;
esac
CLIEOF

# Install CLI to /usr/local/bin (may need sudo)
if [ -w "/usr/local/bin" ]; then
  cp "$TMP_DIR/herder" "$BIN_PATH"
  chmod +x "$BIN_PATH"
else
  sudo cp "$TMP_DIR/herder" "$BIN_PATH"
  sudo chmod +x "$BIN_PATH"
fi
echo -e "  ${GREEN}✓${NC} CLI installed to $BIN_PATH"

# Install hooks
echo ""
echo "Installing hooks..."
"$BIN_PATH" install-hooks

echo ""
echo -e "${GREEN}✓ Herder $VERSION installed!${NC}"
echo ""
echo "  herder open       Launch the app"
echo "  herder update     Update later"
echo "  herder status     Check everything"
echo ""
