# 0076 - Simplify Locals Binaryen Research Plan

Archived under `docs/wiki/raw/research/` during the 2026-04-10 wiki migration.
The original worktree used `0073`, but that serial is already occupied in the
shared archive by the `reorder-locals` research note. Living summaries for this
topic now live in:

- [`../../binaryen/passes/simplify-locals/index.md`](../../binaryen/passes/simplify-locals/index.md)
- [`../../binaryen/passes/simplify-locals/binaryen-strategy.md`](../../binaryen/passes/simplify-locals/binaryen-strategy.md)
- [`../../binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md`](../../binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md)

## Scope

- Research Binaryen's current `simplify-locals` family from source, not just from optimizer output diffs.
- Compare that behavior against the current Starshine hot pass and hot IR constraints.
- Record a concrete implementation order for this worktree before code changes start.

## Existing Starshine Context

- `HotFunc` is the only owned optimizer body representation. Future work must stay within the `lift -> verify -> analyze -> mutate -> verify -> lower` contract from [`0059-2026-03-24-ir2-architecture-rules.md`](0059-2026-03-24-ir2-architecture-rules.md), [`0061-2026-03-24-local-ssa-policy.md`](0061-2026-03-24-local-ssa-policy.md), and [`../../../../docs/0065-2026-03-24-ir2-execution-plan.md`](../../../../docs/0065-2026-03-24-ir2-execution-plan.md).
- The current pass in [`../../../../src/passes/simplify_locals.mbt`](../../../../src/passes/simplify_locals.mbt) is intentionally narrow:
  - it looks up SSA defs for `LocalSet` / `LocalTee`
  - removes defs with zero SSA uses
  - cleans up detached tee children if they become unreferenced
- That means the current pass is a dead-def cleanup pass, not a Binaryen-style local-sinking pass.
- Relevant hot-IR surfaces for the real port already exist:
  - locals metadata in [`../../../../src/ir/hot_core.mbt`](../../../../src/ir/hot_core.mbt)
  - local builders in [`../../../../src/ir/hot_builders.mbt`](../../../../src/ir/hot_builders.mbt)
  - structured region edits in [`../../../../src/ir/hot_region_edit.mbt`](../../../../src/ir/hot_region_edit.mbt)
  - control result retagging in [`../../../../src/ir/hot_mutate.mbt`](../../../../src/ir/hot_mutate.mbt)
  - pass mutation helpers in [`../../../../src/passes/pass_common.mbt`](../../../../src/passes/pass_common.mbt)
- The active backlog already expects a source-backed audit for `SL` in [`../../../../agent-todo.md`](../../../../agent-todo.md).

## Primary Sources

Research below is pinned to Binaryen commit `88a07e028cfb4aa68e7a94743646a0867b31c15b` as of 2026-04-01.

- `SimplifyLocals.cpp`
  - overview and option surface:
    `https://github.com/WebAssembly/binaryen/blob/88a07e028cfb4aa68e7a94743646a0867b31c15b/src/passes/SimplifyLocals.cpp#L17-L46`
  - main sink / invalidation logic:
    `https://github.com/WebAssembly/binaryen/blob/88a07e028cfb4aa68e7a94743646a0867b31c15b/src/passes/SimplifyLocals.cpp#L128-L463`
  - structure rewrites:
    `https://github.com/WebAssembly/binaryen/blob/88a07e028cfb4aa68e7a94743646a0867b31c15b/src/passes/SimplifyLocals.cpp#L470-L838`
  - fixed-point driver and late optimizations:
    `https://github.com/WebAssembly/binaryen/blob/88a07e028cfb4aa68e7a94743646a0867b31c15b/src/passes/SimplifyLocals.cpp#L878-L1167`
- `local-utils.h`
  - `LocalGetCounter` and `UnneededSetRemover`:
    `https://github.com/WebAssembly/binaryen/blob/88a07e028cfb4aa68e7a94743646a0867b31c15b/src/ir/local-utils.h#L26-L117`
- `effects.h`
  - `orderedBefore` / `orderedAfter` / `invalidates`:
    `https://github.com/WebAssembly/binaryen/blob/88a07e028cfb4aa68e7a94743646a0867b31c15b/src/ir/effects.h#L334-L445`
- `pass.cpp`
  - registered variants:
    `https://github.com/WebAssembly/binaryen/blob/88a07e028cfb4aa68e7a94743646a0867b31c15b/src/passes/pass.cpp#L488-L504`
  - default no-DWARF function pipeline placement:
    `https://github.com/WebAssembly/binaryen/blob/88a07e028cfb4aa68e7a94743646a0867b31c15b/src/passes/pass.cpp#L638-L724`

## What Binaryen Actually Does

Binaryen's `simplify-locals` is not one peephole. It is an iterative locals optimizer with several distinct stages.

### 1. Main Sinking Fixpoint

- Binaryen walks each function in linear-execution order and tracks at most one sinkable `local.set` per local per active linear trace.
- The first iteration is intentionally stricter:
  - it only sinks single-use locals
  - it does not create tees on that first cycle
