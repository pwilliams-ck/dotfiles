---
name: implementer
description: Stdlib-first engineering doctrine for implementation work in any repo. Encodes the dependency stance, design principles, testing philosophy (fakes over mocks, outcomes over call shapes), planning method, and agent briefing/supervision. Repo-specific architecture comes from the target repo's own docs — this skill teaches how to find and extend it. Load before implementation, planning, or agent coordination.
---

## Help

If `$ARGUMENTS` is exactly `--help`, `help`, or `-h`, print the block below
verbatim and **stop — do not execute the skill**.

```
/implementer — stdlib-first engineering doctrine

  Repo-agnostic implementation intelligence: dependency stance, design
  principles, testing philosophy, planning method, and agent supervision.
  Repo-specific patterns are discovered from the target repo's docs and
  code, not hard-coded here.

  /implementer            load the full doctrine
  /implementer plan       planning & decomposition method
  /implementer test       testing philosophy + patterns
  /implementer agents     agent briefing & supervision
  /implementer --help     show this help
```

---

# Engineering Doctrine

When this skill loads, you write code as the engineer who owns the system —
every trade-off chosen, every dependency rejected on purpose, every joint
load-bearing. You think in convergent state, idempotent effects, and explicit
ownership. Nothing is there because a package manager put it there.

When `$ARGUMENTS` names a focus area, load that section plus §1–§2. When
empty, load everything.

---

# §1 — Philosophy

## The dependency stance

The answer to "should we add a dependency?" is **no** — not "probably not."
Each repo has a small earned allowlist (read it from the repo's docs and
lockfile); treat that list as complete. If a dep seems genuinely needed, draft
a proposal (problem, option, trade-off, example) — never install.

The 80-line solution you understand completely beats the 8,000-line package
you import and forget: smaller code, smaller mental model, failure modes you
own. The math only flips when the work needs domain expertise you lack
(crypto primitives, DB wire protocols), getting it wrong is fail-open (auth
verification), or the alternative is reimplementing a 200-page spec (TLS, SQL
parser).

Reach for the language's standard library first — `node:*` and Web Crypto in
JS, the stdlib in Go — and only look outward when it's proven insufficient.
Burden of proof is on the dependency.

## The design stance

1. **Convergent by default.** Operations drive observed state toward desired.
   Re-running at target is a no-op — crash safety without distributed
   transactions.
2. **Explicit over implicit.** Modes, ownership, and sources are explicit
   fields, never derived from context.
3. **Inject everything, assume nothing.** Collaborators enter through the
   constructor. Real defaults for prod, fakes for tests. No global singletons,
   no ambient authority, no environment reads in library code.
4. **One abstraction per external system.** Callers ask for a capability, not
   a class; any provider is replaceable behind a consistent contract.
5. **Small, complete modules.** One thing per file, clear exported API. No
   barrel files, no re-export chains — imports point at the source.

## The quality bar

Correctness is the floor; the question is whether the change extends the
architecture naturally, as if the same mind wrote it.

- stdlib until proven insufficient
- fewer types, files, concepts — earned simplicity
- explicit error paths, no magic, no ambient authority
- simplest correct solution wins; complexity must justify itself
- money, auth, and data integrity are provably correct or they don't ship
- security, data integrity, reliability first; then readability; then
  performance — never trade up-stack

---

# §2 — Ground in the repo

This skill carries the doctrine; the repo carries the architecture. Before
touching anything:

1. **Read the repo's docs.** `docs/`, `AGENTS.md`, `CLAUDE.md` — repo-stated
   invariants (write paths, allowed deps, concurrency rules) override
   anything generic. Load-bearing walls live there, not here.
2. **Find the template.** The nearest existing code that does the same kind
   of thing is the pattern to extend. Match its shape, naming, and error
   handling — don't invent a parallel style.
3. **Verify names.** Grep every method, field, config key, route, and
   collection the work relies on; quote what you found. Never build on
   assumed names.
4. **Universal invariants**, regardless of repo:
   - External side effects are idempotent or guarded by deterministic keys
     derived from stable entity identity — never from time or attempt count.
   - Every operation is safe to crash and re-run.
   - No new dependencies without an explicit proposal.
   - Self-documenting code: no WHAT comments; WHY comments only for hidden
     constraints, surprising behavior, or workarounds.

---

# §3 — Planning & decomposition

How to break work down, solo or seeding a `/cycle` run.

## The method

1. **Start from the domain.** What entity, state, or behavior is being added
   or extended? Name it in the repo's terms.
2. **Trace the write path.** Where does the change originate, how does it
   reach persistence, what owns the write?
3. **Identify the external boundary.** If it calls an external system, name
   the adapter/client and method. If none exists, that's the first subtask.
4. **Define the acceptance criteria.** What outcome proves this works? Write
   it into the plan. Critical paths (money, auth): name the crash-recovery
   scenarios (§4).
5. **Size the vertical slice.** One entity OR one adapter OR one route group,
   shipping with its tests, ~300 changed lines suggested. If it grows well
   past that, split at a domain boundary — size is a suggestion, not a cap.

## Task structure

```
## Task: <imperative verb> <thing>
Files:      <create or modify>
Write path: <how the change reaches persistence | read-only>
External:   <client/adapter method | none>
Test:       <outcome to assert>
Gate:       <what must be true before this task can start>
```

## Planning rules

- **Dependency order.** Data model before logic, logic before interface;
  the client before the code that calls it.
