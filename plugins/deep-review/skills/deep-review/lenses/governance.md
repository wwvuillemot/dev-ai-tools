---
name: governance
summary: Auditability, data handling, retention, residency, and regulated-change discipline.
applies_when: The project is subject to a compliance regime, handles personal data, or must answer "who changed this and when" to someone outside the team.
---

# Governance lens

Compliance failures rarely look like bugs. They look like working code that cannot answer a question an auditor will ask. This lens checks whether the change leaves the system able to answer.

Configure the applicable regimes in `.claude/deep-review.yml` (`governance.regimes: [soc2, gdpr, hipaa, pci]`) so findings cite what the project is actually held to rather than a generic checklist.

## Look for

- **Audit trail gaps.** State changes to regulated or customer-visible data that record no actor, timestamp, or before/after value. Especially: administrative overrides, support tooling, bulk operations, and anything that bypasses the normal path.
- **Personal data handling.** New fields that hold personal data without classification; personal data reaching logs, traces, analytics events, error reports, or LLM prompts; identifiers used as cache keys or URL parameters where they will be retained by intermediaries.
- **Retention and deletion.** New data stores with no stated retention; deletion that removes the row but leaves copies in caches, search indexes, backups, exports, or downstream analytics. Whether a deletion request can actually be satisfied end to end.
- **Residency.** Data crossing a region boundary the project has committed to — including indirectly, via a third-party API, model provider, error tracker, or CDN in another jurisdiction.
- **Third-party egress.** Any new outbound destination for customer data. A new vendor is a governance event, not merely a dependency.
- **Access control changes.** Widened permissions, new bypass paths, service accounts with broader scope than the job needs, or break-glass access without a record.
- **Change discipline.** For regulated changes: whether the trail links the change to its approval, and whether configuration that affects controls is versioned rather than applied by hand.
- **Claim honesty.** Documentation, marketing copy, or API descriptions asserting a control the code does not implement. An overstated control is a worse finding than a missing one.

## Do not flag

- Regimes the project is not subject to. Cite the configured list.
- Absence of a control the project has explicitly deferred in writing — note it once against the tracking item, do not re-raise it every review.
- Process concerns with no code consequence in this diff.

## Failure scenario requirement

Name the question that becomes unanswerable, or the commitment that is broken: "the override path writes the new value with no actor recorded, so a SOC 2 access-review question about who changed this entitlement cannot be answered from the system."
