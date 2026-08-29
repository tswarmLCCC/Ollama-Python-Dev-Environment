#!/usr/bin/env bash
set -euo pipefail

if ! pgrep -x ollama >/dev/null 2>&1; then
  nohup ollama serve >/tmp/ollama-server.log 2>&1 &
fi
