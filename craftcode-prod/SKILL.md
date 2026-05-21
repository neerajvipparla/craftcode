---
name: craftcode-prod
description: Use when starting any production feature from scratch. Mandatory read-all-docs-first pass, explicit KNOW/ASSUMED/GAP reasoning, evidence-anchored questions, context document, then phase doc. Entry point that leads into craftcode phases.
---

# CraftCode Prod

Production entry point. Grounds every decision in verified evidence before design begins. No questions until all readable docs are read. No code until context doc exists.

**REQUIRED: Read `craftcode` skill after this one — implementation phases 0-7 are there. This skill is the preamble.**

---

## Step 1: Read Everything First — No Questions Yet

Before speaking, read in this order:

1. `CLAUDE.md` — conventions, constraints, known anti-patterns
2. `docs/POC/POC.md` — shortcuts taken and what must change for prod
3. `docs/phases/` — any existing phase docs for adjacent features
4. `docs/context/` — any prior context docs for this feature area
5. `docs/handoff/HANDOFF.md` — prior session state if it exists
6. Grep `// MODULE:` in all packages this feature will touch — read those AI-docs
7. Read the actual source files for every interface this feature will use or extend

**Do not ask questions about anything you can read. Read it.**

If a file doesn't exist, note that explicitly. Do not assume its contents.

---

## Step 2: Ultrathink — Reason Before Asking

After reading everything, write an explicit reasoning pass. Do this as written notes (even brief ones), not silent assumptions.

Separate facts into three buckets:

```
KNOW (verified — cite source):
- Interface X has method Y(a B) C  →  file:line
- Package A does not import B  →  confirmed: go build ./... passes
- Pattern Z is used in module W  →  file:line

ASSUMED (not yet verified — must read file before using):
- [ASSUMED] Config is loaded at startup  →  TO VERIFY: read main.go
- [ASSUMED] Stream handler follows heartbeat pattern  →  TO VERIFY: read sync_protocols.go

GAPS (only user can answer — no file contains this):
- Whether this should be sync or async (no existing precedent found)
- Priority between constraint A and constraint B (design decision)
- Expected scale: n < 1000 or n > 1M (changes DS choice entirely)
```

**For every `[ASSUMED]` item: read the file before treating it as fact.**

Resolve all ASSUMED items. Only proceed to Step 3 when every item is either KNOW (cited) or a genuine GAP.

This step prevents hallucination. An AI that skips it will confabulate interface signatures, follow stale patterns, and add scope that was never discussed. The 5 minutes here saves hours of backtracking.

---

## Step 3: Targeted Questions (evidence-anchored, grill-me style)

Now ask questions. Only ask what is in your GAP list — nothing else.

**Rules:**
- One question at a time, blocker-first
- Anchor every question to what you read: "I found X in file Y. Given that, is Z intended or..."
- Give your recommendation before waiting
- Ask as many questions as needed until every GAP is resolved. Do not move to context doc with open unknowns.
- Never ask: "What do you want?" / "Tell me about the feature" / "What's the expected behavior?" — those are pre-read questions

**Format:**
```
**[Topic]:** <specific question>

*I checked:* <what you read that makes this question necessary>
*My recommendation:* <your answer + rationale>
*Trade-off:* <what you give up with the other option>
```

For data structure decisions specifically, also ask:
- Expected scale (n < 100 / thousands / millions)?
- Access pattern (key lookup / ordered traversal / membership test)?
- Concurrency requirements (reads only / concurrent writes)?

---

## Step 4: Context Document

Once all GAPs are resolved, write `docs/context/<feature-YYYY-MM-DD>.md` **before any code**.

Dispatch a **Haiku subagent** to write this file:

```
Write docs/context/<feature-YYYY-MM-DD>.md with these sections:

## Files Read
- `path` — what was relevant

## Verified Facts
- <fact> — source: `file:line`

## Data Structures Chosen
| Structure | Type | Access Pattern | Growth Bound | Owner |
|---|---|---|---|---|

## User Decisions
- Q: <verbatim question> → A: <verbatim answer>

## Constraints
- <constraint> — source: CLAUDE.md / user / file:line

## Interfaces This Feature Touches
| Interface | File | Methods Used |
|---|---|---|

## Scope Boundary
- IN: <what is included>
- OUT: <explicitly excluded — name it>

## Known Anti-Patterns (do not do)
- <pattern> — <why, source>

## Open Items
- <unresolved item with resolution path>

Write concisely. Every fact cited. Mark anything unverified as [UNVERIFIED: reason].
```

This doc is the anti-hallucination anchor. Any claim in implementation must trace back to this doc or a direct file read. If your memory and the context doc disagree, trust the doc and re-read the file.

---

## Step 5: Phase Doc → Implementation

Now follow **craftcode** phases in order:

- **Phase 0:** POC/Prod gate (already answered — prod)
- **Phase 1:** Design interrogation (already done — use context doc)
- **Phase 2:** Data structures + design patterns (finalize from context doc DS section)
- **Phase 3:** Implementation phase doc (`docs/phases/<feature>.md`)
- **Phase 4:** Module AI-docs
- **Phase 5:** Time complexity annotations
- **Phase 6:** Test placement in `tests/`
- **Phase 7:** Integration seal

Fire Haiku subagent after each phase to update phase doc and module docs. Do not wait for result before continuing.

---

## Anti-Hallucination Enforcement

| Rule | Enforcement |
|---|---|
| Every interface claim cites `file:line` | Cannot cite it → read the file first |
| No "I believe the pattern is..." | "I read in file X that..." or read the file |
| Scope creep = unverified assumption in code | Check context doc Scope Boundary before adding anything not in phase doc |
| Memory conflicts with context doc | Trust the doc. Re-read the file. Update the doc. |
| Adding a DS not in context doc DS table | Stop. Add it to context doc first. Justify it. |

---

## Red Flags — Stop and Verify

| Thought | Action |
|---|---|
| "I think the interface looks like..." | Read the file. |
| "We discussed this so..." | Check context doc. Not there → ask again. |
| "This is probably similar to X" | Read X. Then decide. |
| "I'll add this small helper while I'm here" | In phase doc? No → don't. |
| "The doc might be outdated" | Read current file. Update doc if needed. |
| "The scale is probably small" | It's in your GAP list. Ask. Scale determines DS. |
| "I'll pick the DS later" | DS choice is Step 3. Later = interface redesign. |
