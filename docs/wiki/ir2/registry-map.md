---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
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

`ssa-nomerge`, `vacuum`, `dead-code-elimination`, `remove-unused-names`, `remove-unused-brs`, `optimize-instructions`, `heap-store-optimization`, `heap2local`, `optimize-casts`, `pick-load-signs`, `precompute`, `code-pushing`, `code-folding`, `tuple-optimization`, `simplify-locals`, `simplify-locals-nostructure`, `simplify-locals-no-structure`, `simplify-locals-notee-nostructure`, `merge-blocks`, and `redundant-set-elimination`.

### Active module passes

These have `ModulePass` category and are runnable through the same pass request path, but apply module-level logic or module-shaped adapters:

`local-cse`, `merge-locals`, `avoid-reinterprets`, `untee`, `duplicate-function-elimination`, `remove-unused-module-elements`, `remove-unused-nonfunction-module-elements`, `memory-packing`, `once-reduction`, `global-refining`, `global-struct-inference`, `reorder-locals`, `local-subtyping`, `coalesce-locals`, `duplicate-import-elimination`, `simplify-globals-optimizing`, `dae-optimizing`, `dead-argument-elimination-optimizing`, `inlining`, `inlining-optimizing`, `no-inline`, `no-full-inline`, `no-partial-inline`, `string-gathering`, `reorder-globals`, and `directize`.

### Active presets

`optimize` and `shrink` currently expand to the same implemented sequence:

```text
memory-packing -> once-reduction -> global-refining -> global-struct-inference ->
ssa-nomerge -> dead-code-elimination -> remove-unused-names -> remove-unused-brs ->
remove-unused-names -> vacuum -> remove-unused-brs -> optimize-instructions ->
heap-store-optimization -> pick-load-signs -> precompute -> code-pushing ->
tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals ->
remove-unused-brs -> heap2local -> optimize-casts -> local-subtyping ->
coalesce-locals -> local-cse -> simplify-locals -> merge-blocks ->
remove-unused-brs -> remove-unused-names -> merge-blocks -> precompute ->
optimize-instructions -> heap-store-optimization -> simplify-globals-optimizing ->
remove-unused-module-elements -> string-gathering -> reorder-globals -> directize
```

The same list is locked by [`../../../src/passes/registry_test.mbt`](../../../src/passes/registry_test.mbt). Slot-specific expectations, such as `code-pushing -> tuple-optimization -> simplify-locals-nostructure`, the single `reorder-locals` preset slot, repeated `remove-unused-brs`, repeated `merge-blocks`, repeated `precompute`, and the accepted late tail `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`, are covered in [`../../../src/passes/optimize_test.mbt`](../../../src/passes/optimize_test.mbt).

## Boundary-Only And Removed Behavior

- Boundary-only names are recognized but rejected as not implemented in the hot pipeline. Examples include the closed-world type/signature families (`type-refining`, `signature-pruning`, `unsubtyping`, `reorder-types`) and broader ABI/layout families (`alignment-lowering`, `i64-to-i32-lowering`, `reorder-functions`).
- Removed names are recognized but rejected as absent from the active hot pipeline registry. Current removed examples include `flatten`, `re-reloop`, `loop-invariant-code-motion`, `const-hoisting`, `dataflow-optimization`, `precompute-propagate`, `de-nan`, and legacy `simplify-locals-no-tee*` variants.
- The original March batch map is now partially stale because many former Batch 2/3 names have since landed as hot or module passes. Treat [`../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md) as the archived planning map, not a reason to ignore live code.

## Practical Rule

- When the question is "can I run this pass or preset now," trust the live registry and its tests.
- When adding a pass, update category tests before docs.
- When scheduling a pass into `optimize` or `shrink`, add slot-level tests that prove its neighborhood and repeated-pass count.
- Keep legacy names explicit for diagnostics; never reintroduce silent no-op acceptance.

## Sources

- Refreshed registry map: [`../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- Live registry and preset expansion: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- Registry coverage: [`../../../src/passes/registry_test.mbt`](../../../src/passes/registry_test.mbt)
- Preset slot coverage: [`../../../src/passes/optimize_test.mbt`](../../../src/passes/optimize_test.mbt)
