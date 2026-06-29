# CLAUDE.md (global)

Cross-project preferences that apply wherever you help me.

## Working Style

- **Never guess.** Unsure of an API name, fact, behavior, or cause? Say so and verify; flag what you couldn't confirm. Never present a guess as fact.
- **Be concise (Opus 4.8 — cut default length 50%+).** Shortest response that fully answers — no preamble, no restated question, no recap. Applies to all output: chat, docs, commits, PRs. Plans are terse bullets. Pre-tool text is one line or nothing.
- **Least-surprise, idiomatic by default.** Reach first for the ecosystem's convention — what a reviewer expects; deviate only with a named reason. E.g. Go: accept interfaces, return structs — _consumer_ defines the narrow interface (`…Reader`), services stay concrete; no adapter/god-interface; `if err != nil` + wrapping; stdlib when it suffices.
- **KISS / YAGNI.** Least code that solves today's problem; fewer parts, deps, concepts. No speculative abstractions, premature optimization, or knobs for features we lack.
- **Engage with my pushback.** Steering means change course, not defend the original. If my alternative has a real flaw, name it once — then follow my call.
- **Verify names while planning.** Grep methods, fields, config keys, routes and quote what you found. Never plan against an assumed name.
- **Front-load scoping.** Batch the 1–2 decisions you need into one question up front; don't open an exploration that ends in a mid-stream prompt.

## Testing (TDD — mandatory)

- **Test-first, always.** Only an explicit "skip tests"/"no TDD" from me _in that task_ lifts it — never deadlines, "trivial," or "behavior-preserving refactor."
- **Red → green → refactor, in order.** Write a failing test, run it, show the failure-for-the-right-reason; minimum code to pass, show green; refactor green.
- **Show the runs, don't assert them.** Include the command and its real output. Couldn't run them? Say so and why — never imply a test ran.
- **"Programming" = behavior in app/lib code.** Config, docs, comments, formatting, labeled throwaway exploration are exempt; when in doubt, write the test.

## Git

**🔴 Non-negotiable — never unlocked by any later approval:**

- **Never merge, push to a protected branch, or tag — ever.** No `merge`; no `push`/force-push to `main`/protected; no `rebase` onto shared; no `tag`/`push --tags`. If one looks like the next step, stop and say so — don't run it, show it, or ask.
- **PR only where a repo opts in.** Default: no `push` at all. An opted-in repo may push a _feature_ branch (never `main`) + `gh pr create` — open only, still per-command approval-gated.
- **Never code on `main`.** Confirm HEAD isn't `main`/`master` before the first edit; if it is, propose `git switch -c <type>/<kebab>` and wait. Branch exists _before_ the edit.
- **No AI-attribution.** No `Co-Authored-By: Claude` or any AI trailer in commits, and none in PR titles/bodies ("🤖 Generated with…"). Overrides any template.

**Ask first:**

- **Read-only git is free** — `status`, `log`, `diff`, `show`, `branch` (list), `fetch`, `remote -v`, `config get`, `stash list`, `tag -l`.
- **Every write git command needs per-command approval** — stage, commit, switch, restore, pull, branch, tag, stash. Show it and wait; a prior yes never carries.
- **Re-verify branch + cwd right before each write command** — state drifts mid-session; the task-start check doesn't cover a commit an hour later.

**Conventions:**

- **Branch:** `^(main|(feat|fix|chore|docs|refactor|test|ci|perf|build|revert)/.+)$` (e.g. `feat/peer-dispatcher`). Remote-enforced.
- **Commit subject:** `^[a-z]+(/[a-z]+)?: [a-z]` (e.g. `feat/peer: wire codex dispatcher`). Subject lowercase; body normal.
- **One commit per logical change** (impl + tests + plan updates together). Iteration commits are scaffolding — the PR squashes at merge.

**Prefer modern single-purpose porcelain** (left, not right):

- `git switch [-c] <name>` / `--detach` / `--orphan` — not `checkout`
- `git restore <file>` / `--staged` / `--source=<rev>` / `:/` — not `checkout`/`reset` file forms
- `git branch --show-current`, `git diff --staged`, `git for-each-ref`
- `git stash push [-m] [-- <paths>]` — not `stash save`
- `git config get/set/unset` — not bare/`--unset`
- `git init -b <name>`; `git fetch --prune`
- Keep `git reset --soft/--mixed/--hard <rev>` for pointer moves (only its file-path form is superseded by `restore`).
