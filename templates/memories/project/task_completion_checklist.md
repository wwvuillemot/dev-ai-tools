# Task Completion Checklist

<!-- ============================================================
  INSTRUCTIONS FOR MAINTAINERS
  This checklist runs in Serena's head after every code change.
  Keep it tight — only steps that MUST happen before the work
  is considered done. Too many steps = ignored steps.

  Order matters: fast/cheap checks first, slow checks last.
  Use exact commands from suggested_commands.md.
  ============================================================ -->

After completing any code change, verify each step in order:

1. **Format** — fix all formatting issues
   - `TODO: format command`

2. **Lint** — fix all lint errors and warnings
   - `TODO: lint command`

3. **Type Check** — no type errors
   - `TODO: type check command`

4. **Tests** — all tests pass
   - `TODO: test command`

5. **Coverage** — thresholds met; never lower them
   - `TODO: coverage command`

6. **Quality Gate** — final check before declaring done
   - `TODO: preflight / CI command`

## Before Opening a PR

<!-- What should Serena summarise or verify before a PR is raised?
     Keep this to 3–5 bullet points. -->

- [ ] Summarise files changed and why
- [ ] Confirm no unintended side-effects (migrations, flag changes, API contract changes)
- [ ] Provide exact commands to reproduce / test the change locally
- [ ] Link related issues or tickets
- [ ] TODO: any project-specific pre-PR requirement
