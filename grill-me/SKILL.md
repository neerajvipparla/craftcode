---
name: grill-me
description: Use when user wants to stress-test a plan or design, mentions "grill me", or asks to be interviewed about their approach. Triggers deep interrogation of every decision branch until shared understanding is reached.
---

# Grill Me

Interview the user relentlessly about every aspect of their plan until reaching shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

## Rules

- Ask **one question at a time** — never stack multiple questions
- For each question, provide your **recommended answer** before waiting for theirs
- If a question can be answered by **exploring the codebase**, do that instead of asking
- Follow decision dependencies: don't ask about X until Y (which X depends on) is resolved
- Keep going until every branch is resolved — don't stop early

## Question Priority

1. **Blockers first** — decisions that gate everything else
2. **Forks second** — choices that split the design tree
3. **Details last** — specifics that only matter once shape is decided

## Format

```
**[Topic]:** <question>

*My recommendation:* <your answer with brief rationale>
```

Wait for user response before proceeding to the next question.
