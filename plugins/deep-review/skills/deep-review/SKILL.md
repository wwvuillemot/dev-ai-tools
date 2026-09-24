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
/deep-review [target] [--lens <names>] [--depth quick|standard|deep] [--post | --no-post]
```

- **target** — omitted: the working diff vs. the merge base. `<PR#>` or a PR URL: that pull request. `<branch>`: that branch vs. its base.
- **--lens** — comma-separated lens names, or `all`. Default: `correctness,design,conventions,blast-radius`.
- **--depth** — `quick` (1 finder/lens, 1 verifier), `standard` (2 finders/lens, 3 verifiers), `deep` (3 finders/lens, 3 verifiers + sweep). Default `standard`.
- **--post / --no-post** — where the findings go. A PR target **posts to the PR by default**; `--no-post` keeps it in chat. Any other target reports in chat unless `--post` is given, which posts to that branch's open PR.

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

- **The exact commit under review, as a SHA (`$SHA`), and its merge base (`$BASE`).** Every later read, every subagent prompt, and the posted review's `commit_id` use this one SHA, so comments anchor to the code that was actually reviewed even if the author pushes mid-run.
- The diff (`git diff --stat`, then the diff itself). Never review a diff you have not actually read.
- The repo's own instructions — root `CLAUDE.md`/`AGENTS.md` plus any in touched directories — and project-local lenses, **read at `$BASE`**, so a change cannot rewrite the rules it is judged by. These bind the `conventions` lens.
- Which lenses are active and why.

> **Never change the checkout — read refs, do not switch to them.** The target is usually a branch
> or PR that is not current, and the working tree is frequently **not yours**: another agent or a
> person may be mid-edit in it, with uncommitted work and a branch they expect to still be on.
> Checking out the branch under review yanks the tree out from under them — observed in the wild,
> where HEAD moved to a detached `origin/<branch>` and the file a working agent was editing ceased
> to exist mid-write.
>
> A reviewer never needs a working tree. Pin the target to a SHA and read everything through it:
>
> ```bash
> git fetch origin                                             # base branches
> git fetch origin "refs/pull/<N>/head" && SHA=$(git rev-parse FETCH_HEAD)   # a PR, fork PRs included
> git fetch origin <branch>             && SHA=$(git rev-parse FETCH_HEAD)   # a branch
> BASE=$(git merge-base origin/<base-branch> "$SHA")
>
> git diff "$BASE" "$SHA"                          # the diff under review
> git show "$SHA:<path>"                           # any file at the target
> git grep -n <pattern> "$SHA"                     # search the target
> git log "$BASE..$SHA"                            # the commits and their messages
> gh pr view <N> --json title,body,baseRefName     # PR metadata
> ```
>
> A plain `git fetch origin` does **not** bring in a fork PR's head — its branch lives in the
> contributor's fork — so always fetch `refs/pull/<N>/head` for a PR. With no target, the working
> tree *is* the target: read it directly; there is no SHA to pin.
>
> `Read`, `Grep` and `Glob` read the working tree, which is **not** the target when reviewing a PR
> or branch; use the `git show`/`git grep` forms instead. If you genuinely need a populated tree (a
> build, a test run, a tool that only walks the filesystem), create an isolated one with
> `git worktree add <scratch-dir> "$SHA"`, or launch the agent with `isolation: "worktree"`, and
> remove it afterwards. Never `git checkout`, `git switch`, `gh pr checkout`, `git stash`,
> `git restore`, `git reset` or `git clean` in the user's checkout.
>
> Subagents never read this file, and they share the working directory — one of them switching
> branches corrupts every other agent's view mid-run. So the rule is also in each agent's own
> definition, and every finder and verifier prompt carries `$SHA` and `$BASE` (Phases 2 and 4).

State the scope in one line before fanning out: files, lines, lenses, depth. If the diff is empty, stop and say so.

## Phase 2 — Find (parallel, per lens)

One finder agent per lens per finder-slot. Each finder gets: the diff, the lens definition, the repo instruction files, the target (`$SHA` and `$BASE`, or "the working tree" when there is no target), and **nothing about the other lenses** — independence is the point; a finder that knows what others are looking for converges with them.

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

> Try to refute this finding. Read the surrounding code at `$SHA` and the repo's instructions. Default to `refuted: true` if you cannot demonstrate the problem is real. A finding you cannot reproduce or evidence is refuted.

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

Where the findings go is decided by the target, not by asking:

- **PR target** (`<PR#>` or a PR URL) — post to the pull request. **Do not ask first**: naming a PR is the explicit request to publish there, so it satisfies any ask-before-publishing rule (such as `autonomy-contract`'s) rather than bypassing it. Only `--no-post` overrides this.
- **Any other target** — chat report, unless `--post` was given. Then find the branch's PR with `gh pr list --head <branch> --state open --json number,baseRefName`; if there is none, or more than one, say so and fall back to the chat report.

### Posting to the PR

- **Line-level comments on the specific lines**, batched into **one** review via the reviews API — not a stream of individual comments, and not one giant summary comment. A finding about a line belongs on that line, where it can be resolved individually. `gh pr review` cannot anchor comments to lines; use the API:

  ```bash
  gh api repos/{owner}/{repo}/pulls/<N>/reviews --input review.json
  # review.json: {"commit_id": "$SHA", "event": "COMMENT", "body": "...",
  #               "comments": [{"path": "...", "line": 42, "side": "RIGHT", "body": "..."}]}
  ```

  `commit_id` is the `$SHA` from Phase 1, not the PR's current head — the line numbers came from that commit. Write `review.json` to a scratch directory, never into the checkout. Submit as `COMMENT` — the review informs; approving or blocking stays the human's call.
- A finding whose line is **not inside a diff hunk** goes in the review body instead. The API rejects the entire review if a single comment is anchored outside the diff.
- Where a review thread already exists on that line, **reply in the thread** rather than opening a duplicate. Replies cannot ride in the batched review; post each one separately, before the review, so its body can link them:

  ```bash
  gh api repos/{owner}/{repo}/pulls/<N>/comments --paginate                     # existing threads: id, path, line, in_reply_to_id
  gh api repos/{owner}/{repo}/pulls/<N>/comments/<id>/replies -f body='...'    # <id>: the thread's top-level comment
  ```
- The review body carries everything global: the verdict, cross-cutting patterns, the coverage note (lenses run, lenses skipped and why), what the cap dropped, and what was checked and found clean.
- **Zero surviving findings still gets posted** — a body-only review with the verdict and the coverage note. No review on the PR reads as "not reviewed," not as "clean."
- **Never resolve threads yourself.** Fix-and-reply, then leave them open for the human to resolve.

After posting, the chat reply is **only** the verdict in one line, the number of comments posted, and the review URL. Do not restate the findings in chat — the PR is the report, and a second copy drifts from the one people actually resolve.

If posting fails (`gh` unauthenticated, no write access, API error), say so with the error and fall back to the full chat report below, so the findings are not lost.

### Chat report

Verdict, ranked findings with evidence, and what was checked but found clean (that last part is what makes a clean review trustworthy).

## Honesty rules

These are the difference between a review that is trusted and one that gets ignored:

- Findings you could not verify are reported as unverified, or not at all — never promoted to certainty by confident phrasing.
- If a lens could not run (missing context, unreadable files, tool failure), say which and why. Silence about a skipped lens implies coverage you did not have.
- Distinguish "I read this and it is fine" from "I did not look at this."
- Do not pad. Zero findings after a real search is a legitimate, valuable result — report it plainly rather than manufacturing nitpicks to look thorough.
