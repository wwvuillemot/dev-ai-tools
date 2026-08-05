---
name: security
summary: Authorization, injection, secret handling, and unsafe input trust.
---

# Security lens

Assume the caller is hostile and the input is attacker-controlled until the code proves otherwise. Report exploitability, not vocabulary.

## Look for

- **Authorization, not just authentication.** Knowing *who* the caller is does not establish that they may touch *this* record. Look for handlers that resolve an object by ID from the request and act on it without checking ownership — the most common real vulnerability in application code.
- **Injection** — string-built SQL, shell invocation with interpolated input, template rendering of untrusted values, path traversal in file operations, deserialization of untrusted payloads.
- **Secrets** — credentials or tokens in source, logs, error messages, URLs, or query strings; secrets echoed into client-visible responses; keys committed to fixtures.
- **Trust boundaries** — client-supplied values used for authorization decisions, validation performed only in the UI, signed values not verified, redirect targets taken from input.
- **Fail-open** — a permission check that returns "allowed" when the backing service errors or the config is missing. Security gates must fail closed; a feature flag or entitlement lookup that defaults to permissive on error is a finding.
- **Enumeration and leakage** — errors that distinguish "not found" from "not permitted," timing differences on credential checks, verbose stack traces reaching clients.
- **Dependency and supply-chain surface** — new dependencies pulled in by the change, especially ones executing at install or build time.

## Do not flag

- Findings a scanner reports without an exploit path in this code.
- Theoretical risk in code unreachable from any untrusted input.
- Generic "add input validation" without naming the input and the consequence.
- Missing hardening the project has explicitly decided against in writing.

## Failure scenario requirement

State who the attacker is, what they control, and what they get: "a tenant member can pass any `document_id`; the handler loads it by primary key without scoping to the caller's tenant, so cross-tenant reads succeed."
