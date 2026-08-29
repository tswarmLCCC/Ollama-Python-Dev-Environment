#!/usr/bin/env bash
set -euo pipefail

MODEL_NAME="${OLLAMA_MODEL:-llama3.2:1b}"
MAX_WAIT_SECONDS=30

if ! command -v ollama >/dev/null 2>&1; then
  install_script="/tmp/ollama-install.sh"
  curl -fsSL https://ollama.com/install.sh -o "$install_script"
  bash "$install_script"
fi

if ! pgrep -x ollama >/dev/null 2>&1; then
  nohup ollama serve >/tmp/ollama-server.log 2>&1 &
fi

ready=false
i=0
while [ "$i" -lt "$MAX_WAIT_SECONDS" ]; do
  if curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 1
  i=$((i + 1))
done

if [ "$ready" = false ]; then
  echo "Ollama server did not become ready within ${MAX_WAIT_SECONDS} seconds." >&2
  exit 1
fi

ollama pull "$MODEL_NAME"

python -m pip install --upgrade pip
python -m pip install -r requirements.txt
