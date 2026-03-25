# Agent Tasks

## Scope
- Keep only unreleased work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Keep each slice actionable enough to implement directly without re-deriving the architecture.
- Move completed work to `CHANGELOG.md`.

## v0.1.0 Active Slice

## v0.2.0 Backlog

### IR2 - 350 - Hot Local Simplification
- Goal:
  Port the first real `simplify-locals` rewrite into the hot pipeline.
- Why this slice exists:
  Local SSA and liveness overlays exist, but the pipeline still lacks a pass that uses them to remove dead local traffic.
- Concrete deliverables:
  - Real `simplify-locals` pass implementation.
  - Dead local-def cleanup using SSA/use-def/liveness overlays.
  - Registry move from `removed` to active hot pass and preset update if appropriate.
- Detailed implementation tasks:
  - Add failing tests first for dead `local.set` / `local.tee` cleanup.
  - Build required overlays through the pass context.
  - Rewrite dead local defs via the shared SSA destruction helpers.
  - Update presets/docs once the batch-1 sequence is active.
- Required utilities / APIs:
  - `pass_require_ssa`.
  - `ssa_remove_dead_local_defs`.
  - `ssa_uses_of_value`, `ssa_value_origin`.
- Invariants / correctness rules:
  - Preserve operand evaluation when removing dead local defs.
  - Leave live local defs untouched.
  - Keep post-pass hot verification green.
- Dependencies:
  - IR2 - 210 - Liveness.
  - IR2 - 240 - Local SSA Construction.
  - IR2 - 250 - SSA Destruction.
- Exit criteria:
  - `simplify-locals` is a real active hot pass with tests, docs, and preset integration.
- Suggested tests:
  - `moon test src/passes`.
  - `bun validate readme-api-sync`.
