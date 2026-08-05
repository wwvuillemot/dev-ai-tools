---
name: performance
summary: Work that scales badly — query patterns, allocation, blocking I/O, cache behaviour.
---

# Performance lens

Look for work whose cost grows with something the system does not control. Ignore micro-optimisation; a review that argues about string concatenation while an N+1 sits two lines below has failed.

## Look for

- **N+1 access** — a query, RPC, or file read inside a loop over results from a previous query. The classic and still the most common real finding.
- **Unbounded work** — fetches with no limit, `SELECT *` feeding an in-memory filter, loading a whole collection to count or check existence, pagination that requests every page eagerly.
- **Blocking in the wrong place** — synchronous I/O on an async path or event loop, network calls holding a lock or an open transaction, sequential awaits that could be concurrent.
- **Algorithmic shape** — nested iteration over inputs that scale together, repeated linear scans where a map is built once, sorting inside a loop.
- **Allocation in hot paths** — per-iteration object or buffer creation, repeated serialization of the same value, regex compiled per call.
- **Cache behaviour** — a cache keyed so it can never hit, cached values never invalidated on write, or **per-instance caches in a multi-replica deployment**, where one instance's invalidation leaves the others serving stale data. That last one is invisible in single-instance local testing and is a frequent production surprise.
- **Chattiness** — a payload that triggers a request per row on the client, or an endpoint the UI must call in a loop to render one view.

## Do not flag

- Constant-factor tweaks with no measurement behind them.
- Cost in code that runs once at startup or in tooling.
- Anything where you cannot state what scales. "This could be slow" is not a finding.

## Failure scenario requirement

Name the scaling variable and the consequence: "renders one query per row, so a 500-row batch issues 501 queries," or "the cache is per-process across N replicas, so invalidation on one leaves the others stale until TTL."
