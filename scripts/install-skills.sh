#!/usr/bin/env bash
# Install the practice skills into a project, in each agent tool's native format.
#
# Authored once in Claude Code's SKILL.md format; generated into the others. The markdown body is
# tool-agnostic by design, so the conversion is frontmatter-only.
#
#   install-skills.sh <project-dir> [only-csv]
#
# Idempotent: re-running refreshes in place. The AGENTS.md section is delimited by markers, so
# nothing you wrote there is ever touched.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO_DIR/plugins/practices/skills"
TARGET="${1:-}"
ONLY="${2:-}"

BEGIN_MARK="<!-- BEGIN dev-ai-tools practice skills -->"
END_MARK="<!-- END dev-ai-tools practice skills -->"

if [[ -z "$TARGET" ]]; then
  echo "usage: install-skills.sh <project-dir> [only-csv]" >&2
  exit 2
fi
TARGET="${TARGET/#\~/$HOME}"
if [[ ! -d "$TARGET" ]]; then
  echo "no such directory: $TARGET" >&2
  exit 1
fi

# Which skills? Default is all of them.
skills=()
for d in "$SRC"/*/; do
  name="$(basename "$d")"
  [[ -f "$d/SKILL.md" ]] || continue
  if [[ -n "$ONLY" ]]; then
    case ",$ONLY," in *",$name,"*) ;; *) continue ;; esac
  fi
  skills+=("$name")
done

if [[ ${#skills[@]} -eq 0 ]]; then
  echo "no skills matched${ONLY:+ ONLY=$ONLY}" >&2
  exit 1
fi

# Read a frontmatter field without a YAML parser — the frontmatter here is two flat string keys.
fm() { sed -n "s/^$2: //p" "$1" | head -1; }
# Everything after the closing --- of the frontmatter.
body() { awk 'f>1{print} /^---$/{f++}' "$1"; }

echo "── Claude Code (.claude/skills/) ────────────────────"
mkdir -p "$TARGET/.claude/skills"
for s in "${skills[@]}"; do
  mkdir -p "$TARGET/.claude/skills/$s"
  cp "$SRC/$s/SKILL.md" "$TARGET/.claude/skills/$s/SKILL.md"
  echo "  [✓] $s"
done

echo "── Cursor (.cursor/rules/) ──────────────────────────"
mkdir -p "$TARGET/.cursor/rules"
for s in "${skills[@]}"; do
  desc="$(fm "$SRC/$s/SKILL.md" description)"
  {
    echo "---"
    echo "description: $desc"
    # alwaysApply:false — these are situational, and a rule that always fires is a rule that gets
    # tuned out. Cursor decides from the description, same as Claude does.
    echo "alwaysApply: false"
    echo "---"
    body "$SRC/$s/SKILL.md"
  } > "$TARGET/.cursor/rules/$s.mdc"
  echo "  [✓] $s.mdc"
done

echo "── Codex / generic (AGENTS.md) ──────────────────────"
agents="$TARGET/AGENTS.md"
touch "$agents"
section="$(mktemp)"
{
  echo "$BEGIN_MARK"
  echo ""
  echo "## Practice skills"
  echo ""
  echo "Working habits that decide whether this agent's output is trustworthy. Each was written after"
  echo "the failure it prevents actually happened. Full text in \`.claude/skills/<name>/SKILL.md\`."
  echo ""
  for s in "${skills[@]}"; do
    echo "- **$s** — $(fm "$SRC/$s/SKILL.md" description)"
  done
  echo ""
  echo "$END_MARK"
} > "$section"

if grep -qF "$BEGIN_MARK" "$agents"; then
  # Replace between the markers, leaving everything else alone.
  python3 - "$agents" "$section" "$BEGIN_MARK" "$END_MARK" <<'PY'
import sys, pathlib
target, section, begin, end = sys.argv[1:5]
t = pathlib.Path(target).read_text()
new = pathlib.Path(section).read_text().rstrip("\n")
pre, rest = t.split(begin, 1)
_, post = rest.split(end, 1)
pathlib.Path(target).write_text(pre + new + post)
PY
  echo "  [✓] AGENTS.md section refreshed"
else
  printf '\n%s\n' "$(cat "$section")" >> "$agents"
  echo "  [✓] AGENTS.md section appended"
fi
rm -f "$section"

echo ""
echo "Installed ${#skills[@]} skill(s) into $TARGET"
echo "  Claude Code picks these up automatically; Cursor reads .cursor/rules/;"
echo "  other tools read AGENTS.md."
