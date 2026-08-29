# Container Guide: How This Environment Actually Works

This page is for students who want to understand *what a dev container is* and
*exactly what happens* when you open this repository in a Codespace. It goes
from "what is a container" to "here is the literal file in this repo that did
that thing." Read top to bottom the first time; use it as a reference later.

---

## 1. The big picture: what problem containers solve

Normally, "it works on my machine" happens because everyone's machine has a
different OS, different Python version, different installed tools, etc.
A **container** is a way to package an entire mini-computer environment
(OS files, tools, settings) into a reusable image, so that everyone who runs
it gets the *exact same* environment, byte for byte.

Think of it like this:

- **Image** = a frozen, read-only snapshot of a filesystem + installed
  software (like a save file for a computer's hard drive).
- **Container** = a running instance of that image (like loading the save
  file and pressing play). You can start many containers from one image.
- **Dev container** = a container specifically configured for *development*
  (has your editor's extensions, your project mounted inside it, ports
  forwarded, etc.).

Containers are **isolated** from your actual laptop/host machine — they have
their own filesystem, their own processes, their own network stack — but they
share the host machine's OS kernel (unlike a full virtual machine, which
emulates hardware and runs its own kernel). This is why containers start in
seconds instead of minutes.

## 2. Where "the container" actually lives for you

You're using **GitHub Codespaces**, which is: GitHub spins up a cloud virtual
machine for you, and inside that VM it builds and runs a container based on
this repo's configuration. Your browser or VS Code Desktop then connects to
that remote container over the network — the editor UI runs locally, but
every file, terminal, and process you touch is happening inside the container
in the cloud, not on your laptop.

```mermaid
flowchart LR
    A[You open repo in Codespaces] --> B[GitHub provisions a cloud VM]
    B --> C[VM pulls the base Docker image]
    C --> D[Container is created from image]
    D --> E[postCreateCommand runs once]
    E --> F[postStartCommand runs every start]
    F --> G[VS Code connects to the running container]
    G --> H[You get a terminal + editor inside the container]
```

## 3. The config folder that defines everything: `.devcontainer/`

Codespaces (and VS Code's "Dev Containers" extension, which works the same
way locally with Docker) looks for a folder named `.devcontainer/` in the
repo root. This repo has three files there:

```
.devcontainer/
    devcontainer.json   <- the main config: what image, what commands, what extensions
    post-create.sh      <- script that runs ONCE, after the container is first built
    post-start.sh       <- script that runs EVERY TIME the container starts
```

### 3.1 `devcontainer.json`

```jsonc
{
  "name": "Ollama Python Dev Environment",
  "image": "mcr.microsoft.com/devcontainers/python:3.11",
  "postCreateCommand": "bash .devcontainer/post-create.sh",
  "postStartCommand": "bash .devcontainer/post-start.sh",
  "customizations": {
    "vscode": {
      "settings": { "python.defaultInterpreterPath": "/usr/local/bin/python" },
      "extensions": ["ms-python.python", "ms-python.vscode-pylance"]
    }
  }
}
```

Line by line, what this tells Codespaces:

| Key | What it means |
|---|---|
| `"image"` | Don't build a custom image from scratch — pull this pre-built Microsoft image, which already has Python 3.11, `pip`, and common dev tools installed on top of a Debian/Ubuntu Linux base. |
| `"postCreateCommand"` | After the container is created for the very first time, run this shell script. This is where "one-time setup" (installing Ollama, downloading the model) happens. |
| `"postStartCommand"` | Every time the container is started (first time *and* every time you resume/reopen the Codespace), run this script. This is where "make sure the background service is running" logic lives. |
| `"customizations.vscode.extensions"` | Automatically install the Python and Pylance VS Code extensions *inside the container* so you get IntelliSense/linting without doing anything. |
| `"customizations.vscode.settings"` | Pre-configure VS Code (inside this container only) to use the container's Python interpreter path. |

**Why two different lifecycle scripts?** Downloading the Ollama binary and
pulling the model is slow and only needs to happen once — that's
`postCreate`. But the Ollama *server process* doesn't survive a container
restart (it's just a process in memory), so it needs to be re-launched every
time you start the container — that's `postStart`.

### 3.2 `post-create.sh` — the one-time setup

```bash
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
```

What this does, step by step:

1. `set -euo pipefail` — bash "safety mode": exit immediately if any command
   fails, treat unset variables as errors, and make pipelines fail if any
   part of them fails. This prevents the script from silently limping along
   after something breaks.
2. `MODEL_NAME="${OLLAMA_MODEL:-llama3.2:1b}"` — use the `OLLAMA_MODEL`
   environment variable if you've set one, otherwise default to
   `llama3.2:1b` (a small ~1B-parameter model, chosen because it downloads
   fast and runs on modest CPU-only cloud machines).
3. Checks if the `ollama` command already exists; if not, downloads and runs
   Ollama's official install script (`curl | bash`-style, but saved to a file
   first so it can be inspected/re-run).
4. Checks if an `ollama` process is already running; if not, starts
   `ollama serve` in the background (`nohup ... &`), redirecting its logs to
   `/tmp/ollama-server.log` so it doesn't spam your terminal and doesn't die
   when the shell session ends.
5. Polls `http://127.0.0.1:11434/api/tags` (Ollama's local REST API, listening
   only inside the container on `localhost`) once a second for up to 30
   seconds, waiting for the server to become responsive before continuing.
