---
name: delib
description: Deliberate engineering decisions via multi-agent adversarial review. Spawns specialist agents (reliability, security, ops, simplicity) to independently propose and challenge, then the head model decides. Use for architecture, design, infrastructure, and migration decisions — not implementation. Pass a question, optionally with a plan file for grounded review. e.g. /delib "should we use gRPC or HTTP", /delib --deep @plan.md "review this plan", /delib @plan.md "is the workflow engine retry strategy sound".
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/delib — multi-agent adversarial review for engineering decisions

  Deliberate engineering decisions via multi-agent adversarial review.
  Spawns specialist agents (reliability, security, ops, simplicity) to
  independently propose and challenge, then the head model decides. Use
  for architecture, design, infrastructure, and migration decisions — not
  implementation. Pass a question, optionally with a plan file for
  grounded review.

  /delib "question"              deliberate a decision
  /delib @plan.md "question"     deliberate grounded in a plan
  /delib --deep @plan.md "q"     add adversarial challenge round
  /delib --lens security,ops "q" run only named lenses
  /delib --amend @plan.md "q"    apply approved amendments to the plan
  /delib --help                  show this help

  See also:
    /slice         implement directly from a /delib decision
    /cycle         plan + execute incrementally
```

---

# Deliberate (`/delib`)

Multi-perspective adversarial review for engineering decisions. Specialist
agents independently propose, then (in deep mode) cross-challenge; the **head
model** synthesizes and decides. Agents never see each other's work except when
the orchestrator hands it to them — the head model controls all information flow.

**Every `Agent()` call in this skill must pass `model: "opus"` explicitly.**
Without it, agents inherit the session default (often Sonnet), defeating the
senior-reviewer intent. Agents run read-only (Read/Bash/grep, no edits) and all
agents in a phase launch in one message (parallel).

## Syntax

```
/delib [flags] [@plan-file] ["question"]
```

| Flag | Effect |
|------|--------|
| `--deep` | Adds the adversarial challenge round (phase 2). For high-stakes, irreversible, or cross-system decisions. Default: propose + decide only. |
| `--lens <list>` | Run only the named lenses (`reliability`, `security`, `ops`, `simplicity`). Default: all four. |
| `--amend` | After the user approves the decision, apply plan amendments to the attached plan. Requires a plan; warns and is ignored otherwise. Default: amendments shown, not applied. |

**Positional:** `@plan-file` is grounding context for all agents (optional).
`"question"` is the problem (optional when a plan is attached — defaults to
`"review this plan — what's going to bite us"`). At least one is required.

Parse `$ARGUMENTS` left to right: flags first, then any `@token` is a plan path
(read it), remaining text is the question.

## Quality bar

Every proposal and the final decision meet one standard: **would a very senior
Go engineer — Rob Pike, Mat Ryer, or a member of the Go team — nod?** If their
first reaction is confusion, the second must be gratitude once the reasoning
lands. If neither, it fails.

- stdlib until proven insufficient — the burden of proof is on the dependency
- fewer types, packages, concepts — earned simplicity
- explicit error paths, no magic, no ambient authority
- the simplest correct solution wins; complexity justifies itself

Non-Go project: translate the spirit — idiomatic for the ecosystem,
least-surprise, smallest surface area that solves the problem.

## Priority order (immutable)

1. Security & data integrity
2. Reliability
3. Readability / understanding
4. Performance

Never trade up-stack. A faster or prettier solution never costs correctness.

---

## Phase 0 — Frame (head model)

1. Parse `$ARGUMENTS`.
2. Read the repo's `CLAUDE.md` and the code/docs the problem touches.
3. If a plan is attached, extract its **constraint brief**: language, locked
   decisions, schema, port signatures, step sequences, dependency choices,
   process topology. This is shared with every agent, which must ground
   proposals and critiques in the plan's concrete artifacts — schema tables,
   port signatures, step names — not abstract alternatives. "Use a message
   queue" is useless; "`send_status_email` should be idempotent because River
   retries re-deliver after SMTP timeout" is useful.
4. State the decision in one sentence and list the concrete constraints.
5. Pick lenses: `--lens` if given, else all four (skip one only if genuinely
   irrelevant, and say why).
6. Pick depth: `--deep` → deep; else standard, unless the problem is
   high-stakes/irreversible enough to upgrade — if so, say why.

---

## Phase 1 — Propose (parallel, independent)

Spawn one agent per active lens simultaneously (`model: "opus"`). Each receives
the problem + constraint brief + the full plan (if attached) + **only its own
lens brief**, has read access to the codebase, and never sees other agents'
output.

### Lens briefs

**Reliability** — failure modes, error handling, blast radius, recovery,
graceful degradation. What breaks, how we detect it, how we recover, how big
the blast radius is. Explicit error paths, context propagation. If on-call at
3am can't reason about the failure from the logs, it's wrong.

**Security** — attack surface, trust boundaries, data flow, authorization. Who
can abuse this, what leaks, where the trust boundaries are, what holds ambient
authority it shouldn't. Smallest attack surface, validate at boundaries, least
privilege.

**Ops** — deployment, observability, debugging, cost, operational burden, plus
CI/CD design, build reproducibility, release safety. Can we deploy and roll back
safely, observe and trace it in production, catch this failure class in CI.
Structured logging, metrics, health checks, no hidden state.

**Simplicity** — complexity budget, alternatives, earned simplicity. Is there a
simpler way, can stdlib do it, can we cut a type/package/concept, is this
abstraction earning its keep — would Rob Pike nod? Fewest moving parts; the
burden of proof is on complexity. Flag speculative abstraction and premature
optimization as defects.

### Agent response format

```
## Proposal
<What to do and how — concrete. Name files, packages, types.>

