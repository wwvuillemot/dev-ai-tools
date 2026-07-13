#!/usr/bin/env bash
# =============================================================================
# dev-ai-tools — install-backlog.sh
# Idempotent installer for Backlog.md: https://backlog.md
#
# Backlog.md is a git-native, markdown task/spec/review layer for human+AI
# collaboration. Tasks are plain .md files in your repo (no database), and it
# exposes an MCP server (`backlog mcp start`) so agents can create, plan, and
# finalize tasks with review checkpoints.
#
# Install:
#   macOS: `brew install backlog-md` when brew is present, else `npm i -g backlog.md`.
#   Linux / WSL: `npm i -g backlog.md` (requires Node.js / npm).
#
# Wiring: unlike Graphify, Backlog.md has no `backlog <client> install` command,
# so we register its MCP server into each detected client ourselves, matching
# the pattern install.sh uses for Serena.
# =============================================================================
set -euo pipefail

info()    { echo "  [·] $*"; }
ok()      { echo "  [✓] $*"; }
warn()    { echo "  [!] $*"; }
section() { echo; echo "── $* ──────────────────────────────────────────────"; }

detect_os() {
  if [[ "$(uname)" == "Darwin" ]]; then
    echo "macos"
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl"
  else
    echo "linux"
  fi
}

OS="$(detect_os)"

win_username() {
  cmd.exe /C "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || echo "$USER"
}
win_appdata() {
  local wuser
  wuser="$(win_username)"
  echo "${APPDATA:-/mnt/c/Users/$wuser/AppData/Roaming}"
}
vscode_user_dir() {
  case "$OS" in
    macos) echo "$HOME/Library/Application Support/Code/User" ;;
    *)     echo "$HOME/.config/Code/User" ;;
  esac
}

# -----------------------------------------------------------------------------
# 1. Install / update the backlog CLI
# -----------------------------------------------------------------------------
section "Backlog.md (git-native task / spec / review)"

install_backlog() {
  if [[ "$OS" == "macos" ]] && command -v brew &>/dev/null; then
    info "Installing via Homebrew..."
    # Skip brew's auto-cleanup: it can fail on unrelated root-owned files and
    # kill this script under `set -e` (same guard as install-rtk.sh).
    HOMEBREW_NO_INSTALL_CLEANUP=1 brew install backlog-md
  elif command -v npm &>/dev/null; then
    info "Installing via npm (npm i -g backlog.md)..."
    npm i -g backlog.md
  else
    warn "Neither Homebrew nor npm found — cannot install Backlog.md."
    warn "  Install Node.js (which provides npm), then re-run, or see: https://backlog.md"
    return 1
  fi
}

upgrade_backlog() {
  if [[ "$OS" == "macos" ]] && command -v brew &>/dev/null && brew list backlog-md &>/dev/null 2>&1; then
    info "Upgrading via Homebrew..."
    HOMEBREW_NO_INSTALL_CLEANUP=1 brew upgrade backlog-md 2>/dev/null || info "Already at latest version"
  elif command -v npm &>/dev/null; then
    info "Upgrading via npm (npm i -g backlog.md@latest)..."
    npm i -g backlog.md@latest
  else
    warn "Neither Homebrew nor npm found — cannot upgrade Backlog.md."
    return 1
  fi
}

_bl_already=false
if command -v backlog &>/dev/null; then
  _bl_already=true
  ok "Backlog.md already installed: $(backlog --version 2>/dev/null | head -1 || echo 'version unknown')"
fi

if $_bl_already; then
  read -r -p "  Update Backlog.md? [y/N] " _bl_answer
  _bl_answer="${_bl_answer:-N}"
else
  read -r -p "  Install Backlog.md? [Y/n] " _bl_answer
  _bl_answer="${_bl_answer:-Y}"
fi

if [[ ! "$_bl_answer" =~ ^[Yy] ]]; then
  info "Skipped Backlog.md install."
  exit 0
fi

if $_bl_already; then
  upgrade_backlog || warn "Upgrade returned non-zero; continuing"
else
  install_backlog || exit 0
fi

# npm global bins usually land on PATH already; nudge common locations just in case.
export PATH="$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:$PATH"

if ! command -v backlog &>/dev/null; then
  warn "backlog CLI not on PATH after install. You may need to restart your shell,"
  warn "  or ensure your global npm/brew bin directory is on PATH."
  exit 0
fi

ok "backlog: $(backlog --version 2>/dev/null | head -1 || echo 'installed')"

# Absolute path — clients that don't inherit the login shell PATH still resolve it.
BACKLOG_PATH="$(command -v backlog 2>/dev/null || echo backlog)"

# -----------------------------------------------------------------------------
# 2. Wire the MCP server into each detected client
# -----------------------------------------------------------------------------
# Merge (or create) a JSON MCP config, adding a "backlog" entry under $top_key.
# Args: <config_path> <top_key: servers|mcpServers> <backlog_cmd> <wrap: none|wsl>
merge_mcp_json() {
  python3 - "$1" "$2" "$3" "$4" <<'PYEOF'
import json, os, shutil, sys

config_path, top_key, backlog_cmd, wrap = sys.argv[1:5]

config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        try:
            config = json.load(f)
        except json.JSONDecodeError:
            print(f"  [!] Could not parse {config_path} — leaving it untouched.")
            sys.exit(0)
    shutil.copy2(config_path, config_path + ".bak")

if wrap == "wsl":
    # Windows-side clients must call the Linux backlog binary through wsl.exe.
    entry = {"command": "wsl.exe", "args": ["--", backlog_cmd, "mcp", "start"]}
else:
    entry = {"command": backlog_cmd, "args": ["mcp", "start"]}

config.setdefault(top_key, {})["backlog"] = entry

os.makedirs(os.path.dirname(config_path), exist_ok=True)
with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print(f"  [✓] Wrote backlog to {config_path}")
PYEOF
}