- Later iterations allow multi-use sinking when tees are enabled.
- When Binaryen reaches a matching `local.get`:
  - single-use: replace the `local.get` with the set's value and nop the origin set
  - multi-use: replace the `local.get` with the set itself, convert that set to a tee, and nop the origin
- If a sunk tee is wrapped in `drop`, Binaryen immediately folds `drop(tee(...))` back to `set(...)`.
- If a later set overwrites an earlier still-pending set for the same local before any read, Binaryen turns the earlier set into `drop(value)` and keeps only the later candidate.

### 2. Effect- and Control-Safety Gating

- Binaryen does not sink across arbitrary side effects.
- It invalidates pending sinkables with `EffectAnalyzer::orderedAfter` / `orderedBefore`, which blocks unsafe motion across:
  - control-flow transfers
  - memory/table/shared-state conflicts
  - local and mutable-global read/write conflicts
  - synchronization fences
  - trap-vs-global-state changes
- It also has targeted extra barriers:
  - do not move dangling `pop` values
  - when entering `try` / `try_table`, forget sinkables whose values may throw
  - when control flow becomes nonlinear, clear or split sinkable state instead of pretending the traces still match

### 3. Structure Rewrites

- When structure is enabled, Binaryen also coalesces matching local writes into structured return values:
  - loop return lifting
  - block return lifting across fallthrough plus all breaks
  - `if` / `if-else` return lifting
- These rewrites are guarded, not unconditional:
  - block lifting refuses blocks already carrying values
  - `br_if` lifting checks for the "value moved out of condition" hazard
  - one-armed `if` speculation only runs for defaultable local types because synthesizing a new `local.get` in the else arm is unsafe for non-defaultable locals
  - unreachable-arm `if-else` cases are treated specially and may still lift from the reachable arm
- Binaryen sometimes grows blocks, if arms, or loop bodies with a trailing `nop` and retries next cycle because its AST walker stores `Expression**` pointers that would otherwise be invalidated mid-turn.

### 4. Late Equivalent-Copy Cleanup

- After the main fixpoint stabilizes, Binaryen runs a second local pass that tracks equivalent locals on linear traces.
- That late phase does two things:
  - canonicalizes `local.get`s toward an equivalent local with either a more refined type or more uses
  - removes redundant equivalent copies when structure mode is enabled
- Important nuance:
  - `simplify-locals-nostructure` still canonicalizes gets
  - but it does not remove equivalent sets in the same way the full structure-enabled pass does

### 5. Final Dead-Set Cleanup

- Binaryen then runs `UnneededSetRemover`.
- That helper removes:
  - sets whose local has zero possible gets
  - sets or tees that just write back the same local value, including tee chains
- Side effects are preserved:
  - dead side-effect-free `local.set` becomes `nop`
  - dead side-effecting `local.set` becomes `drop(value)`
  - dead `local.tee` becomes the raw value expression
- This phase is not SSA-based, so it also cleans dead sets in code the current Starshine SSA overlay skips.

## Binaryen Variants And Pipeline Placement

- Binaryen exposes five variants:
  - `simplify-locals`
  - `simplify-locals-nonesting`
  - `simplify-locals-notee`
  - `simplify-locals-nostructure`
  - `simplify-locals-notee-nostructure`
- On the default no-DWARF optimize path:
  - `simplify-locals-notee-nostructure` runs after `flatten` at `-O4`
  - `simplify-locals-nostructure` runs before `vacuum` and `reorder-locals`
  - full `simplify-locals` runs later, after `local-cse`, before `vacuum`, `reorder-locals`, and another `coalesce-locals`
- That ordering matters because the full late pass intentionally finishes cleanup that the earlier no-structure pass left behind.

## Gap Versus Starshine Today

The current Starshine pass does not yet cover most of Binaryen's actual behavior.

- Present today:
  - zero-use reachable `local.set` and `local.tee` cleanup through SSA
  - detached tee-child preservation when that child is still referenced elsewhere
- Missing today:
  - live sinking into later gets
  - multi-use tee creation
  - overwrite elimination on linear traces
  - `drop(tee)` collapse
  - structure lifting for blocks, ifs, and loops
  - equivalent-local canonicalization
  - non-SSA final dead-set cleanup
  - effect-order invalidation comparable to Binaryen's `orderedBefore`
- Current explicit test behavior that is a Binaryen mismatch:
  - Starshine currently keeps dead unreachable local defs when SSA does not model them.

## Implementation Plan For This Worktree

I do not want a line-for-line AST port. I do want a phase-for-phase port.

### Slice 1. Replace The SSA-Only Core With A Binaryen-Shaped Engine

- Keep the public pass name as `simplify-locals`.
- Rebuild the pass around an internal state machine that mirrors Binaryen's phases:
  - pending sinkables by local id
  - split or merge state for `if` arms
  - per-block exit tracking for block-return lifting
  - fixed-point outer loop with a stricter first cycle
- Do not add a new owned IR. Operate only on `HotFunc`.
- Use hot-IR addressing, not `Expression**`:
  - node ids for in-place node replacement
  - `HotRegionRef` plus region indices for structured body edits

