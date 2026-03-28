# Code Style & Conventions

<!-- ============================================================
  INSTRUCTIONS FOR MAINTAINERS
  This is Serena's style guide. It should reflect decisions that
  are NOT already enforced by your linter/formatter — those tools
  speak for themselves. Focus on:
    • Patterns Serena might choose incorrectly without guidance
    • Architecture rules that aren't obvious from the code
    • Conventions the team has agreed on but not automated

  Add a section per language/layer if the project is polyglot.
  ============================================================ -->

## Primary Language(s)

<!-- List each language/layer with its tooling and key conventions. -->

### TODO: Language (e.g. Python, TypeScript)

- **Formatter / Linter**: TODO (e.g. ruff, biome, eslint)
- **Type Checker**: TODO (e.g. pyright, tsc)
- **Naming**: TODO (e.g. snake_case functions, PascalCase classes)
- **Types / Type Hints**: TODO (required? Pydantic at boundaries?)
- **Async**: TODO (async/await? conventions around blocking I/O?)
- **Error Handling**: TODO (fail loudly? typed exceptions? no silent fallbacks?)
- **Imports**: TODO (ordering, absolute vs relative)
- **Comments / Docstrings**: TODO (where required, what style)

## Architecture Rules

<!-- Constraints Serena must respect when placing or editing code.
     Examples: no cross-feature imports, no business logic in controllers,
     always scope to tenant, etc. -->

- TODO

## Testing Conventions

<!-- TDD? Where do tests live? Naming patterns? Coverage requirements? -->

- **Approach**: TODO (e.g. TDD — write failing test first)
- **Location**: TODO (e.g. `tests/{service}/{test_type}/`)
- **Coverage**: TODO (e.g. never lower thresholds)

## Git & Commit Style

<!-- Commit message format? Branch naming? PR conventions? -->

- **Commits**: TODO (e.g. `feat(scope):`, `fix:` prefixes, or free-form)
- **Branches**: TODO (e.g. `feat/`, `fix/`, `chore/`)

## Things Serena Should Never Do

<!-- Hard rules. Be explicit so Serena doesn't have to infer. -->

- TODO: e.g. "Never invent environment variables or config defaults"
- TODO: e.g. "Never change auth or security logic without explicit instruction"
- TODO: e.g. "Never lower test coverage thresholds"