6. `ollama pull "$MODEL_NAME"` — downloads the model weights (one-time, cached
   in the container's filesystem).
7. Upgrades `pip` and installs this repo's Python dependencies from
   [requirements.txt](requirements.txt) (just the `ollama` Python client
   package).

### 3.3 `post-start.sh` — the "make sure it's alive" script

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! pgrep -x ollama >/dev/null 2>&1; then
  nohup ollama serve >/tmp/ollama-server.log 2>&1 &
fi
```

Much simpler: every time the container starts (including resuming a stopped
Codespace), check whether the `ollama` server process is running, and if
not, start it again. The model and binary are already installed from
`post-create.sh`, so this just needs to bring the *service* back up.

## 4. The base image, unpacked

`mcr.microsoft.com/devcontainers/python:3.11` is a publicly available image
maintained by Microsoft specifically for dev containers. Under the hood it's
layered like this:

```
Layer 3: Python 3.11 + pip + common dev tooling   <- what you actually use
Layer 2: Debian/Ubuntu userland packages (bash, curl, git, build tools)
Layer 1: Minimal Linux base filesystem
```

Each "layer" is cached and reused — this is why pulling the image is fast
even though it contains a whole OS's worth of files: Docker/Codespaces only
downloads layers it doesn't already have cached.

Because the base image is Linux, **everything you run in this Codespace is
Linux**, regardless of whether you're on Windows, macOS, or a Chromebook on
your actual computer. That's part of the point — the container abstracts
away your host OS entirely.

## 5. Networking: how "localhost" works here

Inside the container, `127.0.0.1:11434` is Ollama's private API port — it is
**not** exposed to the internet by default. It's only reachable from
processes running *inside the same container*, which is why the Python
scripts in [examples/](examples/) can call it directly (they use the
`ollama` Python package, which just wraps HTTP calls to that same address).

VS Code's Codespaces integration separately handles **port forwarding** for
things you *do* want to reach from your browser (e.g., if this project ran a
web server on port 8000, Codespaces would offer to forward that port to a
public-ish URL). This repo doesn't forward any ports because nothing here
needs to be reached from outside the container.

## 6. Filesystem: what's persistent vs. what isn't

| Thing | Persists across a container **restart** (stop/resume)? | Persists across a container **rebuild**? |
|---|---|---|
| Your repo files (this git checkout) | Yes | Yes |
| Installed `ollama` binary | Yes | No — reinstalled by `post-create.sh` |
| Downloaded model weights | Yes | No — re-pulled by `post-create.sh` |
| Python packages from `requirements.txt` | Yes | No — reinstalled by `post-create.sh` |
| Running `ollama serve` process | No — it's just a process in memory | No |

"Rebuild" (via the Codespaces "Rebuild Container" command) throws away the
container and creates a fresh one from the image, so `postCreateCommand`
runs again from scratch. A plain restart/resume keeps the same container's
disk, so `postCreateCommand` is *not* re-run — only `postStartCommand` runs.

## 7. Putting it together: a full timeline of "Open in Codespaces"

1. You click "Create codespace" (or it auto-opens for an assignment link).
2. GitHub provisions a cloud VM and starts a Docker engine on it.
3. Docker pulls `mcr.microsoft.com/devcontainers/python:3.11` (or uses a
   cached copy).
4. A container is created from that image, with this repo's files mounted
   inside it at (typically) `/workspaces/Ollama-Python-Dev-Environment`.
5. VS Code's server component starts inside the container; the extensions
   listed in `devcontainer.json` are installed inside the container.
6. `postCreateCommand` runs: `bash .devcontainer/post-create.sh` — installs
   Ollama, starts the server, waits for it, pulls the model, installs Python
   deps.
7. `postStartCommand` runs: `bash .devcontainer/post-start.sh` — confirms the
   server is up (redundant on first boot, essential on later resumes).
8. VS Code (browser tab or desktop app) connects to the now-running
   container. You see a terminal and file explorer that are *actually
   inside the container*, not on your local machine.
9. You run `python examples/01_list_models.py`, etc. — that Python process
   runs inside the container, talks to `127.0.0.1:11434` inside the same
   container, and prints results back to your VS Code terminal.

## 8. Why this matters for you as a student

- **Reproducibility**: everyone in class gets the identical environment —
  no "it works on my machine" debugging.
- **Disposability**: if you break something, you can rebuild the container
  and start clean in a couple of minutes instead of re-imaging your laptop.
- **Transparency**: unlike a black-box cloud tool, everything above is just
  plain shell scripts and one JSON file that you can open and read yourself
  — nothing here is hidden magic.
- **Portability of the pattern**: the `.devcontainer/` approach isn't
  specific to Ollama — any project (a database, a web server, a different
  language toolchain) can use the exact same `devcontainer.json` +
  `postCreateCommand`/`postStartCommand` pattern to define its own
  reproducible environment.

## 9. Useful commands to poke at the container yourself

```bash
# See the model server's own logs
cat /tmp/ollama-server.log

# Confirm the API is alive
curl http://127.0.0.1:11434/api/tags

# See what OS/kernel you're actually running inside
cat /etc/os-release
uname -a

# See the running processes inside the container
ps aux

# See what Python interpreter and packages are active
which python
python -m pip list
```

## 10. Related docs in this repo

- [README.md](README.md) — quick start and default model info.
- [NEWBIE_GUIDE.md](NEWBIE_GUIDE.md) — beginner walkthrough for using/forking
  this repo for a class.
- [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json),
  [.devcontainer/post-create.sh](.devcontainer/post-create.sh),
  [.devcontainer/post-start.sh](.devcontainer/post-start.sh) — the actual
  source files this guide explains.
