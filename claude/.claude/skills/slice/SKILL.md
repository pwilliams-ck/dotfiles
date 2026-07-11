---
name: slice
description: Implement a scoped task as a TDD vertical slice — failing tests first, green checks, feature-branch commits, a PR offer, and a handoff note. Works in any repo; honours the project's own CLAUDE.md, git policy, and test/build tooling. Pass the task id or a pointer to its spec as the argument, e.g. /slice 07c2 or /slice "add rate limiting".
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/slice — implement a scoped task as a TDD vertical slice (red-green-refactor)

  /slice "add rate limiting"     implement by description
  /slice 07c2                    implement by task id
  /slice --help                  show this help
```

---

# TDD Vertical Slice

Implement the task named in the argument (`$ARGUMENTS`) end to end. **All of the
current repo's rules — its `CLAUDE.md`, git policy, and conventions — apply.**
This skill *sequences* them; it does not relax them (git stays approval-gated
per command).

## 1. Scope

- Locate the task spec: the id/title in `$ARGUMENTS` points at a task doc,
  issue, or tracker entry — find it in whatever this repo uses (a `docs/` tree,
  an issue tracker, a TODO/handoff file). Read any prior handoff note first.
- Read the repo's `CLAUDE.md` and any docs it tells you to read for this kind of
  work.
- Verify every API method, struct field, route, or config key the plan relies
  on by grepping the real code — quote what you found. Never plan on assumed
  names.
- If a genuine scope or architecture fork exists, ask the 1–2 questions now, in
  one batch. Otherwise state the plan in a few lines and proceed.

## 2. Branch

- Confirm cwd is the repo root and run `git branch --show-current`.
- Propose `git switch -c <type>/<kebab-task-name>` (approval-gated), following
  the repo's branch-naming convention — never work on the default branch.

## 3. Red → Green → Refactor

Discover the project's test and build/lint commands first (a Makefile,
`package.json` scripts, `pyproject`, etc.). Then for each increment:

- Write the failing test first; run it and show the failure (for the right
  reason).
- Implement the minimum to pass; run and show green.
- Refactor with tests green. Document exported symbols as you go, per the repo's
  conventions.
- Run the full test/lint check and show it green before each commit.
- Propose the iteration commit (approval-gated). Subject per the repo's commit
  convention.

## 4. Finish the slice

- Update the project's docs (README / changelog / etc.) as the task requires.
- Write or refresh the handoff wherever the project keeps one (a `HANDOFF.md`,
  the tracker, or chat if none): what just landed (branch, files), open
  decisions, gotchas, and the next slice. Assume the next session starts with
  zero context.
- Re-run the full check; show green.
- Re-verify branch and cwd, propose the final commit. Bundle the doc + handoff
  updates into it — never a standalone handoff- or doc-only commit.
- Tell the user the task is complete and offer to push the feature branch and
  open a PR (`git push -u origin <branch>` / `gh pr create` — show the exact
  commands, wait for approval, never merge) **if the repo's rules permit it**.

## 5. Handoff

Invoke the `handoff` skill (argument `merged` if the PR merged this session,
none otherwise) — it refreshes the handoff file and prints the paste-ready
prompt for the next session. **Do not** start the next task. After any PR is
opened, note its number so the handoff folds it in. Recommend the user run
`/clear` before the next `/slice` — the handoff is written for zero context on
purpose; a fresh context implements and reviews better than a compacted one
carrying this slice's assumptions.