### Slice 2. Land The No-Structure Core First

- First implement the Binaryen behavior that does not create new result-typed control:
  - get counting
  - single-use sinking
  - multi-use tee sinking
  - overwrite elimination
  - `drop(tee)` collapse
  - final dead-set cleanup outside SSA
- This should remove the biggest current parity gap without mixing in control retagging risk.
- It also matches the worktree focus better than jumping straight to block, `if`, or loop return creation.

### Slice 3. Add A Pass-Local Effect Ordering Helper

- Starshine's existing hot effects overlay is useful but not sufficient by itself for Binaryen parity because Binaryen uses directional `orderedBefore` / `orderedAfter`, not just "node has side effects".
- Implement a pass-local summary for candidate values and intervening expressions that can answer the Binaryen-relevant questions conservatively:
  - local read or write conflicts
  - mutable global conflicts
  - memory, table, heap, or shared-state conflicts
  - throws, control transfer, trap, synchronization, or dangling-pop barriers
- Reuse hot-IR queries and exact-op metadata where available, but keep the policy local to this pass first.

### Slice 4. Add Late Equivalent-Copy Cleanup

- Port Binaryen's late `EquivalentOptimizer` as a separate internal phase after the main sinking loop stabilizes.
- Preserve Binaryen's ranking rule:
  - prefer more refined local type
  - otherwise prefer the equivalent local with more total gets
- Keep refinalization hooks when replacing a get with a more refined type.
- Integrate final dead-set cleanup immediately after this phase.

### Slice 5. Add Structure Rewrites After No-Structure Parity Is Isolated

- Once the non-structural core is green, add:
  - block return lifting
  - `if-else` return lifting
  - one-armed `if` speculative lifting with the defaultable-local guard
  - loop return lifting
- Use existing hot-IR tools for this:
  - `hot_region_*` body edits
  - `hot_control_result_type_set(...)`
  - `hot_replace_child_spans_and_control_result_type(...)`
  - pass wrappers such as `pass_splice_region(...)` and `pass_replace_node(...)`
- Prefer direct region surgery over Binaryen's trailing-`nop` growth hack when the hot-IR APIs make that unnecessary.
- If hot-IR mutation safety still needs staging in some cases, stage it explicitly as a next-cycle request rather than reviving raw-storage edits.

### Slice 6. Keep The Registry Conservative

- Do not restore the removed legacy CLI pass ids yet.
- If Binaryen-style mode splitting becomes necessary during implementation, keep it as an internal config enum first.
- Only promote extra public pass ids if later parity and fuzzing work actually benefit from invoking them directly.

## Correctness Constraints

- No new owned optimizer IR beside `HotFunc`.
- No direct storage pokes from the pass; use public mutation helpers.
- Preserve local typing and result typing exactly when introducing tees or control results.
- Keep one-armed `if` lifting behind the defaultable-local guard from Binaryen.
- Preserve side effects when removing dead sets.
- Keep the pass valid on unreachable code as well as reachable SSA-shaped code.

## Validation Plan

- TDD first in [`../../../../src/passes/simplify_locals_test.mbt`](../../../../src/passes/simplify_locals_test.mbt).
- Focused regressions to add while landing the slices:
  - single-use sink
  - multi-use tee sink
  - overwritten pending set
  - `drop(tee)` collapse
  - side-effect, trap, throw, and `try` or `try_table` barriers
  - unreachable dead-set cleanup
  - equivalent local-get canonicalization with refined-type preference
  - block-return `br_if` hazard
  - one-armed `if` defaultable versus non-defaultable locals
  - `if-else` reachable or unreachable arm lifting
  - loop return lifting
- Required local checks before signoff:
  - `moon test src/passes/simplify_locals_test.mbt`
  - `moon test src/passes/optimize_test.mbt`
  - `moon info`
  - `moon fmt`
  - `moon test`
- Parity checks before signoff:
  - `bun scripts/pass-fuzz-compare.ts --pass simplify-locals --generator gen-valid --count 10000 --min-compared 10000`
  - `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --simplify-locals`
- If the current large-artifact baseline is still invalid earlier in the pipeline, fall back to ordered-prefix replay or the pass-fuzz harness until the baseline artifact is refreshed.

## Performance Notes

- Binaryen marks this pass function-parallel and keeps the main work in linear walks plus a bounded late phase.
- The Starshine port should avoid rebuilding CFG, dominance, or SSA inside the inner fixed-point loop unless a specific substep truly needs them.
- The current descriptor may be able to shrink once the pass stops being SSA-driven.
- Structure rewrites should be staged after the no-structure core because they are the highest-risk part for both lowering validity and pass time.

## Open Questions

- Whether this worktree should stop after a parity-complete no-structure core or continue into the full late `simplify-locals` structure families in the same branch.
- Whether the Binaryen-style linear-execution walker shape is common enough that `src/ir` should grow a reusable helper after this pass lands.
- Whether restoring legacy public names is useful for tooling, or whether internal mode flags plus the main public `simplify-locals` entry are enough.
