---
kind: concept
status: supported
last_reviewed: 2026-08-02
sources:
  - ../binaryen/passes/reorder-locals/index.md
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/registry_test.mbt
  - ../../../src/passes/optimize_test.mbt
related:
  - ./execution-plan.md
  - ./pass-porting-checklist.md
  - ../../../src/passes/pass_manager.mbt
---

# IR2 Registry Map

## Durable Conclusions

- The exact live optimizer surface comes from [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt), not from historical flag lists alone.
- The registry keeps five explicit categories:
  - active hot passes
  - active module passes
  - active presets
  - boundary-only names
  - removed names
- Active hot passes and active module passes are both accepted by the public requested-pass expansion path.
- Boundary-only and removed names stay known for diagnostics and planning, but `run_hot_pipeline` rejects them with explicit errors instead of silently treating them as no-ops.
- Help output intentionally lists hot passes and presets; do not infer that every runnable module pass is in the help roster.

## Current Live Surface

### Active hot passes

These have `HotPass` category and a hot descriptor where applicable:

The registry currently has 28 hot entries: `flatten`, `ssa-nomerge`, `ssa`, `vacuum`, `dead-code-elimination`, `remove-unused-names`, `remove-unused-brs`, `optimize-instructions`, `heap-store-optimization`, `heap2local`, `optimize-casts`, `pick-load-signs`, `precompute`, `precompute-propagate`, `code-pushing`, `code-folding`, `tuple-optimization`, `simplify-locals`, `simplify-locals-notee`, `simplify-locals-no-tee`, `simplify-locals-nonesting`, `simplify-locals-no-nesting`, `simplify-locals-nostructure`, `simplify-locals-no-structure`, `simplify-locals-notee-nostructure`, `merge-locals`, `merge-blocks`, and `redundant-set-elimination`.

### Active module passes

These have `ModulePass` category and are runnable through the same pass request path, but apply module-level logic or module-shaped adapters:

The registry currently has 30 module entries: `local-cse`, `avoid-reinterprets`, `untee`, `duplicate-function-elimination`, `remove-unused-module-elements`, `remove-unused-nonfunction-module-elements`, `memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, `global-struct-inference-desc-cast`, `reorder-locals`, `local-subtyping`, `coalesce-locals`, `duplicate-import-elimination`, `strip-debug`, `simplify-globals-optimizing`, `dead-argument-elimination`, `dae`, `dae-optimizing`, `dead-argument-elimination-optimizing`, `inlining`, `inline-main`, `inlining-optimizing`, `no-inline`, `no-full-inline`, `no-partial-inline`, `string-gathering`, `reorder-globals`, and `directize`.

### Active presets

`optimize` and `shrink` are wall-time-first scheduler entry points outside O4z. O1/O2 expand to `duplicate-function-elimination -> strip-debug`; O3/O4/Os/Oz expand to `duplicate-function-elimination -> vacuum -> reorder-locals -> strip-debug`. `--optimize` resolves to O2, while `--shrink` and literal `-Oz` resolve to `(2, 2)`; literal `-Os` resolves to `(2, 1)`. Direct passes remain runnable independently.

At O4z with all features enabled, both presets retain the full compatibility scheduler and expose Binaryen v131's exact 56-slot sequence. The prelude is `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> remove-unused-module-elements -> global-struct-inference`; the function phase includes the aggressive `ssa-nomerge -> flatten -> simplify-locals-notee-nostructure -> local-cse` prelude, both `precompute-propagate` slots, all three `remove-unused-brs` slots, and the late cleanup cluster; the post phase ends `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`. Starshine then appends its intentional `strip-debug` extension as slot 57.

Registry preset metadata is generated from the same scheduler instead of retaining duplicate hard-coded arrays. Exact O4z order, fast non-O4z rosters, repeated-slot counts, feature-gated O4z runtime execution, and the final extension are locked by [`../../../src/passes/registry_test.mbt`](../../../src/passes/registry_test.mbt) and [`../../../src/passes/optimize_test.mbt`](../../../src/passes/optimize_test.mbt).

## Boundary-Only And Removed Behavior

- Boundary-only names are recognized but rejected as not implemented in the hot pipeline. Examples include the closed-world type/signature families (`type-refining`, `signature-pruning`, `unsubtyping`, `reorder-types`) and broader ABI/layout families (`alignment-lowering`, `i64-to-i32-lowering`, `reorder-functions`).
- Removed names are recognized but rejected as absent from the active hot pipeline registry. Current removed examples include `re-reloop`, `loop-invariant-code-motion`, `const-hoisting`, `dataflow-optimization`, `optimize-added-constants`, `optimize-added-constants-propagate`, `de-nan`, and the legacy `simplify-locals-no-tee-no-structure` spelling. `flatten`, `precompute-propagate`, and the supported SimplifyLocals aliases are active.
- The original March batch map is now partially stale because many former Batch 2/3 names have since landed as hot or module passes. Treat research note 0063 as the archived planning map, not a reason to ignore live code.

## Practical Rule

- When the question is "can I run this pass or preset now," trust the live registry and its tests.
- When adding a pass, update category tests before docs.
- When scheduling a pass into `optimize` or `shrink`, add slot-level tests that prove its neighborhood and repeated-pass count.
- Keep legacy names explicit for diagnostics; never reintroduce silent no-op acceptance.

## Sources

- Refreshed registry map: research note 0063
- Reorder-locals preset-scheduling reconciliation: [research note 0709](../binaryen/passes/reorder-locals/index.md)
- Live registry and preset expansion: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- Registry coverage: [`../../../src/passes/registry_test.mbt`](../../../src/passes/registry_test.mbt)
- Preset slot coverage: [`../../../src/passes/optimize_test.mbt`](../../../src/passes/optimize_test.mbt)
