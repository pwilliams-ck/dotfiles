# Global Agent Instructions

## Working agreement

- Do only what was asked. When you spot an adjacent bug or smell, surface it and ask before expanding scope.
- Don't be sycophantic, it's annoying.
- Don't flatter, it's patronizing.
- Avoid happy talk and useless words. Get directly to the point.
- We're engineers, keep it succinct, imperative mood
- Don't repeat yourself.
- Before starting a task, read the docs whose trigger matches the work. Do not read all docs up front unless the repo explicitly requires it.
- When citing repo files, include relative file paths with exact line numbers whenever possible. Prefer `path/to/file.ext:123` and use line ranges only when they add clarity.
- **Repo rules win.** When a project's CLAUDE.md/AGENTS.md conflicts with this file, follow the repo.

## Git Safety

- NEVER MAKE CHANGES ON THE MAIN BRANCH OF A GIT REPOSITORY. Before editing files, check the current branch. If the branch is `main`, stop and ask the user to approve creating or switching to a non-main branch.

## Source control

- Never run history or remote-mutating commands (`git commit`, `git push`, `git tag`, `gh pr create`) unless explicitly asked. Stage diffs; the human reviews, commits, and pushes.

## Comments

- Prefer self-documenting code: a better name beats a comment.
- Keep only WHY comments: a hidden constraint, an invariant, a workaround for a specific bug, or an RFC citation that explains otherwise-surprising behavior.
- Delete WHAT comments that restate the code, and comments that narrate history or audit findings. If a rename makes a comment redundant, delete it rather than updating it.

## Testing

- Test real behavior and observable outcomes: `results`, return codes, emitted headers, side effects, not how a function was called. Asserting call shape (`calledWith`, arity, call counts) tests the test and hides signature drift.
- Mocks/stubs are a smell. Prefer real inputs; when you must isolate a dependency, inject a seam and assert the outcome. Never leave a stub that neuters the path under test: that yields green tests proving nothing.
- For bug fixes, add a failing test first, then fix.
- Every feature ships with meaningful tests. A `.skip` is a coverage hole: fix it or delete it.

## Markdown & prose

- Do not hard-wrap prose. Write one paragraph per line, with a semantic line break only at a real paragraph boundary, and let the reader's editor soft-wrap at whatever width they choose. This applies to Markdown docs, chat replies, commit messages, and PR bodies.
- A fixed wrap column like 72, 80, or 100 bakes in one width and reads awkwardly at every other one. Never insert newlines mid-sentence to hit a column.
- Exceptions that legitimately keep newlines: fenced code blocks, tables, and list items, one line per item.

## Read These Docs — When Triggered

Do not read all docs up front unless the repo explicitly says to. Read the specific doc when its trigger matches.

| When you are... | Read first |
| --- | --- |
| Starting a numbered task from `docs/todo/` | `docs/todo/README.md`, then the task file |
| Writing code in a language with local examples or conventions | The repo's code examples, style guide, or language-specific doc |
| Working on schema, types, files, formats, or state transitions | The repo's schema, data-model, or state-machine doc |
| Writing or modifying error handling | The repo's error-handling doc |
| Writing, sequencing, or debugging tests | The repo's TDD, testing, or build-sequence doc |
| Unsure how to test something | The repo's testing guide for that language or subsystem |
| Questioning whether architecture should change | The repo's architecture, scaling-threshold, or design-decision doc |
| Working on Docker, CI/CD, release, hosting, or deployment | The repo's deployment, operations, or CI/CD doc |
| Working inside a documented subsystem | That subsystem's README or architecture doc |
