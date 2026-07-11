---
name: blueprint
description: Plan a feature or project as a TODO/ task tree via tiered multi-agent research. The head model frames and decides; lower-tier workers (sonnet/haiku) fetch real current docs and verify names in the codebase. Output is a TODO/ dir — README.md index plus one taskNN-<slug>.md per ~300-line PR, sub-task checklists mapping to atomic commits, links to verified refs. Planning only — implementation is /build. e.g. /blueprint "add OIDC login to the admin panel", /blueprint @spec.md, /blueprint --amend "fold in rate limiting".
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/blueprint — plan a feature as a TODO/ task tree (planning only; /build executes)

  Plan a feature or project as a TODO/ task tree via tiered multi-agent
  research. The head model frames and decides; lower-tier workers
  (sonnet/haiku) fetch real current docs and verify names in the codebase.
  Output is a TODO/ dir — README.md index plus one taskNN-<slug>.md per
  ~300-line PR, sub-task checklists mapping to atomic commits, links to
  verified refs.

  /blueprint "goal"              seed a new plan
  /blueprint @spec.md "goal"     plan grounded in a spec
  /blueprint --amend "change"    fold changes into existing TODO/
  /blueprint --help              show this help

  See also:
    /build         execute this plan task by task
    /delib         deliberate a decision, then feed into /blueprint
    /cycle         rolling alternative (plan + execute incrementally)
    /slice         implement a single-PR task directly
```

---

# Blueprint (`/blueprint`)

Turn a goal into an executable plan: the **head model** (this session) frames,
prioritizes, and decides; **lower-tier workers** gather facts. The deliverable
is a `TODO/` directory a zero-context session (or a cheaper model) can execute
task by task via `/build`.

## Syntax

```
/blueprint [--amend] [@spec-file] ["goal"]
```

- **`@spec-file`** — optional design doc / spec, attached as grounding context.
- **`"goal"`** — the thing to plan. Required unless a spec is attached.
- **`--amend`** — a `TODO/` already exists; fold the new goal into it instead
  of creating one. Show the proposed diff to the index and affected tasks,
  get one OK, then apply. Never silently restructure an existing plan.

## Model tiers

| Role | Model | Job |
|------|-------|-----|
| Head | session model | Frame, prioritize, decompose, write TODO/. Never delegated. |
| Research worker | `model: "sonnet"` | Fetch current docs (WebFetch/WebSearch), read code, verify API/config names. |
| Bulk lookup | `model: "haiku"` | Routine greps, file inventories, list-shaped questions. |

Every `Agent()` call passes `model:` explicitly. **Never spawn Fable
subagents** — Fable is main-thread only.

## Phase 1 — Frame (head)

1. Read the repo's `CLAUDE.md` and any docs it points at; read the attached
   spec if any.
2. State the goal in one sentence and list hard constraints (language, deps
   policy, git policy, existing patterns to extend).
3. List the open questions that block decomposition. If 1–2 need the user,
   batch them into one question **now** — never mid-stream later.

## Phase 2 — Research (parallel workers)

Spawn workers in a single message, one per open question. Each worker gets a
narrow brief and must return:

- **Findings** — concrete, quoted from source (code lines, doc excerpts).
- **Verified names** — real method/field/route/config names grepped from the
  codebase, quoted. Never an assumed name.
- **References** — for anything external (library API, protocol, tool),
  WebFetch the **current official docs** and return URL + version/date.
  Trained memory is not a reference; a URL is.

The head cross-checks anything load-bearing before it enters the plan. Don't
spawn workers for what the head already read in phase 1.

## Phase 3 — Decompose (head)

1. Prioritize: security/data-integrity/reliability work first, then the
   dependency order that keeps every intermediate state shippable.
2. Cut into tasks where **each task = one PR**: target ~300 changed lines,
   hard cap 500 (excluding generated/vendored/lockfiles). Split before a task
   would exceed it.
3. Cut each task into **sub-tasks where each sub-task = one atomic commit**
   (impl + tests together; TDD applies at build time). Each sub-task names
   the files it touches and the behavior its test proves.
4. **Checkpoint:** show the user the priority-ordered task list, one line per
   task (`NN <slug> — <one clause> [deps: NN]`). One OK, then write. This is
   the only mid-skill question.

## Phase 4 — Write `TODO/`

**Guard:** Before writing, check if `TODO/` already exists. If it does **and
`--amend` was not passed**, stop and ask:

> `TODO/` already exists with N task files. Running without `--amend` will
> overwrite it. Options: re-run with `--amend` to fold in, or confirm
> overwrite.

Never silently overwrite an existing `TODO/`.

Create at the repo root (plain file writes — no git commands):

**`TODO/README.md`** — the index, and the shared context that makes every
tier faster. Contents:
- Goal (one paragraph) and any locked decisions.
- Task table: `id | slug | status ([ ]/[~]/[x]) | deps | PR size est.`
- **Shared refs:** verified names table (symbol → file:line), commands
  (test/lint/build, with the repo's bug-surfacing flags), doc URLs from
  phase 2 with version/date. Implementers must not need to re-research.
- Conventions pointer: branch/commit format, anything repo-specific /build
  must honor.

**`TODO/taskNN-<slug>.md`** — one per task:

```markdown
# taskNN: <slug>

**Goal:** <one sentence>  **Branch:** <type>/<kebab>  **Deps:** <ids or none>

## Refs
- <only the refs THIS task needs — links into README's tables + doc URLs>

## Sub-tasks (one atomic commit each)
- [ ] 1. <behavior> — test: <what the failing test proves>; files: <list>
- [ ] 2. ...

## Verify
<exact commands that must pass before the final commit>

## Done when
<observable acceptance criteria — behavior, not effort>
```

Write every task file for a **zero-context reader**: a sonnet-tier session
must be able to execute it without re-deriving the plan. Offer (don't run) a
commit of `TODO/` per the repo's git policy, approval-gated.

## Context budget

- The session runs on 1M-context models; the working budget is **15% used**
  (the `ctx-handoff-nudge` Stop hook fires there — treat it as authoritative).
- From ~10%, gauge remaining runway: stop opening new research rounds and
  start writing what's already decided.
- At 15%: finish the file in progress, mark unwritten tasks as `[ ] stub` in
  the README, then invoke the **`handoff`** skill — HANDOFF.md must say
  exactly which task files exist and which remain.
- **Never exceed 20% in one run.** No phase, worker round, or file is worth
  crossing it — hand off instead.

## When NOT to use

- Single-PR-sized work with an obvious shape — just do it (or `/slice`).
- Architecture *decisions* — that's `/delib`; run it first, feed its action
  plan into `/blueprint`.
