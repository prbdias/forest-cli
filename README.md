<p align="center">
  <img src="forest.png" alt="forest cli" width="600">
</p>

<h3 align="center">🌲 f o r e s t &nbsp; c l i</h3>

<p align="center"><em>Dev workspace switcher for git worktrees</em></p>

<p align="center">
  <strong>Boot, switch, and manage parallel dev environments<br>for AI-assisted multi-agent coding workflows.</strong>
</p>

<p align="center">
  <a href="#installation">Install</a> ·
  <a href="#quick-start">Quick Start</a> ·
  <a href="#commands">Commands</a> ·
  <a href="#configuration">Config</a> ·
  <a href="#how-it-works">How It Works</a>
</p>

---

## What is forest?

**forest** is a CLI tool that bridges **git worktrees**, **Docker Compose**, and **host services** so you (and your AI coding agents) can work in parallel worktrees while you test one at a time.

In multi-agent workflows, each AI coding agent operates in its own git worktree. **forest** provides a single command to:

- See all worktrees at a glance with branch context and status
- Boot the full dev stack (Docker + host services) for any worktree
- Hot-switch between worktrees in seconds
- Track which worktree is active and what's running

### Why not just `docker compose up`?

When you have 5 agents working in parallel worktrees, you need:

| Problem | forest solves it with |
|---|---|
| "Which worktree is running right now?" | `forest status` |
| "Switch to that agent's work to test it" | `forest switch <name>` |
| "I need pre-boot hooks (k8s, migrations, installs)" | Configurable hooks (`pre`, `pre-services`, `post`) |
| "Host services (Vite) need env vars from .env" | Auto-sources `.env` before starting services |
| "Logs are noisy, I want them quiet" | Logs go to `.forest/logs/` by default |
| "Detached HEAD — what was this worktree doing?" | Smart branch memory + labels |

---

## Installation

### One-liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/prbdias/forest-cli/main/install | bash
```

### Manual install

```bash
git clone https://github.com/prbdias/forest-cli.git ~/.forest-cli
ln -sf ~/.forest-cli/forest ~/.local/bin/forest
```

Make sure `~/.local/bin` is in your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"  # add to ~/.zshrc or ~/.bashrc
```

### Verify

```bash
forest --version
# forest v0.1.0
```

---

## Quick Start

```bash
# 1. Navigate to your project (must be a git repo with docker-compose)
cd ~/projects/my-app

# 2. Run the setup wizard
forest init

# 3. Boot the interactive menu
forest
```

The setup wizard will:
- Check requirements (git, docker, jq)
- Auto-detect your Docker Compose file
- Configure host services (e.g. Vite dev servers)
- Set up pre/post boot hooks
- Install `forest` globally

---

## Commands

| Command | Description |
|---|---|
| `forest` | Interactive boot menu (default) |
| `forest init` | Setup wizard — configure project for forest |
| `forest doctor` | Check all requirements |
| `forest list` | List worktrees with branch/issue info |
| `forest boot [name]` | Boot dev stack for a worktree |
| `forest stop` | Stop the active dev stack |
| `forest switch [name]` | Stop current + boot another |
| `forest status` | Show running state |
| `forest logs [service]` | Tail logs (docker + host services) |
| `forest label [name] [l]` | Set a label for a worktree |
| `forest cleanup [name]` | Tear down resources (volumes, etc.) |
| `forest help` | Show help |

### Options

| Flag | Description |
|---|---|
| `-f`, `--follow` | Follow service logs after boot/switch |
| `--project <path>` | Specify project root explicitly |
| `--version` | Show version |

### Examples

```bash
# Interactive menu — pick a worktree to boot
forest

# Boot worktree by index
forest boot 1

# Boot worktree by name
forest boot feature-auth

# Switch to another worktree and follow logs
forest switch atf -f

# Tail a specific host service log
forest logs web

# Tail a Docker Compose service log
forest logs postgres

# Label a detached worktree
forest label 1 "payment-refactor"

# Check what's running
forest status
```

When a command needs a worktree but you don't specify one, forest shows an **interactive picker** automatically.

---

## Configuration

forest auto-detects your editor and reads config from (in priority order):

| Config file | Key | Used by |
|---|---|---|
| `.cursor/worktrees.json` | `"forest"` | Editors using `.cursor/` config |
| `.claude/settings.json` | `"forest"` | Editors using `.claude/` config |
| `.forest/config.json` | root level | Standalone / any editor |

### Config structure

```json
{
  "forest": {
    "project-name": "my-app",
    "compose-file": "docker-compose.yml",
    "hooks": {
      "pre": ["scripts/pre-boot.sh"],
      "pre-services": ["pnpm install --frozen-lockfile"],
      "post": []
    },
    "services": {
      "web": {
        "cmd": "cd frontend && npx vite --port 5173 --host",
        "label": "Frontend (Vite)",
        "port": 5173
      }
    },
    "urls": {
      "App": "http://localhost:3000",
      "API": "http://localhost:3001"
    },
    "branch-pattern": "^(feat|feature|bugfix|fix|chore|hotfix)/(\\d+)?-?(.+)$"
  }
}
```

