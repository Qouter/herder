#!/usr/bin/env bash
# Herder hook: SessionEnd
# Desregistra un agente cuando termina la sesión

set -euo pipefail

SOCKET="/tmp/herder.sock"

# Leer JSON de stdin
INPUT=$(cat)

# Extraer session_id con jq
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TIMESTAMP=$(date +%s)

# Validar
if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

# Crear mensaje JSON
MESSAGE=$(jq -n \
  --arg event "session_end" \
  --arg session_id "$SESSION_ID" \
  --argjson timestamp "$TIMESTAMP" \
  '{event: $event, session_id: $session_id, timestamp: $timestamp}')

# Enviar al socket si existe
if [[ -S "$SOCKET" ]]; then
  echo "$MESSAGE" | timeout 1 socat - UNIX-CONNECT:"$SOCKET" 2>/dev/null || true
fi

exit 0
