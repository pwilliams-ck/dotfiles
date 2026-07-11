---
name: delib
description: Deliberate engineering decisions via multi-agent adversarial review. Spawns specialist agents (reliability, security, ops, simplicity) to independently propose and challenge, then the head model decides. Use for architecture, design, infrastructure, and migration decisions — not implementation. Pass a question, optionally with a plan file for grounded review. e.g. /delib "should we use gRPC or HTTP", /delib --deep @plan.md "review this plan", /delib @plan.md "is the workflow engine retry strategy sound".
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/delib — multi-agent adversarial review for engineering decisions

  /delib "question"              deliberate a decision
  /delib @plan.md "question"     deliberate grounded in a plan
  /delib --deep @plan.md "q"     add adversarial challenge round
  /delib --lens security,ops "q" run only named lenses
  /delib --help                  show this help
```

---

# Deliberate (`/delib`)

Multi-perspective adversarial review for engineering decisions. Spawns
specialist agents that independently analyze, then cross-challenge, then the
**head model** synthesizes and decides. Agents never talk to each other — the
orchestrator controls all information flow.

## Syntax

```
/delib [flags] [@plan-file] ["question"]
```

### Flags

| Flag | Effect | Default |
|------|--------|---------|
| `--deep` | Adds adversarial challenge round (phase 2) between propose and decide. Use for high-stakes, irreversible, or cross-system decisions. | off — standard is propose + decide |
| `--lens <list>` | Comma-separated lens names to run. Valid: `reliability`, `security`, `ops`, `simplicity`. Runs only the named agents — saves cost when the question clearly falls under specific lenses. | all four |
| `--amend` | After the user approves the decision, apply plan amendments to the attached plan file. Without this flag, amendments are shown but not applied. Requires an attached plan. | off — amendments shown only |

### Positional arguments

- **`@plan-file`** — path to a plan or design doc. Attached as grounding
  context for all agents. Optional.
- **`"question"`** — the problem to deliberate. Optional when a plan is
  attached (defaults to full-plan review).

At least one of plan or question is required.

### Argument parsing

Parse `$ARGUMENTS` left to right:
1. Extract flags (`--deep`, `--lens <value>`, `--amend`).
2. Any token starting with `@` is a plan file path — read it.
3. Remaining text is the question.
4. If a plan is attached but no question, default to:
   `"review this plan — what's going to bite us"`.
5. If `--amend` is set but no plan is attached, warn and ignore the flag.

---

## Input modes

1. **Question only** — `/delib "should we use gRPC or HTTP"`. Agents explore
   the codebase and propose from scratch.
2. **Plan + question** — `/delib @plan.md "is the retry strategy sound"`. The
   plan is attached context, not gospel. Agents stress-test the plan's specific
   decisions through their lens. The question narrows focus.
3. **Plan only** — `/delib @plan.md`. Full-plan review. Each agent scrutinizes
   the plan within their lens: reliability probes failure paths and recovery
   gaps, security audits trust boundaries and data flow, ops checks
   observability and deploy story, simplicity hunts over-engineering.
4. **Architecture review** — `/delib @plan.md "review the overall architecture
   and key decisions"`. Agents evaluate structural choices: domain model,
   port/adapter boundaries, schema design, dependency selection, process
   topology, and CI/CD approach. Each lens asks whether the architecture serves
   its concern or fights it.

When a plan is attached, phase 0 extracts its constraints (language, schema,
ports, step sequences, locked decisions) and feeds them to every agent. Agents
must ground proposals and critiques in the plan's concrete artifacts — schema
tables, port signatures, step names — not abstract alternatives. "You should
use a message queue" is useless; "the `send_status_email` step should be
idempotent because River retries will re-deliver after SMTP timeout" is useful.

## Quality bar

Every proposal and the final decision are measured against one standard:
**would a very senior Go engineer — Rob Pike, Mat Ryer, or a member of the Go
team — look at this and nod?** If their first reaction would be confusion, the
second must be gratitude once the reasoning lands. If neither, it fails.

This means:
- stdlib until proven insufficient — the burden of proof is on the dependency
- fewer types, fewer packages, fewer concepts — earned simplicity
- explicit error paths, no magic, no ambient authority
- the simplest correct solution wins; complexity must justify itself

When the project isn't Go, translate the spirit: idiomatic for the ecosystem,
least-surprise, smallest surface area that solves the problem.

