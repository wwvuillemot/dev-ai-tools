---
name: deep-review
description: >-
  Adversarial, lens-driven code review. Selects review lenses (correctness, design/SOLID/DRY,
  performance, security, tenancy, governance, conventions, blast-radius), fans out independent finder agents
  per lens, verifies every candidate by refutation rather than confirmation, checks the change
  against the codebase's existing patterns and components, ranks what survives, and delivers
  findings as batched inline pull-request comments. Use when asked to "deep review", "review
  this branch/PR adversarially", "review for SOLID/DRY/SRP", "review for performance", "review
  for security", "review for governance", or when a review must judge a change against the
  system's existing conventions rather than the diff alone.
---

# Deep Review

A review harness with three commitments that ordinary review lacks:

1. **Lenses are data, not hardcoded.** You pick what the review is *about*.
2. **Verification is adversarial.** Every candidate finding must survive agents actively trying to refute it.
3. **The system is in scope, not just the diff.** A change that reinvents an existing component is a finding, even when every line of it is correct.

## Invocation

```
/deep-review [target] [--lens <names>] [--depth quick|standard|deep] [--post]
```

- **target** — omitted: the working diff vs. the merge base. `<PR#>` or a PR URL: that pull request. `<branch>`: that branch vs. its base.
- **--lens** — comma-separated lens names, or `all`. Default: `correctness,design,conventions,blast-radius`.
- **--depth** — `quick` (1 finder/lens, 1 verifier), `standard` (2 finders/lens, 3 verifiers), `deep` (3 finders/lens, 3 verifiers + sweep). Default `standard`.
- **--post** — deliver as inline PR comments. Without it, report in chat only.

If the user's request names a concern ("check this for N+1s", "is this a security risk"), map it to lenses and say which you selected before running.

## Lens registry

Lenses are markdown files with frontmatter. Load them from all three sources, later sources overriding earlier ones by `name`:

1. **Built-in** — `lenses/*.md` in this skill directory.
2. **Plugin-contributed** — `deep-review/lenses/*.md` inside any other installed plugin. This is how a private or org-specific plugin adds proprietary lenses without forking this one.
3. **Project-local** — `.claude/deep-review/lenses/*.md` in the repo under review, and any `lenses:` block in `.claude/deep-review.yml`.

Read [EXTENDING.md](../../EXTENDING.md) before adding lenses.

Never hardcode a lens in this file. If a review needs a concern that no lens covers, say so and offer to write the lens — do not silently improvise one, because an improvised lens produces findings nobody can reproduce next time.

## Phase 1 — Scope

Establish, with commands and not assumption:

- The diff and its merge base (`git merge-base`, `git diff --stat`). Never review a diff you have not actually read.
- The repo's own instructions — root `CLAUDE.md`/`AGENTS.md` plus any in touched directories. These bind the `conventions` lens.
- Which lenses are active and why.

State the scope in one line before fanning out: files, lines, lenses, depth. If the diff is empty, stop and say so.

## Phase 2 — Find (parallel, per lens)

One finder agent per lens per finder-slot. Each finder gets: the diff, the lens definition, the repo instruction files, and **nothing about the other lenses** — independence is the point; a finder that knows what others are looking for converges with them.

Finders return *candidates*, not findings. Every candidate needs:

- `file`, `line` (1-indexed, anchored in the changed code)
- `summary` — one sentence stating the defect
- `failure_scenario` — **concrete** inputs or state leading to a wrong outcome. For non-correctness lenses, state the concrete cost instead: what is duplicated, what will be re-fixed in three places, which stated rule is broken.
- `lens`, `category` (kebab-case slug)

A candidate without a failure scenario is not a candidate. Drop it at the finder.

**The prior-art finder always runs**, regardless of lens selection. Its job is the question a diff-only review structurally cannot ask: *does this already exist?* It searches the repo for existing abstractions, helpers, components, and patterns that the change duplicates, bypasses, or contradicts, and it reads the neighbouring implementation of the same kind of feature to see how the codebase already solves this. Findings from it are usually the highest-value output of the whole run, because the duplicated thing is by definition not in the diff.

## Phase 3 — Pool and dedupe

Barrier here — this is one of the few places a barrier is correct, because dedupe needs every candidate at once. Merge candidates by `(file, line)` and near-identical summary. Keep the clearest wording; union the lenses that flagged it. A finding flagged independently by two lenses is stronger, so record that.

## Phase 4 — Refute

For every deduped candidate, spawn verifiers **prompted to refute, not to confirm**:

> Try to refute this finding. Read the surrounding code and the repo's instructions. Default to `refuted: true` if you cannot demonstrate the problem is real. A finding you cannot reproduce or evidence is refuted.

At `standard`/`deep`, give the three verifiers **different lenses** — correctness, exploitability/consequence, and does-it-actually-reproduce. Three identical skeptics are one skeptic with variance; three different ones catch failure modes redundancy cannot. Survival requires a majority not refuting.

Kill on sight, without spending a verifier:

- Pre-existing issues on lines the change did not touch — but "untouched" is not
  "pre-existing." If the change is what made a previously-correct line wrong, that is a
  new bug and it is in scope. Ask: was this correct before the diff, and wrong after?
- Anything a linter, typechecker, compiler, or formatter catches
- Style not written down in the repo's own instructions
- Issues silenced deliberately in code (lint-ignore with a reason)
- Intentional changes that are simply part of the stated purpose of the diff

## Phase 5 — Rank and cap

Order by severity, then confidence. **Correctness outranks design, performance, and convention findings whenever the cap forces a cut** — a reviewer who leads with naming while a race condition sits below the fold has failed.

If you cap, **say what you dropped and why**. A silent cap reads as "that's everything," which is a lie the reader cannot detect.

## Phase 6 — Deliver

Default is a chat report: verdict, ranked findings with evidence, and what was checked but found clean (that last part is what makes a clean review trustworthy).

With `--post`, deliver to the pull request:

- **Line-level comments on the specific lines**, batched into **one** review via the reviews API — not a stream of individual comments, and not one giant summary comment. A finding about a line belongs on that line, where it can be resolved individually.
- Where a review thread already exists on that line, **reply in the thread** rather than opening a duplicate.
- Reserve the review body for what is genuinely global: the verdict, cross-cutting patterns, and the coverage note.
- **Never resolve threads yourself.** Fix-and-reply, then leave them open for the human to resolve.

Ask before posting unless the invocation already said `--post`.

## Honesty rules

These are the difference between a review that is trusted and one that gets ignored:

- Findings you could not verify are reported as unverified, or not at all — never promoted to certainty by confident phrasing.
- If a lens could not run (missing context, unreadable files, tool failure), say which and why. Silence about a skipped lens implies coverage you did not have.
- Distinguish "I read this and it is fine" from "I did not look at this."
- Do not pad. Zero findings after a real search is a legitimate, valuable result — report it plainly rather than manufacturing nitpicks to look thorough.
