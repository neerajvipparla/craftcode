---
name: craftcode
description: Use when writing new modules, features, or non-trivial code changes. Triggers design pattern enforcement, POC vs prod decision, phase doc, module AI-docs, time complexity annotation, cyclic dependency checks, and proper test placement.
---

# CraftCode

Interrogate design decisions, enforce patterns, document for future AI editors, and produce code that is closed to scope creep but open to explicit extension.

**For full production entry (read all docs first, ultrathink, context doc): use `craftcode-prod` as the entry point — it calls back into these phases.**

---

## Phase 0: POC or Prod?

**Ask this first. One question. Nothing else until answered.**

```
**[Mode]:** Is this POC or production code?

*My recommendation:* [prototype if exploring unknown territory; prod if interface/domain is stable]
```

### If POC
Create `docs/POC/POC.md` (append if exists):
```markdown
## <Feature Name> — <date>

### Decisions taken for POC
- <decision> → <why acceptable for POC>

### What MUST change for prod
| POC shortcut | Prod requirement | Why |
|---|---|---|

### Recommendations when productionizing
- ...
```
Relaxed: skips time-complexity annotation, allows single-file modules.
Still enforces: no cyclic deps, tests in `tests/`, phase doc required.

### If Prod
All phases below apply in full.

---

## Phase 1: Design Interrogation (grill-me style)

One question at a time. Give your recommended answer. **Wait for the response before the next question — never stack two questions.**

```
**[Topic]:** <question>

*My recommendation:* <answer + rationale>
```

Priority order:
1. **Blockers** — what does this module depend on? What depends on it?
2. **Boundaries** — exact input/output contract of each unit?
3. **Data structures** — what are the core structures? (see DS questions below)
4. **Pattern fit** — which design pattern maps cleanly here?
5. **Extension points** — what will change in 6 months?
6. **Failure modes** — what happens when X fails?

Keep interrogating until: every public interface has a defined contract, every core data structure is chosen and justified, no "figure it out later" dependencies, extension path is explicit, SOLID responsibility is named per module.

### Data Structure Questions (resolve before designing anything else)

Data structure choice is a first-class design decision — it propagates into every interface that passes the data. Wrong choice at this stage is expensive to undo.

Ask all of these before picking a structure:

| Question | Why it matters |
|---|---|
| What is the access pattern? (random key, sequential, ordered range) | Determines map vs slice vs tree |
| What is the mutation pattern? (append-only, in-place update, concurrent writes) | Determines whether locking or copy-on-write is needed |
| What is the expected size? (< 100, thousands, millions, unbounded) | Determines whether O(n) lookup is acceptable |
| Is ordering required? If so, by what key? | Sorted slice vs heap vs ordered map |
| Is membership testing the primary operation? | Set (map[T]struct{}) vs slice |
| Does data need to survive across calls / be passed across package boundaries? | Owned struct vs pointer vs interface |
| Is there a natural maximum size? If unbounded, what is the eviction policy? | LRU, ring buffer, bounded channel |
| Will this structure be read concurrently? Written concurrently? | Lock strategy, RWMutex vs channel vs atomic |

**Recommendation format for DS questions:**
```
**[Data Structure]:** <question about the structure>

*Access pattern I see:* <what you inferred from requirements>
*My recommendation:* <structure name> — because <why it fits the access pattern>
*Trade-off:* <what you give up with this choice>
```

---

## Phase 2: Data Structures + Design Patterns

### Data Structure Selection

Finalize every core data structure before selecting a design pattern. The DS choice shapes the pattern — not the reverse.

| Access pattern | Right structure | Avoid |
|---|---|---|
| Key lookup, unordered | `map[K]V` | Slice linear scan |
| Key lookup, ordered traversal | Sorted slice + binary search, or B-tree | Plain map (no order guarantee) |
| Membership test only | `map[K]struct{}` | `map[K]bool` (wastes space) |
| Queue / FIFO | Ring buffer, buffered channel | Slice with `append`+`[1:]` (GC pressure) |
| Priority / min-max | Heap (`container/heap`) | Sorted insert into slice O(n) |
| Prefix/range scan | Trie, ART, radix tree | Map (no prefix semantics) |
| Append-only log | Slice + WAL on disk | Map (random access semantics wrong) |
| Small fixed set (< 20 items) | Slice linear scan | Map (overhead not worth it) |
| Concurrent read-heavy | `sync.RWMutex` + map, or `sync.Map` | Mutex + map (write bottleneck) |
| Bounded cache with eviction | LRU (doubly-linked list + map) | Unbounded map |

**Document each chosen structure in the phase doc.** "We'll use a slice" is not documentation. "Slice of `Account` ordered by nonce, binary-searched — O(log n) lookup, sequential iteration, append-only during sync" is.

### SOLID Enforcement Gates

Resolve in order before selecting a design pattern. Each is a **hard stop** — do not proceed until the answer is written in the phase doc.

**S — Single Responsibility**
State the ONE invariant this module owns in one sentence.
If you name two invariants, split the module. "It handles auth and logging" → two modules.

