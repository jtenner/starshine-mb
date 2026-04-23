# Writing Agent Briefs

An agent brief is the authoritative contract for work moved to `ready-for-agent`.

## Principles
- Prefer durable descriptions over file paths or line numbers.
- Describe behavior, interfaces, and acceptance criteria.
- State explicit out-of-scope boundaries.

## Template
```md
## Agent Brief

**Category:** bug / enhancement
**Summary:** one-line statement
**Current behavior:** what happens now
**Desired behavior:** what should happen
**Key interfaces:** types, functions, config shapes that matter
**Acceptance criteria:**
- [ ] Criterion 1
- [ ] Criterion 2
**Out of scope:**
- item 1
```
