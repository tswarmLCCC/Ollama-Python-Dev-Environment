# Ollama Python Dev Environment

A lightweight Ollama + Python setup for GitHub Codespaces (including GitHub Education workspaces).

## What this config does

- Uses a Python 3.11 dev container
- Installs Ollama automatically in Codespaces
- Starts the Ollama server automatically
- Pulls a lightweight default model: `llama3.2:1b`
- Installs Python dependency `ollama`
- Provides simple Python demo scripts

## Default model

The container uses `llama3.2:1b` by default (small and practical for workspace use).

You can override it by setting `OLLAMA_MODEL` before container creation.

## Demo scripts

From the repository root, run:

```bash
python examples/01_list_models.py
python examples/02_generate.py
python examples/03_chat.py
```

Optional environment variables:

- `OLLAMA_MODEL` (default: `llama3.2:1b`)
- `OLLAMA_PROMPT` (used by `examples/02_generate.py`)

## Notes

- Ollama server logs are written to `/tmp/ollama-server.log`.
- If needed, you can manually start the server with:

```bash
ollama serve
```
