# practices

Claude Code plugin. Also installable into any repo for Cursor / Codex via `make install-skills`.

## Install (Claude Code)

```sh
claude plugin marketplace add wwvuillemot/dev-ai-tools
claude plugin install practices@dev-ai-tools
```

Updates arrive with `claude plugin update` — no clone, independent of `make setup`.


The rest of this repo bundles **tools**. This bundles **practices** — the working habits that decide
whether an agent's output is trustworthy.

Every skill here was written after the failure it prevents actually happened, on real projects, and
cost real time. None of them are style preferences.

## Portability

Each skill is authored once in Claude Code's `SKILL.md` format (YAML frontmatter + markdown) and
generated into the other tools' formats by `make install-skills`:

| tool | destination | form |
|---|---|---|
| Claude Code | `.claude/skills/<name>/SKILL.md` | copied verbatim |
| Cursor | `.cursor/rules/<name>.mdc` | frontmatter rewritten to Cursor's keys |
| Codex / generic | `AGENTS.md` | appended as a section, between markers |

The markdown body is deliberately tool-agnostic: no Claude-specific tool names, no assumptions about
a particular harness. A human reading these should get the same value an agent does.

## Installing into a project (Cursor / Codex / any tool)

Claude Code is served by the plugin above, so this **skips** `.claude/skills/` by default —
installing both would load every skill twice from two independently drifting sources. Pass
`WITH_CLAUDE=1` only if you are not using the plugin.

```sh
make install-skills DIR=~/Projects/my-repo          # all skills
make install-skills DIR=~/Projects/my-repo ONLY=safe-actions,autonomy-contract
```

Idempotent: re-running updates in place. The `AGENTS.md` section is bounded by markers, so your own
content is never touched.

## The skills

| skill | prevents |
|---|---|
| `verify-before-asserting` | confidently reporting things that were never checked |
| `gates-must-fail-first` | tests and CI checks that pass without ever being able to fail |
| `autonomy-contract` | stopping to ask when the answer was obvious, and not stopping when it wasn't |
| `safe-actions` | killing the user's processes, deleting their files, handing them commands that don't run |
| `visual-iteration` | burning five rounds on a CSS change the user described in one sentence |

## Adding one

A skill earns its place when **you have had to say the same thing twice**. That is the whole test.
Write what went wrong, not what good looks like — the failure is the part that transfers.