**O — Open/Closed**
Name the extension mechanism explicitly.
How does this module accept new behavior **without modifying existing code**?
If the answer is "add another case to the switch/if", stop — redesign.
New behavior must flow through an interface, plugin slot, or registered handler.

**I — Interface Segregation**
Is every interface the minimum surface callers need?
If a caller uses 3 of 7 methods, split. Fat interfaces create false coupling.

**D — Dependency Inversion**
List every external concrete type this module imports.
Each one must be replaced with an interface abstraction before proceeding.
No concrete cross-package imports. Ever.

Document each gate answer in the phase doc under a `## SOLID Gates` heading before selecting a pattern.

---

### Design Pattern Selection

Pick the pattern that fits the boundary, not the one that's familiar.

| Situation | Pattern |
|---|---|
| Multiple implementations of one interface | Strategy / Interface injection |
| Object creation is complex or conditional | Factory / Builder |
| One-to-many event propagation | Observer / Pub-Sub |
| Wrap existing interface without changing it | Decorator / Proxy |
| Step sequence with shared state | Template Method |
| Independent subsystems must not know each other | Mediator / Event bus |
| Tree of composable operations | Composite |
| Accumulate result by traversing a structure | Visitor |

**Hard rules:**
- No concrete type imported across package boundaries — depend on interfaces
- No global mutable state
- No init-time side effects
- Cyclic dependency = block. Extract shared concept to a third package neither side owns.

### Cyclic Dependency Check
```
A imports B? Does B (or anything B imports) import A?
```
If yes → stop, refactor boundary, then proceed.

---

## Phase 3: Implementation Phase Doc

**Write this before touching any code.** Save to `docs/phases/<feature-name>.md`.

```markdown
# <Feature Name> — Implementation Phases

## Phase 1: <name>
- What: <what gets built>
- Data structures: <structures introduced or mutated in this phase, with access pattern>
- Inputs: <what it depends on being done first>
- Done when: <concrete completion condition>

## Phase 2: <name>
- What: ...
- Data structures: <same field — never leave blank>
- Inputs: Phase 1 complete
- Done when: ...

## Phase N: ...
```

### Backtrack notation

If during implementation of Phase N you discover Phase M must change, **do not silently patch it**. Insert this entry in the phase doc immediately after Phase N, before Phase N+1:

```markdown
## Phase N → Phase M.1 (backtrack)
- Trigger: <what you discovered in Phase N that requires this>
- Changes to Phase M: <what specifically changes>
- Impact on already-completed work: <what needs to be revisited>
```

Then implement Phase M.1 before continuing to Phase N+1.

**The phase doc is the source of truth for where you are.** Update it as each phase completes.

---

## Phase 4: Module AI-Doc

Every non-trivial module gets a header block. **Written for the next AI editor, not humans.**

```go
// MODULE: <package/file name>
// PURPOSE: <one sentence — what invariant this module owns>
//
// CORE DATA STRUCTURES:
//   - <StructName>: <what it holds, access pattern, who owns it>
//   - <StructName>: <growth bound — fixed / bounded(N) / unbounded+eviction>
//
// TO MODIFY BEHAVIOR:
//   - Change <X>: edit <function/struct> — impact: <what else changes>
//   - Add new <Y>: implement <interface>, register in <location>
//   - Remove <Z>: delete <symbol>, update <dependents>
//
// DO NOT:
//   - Import <package> from here (creates cycle via <path>)
//   - Store request-scoped state on the struct (stateless by design)
//   - Replace <structure> with <alternative> — <why the current choice is load-bearing>
//
// EXTENSION POINT: <how new variants/cases are added without touching this file>
//
// CHANGE SCENARIOS:
//   Add <new-variant>: implement <Interface> → register in <location> — this file unchanged
//   Change <behavior>: edit <func> in <file> — impacts: <what else changes>
//   Remove <feature>: delete <symbol> → update callers: <list them explicitly>
```

Same fields in other languages (docstring, block comment).

---

## Phase 5: Time Complexity Annotation (prod only)

Every exported function with non-trivial complexity:

```go
// Time: O(n log n) where n = number of accounts; Space: O(n)
// DS: binary search over sorted []Account slice
func DiffAccounts(local, remote *ART) []Account { ... }

// Time: O(1) amortized; worst-case O(n) on map rehash
// DS: map[nonce]Account — rehash triggers at load factor 6.5
func (c *Cache) Put(nonce uint64, a Account) { ... }
```

Non-trivial = anything beyond O(1) field access or O(n) single-pass.
- Name what `n` refers to
- Add `amortized` qualifier if applicable
- Note worst-case if it differs from average
- **Always name the data structure driving the complexity** — the structure is the reason for the cost

---

## Phase 6: Test Placement

```
tests/
  <module-name>/          ← mirrors source package name
    <feature>_test.go     ← one file per logical concern
```

Rules:
- Zero test files outside `tests/` tree
- No `_test.go` files alongside source files
- Each subfolder tests one package/module boundary
- Table-driven tests preferred; name rows descriptively

---