## Priority order (immutable)

1. Security & data integrity
2. Reliability
3. Readability / understanding
4. Performance

Never trade up-stack. A faster or prettier solution never costs correctness.

---

## Phase 0 — Frame

Before spawning agents, the head model:

1. Parses `$ARGUMENTS` per the rules above.
2. Reads the repo's `CLAUDE.md` and any relevant docs/code the problem touches.
3. If a plan is attached, reads it and extracts: language, locked decisions,
   schema, port signatures, step sequences, dependency choices, process
   topology. These become the **constraint brief** shared with all agents.
4. States the decision in one sentence.
5. Lists the concrete constraints (from plan and/or codebase).
6. Determines which lenses to run:
   - If `--lens` was provided, use exactly those.
   - Otherwise, default is all four. Skip one only if it's genuinely irrelevant
     (e.g. no security surface) — and say why.
7. Determines depth:
   - `--deep` flag → deep mode.
   - No flag → standard, unless the head model judges the problem is
     high-stakes/irreversible enough to upgrade. If upgrading, say why.

---

## Phase 1 — Propose (parallel, independent)

Spawn specialist agents **simultaneously**, one per active lens. Each `Agent()`
call **must** include `model: "opus"` — without it, agents inherit the runtime
default (often Sonnet), defeating the senior-reviewer intent. Each agent:

- Receives the problem statement + constraint brief from phase 0
- Receives its lens brief (below) and **only** its lens
- If a plan is attached, receives the full plan text
- Has full tool access to read the codebase, grep, search
- Returns a structured response (format below)
- **Never sees the other agents' output** — independence is the point

### Lens briefs

**Reliability agent:**
> You are reviewing this decision through the lens of failure modes, error
> handling, blast radius, recovery, and graceful degradation. Ask: "What
> breaks? How do we know it broke? How do we recover? What's the blast radius?"
> Propose the approach that fails predictably and recovers cleanly. Explicit
> error paths over implicit ones. Context propagation matters. If the on-call
> engineer at 3am can't reason about the failure from the logs, it's wrong.

**Security agent:**
> You are reviewing this decision through the lens of attack surface, trust
> boundaries, data flow, and authorization. Ask: "Who can abuse this? What
> leaks? Where are the trust boundaries? Does anything have ambient authority
> it shouldn't?" Propose the approach with the smallest attack surface. Validate
> at system boundaries, trust nothing from outside. Least privilege everywhere.

**Ops agent:**
> You are reviewing this decision through the lens of deployment, observability,
> debugging, cost, and operational burden — including CI/CD pipeline design,
> build reproducibility, and release safety. Ask: "Can we deploy this safely?
> Can we roll it back? Can we observe it in production? Can we pprof/trace/debug
> it? What does this cost to run and to operate? Does the CI pipeline catch this
> class of failure before it ships? Is the build reproducible?" Propose the
> approach an on-call engineer would thank you for. Structured logging, metrics,
> health checks. No hidden state. If you can't reason about it in production,
> it's wrong.

**Simplicity agent:**
> You are reviewing this decision through the lens of complexity budget,
> alternatives, and earned simplicity. Ask: "Is there a simpler way? Can stdlib
> do this? Can we cut a type, a package, a concept? Is this abstraction earning
> its keep? Would Rob Pike look at this and nod?" Propose the approach with the
> fewest moving parts. The burden of proof is always on complexity. If two
> approaches are equally correct and reliable, the one with fewer lines, fewer
> deps, and fewer concepts wins — no debate. Flag any speculative abstraction
> or premature optimization as a defect.

### Agent response format

Each agent returns exactly:

```
## Proposal
<What to do and how — concrete, not theoretical. Name files, packages, types.>

## Risks
<What could go wrong with THIS proposal, from THIS lens.>

## Hard requirements
<Non-negotiable constraints this lens imposes on ANY solution.>

## Eyebrow check
<Would the senior engineer nod? What might make them pause?>
```

---

## Phase 2 — Challenge (parallel, adversarial) [deep mode only]

Spawn the same active agents again with `model: "opus"` on every `Agent()`
call (same rule as phase 1). This time each receives **all other agents'
proposals** (not their own). Each agent:

- Must find flaws, gaps, conflicts, and unstated assumptions in the proposals
- Ranks concerns by severity: **blocking** (must fix), **warning** (should
  address), **note** (worth knowing)
