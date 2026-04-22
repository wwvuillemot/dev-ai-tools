#!/usr/bin/env bash
# setup-project.sh — Scaffold .serena/ in a project directory.
# Usage: setup-project.sh [<project-path>]  (defaults to current directory)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES_DIR="$REPO_DIR/templates"

PROJECT_DIR="${1:-$(pwd)}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
SERENA_DIR="$PROJECT_DIR/.serena"
MEMORIES_DIR="$SERENA_DIR/memories/project"

echo "Setting up Serena for: $PROJECT_DIR"

# ── project.yml ───────────────────────────────────────────────────────────────
PROJECT_YML="$SERENA_DIR/project.yml"

if [[ -f "$PROJECT_YML" ]]; then
  echo "  → .serena/project.yml already exists, skipping."
else
  mkdir -p "$SERENA_DIR"
  cat > "$PROJECT_YML" <<EOF
# Serena project configuration for: $(basename "$PROJECT_DIR")
# See: https://oraios.github.io/serena/02-usage/050_configuration.html

# Uncomment and set the languages used in this project.
# Run 'make install-lsp' from the dev-ai-tools repo to install the servers.
# languages:
#   - python
#   - typescript

# Project-specific ignore rules (merged with global ignored_paths)
# ignored_paths:
#   - "tests/fixtures/**"
EOF
  echo "  → Created $PROJECT_YML"
fi

# ── .serena/.gitignore ────────────────────────────────────────────────────────
SERENA_GITIGNORE="$SERENA_DIR/.gitignore"

if [[ ! -f "$SERENA_GITIGNORE" ]]; then
  mkdir -p "$SERENA_DIR"
  printf '/cache\n/project.local.yml\n' > "$SERENA_GITIGNORE"
  echo "  → Created $SERENA_GITIGNORE"
fi

# ── Memory templates ──────────────────────────────────────────────────────────
mkdir -p "$MEMORIES_DIR"

copy_template() {
  local name="$1"
  local src="$TEMPLATES_DIR/memories/project/$name"
  local dst="$MEMORIES_DIR/$name"

  if [[ -f "$dst" ]]; then
    echo "  → $name already exists, skipping."
  elif [[ -f "$src" ]]; then
    cp "$src" "$dst"
    echo "  → Created $dst"
  else
    echo "  [!] Template not found: $src"
  fi
}

copy_template "overview.md"
copy_template "suggested_commands.md"
copy_template "task_completion_checklist.md"
copy_template "style_and_conventions.md"

# ── Project .gitignore ────────────────────────────────────────────────────────
PROJECT_GITIGNORE="$PROJECT_DIR/.gitignore"

if [[ -f "$PROJECT_GITIGNORE" ]]; then
  if ! grep -q "\.serena/cache" "$PROJECT_GITIGNORE" 2>/dev/null; then
    printf '\n# Serena — cache and local overrides are gitignored via .serena/.gitignore\n' >> "$PROJECT_GITIGNORE"
    echo "  → Added Serena note to .gitignore"
  fi
else
  printf '# Serena — cache and local overrides are gitignored via .serena/.gitignore\n' > "$PROJECT_GITIGNORE"
  echo "  → Created .gitignore"
fi

echo "Done: $PROJECT_DIR"
echo
echo "  Next: fill in .serena/memories/project/ with project-specific context."
echo "  Serena will read these files automatically when working in this project."
