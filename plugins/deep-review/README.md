# deep-review

Adversarial, lens-driven code review for Claude Code.

Ordinary AI review has two failure modes: it reports things that aren't real, and it only ever looks at the diff. `deep-review` addresses both — candidates must survive agents actively trying to refute them, and a dedicated finder asks whether the change duplicates something the codebase already has.

## Install

```bash
claude plugin marketplace add wwvuillemot/dev-ai-tools
```

Then `/plugin install deep-review`.

## Use

```
/deep-review                                   # working diff, default lenses
/deep-review --lens design,performance         # target specific concerns
/deep-review 1909 --lens security,tenancy      # a pull request
/deep-review --depth deep --post               # full fan-out, post inline comments
```

| Flag | Values | Default |
|---|---|---|
| `--lens` | any registered lens name, or `all` | `correctness,design,conventions` |
| `--depth` | `quick`, `standard`, `deep` | `standard` |
| `--post` | deliver as batched inline PR comments | off (chat report) |

## Built-in lenses

| Lens | Covers |
|---|---|
| `correctness` | Boundaries, null paths, error handling, concurrency, resource lifecycle, contract drift |
| `design` | SOLID, DRY, SRP, coupling, abstraction quality, code smells |
| `performance` | N+1 patterns, unbounded work, blocking I/O, allocation, cache behaviour |
| `security` | Authorization, injection, secrets, trust boundaries, fail-open gates |
| `tenancy` | Isolation between tenants/workspaces/users — unscoped queries, partition-blind caches, context loss in background work |
| `governance` | Audit trails, personal-data handling, retention, residency, third-party egress |
| `conventions` | The repo's written rules, plus its established patterns |

`tenancy` and `governance` carry an `applies_when` precondition and are skipped — explicitly, not silently — on projects they don't fit.

## How it works

1. **Scope** — read the real diff and the repo's instruction files.
2. **Find** — one agent per lens, each blind to the others. Plus `prior-art-finder`, which always runs.
3. **Pool** — dedupe by location; a finding raised by two lenses independently is stronger.
4. **Refute** — verifiers prompted to kill each candidate, defaulting to refuted when uncertain. At `standard` and above they're given *different* perspectives, because three identical skeptics are one skeptic with variance.
5. **Rank** — correctness outranks everything else when the cap forces a cut, and anything dropped is named rather than silently truncated.
6. **Deliver** — line-level comments batched into one review; existing threads get replies rather than duplicates; threads are never self-resolved.

## Extending

Projects have concerns a generic reviewer can't know. Add lenses instead of forking — see [EXTENDING.md](./EXTENDING.md). Lenses resolve from the built-in set, from any other installed plugin's `deep-review/lenses/`, and from `.claude/deep-review/lenses/` in the repo under review, with later sources overriding by name.

That third path is how an org distributes proprietary lenses privately while still tracking this plugin's updates.

## Requirements

Claude Code with subagent support. The `--post` path needs `gh` authenticated against the target repository.

## Relationship to the built-in reviewers

Claude Code ships `/review` (single-pass, a GitHub PR) and `/code-review` (multi-agent, your working diff). Both are good and neither is configurable. Reach for `deep-review` when you need to aim the review at a specific concern, when the codebase's own patterns should be part of the judgment, or when findings must land as inline PR comments.
