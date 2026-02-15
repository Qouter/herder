#!/usr/bin/env bash
# Herder hook: Stop
# Marca el agente como idle y extrae el último mensaje del transcript

set -euo pipefail

SOCKET="/tmp/herder.sock"

# Leer JSON de stdin
INPUT=$(cat)

# Extraer campos
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
TIMESTAMP=$(date +%s)

# Validar
if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

# Extraer último mensaje del assistant del transcript (si existe)
LAST_MESSAGE=""
if [[ -n "$TRANSCRIPT_PATH" ]] && [[ -f "$TRANSCRIPT_PATH" ]]; then
  # Leer últimas 10 líneas, buscar mensajes de assistant, tomar el último
  LAST_MESSAGE=$(tail -10 "$TRANSCRIPT_PATH" 2>/dev/null | \
    jq -r 'select(.message.role == "assistant") | .message.content[0].text // empty' 2>/dev/null | \
    tail -1 | \
    tr '\n' ' ' | \
    cut -c1-100 || echo "")
fi

# Crear mensaje JSON
MESSAGE=$(jq -n \
  --arg event "agent_idle" \
  --arg session_id "$SESSION_ID" \
  --arg last_message "$LAST_MESSAGE" \
  --argjson timestamp "$TIMESTAMP" \
  '{event: $event, session_id: $session_id, last_message: $last_message, timestamp: $timestamp}')

# Enviar al socket si existe
if [[ -S "$SOCKET" ]]; then
  echo "$MESSAGE" | timeout 1 socat - UNIX-CONNECT:"$SOCKET" 2>/dev/null || true
fi

exit 0