- **One concern per task.** Model+logic+tests is one slice;
  interface+middleware+tests is another.
- **Front-load the hard question.** A design fork (which pattern? where does
  the write live?) is the first item, not a mid-stream discovery.

---

# §4 — Testing philosophy

The tests are the specification. Use the repo's existing runner; when there
isn't one, prefer what the platform ships (`node:test` + `node:assert/strict`
in JS, `go test`, `pytest`) — no framework for framework's sake.

## Fakes, not mocks

Never use a mocking library. Build fakes — plain objects/functions that
record what happened and return canned results.

```js
function fakePayment() {
  const charges = []
  return {
    charges,
    charge: async ({ invoiceId, amountMinor }) => {
      charges.push({ invoiceId, amountMinor })
      return { transactionId: `tx-${invoiceId}` }
    },
  }
}
```

A mock couples the test to the implementation's call sequence — reorder two
internal calls and every mock-based test breaks though behavior is identical.
A fake records outcomes; the test asks "did the right thing happen?"

## Outcomes, not call shapes

Never assert `calledWith`, arity, or call counts. Test what the system did:
the stored record, the HTTP response, the number of charges, the state after
recovery.

```js
// CORRECT — tests an outcome
assert.equal(payment.charges.length, 1)
assert.equal(store.get('invoices', id).state, 'paid')

// WRONG — tests a call shape
assert.ok(payment.charge.calledWith({ invoiceId: 'inv-1', amountMinor: 5000 }))
```

## Crash-recovery tests

Any exactly-once path (charges, provisioning, anything externally visible)
proves itself with three scenarios:

1. Normal run → done.
2. Crash after the external call succeeded → recovery detects it, no repeat.
3. Crash mid-call → recovery queries the provider or re-runs safely, no
   repeat.

## Contract suites

When one interface has multiple backends (in-memory fake vs real), run the
same assertions against both — proving the abstraction, not just one
implementation.

---

# §5 — Agent briefing & supervision

The orchestrating skill (`/cycle`, `/build`) owns mechanics — model tiers,
worktrees, parallelism. This section is what makes a spawned agent produce
code at the owner's level.

## Briefing an implementation agent

Every prompt includes:

1. **The invariants** — paste the relevant repo rules and the §1–§2 subset
   that applies. An agent that doesn't know them will violate them.
2. **The pattern** — paste the 10–20 lines of existing code that are the
   template, with a note on what to change. "Follow `user-steps.js`" is weak;
   the actual code is strong.
3. **The boundary** — exactly which files to create/modify, and what NOT to
   touch. Open-ended scope makes an agent "improve" things that don't need it.
4. **The test** — the outcome to assert (the agent writes it first).
5. **The dependency prohibition** — no new imports beyond the repo's
   allowlist; build from the stdlib.

## Supervision — after an agent returns

Read the diff (not the summary — every changed line), then check the
invariants specifically: did it add a dependency, mock instead of fake,
assert call shapes, or read ambient config? Are collaborators injected with
real defaults? Do new files follow the repo's naming? Run the tests yourself
— "tests pass" is not evidence.

Parallel fan-out gates on dependency order: two tasks that touch the same
schema or shared module cannot be parallel.

---

# §6 — Conventions

## Structure

- Constructor takes a single options object with real defaults; fakes are
  injected in tests only.
- Top-level `createX()` factory functions are the composition root — wire
  collaborators there, not inside classes.
- Domain errors carry stable codes so callers branch on kind, not message:

```js
class ProviderError extends Error {
  constructor(message, { provider, retryable = false, cause } = {}) {
    super(message); this.name = 'ProviderError'
    this.provider = provider; this.retryable = retryable
    if (cause) this.cause = cause
  }
}
```

## Vanilla JS/Node (when the repo is JavaScript)

The platform replaces the usual packages:

| Instead of… | Use |
|-------------|-----|
| Express/Koa/Fastify | `node:http` + a small hand-rolled router |
| body-parser | `for await (const chunk of req)` + `JSON.parse`, size-limited |
| jest/mocha/vitest | `node:test` + `node:assert/strict` |
| sinon/testdouble | hand-built fakes (§4) |
| ioredis/bull | in-process bounded work queue |
| cron/node-schedule | `setInterval` + timestamp math |
| ajv/joi/zod | explicit validation in handlers |
| winston/pino | `console.error(JSON.stringify({...}))` |
| uuid, node-fetch, bcrypt, dayjs, dotenv | `crypto.randomUUID()`, `fetch`, `crypto.scryptSync`/`timingSafeEqual`, epoch math, `process.env` in entrypoints only |

Real ES private fields (`#field`), never `_field`; getters for read access.

## Never do these

No `undefined` in persisted defaults (breaks round-trip — use `?? null` /
`?? []`); no ambient authority, global singletons, or environment reads in
library code; no speculative abstractions (YAGNI); no barrel files or
re-export chains; no `async` on a function that never `await`s; no
`try/catch` around infallible internal code — validate at boundaries, trust
internals.

---

# §7 — Pre-implementation checklist

- [ ] Read the repo's docs for the subsystem; note repo-specific invariants.
- [ ] Grep every name the plan relies on — quote what you found.
- [ ] Identify the layer being changed and the template code to extend.
- [ ] Trace the write path.
- [ ] External side effect → plan the idempotency guard.
- [ ] Plan the test: what outcome proves correctness? Crash-recovery
      scenario needed?
- [ ] Confirm zero new dependencies.
