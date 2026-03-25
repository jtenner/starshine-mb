# Agent Tasks

## Scope
- Keep only unreleased work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Keep each slice actionable enough to implement directly without re-deriving the architecture.
- Move completed work to `CHANGELOG.md`.

## v0.1.0 Active Slice

## v0.2.0 Backlog

### IR2 - 320 - Documentation / ADR / Handoff Notes
- Goal:
  Leave the repository with canonical IR2 planning, ADRs, and backlog references so future agents can continue slice by slice.
- Why this slice exists:
  This migration is explicitly a planning and handoff task and needs stable in-repo execution notes.
- Concrete deliverables:
  - Main IR2 plan doc under `docs/`.
  - CFG contract ADR.
  - SSA policy ADR.
  - Updated `agent-todo.md` and `src/ir/README.md` as implementation lands.
- Detailed implementation tasks:
  - Save the canonical IR2 execution plan in `docs/` using the next serial.
  - Cross-link the main plan doc to CFG and SSA ADRs.
  - Keep `agent-todo.md` active-only and slice-id driven.
  - Add a short “next slice order” and “minimum validation per slice” section to the docs plan.
  - Keep `agent-lost-and-found.md` local-only and uncommitted.
- Required utilities / APIs:
  - `bun validate readme-api-sync`.
  - Docs serial naming convention helpers/process.
- Invariants / correctness rules:
  - The `docs/` plan becomes canonical handoff material.
  - `agent-todo.md` stays active-only backlog, not historical log.
  - Public docs do not overclaim optimizer behavior.
- Dependencies:
  - IR2 - 000 - Architecture Rules.
  - IR2 - 140 - CFG Contract and Block Boundary Rules.
  - IR2 - 230 - SSA Design Policy.
  - IR2 - 270 - Pipeline Orchestration.
  - IR2 - 310 - Dead Code / Old Abstraction Cleanup.
- Exit criteria:
  - Repo contains canonical IR2 handoff docs and active backlog references.
- Suggested tests:
  - `bun validate readme-api-sync`.
  - Docs naming-convention check.
  - Manual or scripted backlog-format check referencing active slice ids only.
