---
name: conventions
summary: Adherence to the repo's own written rules and its established patterns.
default: true
---

# Conventions lens

Two distinct jobs, and both matter:

1. **Written rules** — does the change comply with what the repo says about itself?
2. **Established patterns** — does it look like the code around it?

The second is where real drift comes from. A codebase does not decay because someone violated `CLAUDE.md`; it decays because each change was locally reasonable and collectively inconsistent.

## Written rules

Read the root `CLAUDE.md` / `AGENTS.md` and any in the touched directories. Also read `CONTRIBUTING.md`, lint and formatter configuration, and `.editorconfig`.

Flag a violation only when the rule **actually says so** — quote it. A rule you inferred from surrounding style is a pattern finding, not a rule violation, and labelling it as the latter destroys trust in the review. Remember that agent instruction files are guidance for writing code: not every line is a review criterion.

## Established patterns

Read the neighbouring implementation of the same *kind* of thing before judging. If the change adds an endpoint, read two existing endpoints. If it adds a migration, read the last three.

- **Structural placement** — does the file live where its peers live? Does it respect the project's layering or module-boundary rules, including import direction?
- **Error handling** — does it raise, return, or log the way the rest of the codebase does?
- **Naming and vocabulary** — does it use the project's domain terms, or invent synonyms for concepts that already have names? Synonym drift is how one concept ends up with three names.
- **Configuration** — new settings surfaced the way existing ones are, or bolted on ad hoc?
- **Testing shape** — do tests follow the established structure and fixtures, or introduce a parallel approach?
- **Documentation and changelog** — where the project requires an entry, whether one exists, in the required form.
- **Single source of truth** — status tables, enums, and catalogs duplicated into a second place that can drift out of sync.

## Do not flag

- Personal preference. If neither the written rules nor the surrounding code supports it, it is not a finding.
- Deliberate, commented departures from a pattern.
- Formatting a formatter owns.
- Inconsistency with a pattern the project is actively migrating away from — check direction of travel before insisting on the old shape.

## Failure scenario requirement

Quote the rule, or cite the neighbouring file that establishes the pattern, with a path. A conventions finding without a citation is an opinion.