## Risks
<What could go wrong with THIS proposal, from THIS lens.>

## Hard requirements
<Non-negotiable constraints this lens imposes on ANY solution.>

## Eyebrow check
<Would the senior engineer nod? What might make them pause?>
```

---

## Phase 2 — Challenge (parallel, adversarial) [deep mode only]

Re-spawn the active agents (`model: "opus"`). Each receives **all other agents'
proposals** (not its own) and must find flaws, gaps, conflicts, and unstated
assumptions, ranked **blocking** / **warning** / **note**. Told explicitly:
"Agreement is not your job. Finding what's wrong is."

**Circuit breaker:** if challenge output is circular, restating proposals, or
surfacing nothing new — stop and go to phase 3. Never run a third round. Max
agent rounds in this skill: **2**.

---

## Phase 3 — Decide (head model only, no agents)

Read all proposals (and challenges, if deep) and produce the deliverable.

```
## Decision
<One sentence: what we're doing.>

## Rationale
<Why. Name what was rejected and why, in quality-bar terms — concrete, not
"balances concerns": "option B is 40 fewer lines, zero new deps, explicit error
paths. Option A needed custom middleware that doesn't earn its complexity.">

## From each lens
- **Reliability / Security / Ops / Simplicity:** <requirement preserved or tradeoff accepted>

## Risks accepted
<What we're knowingly trading off and why it's acceptable.>

## Action plan
<Concrete next steps — files, order of operations. Feeds directly into /slice.>

## Plan amendments [only when a plan was attached]
<Copy-pasteable edits keyed to plan sections:
**Section "X" → change:** <what to add/remove/reword and why>
Recommendations only — never surprise-edit a plan. Present for approval.
If --amend: on confirmation, apply the edits; on rejection, drop them.>
```

### Decision rules

- Reliability beats simplicity when they conflict.
- Two equally reliable approaches → the simpler one wins by default; complexity
  bears the burden of proof.
- A dependency is guilty until proven innocent. "It's popular" is not proof.
- If no agent surfaced a real concern about the simplest approach, that's the
  answer. Don't complicate it because the process has four lenses.
- The decision must be expressible in quality-bar terms. If you can't explain
  why the senior engineer would nod, rethink it.

### Recommend the next command

A decision nobody executes is waste. After the verdict, route through
`~/.claude/skills/shared/next-command.md` and emit its fenced `Next:` block —
`/cycle` when the decision opens up multi-PR work, `/slice` when it's one PR. If the
decision amends an existing plan, name the task the change lands in.

---

## When NOT to use this skill

Implementation → `/slice`. Simple bugs, config, or docs → just do them. Obvious
answers → answer directly. The head model should refuse the full process when
the problem doesn't warrant it.

## Examples

```
/delib "gRPC vs HTTP for internal service communication"
/delib @plan.md "is the workflow engine retry strategy sound"
/delib --deep @plan.md "review the SSH key lifecycle for security gaps"
/delib --lens security,reliability @plan.md "is the SSH private key lifecycle sound"
/delib --amend @plan.md "review the schema — what needs to change before we start"
```
