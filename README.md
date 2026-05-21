# craftcode

A suite of Claude Code skills that enforce engineering discipline before, during, and after writing code — designed to counter the specific failure modes of AI-assisted ("vibe") coding.

---

## The Problem: Why Vibe Coding Breaks Down

AI coding tools are fast. They're also predictably bad at a specific set of things:

| Vibe coding failure | What actually happens |
|---|---|
| **Hallucination** | AI confabulates interface signatures, follows stale patterns, adds scope that was never discussed |
| **No design pass** | Jumps straight to code, picks the first familiar pattern, ignores access patterns and data structure fit |
| **Wrong data structures** | Slices where maps are needed, maps where ordered traversal is needed — no justification, discovered in production |
| **Scope creep** | "While I'm here" additions that break interfaces and introduce new bugs |
| **Cyclic dependencies** | Circular imports accumulate silently until the build breaks |
| **Closed to extension** | Every new feature requires modifying existing code instead of extending through designed points |
| **No module memory** | Every new AI session re-learns the codebase from scratch, re-makes the same decisions |
| **POC becomes prod** | Prototype shortcuts live forever because no one wrote down what must change |
| **Tests scattered everywhere** | `_test.go` files alongside source, no structure, hard to run module-level suites |
| **Hidden complexity** | No time complexity annotations, O(n²) disguised as simple loops |

These aren't model failures — they're process failures. The AI does exactly what the process allows. These skills change the process.

---

## Skills

### `/craftcode` — Implementation Discipline

**Use for:** Any non-trivial code change, new module, or feature implementation.

The core ruleset. Eight phases that enforce design before code, documentation before sealing, and tests in the right place.

**What it solves:**

**Phase 0 — POC or Prod gate**
Forces an explicit choice before any code is written. If POC, a `docs/POC/POC.md` entry is created with the shortcuts taken and what *must* change for production — so the debt is named, not accumulated silently.

**Phase 1 — Design Interrogation (grill-me style)**
One question at a time. AI gives its recommendation, then waits. Never stacks questions. Interrogates blockers, boundaries, data structures, pattern fit, extension points, and failure modes — in that order. Doesn't close until every dependency and interface contract is explicit.

**Phase 2 — Data Structures + SOLID Gates**
Data structure choice is resolved *before* pattern selection, because the DS shapes every interface that passes it — swapping it later means redesigning the interfaces.

Then four hard stops before any pattern is selected:
- **S:** Name the ONE invariant this module owns. Two invariants → split.
- **O:** Name the extension mechanism explicitly. "Add another switch case" is not an answer — redesign.
- **I:** Every interface is the minimum surface callers need. Fat interfaces → split.
- **D:** Every cross-package dependency targets an interface. No concrete imports across boundaries.

These gates are written into the phase doc before pattern selection. Not guidelines — stops.

**Phase 3 — Implementation Phase Doc**
Written *before* touching code. Each phase has: what gets built, which data structures are introduced, what it depends on, and a concrete done condition. If a mid-phase discovery forces a change to an earlier phase, a backtrack entry is inserted and resolved before continuing. The phase doc is the source of truth for where you are.

**Phase 4 — Module AI-Doc**
Every non-trivial module gets a header block written for the *next AI editor*, not humans. It contains:
- `PURPOSE` — the one invariant this module owns
- `CORE DATA STRUCTURES` — what each holds, access pattern, growth bound
- `TO MODIFY BEHAVIOR` — exactly which function to edit for each type of change
- `DO NOT` — what creates cycles, breaks invariants, or destroys a load-bearing design choice
- `EXTENSION POINT` — how new variants are added without touching this file
- `CHANGE SCENARIOS` — concrete: "to add X, implement Interface Y, register in location Z — this file unchanged"

This is the fix for the "AI re-learns everything from scratch" problem. The next session reads this block and knows exactly what can be changed and how.

**Phase 5 — Time Complexity Annotation**
Every exported function with non-trivial complexity gets an annotation naming the data structure driving the cost. `O(n log n) where n = accounts; DS: binary search over sorted []Account slice`. Not optional — complexity without the DS name is half the information.

**Phase 6 — Test Placement**
Zero test files outside `tests/<module-name>/`. No `_test.go` alongside source. The phase seal includes a `find` command that must return empty before closing.