## Phase 7: Integration Seal

| Check | Pass condition |
|---|---|
| Cyclic deps | `go build ./...` — zero import cycles |
| Interface boundaries | Every cross-package dep is an interface |
| SOLID-S | Every module AI-doc names exactly one invariant — two named → must split before sealing |
| SOLID-O | New behavior is addable via named extension point without modifying sealed code |
| SOLID-I | No interface has methods unused by any single caller |
| SOLID-D | Zero concrete cross-package imports — confirmed by module AI-doc DO NOT section |
| Data structures documented | Every core DS named in module AI-doc with access pattern + growth bound |
| DS matches access pattern | No map where ordered traversal needed; no slice where O(1) lookup needed at scale |
| Unbounded structures | Every unbounded structure has an explicit eviction/cleanup path documented |
| Module AI-doc present | Every new/modified package has the block |
| Time complexity annotated | All exported non-trivial functions, with DS named in annotation (prod) |
| Tests in correct location | `find . -name "*_test.go" -not -path "*/tests/*"` → empty |
| Phase doc current | All completed phases marked done, backtracks documented |
| POC.md updated | If mode=POC, file exists and is current |
| No scope creep | No helpers/utils/"while I'm here" additions |

---

## Execution Discipline

**Implement one phase at a time. Do not start Phase N+1 until Phase N is complete.**

If you must skip ahead (genuinely blocked, not impatient):
- Write a `## BLOCKED: Phase N` entry in the phase doc with the exact blocker
- Note which phase you are jumping to and why
- Return to the skipped phase before marking the feature done

Skipping silently = lost context = broken invariants. The phase doc prevents this.

---

## Living Documentation — Haiku Subagent

Docs must stay current without burning main-model tokens. Use a **Haiku subagent** for all doc writes after each phase completes.

### Trigger points

| Event | Subagent task |
|---|---|
| Phase N implementation complete | Update phase doc: mark phase done, note any deviations |
| New/modified module | Update or write module AI-doc block |
| POC decision made | Append entry to `docs/POC/POC.md` |
| Backtrack discovered | Insert backtrack entry in phase doc |
| Context approaching compaction | Write handoff doc (see below) |

### Subagent prompt template

```
You are a documentation subagent. Update <file> with the following information.
Do not change any existing content except the specific section described.
Write concisely. No filler. Return only the updated file content.

File: <path>
Section to update: <phase N / module name / POC entry>
Information: <what happened, decisions made, completion state>
```

Dispatch with `model: haiku`. Do not wait for the result before continuing implementation — fire and continue.

### Handoff doc before compaction

When context is approaching its limit (conversation growing long, compaction likely), **before continuing any implementation**, dispatch a Haiku subagent to write `docs/handoff/HANDOFF.md`:

```
You are a handoff documentation subagent. Write a handoff document so a fresh AI agent
can pick up this work with full context. Include:

1. Feature being implemented
2. Current phase (from phase doc at docs/phases/<name>.md)
3. What is complete
4. What is in progress (exact function/file being worked on)
5. What is not yet started
6. Any open decisions or blockers
7. Any deviations from the original phase doc
8. Files modified so far

Be specific. No summaries. A fresh agent must be able to continue without asking questions.
Write to docs/handoff/HANDOFF.md.
```

Do not compact until this doc is written.

---

## Red Flags — Stop and Interrogate

| Thought | Reality |
|---|---|
| "I'll add a utils package for this" | Utils = no owner = cyclic magnet. Name the concept. |
| "We can generalize later" | YAGNI. Scope to now. |
| "Tests next to source for convenience" | `tests/` only. No exceptions. |
| "Complexity is obvious from the name" | Annotate anyway. "Obvious" rotates with the reader. |
| "POC so design doesn't matter" | Shortcut list still goes in POC.md. Name the debt. |
| "I'll update the doc after this batch" | Update after each phase. Batched docs are always stale. |
| "Phase doc is overhead for a small feature" | Small features grow. Phase doc costs 2 minutes. Confusion costs hours. |
| "I'll just finish phase N+1 quickly first" | No. Phase N must be complete and documented before N+1 starts. |
| "I'll use a map for this" | Justify it. Map is O(1) lookup but unordered, heap-allocated, GC pressure at scale. |
| "A slice is fine" | Check access pattern first. O(n) scan is fine at n < 50. At n = 100k it's a bug. |
| "We can swap the data structure later" | Interfaces are designed around DS semantics. Swapping later = interface redesign. |
| "I'll just add a generic cache" | Own the eviction policy, size bound, and key type explicitly or don't add it. |
| "I'll just add another case here" | OCP violation. Add an extension point — do not modify sealed logic. |
| "This module handles two related things" | SRP violation. One invariant per module. Name it. Split the rest. |
| "The interface just needs one more method" | ISP violation. Can callers avoid that method? Split the interface. |
| "I need the concrete type just this once" | DIP violation. Define an interface. Import that instead. |
| "We can always refactor the extension model later" | OCP is hardest to retrofit. Name the extension point now or pay the rewrite tax later. |
