#!/usr/bin/env bash
# =============================================================================
# dev-ai-tools — install-rtk.sh
# Idempotent installer for RTK (Rust Token Killer): https://github.com/rtk-ai/rtk
#
# macOS: brew install rtk if brew is present, else the official curl installer.
# Linux / WSL: always the curl installer.
# Native Windows is not supported from this repo (use WSL).
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
RTK_CURL_URL="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"

install_rtk_macos() {
  if command -v brew &>/dev/null; then
    info "Installing via Homebrew..."
    # Skip brew's 30-day auto-cleanup: it can fail on unrelated root-owned
    # files elsewhere in the prefix and kill this script under `set -e`.
    HOMEBREW_NO_INSTALL_CLEANUP=1 brew install rtk
  else
    info "Homebrew not found — using curl installer..."
    curl -fsSL "$RTK_CURL_URL" | sh
  fi
}

install_rtk_linux_wsl() {
  info "Installing via curl..."
  curl -fsSL "$RTK_CURL_URL" | sh
}

install_rtk() {
  case "$OS" in
    macos) install_rtk_macos ;;
    wsl|linux) install_rtk_linux_wsl ;;
  esac
}

upgrade_rtk() {
  if [[ "$OS" == "macos" ]] && command -v brew &>/dev/null && brew list rtk &>/dev/null 2>&1; then
    info "Upgrading via Homebrew..."
    brew upgrade rtk 2>/dev/null || info "Already at latest version"
  else
    info "Re-running installer to upgrade..."
    curl -fsSL "$RTK_CURL_URL" | sh
  fi
}

section "RTK (Rust Token Killer)"

if command -v rtk &>/dev/null; then
  _current_version="$(rtk --version 2>/dev/null | head -1 || echo 'unknown')"
  ok "RTK already installed: $_current_version"
  read -r -p "  Update RTK? [y/N] " _rtk_answer
  _rtk_answer="${_rtk_answer:-N}"
  if [[ "$_rtk_answer" =~ ^[Yy] ]]; then
    upgrade_rtk
    ok "RTK: $(rtk --version 2>/dev/null | head -1 || echo 'installed')"
  else
    info "Keeping current RTK version."
  fi
else
  read -r -p "  Install RTK? [Y/n] " _rtk_answer
  _rtk_answer="${_rtk_answer:-Y}"
  if [[ "$_rtk_answer" =~ ^[Yy] ]]; then
    install_rtk
    # Re-source PATH additions that the installer may have dropped into the env
    export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    if command -v rtk &>/dev/null; then
      ok "RTK installed: $(rtk --version 2>/dev/null | head -1 || echo 'installed')"
    else
      warn "RTK install ran, but 'rtk' not on PATH. You may need to restart your shell."
      warn "  Add the install target to your PATH (typically \$HOME/.local/bin or \$HOME/.cargo/bin)."
    fi
  else
    info "Skipped RTK install."
  fi
fi
