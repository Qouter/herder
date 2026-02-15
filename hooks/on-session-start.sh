#!/usr/bin/env bash
# Herder hook: SessionStart
# Registra un nuevo agente cuando inicia sesión

set -euo pipefail

SOCKET="/tmp/herder.sock"

# Leer JSON de stdin
INPUT=$(cat)

# Extraer campos con jq
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
TIMESTAMP=$(date +%s)

# Validar que tenemos los datos necesarios
if [[ -z "$SESSION_ID" ]] || [[ -z "$CWD" ]]; then
  # Datos incompletos, salir silenciosamente
  exit 0
fi

# Crear mensaje JSON
MESSAGE=$(jq -n \
  --arg event "session_start" \
  --arg session_id "$SESSION_ID" \
  --arg cwd "$CWD" \
  --argjson timestamp "$TIMESTAMP" \
  '{event: $event, session_id: $session_id, cwd: $cwd, timestamp: $timestamp}')

# Enviar al socket si existe
if [[ -S "$SOCKET" ]]; then
  # Usar timeout para evitar bloqueos
  echo "$MESSAGE" | timeout 1 socat - UNIX-CONNECT:"$SOCKET" 2>/dev/null || true
fi

# Siempre salir con éxito (no bloquear Claude Code)
exit 0
