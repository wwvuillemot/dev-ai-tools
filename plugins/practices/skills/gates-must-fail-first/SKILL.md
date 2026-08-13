---
name: gates-must-fail-first
description: Never add or change a test, lint rule, CI check, or parity gate without first observing it FAIL. Use when writing tests, adding a CI job, introducing a schema/contract check, or reviewing a PR that adds one. Prevents gates that pass forever because they can never detect anything.
---

# A gate must be observed failing before it counts

A test that has never been red is not a test. It is a line in a report that says "green" and means
nothing.

## The rule

**Before merging any new or changed gate — test, lint rule, CI check, parity check — perturb the
thing it guards, watch it go red, then revert.** Put the failing output in the commit message or the
PR body.

"The suite passes" tells you the gate *runs*. It never tells you the gate *detects*.

This costs about ninety seconds and is the single highest-yield habit in this repo.

## Why this keeps happening

**Retrofit tests are born green.** Written after the behaviour exists, asserted against reality as it
already is, passing on the first run. Nobody ever sees them fail, so nobody learns they can't. In any
codebase where an agent writes tests in bulk, this is the dominant failure mode — the incentive is to
produce something that passes, and a test that merely restates current behaviour does that perfectly.

One audit of a mature project found **seven separate gates that did not gate**:

- a lint target nothing ever invoked
- a two-backend conformance suite that compared no money-computing response at all
- a CI path filter that omitted the file owning withdrawal ordering and taxation, so a required check
  *skipped* — and a skipped required check counts as passing
- a parity test whose only assertion was `!paths.is_empty()`
- a test asserting "production enables all providers" that matched the **comment** saying the provider
  was disabled

Not one had ever been seen red.

## The subtler failure: a gate blind to omissions

**A gate that derives its scope from the artifact under test cannot see what the artifact is
missing.**

- An i18n linter enumerated keys *from the dictionary*, so a screen whose text was never a key was
  invisible — while the gate reported a clean bill of health.
- A staleness check hashed the files a document *lists*, so a file cited but not listed was invisible.

The omission and the blindness are the same omission. TDD does not fix this: it verifies the spec you
wrote, never the completeness of the spec.

**Derive scope from an independent source** — the import graph, the rendered component tree, the
route table, a citation scan — not from the thing being checked. If you add a route to a sitemap and
your check enumerates its own table of routes, it will pass while the new page ships broken. If it
enumerates *the sitemap*, it fails. Same check, opposite outcome, one design decision.

## Coverage will lie to you here

All seven gates above would show as covered lines. A 90% threshold was satisfied by every one.
**Coverage measures execution, never assertion strength.** A test that runs the code and asserts
nothing useful is indistinguishable from a good one by coverage alone.

## In review

When a diff adds a gate, the question is not "does this look right." It is:

> **Has anyone seen this fail? What exactly did they break to make it fail?**

If the PR cannot answer that, the gate is unproven — regardless of how sensible it reads.
