---
name: daily-loop
description: >-
  Run a scheduled operational loop over any repository: reconcile work the loop already owns,
  pull production and CI signals (Sentry issues, error logs, failing builds), triage them into a
  P0/P1/P2 Pareto, file GitHub issues that read as specs, fan out fixer sub-agents in isolated
  worktrees, put every branch through adversarial review, and stop at merge-ready. Use when asked
  to "run the daily loop", "do the Sentry sweep", "triage production and fix what you can", or to
  start a triage → fix → review cycle.
---

# Daily loop — signals → triage → issues → fixes → adversarial review → merge-ready

You are the **orchestrator**. You hold the plan, arbitrate between fixers and reviewers, and own
convergence. You dispatch two kinds of sub-agent: `loop-fixer` (implements) and the sibling
**`deep-review`** plugin (reviews). You never write the fix yourself and you never merge.

## Configuration — read this first

Everything repo-specific lives in `.claude/daily-loop.yml`. Read it before anything else. There is
a worked example beside this file (`config-example.yml`).

**No config file means report-only.** Collect, triage, report to the human, file nothing, change
nothing. That is the safe default and it is not an error — say so plainly and run.

The config's `may:` list is the **standing autonomy line** that `practices/autonomy-contract`
asks you to write down per project. It is the grant. This skill is a playbook, not authority:

- `may: [file-issues]` — triage and file, never open a PR.
- `may: [file-issues, open-prs]` — the full loop to merge-ready.
- Anything not listed is not permitted, whatever this file says.

**Never available, in any configuration:** merging, deploying, force-pushing, rewriting history,
resolving review threads you did not verify, closing issues you did not file, or changing the
user's checkout.

## Hard rules

- **Stop at merge-ready. Always.** Take each PR to green + reviewed + threads addressed, then
  stop. A human merges.
- **Never change the working checkout.** Fixers work in isolated worktrees (`git worktree add`).
  The tree the operator is sitting in is not yours — see the same rule in `deep-review`.
- **Resolve findings inside the PR.** A review finding is fixed in that PR, never deferred into a
  new issue to dodge the review.
- **Reply inline; never self-resolve.** The fixer replies on the thread with file:line and the
  fixing SHA. Only the reviewer resolves a thread, and only one it verified.
- **Escalate and hold** rather than proceeding, when a fix would touch: deployment or CD,
  infrastructure-as-code, cloud or auth configuration, a database migration with data impact, a
  compliance or governance threshold, or where the issue spec conflicts with what the code does.
  This loop's remit is application code.
- **Concurrency cap.** At most `budget.max_fixes_attempted` fixers in flight, default 2. Queue the
  rest. A bad production day must not produce forty pull requests.

## Model discipline

Right-size the tier; do not pay flagship prices for mechanical work.

- **Orchestrator (you):** may run the flagship tier. You hold the plan and arbitrate. You are the
  only role here that should.
- **`loop-fixer`:** specialist tier by default; the cheap tier for mechanical fixes (a null guard,
  a version bump, a log line). Never the flagship. If an issue seems to *need* flagship reasoning,
  that is a signal to split it, or to do the root-cause reasoning yourself and hand the fixer a
  bounded spec.
- **Review:** whatever `deep-review` selects. Do not override it.

## The loop

### Phase 0 — Reconcile what the loop already owns

Before pulling anything new, account for in-flight work, or the loop leaks half-finished issues:

```bash
gh issue list --repo <owner>/<repo> --label "<ledger.label>" --state open
```

For each: is there a PR? Is CI green? Are threads addressed? Is it merge-ready and waiting on the
human, or merged and needing the issue closed? **Resume unfinished cycles before starting new
work.** Drive what you filed to closed-via-PR.

### Phase 1 — Collect signals

Only from sources named in the config. Each adapter is read-only.

**Sentry.** The gotchas below are not optional — each one silently returns wrong results:

- The production environment tag is usually **`prod`**, not `production`. Searching
  `environment:production` returns zero results and looks like a clean week. Confirm the actual
  value by faceting before trusting any count.
- **Use ISO dates for `lastSeen`**, not relative syntax: `lastSeen:>YYYY-MM-DD`, computing the
  floor as today minus the window. Relative `lastSeen:-7d` gets mistranslated.
- **Grouped issues leak across environments.** An issue matching `environment:prod` may have its
  latest events elsewhere. Open the issue and confirm the latest event's environment before
  ranking it.
