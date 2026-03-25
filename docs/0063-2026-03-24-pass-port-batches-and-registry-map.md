# IR2 Pass Port Batches And Registry Map

## Scope

- Define the concrete pass-port batches that replace the old compatibility and no-op optimizer surface.
- Lock the current registry disposition for every named pass or preset the CLI has historically accepted.

## Current Registry Contract

- Active hot passes:
  `ssa-nomerge`, `dead-code-elimination`, `vacuum`, `optimize-instructions`, `simplify-locals`.
- Active presets:
  `optimize`, `shrink`.
- Boundary-only names stay known to the registry for mapping and diagnostics, but remain rejected by the hot pipeline and hidden from help output.
- Removed names stay known to the registry so the repository has an explicit current answer for each legacy flag while its hot port is still absent.

## Batch 1

- Current hot passes:
  `ssa-nomerge`, `dead-code-elimination`, `vacuum`, `optimize-instructions`, `simplify-locals`.
- Initial placeholder modules:
  [`src/passes/ssa_nomerge.mbt`](../src/passes/ssa_nomerge.mbt),
  [`src/passes/dead_code_elimination.mbt`](../src/passes/dead_code_elimination.mbt),
  [`src/passes/optimize_instructions.mbt`](../src/passes/optimize_instructions.mbt),
  [`src/passes/simplify_locals.mbt`](../src/passes/simplify_locals.mbt).
- Removed until hot implementation lands:
  `avoid-reinterprets`, `coalesce-locals`, `code-folding`, `code-pushing`, `const-hoisting`, `dataflow-optimization`, `local-cse`, `merge-locals`, `optimize-added-constants`, `optimize-added-constants-propagate`, `precompute`, `precompute-propagate`, `simplify-locals-no-tee`, `simplify-locals-no-structure`, `simplify-locals-no-tee-no-structure`, `simplify-locals-no-nesting`, `untee`, `de-nan`.

## Batch 2

- Removed until hot implementation lands:
  `flatten`, `merge-blocks`, `re-reloop`, `tuple-optimization`, `remove-unused-brs`, `redundant-set-elimination`, `pick-load-signs`, `optimize-casts`.

## Batch 3

- Removed until hot implementation lands:
  `local-subtyping`, `loop-invariant-code-motion`.

## Boundary-Only Names

- Type, global, and signature shaping:
  `abstract-type-refining`, `constant-field-propagation`, `constant-field-null-test-folding`, `dead-argument-elimination`, `dead-argument-elimination-optimizing`, `signature-pruning`, `signature-refining`, `global-refining`, `global-struct-inference`, `global-struct-inference-desc-cast`, `global-type-optimization`, `simplify-globals`, `simplify-globals-optimizing`, `global-effects`, `propagate-globals-globally`, `type-refining`, `type-generalizing`, `type-finalizing`, `type-un-finalizing`, `unsubtyping`.
- Whole-module or layout transforms:
  `alignment-lowering`, `duplicate-import-elimination`, `directize`, `heap2local`, `heap-store-optimization`, `inlining`, `inlining-optimizing`, `inline-main`, `merge-similar-functions`, `once-reduction`, `minimize-rec-groups`, `type-merging`, `monomorphize`, `monomorphize-always`, `memory-packing`, `gufa`, `gufa-optimizing`, `gufa-cast-all`, `i64-to-i32-lowering`, `duplicate-function-elimination`.
- Boundary cleanup and ordering:
  `remove-unused-names`, `reorder-locals`, `reorder-types`, `reorder-globals`, `reorder-globals-always`, `reorder-functions`, `reorder-functions-by-name`, `remove-unused-types`, `remove-unused`, `remove-unused-module-elements`, `remove-unused-non-function-elements`.

## Preset Composition

- `optimize` expands to `["ssa-nomerge", "dead-code-elimination", "vacuum", "optimize-instructions", "simplify-locals"]`.
- `shrink` expands to `["ssa-nomerge", "dead-code-elimination", "vacuum", "optimize-instructions", "simplify-locals"]`.
- Future preset growth must only add implemented hot passes or explicitly documented boundary-only phases.

## Correctness Rules

- No legacy flag remains silently accepted as a no-op.
- Hidden legacy names may stay in the registry for explicit diagnostics and planning, but help output only lists active hot passes and presets.
- Batch placeholders must declare truthful anticipated analysis dependencies before real pass code lands.

## Validation Plan

- Add registry coverage tests for active, boundary-only, and removed names.
- Add tests for preset expansion and rejection paths on removed or boundary-only names.
- Before commit, run `moon info`, `moon fmt`, `bun validate readme-api-sync`, and `moon test`.

## Open Questions

- Whether `optimize` and `shrink` should remain identical until a size-only batch diverges from the general preset.
- Whether any current boundary-only names should later move into the hot pipeline once the optimizer owns broader module context.
