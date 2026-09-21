#!/usr/bin/env bash
# setup-all-projects.sh — Run setup-project.sh for every subdirectory of your projects root.
# Usage: setup-all-projects.sh [<root-dir>]
#   root-dir  explicit root. When omitted, PROJECTS_ROOT from the environment is
#             used; failing that, common locations are probed.
set -euo pipefail

# Precedence: explicit argument → PROJECTS_ROOT in the environment → probe.
# NOTE: install-language-servers.sh carries the same candidate list — keep in sync.
PROJECTS_ROOT="${1:-${PROJECTS_ROOT:-}}"
if [[ -z "$PROJECTS_ROOT" ]]; then
  for _candidate in "$HOME/projects" "$HOME/Projects" "$HOME/dev" "$HOME/src" "$HOME/code" "$HOME/work"; do
    if [[ -d "$_candidate" ]]; then
      PROJECTS_ROOT="$_candidate"
      break
    fi
  done
fi

if [[ -z "$PROJECTS_ROOT" ]]; then
  echo "Error: no projects root found. Re-run with an explicit path:"
  echo "  make setup-projects PROJECTS_ROOT=/path/to/your/repos"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/setup-project.sh"

if [[ ! -d "$PROJECTS_ROOT" ]]; then
  echo "Error: $PROJECTS_ROOT does not exist."
  exit 1
fi

echo "Scanning $PROJECTS_ROOT for project directories..."
echo

count=0
skipped=0

while IFS= read -r -d '' dir; do
  # Skip the dev-ai-tools repo itself and hidden dirs
  basename_dir="$(basename "$dir")"
  if [[ "$basename_dir" == dev-ai-tools || "$basename_dir" == .* ]]; then
    continue
  fi

  # Only treat it as a project if it has a git repo or common project markers
  if [[ -d "$dir/.git" || -f "$dir/package.json" || -f "$dir/pyproject.toml" || \
        -f "$dir/Cargo.toml" || -f "$dir/go.mod" || -f "$dir/pom.xml" || \
        -f "$dir/build.gradle" || -f "$dir/Makefile" ]]; then
    bash "$SETUP_SCRIPT" "$dir"
    ((count++)) || true
  else
    echo "  Skipping (no project markers): $dir"
    ((skipped++)) || true
  fi
done < <(find "$PROJECTS_ROOT" -mindepth 1 -maxdepth 2 -type d -print0 | sort -z)

echo
echo "Done. Configured $count project(s), skipped $skipped."