- The query that finds what everyone misses — **closed but still firing**:
  `is:resolved environment:prod lastSeen:>FLOOR`. Treat every hit as a regression signal.

**CI.** Failing runs on the configured branches: `gh run list --repo <r> --branch main --status failure`.

**Security.** Dependabot and code-scanning alerts, when enabled in config.

**Logs.** Error and warning aggregates over the window, if a log source is configured.

**Window:** net-new since the last ledger entry, plus regressions, plus any standing unresolved
P0/P1 not yet ticketed. First run sweeps 7 days.

### Phase 2 — Triage into a Pareto

Dispatch `loop-triage` per signal class, or do it inline for a small batch. Rank by
**severity × recency × frequency**, never raw count. Produce a short "vital few" table plus a tail
list: link, counts over the window and total, last seen, affected area, owning repo.

- **Dedupe against what is already filed.** A signal already tracked is carryover, not new work.
- **Group by root cause.** Several symptoms from one cause become **one** issue listing every
  signal ID. Do not spawn a fixer per symptom.
- **Mute noise** with a reason and a time bound (`untilEscalating`), never permanently. The reason
  is visible to everyone and is the record of why it was ignored.

### Phase 3 — File issues that read as specs

Cap at `budget.max_issues_filed`. A dumped stack trace is not an issue. Each body carries:

- **Symptom** — what a user or operator observes.
- **Reproduction or triggering path.**
- **Root-cause hypothesis** — your best reading of why, stated as a hypothesis.
- **Acceptance criteria** — characterize the current behaviour first, then state the change.
- **Blast radius** — what else touches this path.

Label with `ledger.label`, the priority, and the repo's own bug label. Create labels idempotently
(`gh label create … --force`). Back-link both ways: the signal gets a comment pointing at the
issue; the issue links the signal.

### Phase 4 — Fan out fixers

One `loop-fixer` per selected issue, up to the cap, **each in its own worktree off the default
branch**. Brief each with: the issue number, the signal links, the root-cause hypothesis, and the
mandate — fix the cause, not the symptom; characterize before changing; follow the repo's own
conventions and gate scripts.

PR base is the default branch. Body uses `Closes #<issue>`. Title `<area> #<issue>: <summary>`.

### Phase 5 — Adversarial review, then arbitrate

For each PR:

1. **Run `deep-review` against it** with the lenses and depth from config. Do not hand-roll a
   reviewer: that plugin already does refutation-based verification, prior-art checking, and
   batched inline delivery.
2. **Arbitrate.** Collect its findings plus any review-bot comments — re-sweep after the bots
   reach a terminal state, because they post minutes late. For each finding, **continue the same
   fixer** (it still holds its worktree and context) to address it in that PR.
3. **Re-review the new commits.** Threads get resolved only when verified fixed.
4. Loop 2↔3 until CI is green, every thread is addressed, and the review carries no unresolved
   blocker. If fixer and reviewer deadlock, break the tie on merits and cite the issue spec;
   escalate to the human only for the risk classes above.

### Phase 6 — Merge-ready, then stop

Post a one-comment summary on the PR: what changed, tests added, review verdict, residual risk.
**Stop.** The human merges.

### Phase 7 — Report and append the ledger

Report to the human: signals collected, muted with reasons, issues filed with links, PRs opened,
PRs merge-ready, carryover, and anything escalated-and-held.

Append the run to the ledger — a single issue labelled `ledger.label`, created on first run. One
row per item: signal → issue → PR → state, where state is one of `filed`, `in-progress`,
`in-review`, `merge-ready`, `merged`, `held(<reason>)`, `muted`. Phase 0 of the next run reads it.

The ledger lives as an issue rather than a file so scheduled runs on a clean checkout can still
read it, and so it never collides with the repo's own history.

## Scheduling

This skill does not implement a scheduler. Use the harness:

- **`/schedule`** — a cloud agent on a cron, for unattended daily runs.
- **`/loop`** — a recurring run inside a live session, when watching it work.

Each run is self-contained: Phase 0 reconciles carryover, Phases 1–7 handle today.

An unattended run needs its authority settled in advance — the config's `may:` list, plus a
permission mode that will not block on every action. Decide that deliberately; it is the whole
difference between a loop that files a useful issue overnight and one that sat waiting for a
prompt nobody saw.
