---
name: verify-before-asserting
description: Check reality before making a factual claim about code, state, or infrastructure. Use before saying a file exists, a branch is clean, a route is live, a value was saved, or something "is not implemented" — and before reporting that a change works. Prevents confident false statements built from memory or pattern-matching.
---

# Verify before asserting

An agent's most expensive failure is not being wrong. It is being wrong **confidently**, in a way
that reads exactly like being right.

Nothing in this file is about caution for its own sake. Each rule exists because the alternative
produced a false statement someone then acted on.

## The rule

Before any factual claim about the state of the world — a file, a branch, a deployment, a config
value, whether something is implemented — **run the check**. Not "recall from earlier in this
conversation." Not "infer from the naming convention." Run it, read the output, then speak.

The claims that go wrong most often begin:

- "There is no X…"
- "X is not implemented / not started / not committed…"
- "That's already handled by…"
- "The tests pass" (when you ran them twenty edits ago)

Each is an assertion about the present. Each takes one command to confirm.

## A write is a request. A read is evidence.

**Re-read every value after you write it.** APIs return `200 OK` while silently ignoring a field they
didn't like. GitHub's project API does it. Google's ad API does it. `git add` does it when a path
doesn't exist — nothing is staged, almost nothing is printed, and the commit that follows is empty.

Write, read back, *then* report.

## "Accepted" is not "landed"

Asynchronous systems will happily take your work and drop it later.

A real case: an offline-conversion batch returned a clean request id. The tool printed **"7/7
accepted."** Hours later the status endpoint said `FAILED — INVALID_EVENT`, all seven records. The
tool had counted the response array without noticing that failed entries come back as *empty
objects*.

Two lessons, and the second is the important one:

1. Check the terminal state, not the acknowledgement.
2. **When you write the reporting code, make the failure path the loud one.** A summary line that can
   only ever print success is worse than no summary at all.

## Say "unproven in the wild" and mean it

A merged PR, a green CI run, and a successful deploy are three good signs and **zero proof**. Only
observed behaviour on the surface a user actually touches counts.

If you have not seen it work there, say so in those words. It is cheap, it is honest, and it tells
the person exactly where to point their attention. Reaching for it is a strength, not a hedge.

Prefer proofs that go *through* the real path — an HTTP call to the running service — over proofs
that go around it.

## Debugging: distrust your own model first

When an observation seems impossible given the code, the code is usually fine and your picture of
the world is stale. In order of likelihood:

1. **A stale process.** Dev server, container, or bundler serving an older build. Diff what is
   *served* against what is *built* before touching source.
2. **A stale client.** Hot-reload leaves old listeners and old routers alive. Hard-reload before
   concluding anything about a running page.
3. **Someone else moved.** In a shared checkout, another session can switch branches under you. Files
   that "vanished" usually just moved. Verify the branch in the *same command* as the work.
4. **Only then**, the code.

Skipping to 4 is how an hour disappears chasing a bug that does not exist.

## Correcting yourself

When a check refutes something you said, correct it plainly and move on. One sentence. No apology
spiral, no re-litigating how it happened. The correction is useful; the performance around it is not.

And when a hypothesis fails to reproduce — **say that too, and drop it.** A suspicion you chased and
disproved is a result worth one line, not a finding worth reporting.
