# Using dev-ai-tools in a session

A practical guide for verifying and leveraging Serena, Graphify, Backlog.md, and RTK once `make setup` has run.

> TL;DR:
> - **Serena** — use *instead of* reading whole files when you want a symbol, its callers, or a refactor. Semantic, surgical, cheap.
> - **Graphify** — run once per codebase to build a knowledge graph. Ask conceptual questions: "what talks to the billing service?", "explain the data flow."
> - **Backlog.md** — break work into small markdown tasks with acceptance criteria; review the *spec* and *plan* before any code exists. `backlog board`, `backlog browser`.
> - **RTK** — wrap noisy dev commands to cut 60–90% of output tokens. `rtk npm test`, `rtk cargo build`.

> **Wire new projects without returning to this repo.** `make setup` installs a `dev-ai-tools` command on `PATH`. From any repo, run `dev-ai-tools install-graphify` or `dev-ai-tools install-serena`. See [the `dev-ai-tools` wrapper](#the-dev-ai-tools-wrapper) below.

---

## One-shot verification

```bash
# Global check — from the dev-ai-tools repo
make check

# Per-project + global check — from any project
dev-ai-tools check
```

Expected output: a `[✓]` for each of uv, `~/.serena/serena_config.yml`, Claude Code MCP, Cursor, VS Code, Claude Desktop (if installed), Graphify, Backlog.md, RTK. Any `[✗]` tells you exactly which `make install-*` target to run. `dev-ai-tools check` additionally reports whether the current project has `.serena/project.yml`, graphify rules in `CLAUDE.md` / `AGENTS.md`, and a built graph.

---

## Serena — semantic code intelligence

### Verify in a session

- **Claude Code**: run `/mcp` inside a session. You should see `serena ✓ connected`.
- **Cursor**: Cursor Settings → MCP → `serena` should show connected.
- **VS Code**: open the MCP panel; `serena` should be running.
- **Any client**: ask the agent to run `get_symbols_overview` on a file in your project. If it returns a symbol tree, Serena is live.

### When to reach for it

| Use case | Why Serena beats reading files |
|---|---|
| "Find every caller of `createUser`" | `find_referencing_symbols` scans the indexed tree — no grep false positives, no import-graph confusion |
| "Rename `foo` to `bar` everywhere" | `rename_symbol` does it semantically across the project |
| "What does `PaymentService.charge` actually do?" | `find_symbol` with `include_body=True` returns just the method, not a 1000-line file |
| "What's the public API of this module?" | `get_symbols_overview` returns the symbol tree without bodies |
| Picking up a new codebase | On first Serena use in a project, it runs onboarding and writes memories to `.serena/memories/` — persistent context that survives session restarts |

### Session tips

- **Prefer `find_symbol` over `Read`** when you know what you're looking for. Cheaper on context, more precise.
- **Commit `.serena/project.yml` and `.serena/memories/`** so teammates share the context. Gitignore `.serena/cache/` and `.serena/*.log`.
- **Re-run `make setup-project PATH=~/Projects/foo`** to scaffold `.serena/project.yml` for a new repo.

---

## Graphify — knowledge-graph skill

Graphify is a **shell CLI plus per-client rules + hooks** — it is *not* a Claude Code or Codex slash command. There is no `/graphify` to type. Agents use it by running the CLI via Bash, steered by rules the installer writes into `CLAUDE.md`, `AGENTS.md`, `.cursor/rules/`, etc.

### Verify in a session

- **CLI on PATH**: `graphify --version`.
- **Claude Code**: `CLAUDE.md` contains a `## graphify` section and `.claude/settings.json` has a `PreToolUse` hook that nudges the agent toward the graph.
- **Codex**: `AGENTS.md` contains the same `## graphify` section and `.codex/hooks.json` has the equivalent hook.
- **Cursor / VS Code / others**: each has its own rules file (e.g., `.cursor/rules/graphify.mdc`). `make install-graphify` writes per-client files when detected.

If any of these are missing, re-run `make install-graphify` and accept the per-client prompt.

### First-run in a project

Build the initial graph from the repo root (see [graphify docs](https://graphify.net) for the exact command — the initial extraction runs LLM subagents over docs, images, and transcripts, so it needs API credentials). Output lands in `graphify-out/` as interactive HTML + `graph.json` + `GRAPH_REPORT.md`.

It's heavy the first time — expect multi-minute runs on larger codebases. Re-run incrementally with `graphify update .` after code changes (AST-only, no API cost).

### Invoking it in a session

Either ask the agent a codebase question in plain English and let the rules in `CLAUDE.md` / `AGENTS.md` direct it to graphify, or run the CLI yourself and let the agent read the result:

```bash
graphify query "what talks to the billing service?"
graphify path "AuthMiddleware" "UserRepository"
graphify explain "PricingEngine"
graphify update .
```

### When to reach for it

- **Onboarding to an unfamiliar codebase** — "explain the overall architecture," "what are the main subsystems?"
- **Tracing conceptual dependencies** across code AND docs AND design assets — Graphify unifies them in one graph
- **Finding non-obvious relationships** — "where is auth decided?", "what touches the pricing logic?"
- **Multi-modal repos** (code + PDFs + diagrams + recorded demos) — Graphify is the only tool in this bundle that ingests non-code

### Session tips

- Graphify is a **CLI + ruleset**, not an MCP server or slash command. The agent runs `graphify …` via Bash when your prompt matches the rules; it won't run implicitly without a reason.
- Don't rebuild every session. The graph persists in `graphify-out/`; `graphify update .` keeps it fresh after code changes, and a full rebuild is only needed when the codebase shifts substantially.

---

## Backlog.md — git-native tasks, spec & plan review

The point isn't project management — it's **review leverage**. Agents produce code faster than you can read it, so Backlog.md moves your attention upstream: you review a one-paragraph task spec and an implementation plan *before* any code exists, catching misunderstandings while they're cheap to fix.

### Verify in a session

- **CLI on PATH**: `backlog --version`.
- **Claude Code**: run `/mcp` — you should see `backlog ✓ connected` alongside `serena`.
- **Any MCP client**: ask the agent to read `backlog://workflow/overview`, or from the CLI run `backlog instructions overview`.

### First-run in a project

```bash
cd ~/Projects/my-repo
backlog init "My Repo"    # creates backlog/ store + appends agent instructions to AGENTS.md / CLAUDE.md
```

Backlog.md is **project-scoped** — like Serena, the global install is the binary + MCP wiring, but each repo needs its own `backlog init` to create the task store. The MCP server resolves the project from the working directory.

### The three review checkpoints

| Step | What the agent does | Your checkpoint |
|---|---|---|
| **1. Decompose** | Splits work into small tasks with descriptions + acceptance criteria | Read the task specs — is the scope right? |
| **2. Plan** | Researches the codebase, writes an implementation plan *into the task* | Approve or revise the plan before code |
| **3. Implement** | One task per session, one PR per task | Review code against the acceptance criteria |

### When to reach for it

- **Non-trivial features** where a wrong assumption costs hours — review the spec first.
- **Running multiple agents / sessions** — tasks are the shared, git-versioned source of truth; one task per session keeps context windows small.
- **Handoffs** — the task file (spec + plan + acceptance criteria) *is* the context a fresh session needs.

### Session tips

- **`backlog board`** for a terminal Kanban; **`backlog browser`** for a local drag-and-drop web UI.
- Tasks are plain `.md` files under `backlog/` — commit them so the spec/plan lives in the PR and teammates (and future sessions) share it.
- Ask the agent to "create Backlog.md tasks for this" *before* "implement this" — that's where the review leverage comes from.

---

## RTK — Rust Token Killer

### Verify

```bash
rtk --version
```

On Claude Code with the hook installed, RTK transparently rewrites noisy commands in Claude's tool calls. Without the hook, you wrap commands manually.

### When to reach for it

Any command whose output is mostly noise that Claude doesn't need to see verbatim:

| Command | Token cut typical |
|---|---|
| `rtk npm install` / `rtk pnpm install` | 80–90% |
| `rtk npm test` (Jest, Mocha) | 70–90% |
| `rtk cargo build` / `rtk cargo test` | 60–85% |
| `rtk pytest` | 70–85% |
| `rtk docker build` | 75–90% |
| `rtk terraform plan` | 60–80% |
| `rtk gh pr checks` | 50–70% |

RTK filters progress bars, duplicate lines, timestamps, and other low-signal noise while preserving errors, warnings, test failures, and final summaries.

### Session tips

- **Use it as the default prefix for long-running commands.** If the command takes more than ~5s or prints more than ~50 lines, prefix with `rtk`.
- **Check `rtk --list`** (or `rtk help commands`) for the full list of wrapped commands. Fall back to the raw command if rtk doesn't support it.
- **When RTK hides something you need**, run the raw command once to see the full output.
- On Claude Code, the hook version auto-rewrites supported commands — you don't need to type `rtk` explicitly. Verify with `rtk hook status` (if available) or just run a noisy command and watch the token count.

---

## Workflow: starting a new session

1. **cd to the project** (not to this repo).
2. **`/mcp`** in Claude Code — confirm serena is connected.
3. **First time in the project?** Run `dev-ai-tools install-serena` (scaffolds `.serena/`) and `dev-ai-tools install-graphify` (wires graphify rules + hooks into `CLAUDE.md`, `AGENTS.md`, `.claude/settings.json`). Then ask the agent to run a Serena tool; it triggers onboarding and memory creation.
4. **Big codebase you don't know?** Build the knowledge graph with `graphify` (see the Graphify section above), then ask conceptual questions — the agent will query it via the rules in `CLAUDE.md` / `AGENTS.md`.
5. **Non-trivial feature?** `backlog init` (once per repo), then have the agent create Backlog.md tasks first; review the spec + plan before it writes code.
6. **Running builds/tests/installs?** Prefix with `rtk`, or let the hook auto-rewrite.

---

## The `dev-ai-tools` wrapper

`make setup` symlinks `bin/dev-ai-tools` into `~/.local/bin` (override with `DEV_AI_TOOLS_BIN`). It's a thin dispatcher so you can wire new projects without cd'ing back to this repo.

| Command | What it does |
|---|---|
| `dev-ai-tools install-graphify` | Installs/updates the Graphify CLI and runs `graphify <client> install` for each detected client — writes land in the **current** directory (`CLAUDE.md`, `AGENTS.md`, `.claude/settings.json`, etc.) |
| `dev-ai-tools install-serena` | Scaffolds `.serena/project.yml` + memory templates in the current directory |
| `dev-ai-tools check` | Per-project wiring status + the global `make check` output |
| `dev-ai-tools update` | `git pull` on the dev-ai-tools repo and re-run `make setup` |
| `dev-ai-tools help` | Show usage |

Typical flow when onboarding a new project:

```bash
cd ~/Projects/new-repo
dev-ai-tools install-serena       # .serena/project.yml + memories
dev-ai-tools install-graphify   # CLAUDE.md/AGENTS.md section + hooks
dev-ai-tools check              # verify everything is in place
```

**macOS note**: `~/.local/bin` is not on `PATH` by default on macOS. After `make setup`, if `dev-ai-tools: command not found`, add this to `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then `source ~/.zshrc`. Linux distros and WSL usually have `~/.local/bin` on `PATH` already.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/mcp` shows `serena ✘ failed` | `make check` → likely uvx PATH issue → `make setup` re-registers with the absolute uvx path |
| `graphify --version` not found | Either `uv tool install graphifyy` didn't run or `~/.local/bin` isn't on PATH — `make install-graphify`, then `uv tool update-shell` |
| `rtk` not found | `make install-rtk` (brew on macOS when present, else curl) |
| `backlog` not found | `make install-backlog` (brew on macOS when present, else npm — needs Node.js) |
| `/mcp` shows `backlog ✘ failed` | Usually a missing project store — run `backlog init` in the repo; check the entry uses the absolute `backlog` path (`make install-backlog` bakes it in) |
| Graphify rules or hook missing in a client | Re-run `make install-graphify` and accept the per-client prompt; or run `graphify <client> install` directly (Claude Code, Codex, Cursor, VS Code, and others are supported — see `graphify --help`) |
| Serena onboarding runs every session | Commit `.serena/memories/` for the project — if it's gitignored or missing, Serena thinks the project is new every time |

---

## References

- Serena: [docs](https://oraios.github.io/serena/01-about/000_intro.html) · [GitHub](https://github.com/oraios/serena)
- Graphify: [graphify.net](https://graphify.net) · [GitHub](https://github.com/safishamsi/graphify)
- Backlog.md: [backlog.md](https://backlog.md) · [GitHub](https://github.com/MrLesk/Backlog.md)
- RTK: [GitHub](https://github.com/rtk-ai/rtk)
