#!/usr/bin/env bash
# =============================================================================
# dev-ai-tools — install-graphify.sh
# Idempotent installer for Graphify: https://graphify.net
#
# Installs the graphify CLI via `uv tool install graphifyy`, then — for each
# AI coding client detected on this machine — offers to wire Graphify into it
# via `graphify <client> install` (skipped if the installed graphify CLI
# does not advertise that subcommand in its --help output).
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

vscode_user_dir() {
  case "$OS" in
    macos) echo "$HOME/Library/Application Support/Code/User" ;;
    *)     echo "$HOME/.config/Code/User" ;;
  esac
}

section "Graphify (knowledge-graph skill)"

if ! command -v uv &>/dev/null; then
  warn "uv not found — Graphify is installed via 'uv tool install graphifyy'."
  warn "  Run 'make setup' first (it installs uv), or install uv manually:"
  warn "    curl -LsSf https://astral.sh/uv/install.sh | sh"
  exit 0
fi

_gf_already_installed=false
if command -v graphify &>/dev/null; then
  _gf_already_installed=true
  ok "graphify already installed: $(graphify --version 2>/dev/null | head -1 || echo 'version unknown')"
fi

if $_gf_already_installed; then
  if [[ "${DEV_AI_TOOLS_SKIP_CLI_UPGRADE:-0}" == "1" ]]; then
    info "CLI already installed — skipping upgrade check (run 'make install-graphify' from the dev-ai-tools repo to upgrade)."
  else
    read -r -p "  Update Graphify (uv tool upgrade graphifyy)? [y/N] " _gf_answer
    _gf_answer="${_gf_answer:-N}"
    if [[ "$_gf_answer" =~ ^[Yy] ]]; then
      uv tool upgrade graphifyy || warn "uv tool upgrade returned non-zero; continuing"
    else
      info "Keeping current Graphify version."
    fi
  fi
else
  read -r -p "  Install Graphify (uv tool install graphifyy)? [Y/n] " _gf_answer
  _gf_answer="${_gf_answer:-Y}"
  if [[ "$_gf_answer" =~ ^[Yy] ]]; then
    uv tool install graphifyy
  else
    info "Skipped Graphify install — per-client wiring needs the graphify CLI. Exiting."
    exit 0
  fi
fi

# Re-source PATH in case uv tool install dropped a shim into ~/.local/bin
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

if ! command -v graphify &>/dev/null; then
  warn "graphify CLI not on PATH after install. You may need to restart your shell,"
  warn "  or run:  uv tool update-shell"
  exit 0
fi

ok "graphify: $(graphify --version 2>/dev/null | head -1 || echo 'installed')"

# Probe which client subcommands this graphify version supports.
GF_HELP="$(graphify --help 2>&1 || true)"

graphify_supports() {
  # Match the subcommand as a word boundary to avoid false positives.
  grep -Eq "(^|[[:space:]])$1([[:space:]]|$)" <<<"$GF_HELP"
}

offer_graphify_client() {
  local client_subcmd="$1"   # e.g. "claude", "vscode", "cursor"
  local client_label="$2"    # e.g. "Claude Code"
  local detect_cmd="$3"      # a bash expression that returns 0 if the client is installed

  if ! graphify_supports "$client_subcmd"; then
    info "Graphify does not expose a '$client_subcmd' subcommand — skipping $client_label."
    return 0
  fi

  if ! eval "$detect_cmd"; then
    info "$client_label not detected on this machine — skipping."
    return 0
  fi

  read -r -p "  Install Graphify into $client_label? [Y/n] " _ans
  _ans="${_ans:-Y}"
  if [[ "$_ans" =~ ^[Yy] ]]; then
    if graphify "$client_subcmd" install; then
      ok "Graphify wired into $client_label."
    else
      warn "Graphify '$client_subcmd install' returned non-zero. See Graphify docs: https://graphify.net"
    fi
  else
    info "Skipped $client_label."
  fi
}

echo
info "Checking which clients to wire Graphify into..."

offer_graphify_client "claude" "Claude Code" 'command -v claude &>/dev/null'
offer_graphify_client "cursor" "Cursor IDE"  '[[ -d "$HOME/.cursor" ]]'
offer_graphify_client "vscode" "VS Code"     '[[ -d "$(vscode_user_dir)" ]]'

echo
info "Graphify also supports Codex, OpenCode, Copilot CLI, Aider, and others —"
info "  run 'graphify --help' to see the full list, or 'graphify <client> install' manually."
