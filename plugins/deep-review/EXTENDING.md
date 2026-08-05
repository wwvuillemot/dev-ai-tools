# Extending deep-review

`deep-review` ships a generic lens set. Real projects have concerns no generic reviewer knows about — a layering rule, a domain invariant, a compliance regime, a framework's footguns. Add those as **lenses** rather than forking the skill, so the engine keeps updating underneath you.

## Where lenses come from

Resolved in order, later sources overriding earlier ones by `name`:

| Priority | Source | Use it for |
|---|---|---|
| 1 | `plugins/deep-review/skills/deep-review/lenses/*.md` | The built-in generic set. |
| 2 | `deep-review/lenses/*.md` inside any other installed plugin | Org-wide or proprietary lenses distributed privately. |
| 3 | `.claude/deep-review/lenses/*.md` in the repo under review | One project's own rules. |

Overriding by name is deliberate: a project that needs a stricter `security` lens redefines `security` rather than adding `security-v2` and getting both.

## Lens format

```markdown
---
name: my-lens                  # required, unique, kebab-case
summary: One line.             # required — shown when listing lenses
default: false                 # optional — run without being named
applies_when: >-               # optional — plain-language precondition
  The project uses <X>.
outranks: []                   # optional — lens names this one beats when capping
---

# My lens

## Look for
...

## Do not flag
...

## Failure scenario requirement
...
```

All three body sections are required, and **"Do not flag" is the one that determines whether the lens is usable.** A lens with no exclusions produces noise, reviewers learn to skim it, and the whole run loses credibility. Write the exclusions first if it helps.

State a concrete failure-scenario bar. Findings that cannot meet it should not survive the finder.

## Project configuration

`.claude/deep-review.yml` in the repo under review:

```yaml
lenses:
  default: [correctness, design, conventions, tenancy]
  disabled: [governance]

tenancy:
  partition: tenant_id

governance:
  regimes: [soc2, gdpr]

paths:
  exclude: ["**/generated/**", "**/*.pb.go"]
```

Configuration is advisory to the model, not a parser contract — keep it readable.

## Distributing lenses in a private plugin

To ship proprietary lenses without publishing them, put a `deep-review/lenses/` directory in a plugin of your own:

```
my-org-skills/
  .claude-plugin/marketplace.json
  plugins/
    my-org-review-lenses/
      .claude-plugin/plugin.json
      deep-review/
        lenses/
          layering.md
          domain-invariants.md
```

Install both plugins; `deep-review` discovers the contributed lenses at run time. Nothing in the public plugin needs to know your lenses exist, and nothing in your private plugin needs to duplicate the engine.

## Writing a good lens

- **Name the cost, not the taste.** Every lens needs a concrete consequence its findings must demonstrate.
- **Encode what your team re-explains in review.** The best lens is the comment you have written on five different pull requests.
- **Prefer one sharp lens to three vague ones.** Finders run per lens; vague lenses spend budget generating candidates that verifiers then kill.
- **Say when it does not apply.** `applies_when` stops a lens firing on projects it was never meant for.
- **Test it on a diff you already understand.** If it misses the finding you know is there, or invents two you know are not, fix the lens before trusting it.
