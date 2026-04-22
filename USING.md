# Using dev-ai-tools in a session

A practical guide for verifying and leveraging Serena, Graphify, and RTK once `make setup` has run.

> TL;DR:
> - **Serena** — use *instead of* reading whole files when you want a symbol, its callers, or a refactor. Semantic, surgical, cheap.
> - **Graphify** — run once per codebase to build a knowledge graph. Ask conceptual questions: "what talks to the billing service?", "explain the data flow."
> - **RTK** — wrap noisy dev commands to cut 60–90% of output tokens. `rtk npm test`, `rtk cargo build`.

---

## One-shot verification

```bash
make check
```

Expected output: a `[✓]` for each of uv, `~/.serena/serena_config.yml`, Claude Code MCP, Cursor, VS Code, Claude Desktop (if installed), Graphify, RTK. Any `[✗]` tells you exactly which `make install-*` target to run.

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

### Verify in a session

- **CLI on PATH**: `graphify --version`.
- **Per client**: in Claude Code, Codex, Cursor, etc., type `/graphify` — if the skill is installed, you'll see it in the command palette. `make setup` offered per-client wiring; you can re-run `make install-graphify` any time.

### First-run in a project

```
/graphify
```

This runs Graphify's three passes: (1) AST extraction from code, (2) transcription of any video/audio/image assets, (3) LLM-subagent extraction of concepts and relationships from docs + papers + transcripts. Output lands as interactive HTML + queryable JSON + an audit report.

It's heavy the first time — expect multi-minute runs on larger codebases. Re-runs are incremental.

### When to reach for it

- **Onboarding to an unfamiliar codebase** — "explain the overall architecture," "what are the main subsystems?"
- **Tracing conceptual dependencies** across code AND docs AND design assets — Graphify unifies them in one graph
- **Finding non-obvious relationships** — "where is auth decided?", "what touches the pricing logic?"
- **Multi-modal repos** (code + PDFs + diagrams + recorded demos) — Graphify is the only tool in this bundle that ingests non-code

### Session tips

- Graphify is a **skill**, not an MCP — you invoke it explicitly with `/graphify` or by asking the agent to use it. It won't run implicitly.
- Don't re-run it every session; the generated graph is persisted. Re-run when the codebase changes substantially.

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
3. **First time in the project?** Ask the agent to run a Serena tool; it triggers onboarding and memory creation.
4. **Big codebase you don't know?** Run `/graphify` to build the knowledge graph, then ask conceptual questions against it.
5. **Running builds/tests/installs?** Prefix with `rtk`, or let the hook auto-rewrite.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `/mcp` shows `serena ✘ failed` | `make check` → likely uvx PATH issue → `make setup` re-registers with the absolute uvx path |
| `graphify --version` not found | Either `uv tool install graphifyy` didn't run or `~/.local/bin` isn't on PATH — `make install-graphify`, then `uv tool update-shell` |
| `rtk` not found | `make install-rtk` (brew on macOS when present, else curl) |
| Graphify slash command missing in a client | Re-run `make install-graphify` and accept the per-client prompt; or run `graphify <client> install` directly |
| Serena onboarding runs every session | Commit `.serena/memories/` for the project — if it's gitignored or missing, Serena thinks the project is new every time |

---

## References

- Serena: [docs](https://oraios.github.io/serena/01-about/000_intro.html) · [GitHub](https://github.com/oraios/serena)
- Graphify: [graphify.net](https://graphify.net) · [GitHub](https://github.com/safishamsi/graphify)
- RTK: [GitHub](https://github.com/rtk-ai/rtk)
