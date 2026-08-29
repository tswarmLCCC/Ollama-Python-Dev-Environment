#!/usr/bin/env bash
set -euo pipefail

MODEL_NAME="${OLLAMA_MODEL:-llama3.2:1b}"
MAX_WAIT_SECONDS=30
LOG_FILE="/tmp/ollama-server.log"
STATUS_LOG="/tmp/ollama-setup-status.log"
READY_FILE="/tmp/ollama-setup-ready"

touch "$STATUS_LOG"

log() {
  echo "[setup] $1" | tee -a "$STATUS_LOG"
}

retry() {
  attempts="$1"
  delay_seconds="$2"
  shift 2
  try=1
  while true; do
    if "$@"; then
      return 0
    fi
    if [ "$try" -ge "$attempts" ]; then
      log "Command failed after ${attempts} attempts: $*"
      return 1
    fi
    log "Command failed (attempt ${try}/${attempts}): $*. Retrying in ${delay_seconds}s."
    try=$((try + 1))
    sleep "$delay_seconds"
  done
}

log "Starting post-create setup."

if ! command -v ollama >/dev/null 2>&1; then
  log "Ollama not found. Installing..."
  install_script="/tmp/ollama-install.sh"
  curl -fsSL https://ollama.com/install.sh -o "$install_script"
  bash "$install_script"
  log "Ollama install complete."
else
  log "Ollama already installed."
fi

if ! pgrep -f "ollama serve" >/dev/null 2>&1; then
  log "Starting Ollama server."
  nohup ollama serve >"$LOG_FILE" 2>&1 &
else
  log "Ollama server already running."
fi

ready=false
i=0
log "Waiting for Ollama API readiness (up to ${MAX_WAIT_SECONDS}s)."
while [ "$i" -lt "$MAX_WAIT_SECONDS" ]; do
  if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
  i=$((i + 1))
done

if [ "$ready" = false ]; then
  log "Ollama server did not become ready within ${MAX_WAIT_SECONDS} seconds."
  exit 1
fi

log "Ollama API is ready."
log "Pulling model: ${MODEL_NAME}"
retry 3 3 ollama pull "$MODEL_NAME"
log "Model pull complete."

log "Installing Python dependencies."
retry 3 3 python -m pip install --upgrade pip
retry 3 3 python -m pip install -r requirements.txt
log "Python dependency install complete."

ready_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'ready_at=%s model=%s\n' "$ready_at" "$MODEL_NAME" >"$READY_FILE"
log "Setup complete. Ready marker: ${READY_FILE}"
log "Server log: ${LOG_FILE}"