- Is explicitly told: "Agreement is not your job. Finding what's wrong is."

### Circuit breaker

If the head model judges that challenge output is circular, restating
proposals, or not surfacing new information: **stop. Proceed to phase 3
immediately.** Never run a third round of agents.

Maximum agent rounds across the entire skill: **2** (propose + challenge).
The head model can always short-circuit to decide earlier.

---

## Phase 3 — Decide (head model only, no agents)

The head model reads all proposals (and challenges, if deep mode) and produces
the final deliverable. No more agents — this is synthesis, and it's the
orchestrator's job.

### Decision format

```
## Decision
<One sentence: what we're doing.>

## Rationale
<Why this approach. Name what was rejected and why — in terms of the quality
bar. Not "balances concerns" — concrete: "option B is 40 fewer lines, zero new
deps, and the error paths are explicit. Option A needed a custom middleware
that doesn't earn its complexity.">

## From each lens
- **Reliability:** <key requirement preserved or tradeoff accepted>
- **Security:** <key requirement preserved or tradeoff accepted>
- **Ops:** <key requirement preserved or tradeoff accepted>
- **Simplicity:** <key requirement preserved or tradeoff accepted>

## Risks accepted
<What we're knowingly trading off and why it's acceptable.>

## Action plan
<Concrete next steps — files to create/modify, order of operations.
If implementation follows, this feeds directly into /slice.>

## Plan amendments [only when a plan was attached]
<Specific, copy-pasteable edits keyed to plan sections. Format:

**Section "X" → change:** <what to add, remove, or reword and why>

These are recommendations — the head model does NOT edit the plan directly.
Present them for user approval. If the user confirms, apply them; otherwise
drop them. Never surprise-edit a plan file.

If --amend was set: after presenting amendments, ask the user to confirm.
On confirmation, apply edits to the plan file. On rejection, drop them.>
```

### Decision rules

- When reliability and simplicity conflict, reliability wins.
- When two equally reliable approaches exist, the simpler one wins by default.
  Complexity bears the burden of proof.
- A dependency is guilty until proven innocent. "It's popular" is not proof.
- If no agent surfaced a meaningful concern about the simplest approach, that's
  the answer. Don't complicate it because the process has four lenses.
- The decision must be expressible in terms of the quality bar. If you can't
  explain why the senior engineer would nod, rethink it.

---

## Agent configuration

- **Model:** every `Agent()` call **must** pass `model: "opus"` explicitly.
  Without it, agents inherit the session default (often Sonnet). These are
  senior reviewers, not search workers — Opus is the floor.
- **Isolation:** agents run in the main worktree (read-only analysis, no edits).
- **Parallelism:** all agents in a given phase launch in a single message
  (parallel tool calls).
- **Tool access:** full read access (Read, Bash, grep, find). No writes.
- **Context:** each agent gets the problem + constraints + its lens brief +
  (in phase 2) other agents' proposals. Nothing else. No conversation history,
  no prior decisions.

---

## When NOT to use this skill

- **Implementation tasks** — use `/slice`.
- **Simple bugs** — just fix them.
- **Config/docs changes** — just make them.
- **Questions with obvious answers** — if the stdlib has a clear solution and
  there's no architectural decision, you don't need four agents to confirm it.

The head model should refuse to run the full process if the problem doesn't
warrant deliberation, and instead answer directly.

---

## Example invocations

```
# Question-only — agents explore the codebase and propose
/delib "gRPC vs HTTP for internal service communication"
/delib "design the background job queue — Redis, Postgres, or in-process"

# Plan-grounded — agents stress-test a specific design
/delib @plan.md "is the workflow engine retry strategy sound"
/delib @plan.md "review this plan — what's going to bite us"
/delib --deep @plan.md "review the SSH key lifecycle for security gaps"

# Lens-filtered — run only relevant agents
/delib --lens security,reliability @plan.md "is the SSH private key lifecycle sound"
/delib --lens reliability,simplicity "SELECT FOR UPDATE vs advisory locks for step transitions"

# Amend — apply approved changes back to the plan
/delib --amend @plan.md "review the schema — what needs to change before we start"

# Deep + amend — full adversarial review with plan updates
/delib --deep --amend @plan.md "review the overall architecture and key decisions"

# Deep mode — adds adversarial challenge round
/delib --deep "migrate auth from session cookies to JWT — what breaks"
```
