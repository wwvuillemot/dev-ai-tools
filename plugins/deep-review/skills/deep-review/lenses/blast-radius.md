---
name: blast-radius
summary: Consumers that depend on a property this change altered — identity, volatility, nullability, ordering, lifetime, or failure mode.
default: true
---

# Blast-radius lens

Every other lens reads the diff. This one reads the code the diff *affects without touching*.

The question: **for each value, invariant, or timing property this change alters, who else depends on the thing that changed?**

Those consumers are usually not in the diff, and their lines are usually unchanged. That is exactly why nothing else finds them — a diff-only pass cannot see a bug whose site has zero changed characters.

## The distinction this lens exists for

"Untouched line" and "pre-existing bug" are not the same thing. A bug is **new** when the change is what made a previously-correct line wrong. That is in scope here, and it is the single most common thing this lens catches.

Ask, for any consumer you find: *was this line correct before the diff, and is it wrong after?* If yes, the diff caused it, however far from the diff it lives.

## Method

1. **List what the change alters about a value — not what it alters textually.** For each value the diff touches, name the property that moved:
   - **Identity / stability** — was constant or referentially stable, now recomputed, polled, or time-varying
   - **Volatility** — changed rarely on deliberate action, now changes on a timer, a subscription, or every render
   - **Nullability / presence** — required becomes optional, or absent becomes always-present
   - **Ordering / cardinality** — unordered becomes ordered, single becomes many, bounded becomes unbounded
   - **Lifetime / scope** — per-session becomes per-request, global becomes per-tenant, cached becomes fresh
   - **Failure mode** — threw, now returns a sentinel; was silent, now raises; was total, now partial

2. **Find every reader of that value.** Grep the symbol, the prop name, the query key, the config key — repo-wide, not just the touched files. Enumerate them; do not stop at the one the PR is about.

3. **For each reader, name the property it relies on.** A consumer is only at risk if it depends on the *specific* property that moved. Most will not. Say so.

## Where this bites hardest

Reactive and cache-keyed code, because dependence is implicit:

- A value in a `useEffect` / `useMemo` / `useCallback` dependency array, a `key=` prop, a query key, a cache key, or a URL used as a cache key. If it was stable and is now volatile, everything keyed on it now re-runs on a cadence it was never designed for — refetching, remounting, resetting local state, cancelling in-flight work.
- **Local unsaved state is the expensive version.** An effect that re-initialises state from a server value is safe while its trigger is stable and destroys user work once it isn't.
- Config or feature values read at module load vs. per request.
- Serialized shapes with readers in another repo, another service, or a generated client.

Also: **claims are consumers.** A docstring, comment, tool description, CHANGELOG entry, or README that asserts something the change makes false is a consumer whose line did not change. Same test — true before, false after.

## Do not flag

- Consumers that do not depend on the property that moved. Enumerating readers is the method, not the finding.
- Genuinely pre-existing bugs — wrong before the diff and equally wrong after.
- Anything a typechecker catches. A changed *type* surfaces at compile time; this lens is for changed *behaviour* under an unchanged type.
- Speculative future consumers. Name a reader that exists today.

## Failure scenario requirement

Name three things: **the property that changed**, **the consumer that depends on it**, and **what that consumer does when it changes**.

> "`composeUrl` was stable while the editor dialog was open (id + a nonce bumped only on deliberate save); this diff keys it on a 5s-polled `updated_at`. `CanvasWysiwygEditor`'s load effect has `composeUrl` in its dependency array and unconditionally calls `setBlocks(...)` with no dirty check, so an agent write mid-edit discards the user's unsaved blocks. Neither that file nor that prop line is in the diff."

Not: "other components use `composeUrl` and might be affected."
