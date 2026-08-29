#!/usr/bin/env bash
set -euo pipefail

MODEL_NAME="${OLLAMA_MODEL:-llama3.2:1b}"

if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.com/install.sh | sh
fi

if ! pgrep -x ollama >/dev/null 2>&1; then
  nohup ollama serve >/tmp/ollama-server.log 2>&1 &
  sleep 3
fi

ollama pull "$MODEL_NAME"

python -m pip install --upgrade pip
python -m pip install -r requirements.txt