json_has_backlog() {
  # Args: <config_path> <top_key>
  [[ -f "$1" ]] && python3 -c \
    "import json,sys; d=json.load(open(sys.argv[1])); exit(0 if 'backlog' in d.get(sys.argv[2],{}) else 1)" \
    "$1" "$2" 2>/dev/null
}

# Generic prompt for a JSON-config client.
# Args: <label> <config_path> <top_key> <wrap: none|wsl>
offer_json_client() {
  local label="$1" cfg="$2" key="$3" wrap="$4"
  if json_has_backlog "$cfg" "$key"; then
    read -r -p "  Backlog.md already configured. Update $label MCP entry? [y/N] " _ans
    _ans="${_ans:-N}"
  else
    read -r -p "  Install Backlog.md into $label? [Y/n] " _ans
    _ans="${_ans:-Y}"
  fi
  if [[ "$_ans" =~ ^[Yy] ]]; then
    merge_mcp_json "$cfg" "$key" "$BACKLOG_PATH" "$wrap"
  else
    info "Skipped $label."
  fi
}

# ── Claude Code (global user-scope MCP via its own CLI) ──────────────────────
section "Claude Code (global MCP)"
if ! command -v claude &>/dev/null; then
  info "Claude Code CLI not found — skipping."
else
  if claude mcp list 2>/dev/null | grep -q backlog; then
    read -r -p "  Backlog.md already configured. Update Claude Code MCP entry? [y/N] " _cc_answer
    _cc_answer="${_cc_answer:-N}"
  else
    read -r -p "  Install Backlog.md into Claude Code? [Y/n] " _cc_answer
    _cc_answer="${_cc_answer:-Y}"
  fi
  if [[ "$_cc_answer" =~ ^[Yy] ]]; then
    claude mcp remove backlog 2>/dev/null || true
    claude mcp add -s user backlog -- "$BACKLOG_PATH" mcp start
    ok "Backlog.md added to Claude Code global MCP (backlog resolves the project from cwd)."
  else
    info "Skipped Claude Code setup."
  fi
fi

# ── VS Code (user mcp.json, top-level "servers") ─────────────────────────────
section "VS Code (user mcp.json)"
VSCODE_MCP="$(vscode_user_dir)/mcp.json"
if [[ ! -d "$(vscode_user_dir)" ]]; then
  info "VS Code user directory not found — skipping."
else
  offer_json_client "VS Code" "$VSCODE_MCP" "servers" "none"
fi

# WSL: also update the Windows-side VS Code mcp.json (via wsl.exe).
if [[ "$OS" == "wsl" ]]; then
  WIN_MCP="$(win_appdata)/Code/User/mcp.json"
  if [[ -d "$(dirname "$WIN_MCP")" ]]; then
    section "VS Code Windows-side (WSL)"
    offer_json_client "Windows-side VS Code" "$WIN_MCP" "servers" "wsl"
  fi
fi

# ── Cursor (~/.cursor/mcp.json, top-level "mcpServers") ──────────────────────
section "Cursor IDE (~/.cursor/mcp.json)"
if [[ ! -d "$HOME/.cursor" ]]; then
  info "Cursor IDE not found — skipping."
else
  offer_json_client "Cursor" "$HOME/.cursor/mcp.json" "mcpServers" "none"
fi

# ── Claude Desktop (claude_desktop_config.json, top-level "mcpServers") ───────
section "Claude Desktop"
claude_desktop_installed() {
  case "$OS" in
    macos) [[ -d "/Applications/Claude.app" ]] ;;
    wsl)
      local wuser; wuser="$(win_username)"
      [[ -d "/mnt/c/Users/$wuser/AppData/Local/AnthropicClaude" ]] \
        || [[ -d "/mnt/c/Users/$wuser/AppData/Local/Programs/claude-desktop" ]] ;;
    *) return 1 ;;
  esac
}
claude_desktop_config() {
  case "$OS" in
    macos) echo "$HOME/Library/Application Support/Claude/claude_desktop_config.json" ;;
    wsl)   echo "/mnt/c/Users/$(win_username)/AppData/Roaming/Claude/claude_desktop_config.json" ;;
    *)     echo "" ;;
  esac
}
if claude_desktop_installed; then
  _cd_wrap="none"; [[ "$OS" == "wsl" ]] && _cd_wrap="wsl"
  offer_json_client "Claude Desktop" "$(claude_desktop_config)" "mcpServers" "$_cd_wrap"
  info "Restart Claude Desktop to pick up the new MCP server."
  info "Backlog.md is project-oriented — point it at a repo with:"
  info "  set BACKLOG_CWD=/absolute/path in the backlog entry's \"env\", or run 'backlog init' there."
else
  info "Claude Desktop not found — skipping."
fi

# -----------------------------------------------------------------------------
# 3. Next steps
# -----------------------------------------------------------------------------
echo
info "Per-project: run 'backlog init \"<Project Name>\"' in a repo to create the"
info "  backlog/ task store and register agent instructions in AGENTS.md / CLAUDE.md."
info "Then 'backlog board' (terminal Kanban) or 'backlog browser' (local web UI)."
