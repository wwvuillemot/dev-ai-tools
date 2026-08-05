---
name: tenancy
summary: Isolation between tenants, users, or any other partition the system promises to keep separate.
applies_when: The project stores or serves data belonging to more than one customer, organization, workspace, or user, and promises they cannot see each other's data.
---

# Tenancy lens

Every multi-tenant system makes one promise above all others: *your data is not visible to anyone else*. This lens exists because that promise is broken by omission far more often than by intent — a missing `WHERE` clause, a cache keyed without the partition, a background job that runs outside the request's scope.

Configure the partition key for the project in `.claude/deep-review.yml` (`tenancy.partition: tenant_id`). Where the project has no such partition, this lens does not apply — skip it and say so rather than inventing findings.

## Look for

- **Unscoped reads and writes.** Any query that resolves a row by primary key or by a user-supplied identifier without also constraining the partition. Check the *actual* query, not the repository method's name.
- **Enforcement that lives only in application code.** Where the datastore supports row-level security or equivalent policies, application-layer scoping is a single forgotten `WHERE` away from a breach. Note whether the change relies solely on the application remembering.
- **Session-scoped enforcement that outlives the session.** Policies set per connection but used on a pooled connection, or set on one statement and assumed for the rest of a transaction.
- **Caches and memoization keyed without the partition.** A cache keyed on `user_id` alone in a system where a user belongs to several tenants will serve the wrong tenant's data after a switch. **Per-instance caches are worse**: with multiple replicas, invalidating on one leaves the others serving another tenant's stale state.
- **Context loss at boundaries.** Background jobs, queue consumers, scheduled tasks, webhooks, and admin tooling frequently execute with no partition context and therefore no scoping. Any code that moves work off the request path deserves scrutiny here.
- **Cross-partition references.** Foreign keys, ID lists, or denormalized copies that can point at another partition's row — a real source of both leakage and undeletable records.
- **Aggregate and admin paths.** Reporting, exports, search indexes, and support tooling that deliberately span partitions, where the widened scope must be authorized and auditable rather than incidental.
- **Deletion and lifecycle.** Whether removing a partition actually removes its data, including from caches, search indexes, blob storage, and analytics.

## Do not flag

- Genuinely global reference data that belongs to no partition.
- Paths where a documented, authorized cross-partition capability is the stated purpose.
- Absence of row-level policies where the project has consciously chosen application-layer enforcement and written that decision down — note the risk once, do not re-litigate it every review.

## Failure scenario requirement

Name the two partitions and the path: "the list endpoint filters by `workspace_id` taken from the request body rather than the session, so a member of workspace A can enumerate workspace B by changing one field."