> For standalone mode (`.forest/config.json`), omit the wrapping `"forest"` key — put everything at the root level.

### Config fields

| Field | Description |
|---|---|
| `project-name` | Docker Compose project name |
| `compose-file` | Path to your Docker Compose file |
| `hooks.pre` | Scripts to run before `docker compose up` (e.g. k8s setup) |
| `hooks.pre-services` | Commands to run before host services (e.g. `pnpm install`) — sequential |
| `hooks.post` | Scripts to run after everything is up |
| `services` | Host processes (not Docker) — e.g. Vite, webpack, tsc --watch |
| `services.<key>.cmd` | Shell command to run |
| `services.<key>.label` | Display name in logs/status |
| `services.<key>.port` | Port for status display |
| `urls` | Quick-reference URLs shown after boot |
| `branch-pattern` | Regex to extract issue numbers from branch names |

### Hooks

Hooks run in the context of the worktree directory with these env vars available:

| Variable | Description |
|---|---|
| `WORKSPACE_ROOT` | Path to the active worktree |
| `MAIN_ROOT` | Path to the main (root) worktree |

---

## How It Works

### Architecture

```
  You (human)
    │
    ▼
  ┌─────────┐    forest boot 2    ┌──────────────────────┐
  │ forest   │ ──────────────────▶ │ Worktree #2          │
  │ CLI      │                     │ feature/payment-flow │
  └─────────┘                     └──────────┬───────────┘
                                             │
                        ┌────────────────────┼────────────────────┐
                        ▼                    ▼                    ▼
                  ┌───────────┐      ┌─────────────┐     ┌──────────┐
                  │ Docker    │      │ Host Svc 1  │     │ Host Svc │
                  │ Compose   │      │ (Vite web)  │     │ (Vite    │
                  │ Stack     │      │ port 5173   │     │  admin)  │
                  └───────────┘      └─────────────┘     └──────────┘

  Meanwhile, other agents keep working in:
    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
    │ Worktree #1 │  │ Worktree #3 │  │ Worktree #4 │
    │ (idle)      │  │ (idle)      │  │ (idle)      │
    └─────────────┘  └─────────────┘  └─────────────┘
```

### What `forest boot` does

1. **Pre-hooks** — Run scripts like k8s cluster setup, DB migrations
2. **Docker Compose** — `docker compose up -d --build` with proper env/project flags
3. **Pre-services hooks** — Sequential commands like `pnpm install`
4. **Host services** — Start Vite, webpack, etc. (output redirected to `.forest/logs/`)
5. **Post-hooks** — Seed data, health checks, etc.
6. **Summary** — Print URLs and status

### Smart Branch Memory

When a worktree has a branch, forest **remembers it**. If the worktree later enters detached HEAD state (common during rebases or agent operations), forest displays the remembered branch name prefixed with `~` instead of a cryptic SHA.

You can also set **manual labels** with `forest label` for extra context.

### Runtime files

All runtime state lives in `.forest/` (add to `.gitignore`):

```
.forest/
├── active.json    # Currently running worktree info + PIDs
├── meta.json      # Persisted labels and branch memory
└── logs/
    ├── web.log    # Host service stdout/stderr
    └── admin.log
```

---

## Requirements

| Tool | Min version | Notes |
|---|---|---|
| **bash** | 3.2+ | macOS default works fine |
| **git** | 2.5+ | Worktree support required |
| **docker** | 20+ | With Docker Compose v2 |
| **jq** | 1.6+ | JSON processing |

Run `forest doctor` to verify everything.

---

## Multi-Agent Workflow

forest is designed for the modern AI-assisted development workflow:

```
  ┌──────────────────────────────────────────────────────────┐
  │                    Your Project                          │
  │                                                          │
  │  main/        ← stable base                              │
  │  ├── wt-1/    ← Agent 1: working on auth refactor        │
  │  ├── wt-2/    ← Agent 2: working on payment flow         │
  │  ├── wt-3/    ← Agent 3: fixing CSS bug                  │
  │  └── wt-4/    ← Agent 4: adding API endpoint             │
  │                                                          │
  │  You: `forest switch 2` → test Agent 2's payment flow    │
  │  You: `forest switch 3` → review Agent 3's CSS fix       │
  └──────────────────────────────────────────────────────────┘
```

Each agent works independently in its own worktree. When you want to test or review, just `forest switch` to that worktree — the full stack boots in seconds.

---

## Contributing

Contributions are welcome! Please:

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Run ShellCheck: `shellcheck forest`
4. Submit a PR

### Development

```bash
# Clone
git clone https://github.com/prbdias/forest-cli.git
cd forest-cli

# Run ShellCheck
shellcheck forest

# Run tests
bash test/test_forest.sh

# Test locally
./forest --version
```

---

## License

[MIT](LICENSE) — Paulo Dias

---

<p align="center">
  <strong>🌲 forest</strong> — because your agents deserve their own trees.
</p>
