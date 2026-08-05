---
name: correctness
summary: Bugs that produce wrong output, crashes, data loss, or hangs.
default: true
outranks: [design, performance, conventions, governance]
---

# Correctness lens

Hunt for code that does the wrong thing. This lens outranks every other when the output cap forces a cut.

## Look for

- **Boundaries** — off-by-one, empty collection, single element, maximum size, zero, negative, overflow.
- **Null and absent paths** — a value that can be absent on a path that assumes presence. Trace the actual callers rather than the type signature.
- **Error handling** — swallowed exceptions, `catch` that logs and continues into code requiring success, failure paths that leave state half-written.
- **Concurrency** — shared mutable state, check-then-act races, missing idempotency on retried operations, unawaited async work, ordering assumptions across parallel calls.
- **Resource lifecycle** — unclosed handles, connections returned to a pool in a bad state, cleanup skipped on the error path.
- **Contract drift** — a caller updated without its callee, a serialized shape changed without its reader, a migration that assumes a column the code no longer writes.
- **State machines** — transitions that can be entered twice, or that cannot be exited on failure.

## Do not flag

- Anything a typechecker or compiler catches.
- Theoretical inputs the system cannot produce — trace whether it can actually arrive.
- Pre-existing bugs on untouched lines.
- Missing tests. That is a `test-coverage` finding, not a correctness one.

## Failure scenario requirement

Concrete inputs or interleaving → the wrong result. "Could be null" is not a failure scenario. "`resolve()` returns `None` when the register lacks the tail, and line 88 dereferences it, so an unknown tail 500s instead of returning the documented not-found error" is.
