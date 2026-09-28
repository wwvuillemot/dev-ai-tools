# daily-loop

A scheduled operational loop for any repository: collect production and CI signals, triage them
against what is already filed, file issues that read as specs, fix what the repo authorises, put
every branch through adversarial review, and **stop at merge-ready**.

```bash
claude plugin marketplace add wwvuillemot/dev-ai-tools
claude plugin install daily-loop@dev-ai-tools
```

## Usage

```
/daily-loop                      # run today's loop for the current repo
```

Per-repo configuration lives in `.claude/daily-loop.yml`. With no config the loop runs
**report-only**: it collects, triages, tells you, and changes nothing. See
[`config-example.yml`](./skills/daily-loop/config-example.yml).

## The loop

| Phase | What happens |
|---|---|
| 0 | Reconcile issues the loop already filed — resume unfinished cycles before starting new work |
| 1 | Collect signals: Sentry, failing CI, security alerts, log aggregates |
| 2 | Triage into a P0/P1/P2 Pareto — dedupe against what's filed, group by root cause, mute noise with a reason |
| 3 | File issues as **specs**: symptom, trigger, root-cause hypothesis, acceptance criteria, blast radius |
| 4 | Fan out `loop-fixer` sub-agents, one per issue, each in its own worktree |
| 5 | Run `deep-review` on every PR, then arbitrate fixer ↔ reviewer to convergence |
| 6 | Merge-ready → **stop**. A human merges |
| 7 | Report, and append the run to a ledger issue so tomorrow's Phase 0 is fast |

## What it will not do

Merge, deploy, force-push, rewrite history, resolve a review thread it did not verify, close an
issue it did not file, or touch your working checkout. Fixers run in isolated worktrees.

It also **escalates and holds** rather than proceeding when a fix would touch deployment, IaC,
cloud or auth configuration, a data-affecting migration, or a governance threshold — and when the
issue spec contradicts the code. The remit is application code.

## Authority

This plugin is a playbook, not a grant. The `may:` list in `.claude/daily-loop.yml` is the
**standing autonomy line** that [`practices/autonomy-contract`](../practices/) asks you to write
down per project — that list is what the loop may do without stopping, and nothing else.

Unattended runs need that settled in advance, together with a permission mode that won't block on
every action. That decision is the difference between a loop that files a useful issue overnight
and one that sat waiting for a prompt nobody saw.

## Reuse over reinvention

Adversarial review is the sibling [`deep-review`](../deep-review/) plugin, not a second reviewer
built into this one: it already does lens-driven finding, refutation-based verification,
prior-art checking and batched inline PR delivery. The loop orchestrates it.

The same goes for discipline: [`practices`](../practices/) supplies `verify-before-asserting`,
`gates-must-fail-first`, `safe-actions` and `autonomy-contract`, and this loop assumes them rather
than restating them.

## Scheduling

No scheduler here — use the harness. `/schedule` for an unattended cloud cron, `/loop` for a
recurring run inside a live session. Every run is self-contained.

## Requirements

`gh` authenticated against the target repositories. Sentry collection needs `sentry-cli` or a
Sentry MCP server plus credentials; without either, that source is skipped and the run says so.