**Phase 7 — Integration Seal**
A checklist that cannot be skipped:
- Zero import cycles
- All cross-package deps are interfaces
- SOLID-S, O, I, D verified against module AI-docs
- Every unbounded data structure has an eviction path
- Every exported non-trivial function has complexity annotation
- Phase doc current, backtracks documented
- No scope creep

---

### `/craftcode-prod` — Production Entry Point

**Use for:** Starting any production feature from scratch.

The anti-hallucination preamble that runs before `craftcode` phases. The core rule: **no questions until all readable documentation is read. No code until a context document exists.**

**What it solves:**

**Step 1 — Read everything first**
In order: CLAUDE.md, POC.md, existing phase docs, prior context docs, handoff docs, module AI-doc blocks, source files for every interface this feature will touch. If it can be read, it must be read before asking.

**Step 2 — KNOW / ASSUMED / GAP**
After reading, explicit written reasoning:
- `KNOW` — verified facts, each cited to a file and line
- `ASSUMED` — things not yet verified, each with a TO VERIFY action (must be resolved before using)
- `GAPS` — only things *only the user can answer* — no file contains this

Every ASSUMED item gets resolved by reading the file before it's treated as fact. This is the step that prevents the AI from confabulating interface signatures or following patterns that were refactored away three months ago.

**Step 3 — Targeted, evidence-anchored questions**
Only asks about things in the GAP list. Every question cites what was read that makes it necessary. Gives a recommendation before waiting. Asks as many questions as needed — doesn't close until every GAP is resolved.

**Step 4 — Context document**
`docs/context/<feature-YYYY-MM-DD>.md` written before any code. Contains: files read, verified facts with citations, data structures chosen, user decisions verbatim, constraints, interfaces touched, scope boundary (IN and OUT explicitly named), known anti-patterns, open items. This is the anti-hallucination anchor — any claim in implementation must trace back to it.

**Step 5 → craftcode phases**
Hands off to `craftcode` Phase 0–7 with full context established.

---

### `/grill-me` — Plan Stress-Testing

**Use for:** Stress-testing a plan or design before committing to it.

Interrogates every decision branch relentlessly. One question at a time. Gives a recommendation before waiting. Follows decision dependencies — doesn't ask about X until Y (which X depends on) is resolved. Doesn't stop until every branch is resolved.

**What it solves:** Plans that sound coherent but haven't been pressure-tested. Forces explicit answers to the questions that will come up anyway — better before the code than during it.

---

### `/handoff` — Session Continuity

**Use for:** Handing off an in-progress session to a fresh agent, or before a long break.

Writes a `docs/handoff/HANDOFF.md` with: what's being built, current phase, what's complete, what's in progress (exact function/file), what's not started, open decisions and blockers, deviations from the phase doc, and files modified.

**What it solves:** Context loss between sessions. A fresh agent that reads the handoff doc can continue without asking questions that were already resolved.

---

## How They Work Together

```
New production feature
        │
        ▼
/craftcode-prod
  Step 1: Read all docs
  Step 2: KNOW / ASSUMED / GAP
  Step 3: Evidence-anchored questions (until all GAPs resolved)
  Step 4: Write context doc
        │
        ▼
/craftcode
  Phase 0: POC or Prod?
  Phase 1: Design interrogation (grill-me style, one question at a time)
  Phase 2: Data structures → SOLID gates → pattern selection
  Phase 3: Phase doc written before code
  Phase 4: Module AI-docs (change scenarios, extension points)
  Phase 5: Time complexity annotations
  Phase 6: Tests in tests/<module>/ only
  Phase 7: Integration seal (SOLID + cyclic + scope checks)
        │
        ▼
      Ship
```

For POC work or when context is already established, invoke `/craftcode` directly.

For stress-testing a plan before or during design, invoke `/grill-me`.

Before the conversation compacts or a session ends mid-feature, invoke `/handoff`.

---

## Installation

```bash
cd craftcode
./install.sh
```

Restart Claude Code. Skills are available as `/craftcode`, `/craftcode-prod`, `/grill-me`, `/handoff`.

To update after pulling:

```bash
./install.sh
```

---

## Credit

`grill-me` and `handoff` are taken from [Matt Pocock's skills repository](https://github.com/mattpocock/skills). All credit for those two skills goes to [Matt Pocock](https://github.com/mattpocock).

`craftcode` and `craftcode-prod` were built on top of that foundation with additional phases for SOLID enforcement, data-structure-first design, module AI-docs, time complexity annotation, and the anti-hallucination context doc protocol.
