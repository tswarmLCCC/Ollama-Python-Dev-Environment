# Newbie Guide: Using This Ollama Python Container

If you're new to GitHub Codespaces/devcontainers, this guide is for you.

## What this repository is

This repo is a **starter environment** for running a small local Ollama model with Python.

It includes:
- Devcontainer config (`.devcontainer/`) so Codespaces auto-sets up the environment
- Auto-install/start logic for Ollama
- A lightweight default model (`llama3.2:1b`)
- Example Python scripts in `examples/`

## Can I just fire this up?

**Yes.** In most cases, you can open this repo in a GitHub Codespace and it will auto-setup.

Expected first-run behavior:
1. Container builds
2. Ollama installs (if missing)
3. Ollama server starts
4. Default model downloads
5. Python dependencies install

Then run from repo root:

```bash
python examples/01_list_models.py
python examples/02_generate.py
python examples/03_chat.py
```

## Is this a template?

It is a **template-style starter repo**, even if the GitHub "Use this template" toggle is not enabled.

You can still reuse it by:
- creating your own repo from this code,
- or forking it,
- then customizing model/scripts for your class.

## How to use this personally

1. Create your own copy (fork or new repo from this content).
2. Open it in a Codespace.
3. Wait for post-create setup to finish.
4. Run the example scripts.
5. Change prompt/model via env vars when needed:

```bash
export OLLAMA_MODEL=llama3.2:1b
export OLLAMA_PROMPT="Explain Python decorators in simple terms"
python examples/02_generate.py
```

## How your students can use it

### Option A (simplest): one shared starter repo
1. Publish this repo (or your copy) for students.
2. Students open it in their own Codespaces.
3. Students run the scripts and experiment.

### Option B: per-assignment repos
1. Copy this starter into each assignment repo.
2. Keep `.devcontainer/` in each assignment.
3. Students open assignment repo in Codespaces and get the same environment.

## Tips to avoid "borking" things

- Keep `.devcontainer/devcontainer.json` and `.devcontainer/post-*.sh` in version control.
- If Ollama looks stuck, check logs:
  - `/tmp/ollama-server.log`
  - `/tmp/ollama-setup-status.log`
- Confirm setup completion marker:
  - `/tmp/ollama-setup-ready`
- If setup failed on first build, rebuild container in Codespaces.
- Stick to small models for smoother student experience in cloud workspaces.

## Quick reset checklist

1. Rebuild Codespace container
2. Confirm server:
   ```bash
   curl http://127.0.0.1:11434/api/tags
   ```
3. Pull model manually if needed:
   ```bash
   ollama pull llama3.2:1b
   ```
4. Re-run demo script

## How do I know setup is done?

Run:

```bash
cat /tmp/ollama-setup-status.log
cat /tmp/ollama-setup-ready
```

If setup completed, the status log will end with a line like `Setup complete` and the ready file will contain a timestamp and model name.
