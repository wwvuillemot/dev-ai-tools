# serena-setup

Portable, idempotent setup for [Serena](https://github.com/oraios/serena) — a semantic code-intelligence MCP server that gives AI tools (Claude Code, Cursor, VS Code Copilot, etc.) IDE-like symbol navigation, refactoring, and code understanding across 40+ languages.

## Quick start

```bash
git clone https://github.com/wwvuillemot/serena ~/Projects/serena
cd ~/Projects/serena
make setup
```

## Available commands

| Command | Description |
|---|---|
| `make setup` | Full bootstrap: installs `uv`, wires all clients, then runs `install-lsp` |
| `make install-lsp` | Scan repos, detect languages, interactively install language servers |
| `make setup-projects` | Add `.serena/project.yml` to every project under `~/Projects` |
| `make setup-project PATH=~/Projects/my-repo` | Add `.serena/project.yml` to one project |
| `make update` | Pull latest changes from this repo and re-run `make setup` |
| `make check` | Verify Serena is correctly wired in all three clients |
| `make cache-clean` | Force `uvx` to re-download Serena on next use |
| `make help` | Show all targets |

`PROJECTS_ROOT` defaults to `~/Projects`. Override with:

```bash
make setup-projects PROJECTS_ROOT=/some/other/path
```

---

## What this repo manages

| File | Purpose |
|---|---|
| `Makefile` | All commands — the primary interface |
| `install.sh` | Called by `make setup`; idempotent bootstrap for all clients |
| `serena_config.yml` | Global Serena config, symlinked to `~/.serena/serena_config.yml` |
| `templates/cursor-mcp.json` | Cursor global MCP config (`~/.cursor/mcp.json`) |
| `templates/vscode-mcp-snippet.json` | VS Code MCP entry merged into user `settings.json` |
| `scripts/setup-project.sh` | Creates `.serena/project.yml` in a single project |
| `scripts/setup-all-projects.sh` | Runs `setup-project.sh` across every project under `~/Projects` |

Serena itself is **not** installed locally — it runs via `uvx` (always pulls latest).

---

## Prerequisites

- macOS, Linux, or WSL on Windows 11
- `make` — ships with macOS (Xcode CLT) and all Linux distros
- `uv` — `make setup` will install it if missing
- `python3` — for JSON merging; ships with macOS and most Linux distros
- For **Claude Code**: `claude` CLI installed and authenticated
- Language servers for your languages (see [Language Support](https://oraios.github.io/serena/01-about/020_programming-languages.html))

---

## Setting up a new machine

```bash
git clone https://github.com/wwvuillemot/serena ~/Projects/serena
cd ~/Projects/serena
make setup
```

`make setup` will:
1. Install `uv` if not present
2. Pre-fetch Serena so first use is fast
3. Symlink `serena_config.yml` → `~/.serena/serena_config.yml`
4. Register Serena in **Claude Code** global MCP
5. Merge Serena into **VS Code** user `settings.json`
6. Merge Serena into **Cursor** `~/.cursor/mcp.json`

Verify everything is wired correctly:

```bash
make check
```

---

## Per-project setup (optional but recommended)

Each project under `~/Projects` can have a `.serena/project.yml` for project-specific overrides and a `.serena/memories/` folder for Serena's persistent notes.

### All projects at once

```bash
make setup-projects
```

### One project

```bash
make setup-project PATH=~/Projects/my-repo
```

Both commands are idempotent — safe to re-run as new projects are added.

---

## How each client uses Serena

### Claude Code CLI

Configured globally — no per-project action needed.

```bash
cd ~/Projects/my-repo
claude   # Serena detects the project from cwd automatically
```

Serena is registered with `--project-from-cwd`. To verify:

```bash
claude mcp list
```

### VS Code

Serena is merged into your **user** `settings.json` with `${workspaceFolder}` — activates automatically when you open any folder.

If you prefer per-workspace config, create `.vscode/mcp.json` in the project:

```json
{
  "servers": {
    "serena": {
      "type": "stdio",
      "command": "uvx",
      "args": ["--from", "git+https://github.com/oraios/serena",
               "serena", "start-mcp-server",
               "--context", "ide",
               "--project", "${workspaceFolder}"]
    }
  }
}
```

### Cursor IDE

Configured globally via `~/.cursor/mcp.json`. To verify: **Cursor Settings → MCP** → confirm `serena` is listed.

---

## Configuration

### Global config: `serena_config.yml`

Symlinked to `~/.serena/serena_config.yml`. Edit it here — changes take effect immediately everywhere.

Key options:

```yaml
language_backend: language_servers   # or "JetBrains"
log_level: INFO                      # DEBUG | INFO | WARNING | ERROR
global_ignore_rules:                 # gitignore-style patterns
  - "**/node_modules/**"
  - "**/.venv/**"
```

### Per-project config: `.serena/project.yml`

Created by `make setup-project` or `make setup-projects`. Use it to override global settings:

```yaml
ignore_rules:
  - "tests/fixtures/**"
auto_onboarding: false
```

Commit `project.yml` and `memories/` to the project repo so teammates share context. Exclude caches:

```gitignore
.serena/cache/
.serena/*.log
```

---

## Keeping Serena up to date

```bash
# Pull this repo's config changes and re-run setup
make update

# Force uvx to re-download the latest Serena release
make cache-clean
```

To pin to a specific Serena commit, replace the `--from` URL in `templates/cursor-mcp.json`, `templates/vscode-mcp-snippet.json`, and the `claude mcp add` line in `install.sh`:

```
--from git+https://github.com/oraios/serena@<commit-sha>
```

---

## Troubleshooting

**`make` not found**

```bash
# macOS
xcode-select --install
# Linux
sudo apt install make   # or equivalent
```

**`uv` not in PATH after install**

Add to `~/.zshrc` or `~/.bashrc`, then restart your shell:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

**Claude Code doesn't see Serena**

```bash
make check                          # diagnose
claude mcp remove serena
make setup                          # re-register
```

**VS Code settings not updated**

Manually merge `templates/vscode-mcp-snippet.json` into:
- macOS: `~/Library/Application Support/Code/User/settings.json`
- Linux/WSL: `~/.config/Code/User/settings.json`

**Onboarding runs every time**

Serena writes memory files to `.serena/memories/`. If they're missing or gitignored, onboarding re-triggers. Either commit the memories or add `auto_onboarding: false` to `.serena/project.yml`.

**Slow first start**

Expected — `uvx` downloads and caches Serena on first run. Run `make setup` to pre-cache on a new machine.

---

## References

- [Serena GitHub](https://github.com/oraios/serena)
- [Serena Docs](https://oraios.github.io/serena/01-about/000_intro.html)
- [Configuration Reference](https://oraios.github.io/serena/02-usage/050_configuration.html)
- [Client Setup Guide](https://oraios.github.io/serena/02-usage/030_clients.html)
- [Language Support](https://oraios.github.io/serena/01-about/020_programming-languages.html)
