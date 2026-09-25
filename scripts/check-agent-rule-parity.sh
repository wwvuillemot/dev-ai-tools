#!/usr/bin/env bash
# The "target is a commit, not the working tree" rule is duplicated verbatim in
# every agent definition, because subagents never read SKILL.md. Nothing else
# keeps those copies in step: this gate fails the moment one of them drifts.
set -euo pipefail

cd "$(dirname "$0")/.."

agents=(
  plugins/deep-review/agents/prior-art-finder.md
  plugins/deep-review/agents/review-finder.md
  plugins/deep-review/agents/review-verifier.md
)

extract() {
  sed -n '/^## The target is a commit, not the working tree$/,/^\*\*Never change the checkout\*\*/p' "$1"
}

reference=""
reference_file=""
drifted=0

for f in "${agents[@]}"; do
  [ -f "$f" ] || { echo "missing agent definition: $f" >&2; exit 1; }
  block=$(extract "$f")
  [ -n "$block" ] || { echo "$f: no checkout-rule block found" >&2; exit 1; }

  if [ -z "$reference" ]; then
    reference=$block
    reference_file=$f
  elif [ "$block" != "$reference" ]; then
    echo "checkout rule differs: $reference_file vs $f" >&2
    diff <(printf '%s\n' "$reference") <(printf '%s\n' "$block") >&2 || true
    drifted=1
  fi
done

if [ "$drifted" -ne 0 ]; then
  echo "The rule must stay identical in all ${#agents[@]} agent definitions." >&2
  exit 1
fi

echo "checkout rule identical across ${#agents[@]} agent definitions"
