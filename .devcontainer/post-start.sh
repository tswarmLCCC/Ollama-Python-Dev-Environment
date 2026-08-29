#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/tmp/ollama-server.log"
STATUS_LOG="/tmp/ollama-setup-status.log"

touch "$STATUS_LOG"

log() {
  echo "[start] $1" | tee -a "$STATUS_LOG"
}

if ! pgrep -f "ollama serve" >/dev/null 2>&1; then
  log "Ollama server not running. Starting it now."
  nohup ollama serve >"$LOG_FILE" 2>&1 &
else
  log "Ollama server already running."
fi
