# IR2 Pass Port Batches And Registry Map

## Scope

- Keep the original pass-port batch intent usable without letting it overrule the live registry.
- Lock the current disposition for every major pass category the CLI has historically accepted.
- Point future agents at the source-of-truth files that decide whether a pass is runnable today.

## Source-Of-Truth Rule

The live registry in [`src/passes/optimize.mbt`](../src/passes/optimize.mbt) and its coverage in [`src/passes/registry_test.mbt`](../src/passes/registry_test.mbt) are authoritative for current behavior. This March batch map is a planning document; it must be refreshed when a pass moves between `hot`, `module`, `boundary-only`, or `removed` categories.

The runner accepts active hot passes, active module passes, and presets. Boundary-only and removed names stay known for diagnostics, but they return explicit errors instead of silently doing nothing.

## Current Registry Contract

### Active hot passes

These entries have `HotPass` registry category and are runnable through the hot pipeline:

- `ssa-nomerge`
- `vacuum`
- `dead-code-elimination`
- `remove-unused-names`
- `remove-unused-brs`
- `optimize-instructions`
- `heap-store-optimization`
- `heap2local`
- `optimize-casts`
- `pick-load-signs`
- `precompute`
- `code-pushing`
- `code-folding`
- `tuple-optimization`
- `simplify-locals`
- `simplify-locals-nostructure`
- `simplify-locals-no-structure` (alias for the no-structure variant)
- `simplify-locals-notee-nostructure`
- `merge-blocks`
- `redundant-set-elimination`

### Active module passes

These entries have `ModulePass` registry category and are runnable through the same requested-pass expansion path, but apply to the whole module or use module-shaped adapters rather than a single hot-function descriptor:

- `local-cse`
- `merge-locals`
- `avoid-reinterprets`
- `untee`
- `duplicate-function-elimination`
- `remove-unused-module-elements`
- `remove-unused-nonfunction-module-elements`
- `memory-packing`
- `once-reduction`
- `global-refining`
- `global-struct-inference`
- `reorder-locals`
- `local-subtyping`
- `coalesce-locals`
- `duplicate-import-elimination`
- `dae-optimizing`
- `dead-argument-elimination-optimizing`
- `string-gathering`
- `reorder-globals`
- `directize`

### Active presets

- `optimize`
- `shrink`

Both presets currently expand to the same implemented sequence:

```text
memory-packing -> once-reduction -> global-refining -> global-struct-inference ->
ssa-nomerge -> dead-code-elimination -> remove-unused-names -> remove-unused-brs ->
remove-unused-names -> vacuum -> remove-unused-brs -> optimize-instructions ->
heap-store-optimization -> pick-load-signs -> precompute -> code-pushing ->
tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals ->
remove-unused-brs -> heap2local -> optimize-casts -> local-subtyping ->
coalesce-locals -> local-cse -> simplify-locals -> merge-blocks ->
remove-unused-brs -> remove-unused-names -> merge-blocks -> precompute ->
optimize-instructions -> heap-store-optimization
```

Important scheduling caveats:

- `simplify-locals-notee-nostructure` is active as an explicit hot pass, but stays out of both presets until the exact `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood is ready.
- `reorder-locals` is now scheduled once inside the tuple/no-structure cleanup lane, not kept entirely out of presets.
- `optimize` and `shrink` remain identical until a size-only divergence is implemented and tested.

## Boundary-Only Names

Boundary-only names are recognized for diagnostics and planning, but `run_hot_pipeline` rejects them with `pass flag <name> is boundary-only and is not implemented in the hot pipeline`.

- Type, global, and signature shaping: `abstract-type-refining`, `constant-field-propagation`, `constant-field-null-test-folding`, `dead-argument-elimination`, `signature-pruning`, `signature-refining`, `global-struct-inference-desc-cast`, `global-type-optimization`, `simplify-globals`, `simplify-globals-optimizing`, `global-effects`, `propagate-globals-globally`, `type-refining`, `type-generalizing`, `type-finalizing`, `type-un-finalizing`, `unsubtyping`.
- Whole-module, layout, or closed-world transforms: `alignment-lowering`, `inlining`, `inlining-optimizing`, `inline-main`, `merge-similar-functions`, `minimize-rec-groups`, `type-merging`, `monomorphize`, `monomorphize-always`, `gufa`, `gufa-optimizing`, `gufa-cast-all`, `i64-to-i32-lowering`.
- Boundary cleanup and ordering: `reorder-types`, `reorder-globals-always`, `reorder-functions`, `reorder-functions-by-name`, `remove-unused-types`, `remove-unused`.

## Removed Names

Removed names are recognized for explicit diagnostics while no active port exists. `run_hot_pipeline` rejects them with `pass flag <name> is removed from the active hot pipeline registry`.

- `const-hoisting`
- `dataflow-optimization`
- `loop-invariant-code-motion`
- `flatten`
- `re-reloop`
- `optimize-added-constants`
- `optimize-added-constants-propagate`
- `precompute-propagate`
- `de-nan`
- `simplify-locals-no-tee`
- `simplify-locals-no-tee-no-structure`
- `simplify-locals-no-nesting`

## Original Batch Map Status

The original batch labels are now partly historical:

- Many former Batch 1, Batch 2, and Batch 3 entries have landed as active hot or module passes.
- The remaining removed names above are the true current migration gaps, not every item in the original batch lists.
- Boundary-only names are often broader module/type/ABI transformations and should not be treated as ordinary hot-pass backlog without a separate module/type rewrite contract.

## Correctness Rules

- No legacy flag may be silently accepted as a no-op.
- Help output lists only active hot passes and presets; module passes are runnable but not all are presented as hot-pass help entries.
- Preset expansion may only reference implemented active hot or module passes.
- Any future move between categories must update this file, [`docs/wiki/ir2/registry-map.md`](wiki/ir2/registry-map.md), registry tests, and affected pass wiki pages in the same change.

## Validation Plan

- Registry category coverage: [`src/passes/registry_test.mbt`](../src/passes/registry_test.mbt).
- Preset expansion and slot coverage: [`src/passes/registry_test.mbt`](../src/passes/registry_test.mbt) and [`src/passes/optimize_test.mbt`](../src/passes/optimize_test.mbt).
- CLI/runner rejection behavior: tests around `run_hot_pipeline_expand_passes` and public pass requests.
- Before commit, run `moon info`, `moon fmt`, `bun validate readme-api-sync`, and `moon test` when the change affects API or behavior; docs-only refreshes may record why repository evidence was sufficient.

## Open Questions

- When `optimize` and `shrink` should diverge.
- Whether some module-shaped entries should become visible in help output or stay discoverable through pass-list tooling only.
- Which remaining removed names deserve near-term ports versus permanent diagnostic-only treatment.
