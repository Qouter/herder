#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
HOOKS_DIR="$CLAUDE_DIR/hooks/herder"
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Herder Hook Installer"

if [[ "${1:-}" == "--uninstall" ]]; then
  echo "Uninstalling..."
  python3 -c "
import json, os
sf = os.path.expanduser('$SETTINGS_FILE')
try:
    s = json.load(open(sf))
except: exit(0)
h = s.get('hooks', {})
for e in ['SessionStart','SessionEnd','Stop','UserPromptSubmit']:
    if e in h:
        h[e] = [g for g in h[e] if not any('herder' in x.get('command','') for x in g.get('hooks',[]))]
        if not h[e]: del h[e]
s['hooks'] = h
json.dump(s, open(sf,'w'), indent=2)
print('✓ Hooks removed')
"
  rm -rf "$HOOKS_DIR" 2>/dev/null || true
  echo "✓ Done"
  exit 0
fi

mkdir -p "$HOOKS_DIR"
for script in on-session-start.sh on-session-end.sh on-stop.sh on-prompt.sh; do
  cp "$SCRIPT_DIR/hooks/$script" "$HOOKS_DIR/"
  chmod +x "$HOOKS_DIR/$script"
  echo "  ✓ $script"
done

[[ ! -f "$SETTINGS_FILE" ]] && echo "{}" > "$SETTINGS_FILE"

python3 -c "
import json, os
sf = os.path.expanduser('$SETTINGS_FILE')
hd = os.path.expanduser('$HOOKS_DIR')
try: s = json.load(open(sf))
except: s = {}
if 'hooks' not in s: s['hooks'] = {}
h = s['hooks']
cfgs = {'SessionStart':'on-session-start.sh','SessionEnd':'on-session-end.sh','Stop':'on-stop.sh','UserPromptSubmit':'on-prompt.sh'}
for event, script in cfgs.items():
    cmd = f'{hd}/{script}'
    if event not in h: h[event] = []
    if not any('herder' in x.get('command','') for g in h[event] for x in g.get('hooks',[])):
        h[event].append({'hooks':[{'type':'command','command':cmd,'async':True}]})
        print(f'  ✓ Registered {event}')
    else:
        print(f'  ✓ {event} already registered')
s['hooks'] = h
json.dump(s, open(sf,'w'), indent=2)
"
echo "✓ Hooks installed!"
