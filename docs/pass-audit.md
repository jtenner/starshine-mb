# Pass Audit

## Status

- Date: 2026-03-18
- Scope: `src/passes`, `src/passes/optimize.mbt`, existing pass-specific docs and tests.
- This started as the Phase 1 inventory and initial audit baseline and now includes the first runner-level metrics plus a dedicated benchmark harness entrypoint.
- This document is currently being used as the planning checkpoint for the execution work.
- Behavior-changing refactors and committed benchmark deltas are still pending below this checkpoint.
- Locals-model note: all pass inventory below now assumes the post-refactor canonical locals model (`Locals` + `LocalRun` with cached run-start indices). The old flat typed-locals representation is gone.

## Planning Checkpoint

- Completed planning/infrastructure:
- `src/passes` inventory and default pipeline mapping are captured below.
- Binaryen-nearest mappings and initial inefficiency notes are captured below.
- `src/passes/optimize.mbt` now emits runner-level per-pass change/function/instruction metrics in trace output.
- `bun make benchmark-optimize` is the dedicated benchmark entrypoint, and `scripts/test/make-benchmark-output.ts` locks the parser against a stable sample trace.
- Pending execution in strict order:
- capture and commit baseline measurements for `examples`, `spec-sanity`, `dist-optimized`, and the documented user-run `self-opt-debug` command
- refactor `SimplifyLocals` first with red/green tests and microbenchmarks
- refactor `Vacuum` next using the new measurements
- audit scheduling/gating after the first two high-impact refactors
- then refactor `AlignmentLowering` and lower-priority passes
- Current `SimplifyLocals` implementation notes that directly inform the next refactor:
- sinkable storage is still `Map[Int, SLSinkableInfo]` even though the keys are bounded local indexes
- invalidation indexes are still `Map[Int, Set[Int]]`, which creates avoidable allocation and update churn on hot paths
- non-linear-boundary cleanup still clears whole sinkable maps/indexes instead of using cheap generation or dirty-list reset strategies
- get-count and no-tee opportunity summaries are still collected in separate traversals in some paths

## Goals

- Recover module-size wins in the default optimizer and self-optimization workflows.
- Reduce pass overhead without weakening correctness.
- Make pass cost and size impact measurable at runner level.
- Compare each Starshine pass to the closest Binaryen pass or pass family.

## File Inventory

### Scheduler, package glue, and support

- `src/passes/optimize.mbt`: scheduler, default pipelines, stacked function-runner, validation policy, pass dispatch, scheduler tests.
- `src/passes/imports.mbt`: shared imports for the package.
- `src/passes/util.mbt`: shared helper utilities used by passes.
- `src/passes/moon.pkg`: package manifest.
- `src/passes/pkg.generated.mbti`: generated public interface.
- `src/passes/LICENSE`: upstream license text.

### Pass implementation files

- `src/passes/abstract_type_refining.mbt`
- `src/passes/alignment_lowering.mbt`
- `src/passes/asyncify.mbt`
- `src/passes/avoid_reinterprets.mbt`
- `src/passes/coalesce_locals.mbt`
- `src/passes/code_folding.mbt`
- `src/passes/code_pushing.mbt`
- `src/passes/const_hoisting.mbt`
- `src/passes/constant_field_propagation.mbt`
- `src/passes/dataflow_opt.mbt`
- `src/passes/dead_argument_elim.mbt`
- `src/passes/dead_code_elimination.mbt`
- `src/passes/de_nan.mbt`
- `src/passes/directize.mbt`
- `src/passes/duplicate_function_elimination.mbt`
- `src/passes/duplicate_import_elimination.mbt`
- `src/passes/flatten.mbt`
- `src/passes/global_effects.mbt`
- `src/passes/global_refining.mbt`
- `src/passes/global_struct_inference.mbt`
- `src/passes/global_type_optimization.mbt`
- `src/passes/gufa.mbt`
- `src/passes/heap2local.mbt`
- `src/passes/heap_store_optimization.mbt`
- `src/passes/i64_to_i32_lowering.mbt`
- `src/passes/inlining.mbt`
- `src/passes/lift_to_texpr.mbt`
- `src/passes/local_cse.mbt`
- `src/passes/local_subtyping.mbt`
- `src/passes/loop_invariant_code_motion.mbt`
- `src/passes/lower_to_expr.mbt`
- `src/passes/memory_packing.mbt`
- `src/passes/merge_blocks.mbt`
- `src/passes/merge_locals.mbt`
- `src/passes/merge_similar_functions.mbt`
- `src/passes/minimize_rec_groups.mbt`
- `src/passes/monomorphize.mbt`
- `src/passes/once_reduction.mbt`
- `src/passes/optimize_added_constants.mbt`
- `src/passes/optimize_casts.mbt`
- `src/passes/optimize_instructions.mbt`
- `src/passes/pick_load_signs.mbt`
- `src/passes/precompute.mbt`
- `src/passes/redundant_set_elimination.mbt`
- `src/passes/re_reloop.mbt`
- `src/passes/remove_unused.mbt`
- `src/passes/remove_unused_brs.mbt`
- `src/passes/remove_unused_names.mbt`
- `src/passes/remove_unused_types.mbt`
- `src/passes/reorder_functions.mbt`
- `src/passes/reorder_globals.mbt`
- `src/passes/reorder_locals.mbt`
- `src/passes/reorder_types.mbt`
- `src/passes/signature_pruning.mbt`
- `src/passes/signature_refining.mbt`
- `src/passes/simplify_globals.mbt`
- `src/passes/simplify_locals.mbt`
- `src/passes/tuple_optimization.mbt`
- `src/passes/type_finalizing.mbt`
- `src/passes/type_generalizing.mbt`
- `src/passes/type_merging.mbt`
- `src/passes/type_refining.mbt`
- `src/passes/unsubtyping.mbt`
- `src/passes/untee.mbt`
- `src/passes/vacuum.mbt`

### Focused test and parity files inside `src/passes`

- `src/passes/lift_lower_tests.mbt`: lift/lower roundtrip tests.
- `src/passes/merge_blocks_parity_wbtest.mbt`: merge-blocks parity corpus and timing harness.
- `src/passes/merge_locals_tests.mbt`: merge-locals targeted tests.

## Pipeline Inventory

### Default function pipeline

Current default function pipeline from `default_function_optimization_passes(...)`:

1. `SSANoMerge` when `optimize_level >= 3 || shrink_level >= 1`
2. `Flatten`, `SimplifyLocalsNoTeeNoStructure`, `LocalCSE` when `optimize_level >= 4`
3. `DeadCodeElimination`
4. `RemoveUnusedNames`
5. `RemoveUnusedBrs`
6. `RemoveUnusedNames`
7. `OptimizeInstructions`
8. `HeapStoreOptimization` when GC is present
9. `PickLoadSigns` when `optimize_level >= 2 || shrink_level >= 2`
10. `Precompute` or `PrecomputePropagate`
11. `OptimizeAddedConstants` or `OptimizeAddedConstantsPropagate` when `low_memory_unused`
12. `CodePushing` when `optimize_level >= 2 || shrink_level >= 2`
13. `TupleOptimization` when multivalue is present
14. `SimplifyLocalsNoStructure`
15. `Vacuum`
16. `ReorderLocals`
17. `RemoveUnusedBrs`
18. `Heap2Local` when `optimize_level > 1` and GC is present
19. `MergeLocals` when `optimize_level >= 3 || shrink_level >= 2`
20. `OptimizeCasts`, `LocalSubtyping` when `optimize_level > 1` and GC is present
21. `CoalesceLocals`
22. `LocalCSE` when `optimize_level >= 3 || shrink_level >= 1`
23. `SimplifyLocals`
24. `Vacuum`
25. `ReorderLocals`
26. `CoalesceLocals`
27. `ReorderLocals`
28. `Vacuum`
29. `CodeFolding` when `optimize_level >= 3 || shrink_level >= 1`
30. `MergeBlocks`
31. `RemoveUnusedBrs`
32. `RemoveUnusedNames`
33. `MergeBlocks`
34. `Precompute` or `PrecomputePropagate`
35. optional late `OptimizeInstructions`
36. `HeapStoreOptimization` when GC is present
37. `RedundantSetElimination` when `optimize_level >= 2 || shrink_level >= 1`
38. `Vacuum`

### Default global pre-pass pipeline

1. `DuplicateFunctionElimination`
2. `RemoveUnusedModuleElements` at `-O2+`
3. `MemoryPacking`
4. `OnceReduction` at `-O2+`
5. GC/closed-world gated cluster:
6. `TypeRefining`
7. `SignaturePruning`
8. `SignatureRefining`
9. `GlobalRefining`
10. `GlobalTypeOptimization`
11. `RemoveUnusedModuleElements`
12. `RemoveUnusedTypes`
13. `ConstantFieldPropagation`
14. `ConstantFieldNullTestFolding` at `-O3+`
15. `GlobalStructInference`
16. `AbstractTypeRefining`
17. `Unsubtyping`

### Default global post-pass pipeline

1. `DeadArgumentEliminationOptimizing` at `-O2` or `-Os1`
2. `InliningOptimizing` at `-O2` or `-Os2`
3. `DuplicateFunctionElimination`
4. `DuplicateImportElimination`
5. `MergeSimilarFunctions` at `-Os2`
6. `SimplifyGlobals` or `SimplifyGlobalsOptimizing`
7. `RemoveUnusedModuleElements`
8. `ReorderGlobals` at `-O2` or `-Os1`
9. `Directize(true)`

### Current scheduler segmentation

- `optimize.mbt` already splits the pass list into `FunctionPassStack` and `BarrierPass` segments.
- Stackable passes are currently limited to a subset of IR-context and unit transformer passes.
- Module-shaped transforms and analysis-heavy wrappers remain barriers even when their rewrites are function-local.
- Current change-state gating is extremely narrow: only repeated `Vacuum` can be skipped when the prior `Vacuum` changed nothing and no intervening pass changed anything.
- There is no general per-pass change-summary gating yet.

## Mutually Enabling Pass Relationships

- `DeadCodeElimination` -> `RemoveUnusedNames` -> `RemoveUnusedBrs`: early cleanup removes dead structure and branch labels before more expensive simplifiers.
- `Precompute` / `PrecomputePropagate` -> `CodePushing` -> `SimplifyLocalsNoStructure`: canonicalization and constant exposure create more sinkable / foldable local patterns.
- `SimplifyLocals*` -> `Vacuum`: local rewrites introduce dead wrappers, dead drops, and trivial blocks that `Vacuum` must remove promptly.
- `Vacuum` -> `MergeBlocks` -> `RemoveUnusedBrs` -> `RemoveUnusedNames`: cleanup shortens nested structure, then block merging and branch/name cleanup shrink remaining control scaffolding.
- `MergeLocals` / `CoalesceLocals` / `ReorderLocals`: local count and ordering cleanups reinforce each other, but the current sequence reruns them without a precise relevance gate.
- `AlignmentLowering` -> `Vacuum`: lowering introduces helper blocks, locals, shifts, and reinterpret wrappers that want immediate cleanup.
- `Heap2Local` / `OptimizeCasts` / `LocalSubtyping` -> `SimplifyLocals` / `Vacuum`: GC-local rewrites can expose ordinary local and dead-wrapper opportunities.
- `InliningOptimizing` / `MergeSimilarFunctions` / `SimplifyGlobalsOptimizing` -> `RemoveUnusedModuleElements`: post-global rewrites create dead functions/imports/globals that should be trimmed immediately.

## Pass Inventory

### Function and cleanup passes

| Pass | File | Purpose | Class | Closest Binaryen equivalent | Missing Binaryen-style optimization | Redundant work / cost risk |
| --- | --- | --- | --- | --- | --- | --- |
| `SSANoMerge` | `dataflow_opt.mbt` | no-merge SSA prep for local-copy propagation | cleanup, analysis | `ssa-nomerge` | More aggressive relevance gating and cheaper function summaries | Improved recently, but still a full-function analysis pass |
| `DataflowOptimization` | `dataflow_opt.mbt` | copy/constant propagation on locals | speed, cleanup | `data-flow-opts` family | Better scheduler integration and pass-result gating | Separate full-function walk family from `SSANoMerge` |
| `DeadCodeElimination` | `dead_code_elimination.mbt` | trim unreachable or unused instruction trees | cleanup, size | `dce` | More immediate post-rewrite cleanup coupling | Full-function scans remain expected |
| `RemoveUnusedBrs` | `remove_unused_brs.mbt` | remove useless branches and thread trivial jumps | cleanup, size | `remove-unused-brs` | More localized reprocessing instead of fixpoint whole-body loops | Very large file, repeated rounds, known hot path |
| `RemoveUnusedNames` | `remove_unused_names.mbt` | prune unnecessary block/loop labels | cleanup, size | `remove-unused-names` | Better change gating around no-name modules | Low per-pass value when run unchanged |
| `OptimizeInstructions` | `optimize_instructions.mbt` | local instruction-level algebraic cleanup | cleanup, size, speed | `optimize-instructions` | Better before/after size accounting for late pass gate | Late rerun is only heuristically gated |
| `PickLoadSigns` | `pick_load_signs.mbt` | choose smaller signed/unsigned load forms | size | `pick-load-signs` | Module/function no-candidate fast path at runner level | Still requires full walk to discover candidates |
| `Precompute` | `precompute.mbt` | fold constant expressions without propagation | cleanup, size | `precompute` | Better rerun gating based on exposed constants | Repeated whole-function walk |
| `PrecomputePropagate` | `precompute.mbt` | fold and propagate constants | cleanup, size, speed | `precompute-propagate` | Better sharing with other local analyses | Same pass family repeated twice in default pipeline |
| `OptimizeAddedConstants` | `optimize_added_constants.mbt` | reassociate added constants for size | size | `optimize-added-constants` | Stronger byte-size accounting in profitability | Low-memory-only path limits exposure |
| `OptimizeAddedConstantsPropagate` | `optimize_added_constants.mbt` | added-constants cleanup with propagation | size | `optimize-added-constants-propagate` | Same as above | Same family rerun without change summary |
| `CodePushing` | `code_pushing.mbt` | sink/push code into branches to shrink wrappers | size, cleanup | `code-pushing` | Tighter interaction with immediate parent cleanup | Full nested walk; benefits rely on later cleanup |
| `TupleOptimization` | `tuple_optimization.mbt` | normalize multivalue shapes | cleanup, size | `tuple-optimization` | Better skip path when multivalue is sparse | Mostly gated already |
| `SimplifyLocals` | `simplify_locals.mbt` | sink/set/get/tee/structured local rewrites | cleanup, size | `simplify-locals` | Dense local-index storage, fused summaries, cheaper validation staging | Major Map/Set hot paths and repeated fixpoint rescans |
| `SimplifyLocalsNoTee` | `simplify_locals.mbt` | simplify locals without tee creation | cleanup, size | `simplify-locals-notee` family | Same as `SimplifyLocals` | Same hot-path debt |
| `SimplifyLocalsNoStructure` | `simplify_locals.mbt` | local rewrite without result-structuring | cleanup, size | `simplify-locals-nostructure` family | Same as `SimplifyLocals` | Same hot-path debt |
| `SimplifyLocalsNoTeeNoStructure` | `simplify_locals.mbt` | early cheap local canonicalization | cleanup, size | `simplify-locals-notee-nostructure` | Same as `SimplifyLocals` | Good early slot, but still full analysis walk |
| `SimplifyLocalsNoNesting` | `simplify_locals.mbt` | local cleanup that avoids nested sinks | cleanup | `simplify-locals` restricted mode | Same as `SimplifyLocals` | Useful guard mode, but still shares cost centers |
| `Vacuum` | `vacuum.mbt` | peephole dead-wrapper and dead-drop cleanup | cleanup, size | `vacuum` | Parent worklist and less whole-function reseeding | Very large pass, full seed/optimize/final cycle, known correctness blocker |
| `ReorderLocals` | `reorder_locals.mbt` | renumber locals for compact output | size, cleanup | `reorder-locals` | Relevance gate from local-count deltas | Rerun multiple times without explicit need tracking |
| `Heap2Local` | `heap2local.mbt` | replace short-lived heap traffic with locals | size, speed | `heap2local` | Better cleanup handoff summary to later passes | Barrier pass, can introduce local cleanup debt |
| `MergeLocals` | `merge_locals.mbt` | merge compatible local slots | size | `merge-locals` | Dense bitset-ish flow state instead of set-heavy state | Current analysis uses copied sets and graph snapshots |
| `OptimizeCasts` | `optimize_casts.mbt` | remove/refine redundant ref casts/tests | cleanup, size | `optimize-casts` | More immediate cleanup coupling with `Vacuum` | Full-function typed walk |
| `LocalSubtyping` | `local_subtyping.mbt` | narrow local types after GC rewrites | cleanup, size | `local-subtyping` | More reuse of preceding type facts | Barrier pass even when benefits are function-local |
| `CoalesceLocals` | `coalesce_locals.mbt` | coalesce equivalent locals after rewrites | size | `coalesce-locals` | Change-summary gating after no local-count changes | Repeated with `ReorderLocals` |
| `LocalCSE` | `local_cse.mbt` | common-subexpression elimination within functions | speed, size | `local-cse` | Better module barrier removal via prepared summaries | Analysis is whole-module-prep-heavy |
| `CodeFolding` | `code_folding.mbt` | fold repeated terminating code tails | size | `code-folding` | More worklist-style recollection and cheaper tail measurement | Repeated recollect/measure/walk rounds are expensive |
| `MergeBlocks` | `merge_blocks.mbt` | collapse trivial/adjacent block structures | cleanup, size | `merge-blocks` | Better immediate cleanup linkage and change gating | Known hot path; still barrier and rerun twice |
| `Flatten` | `flatten.mbt` | flatten nested expression structure | cleanup | `flatten` | Better selective use for functions that need it | Barrier pass at `-O4` by design |
| `ReReloop` | `re_reloop.mbt` | rebuild structured control from flattened CFG shapes | cleanup, legalization | `relooper` / `rereloop` family | Tighter pipeline slotting when flatten-like passes introduce debt | Not in default pipeline |
| `RedundantSetElimination` | `redundant_set_elimination.mbt` | remove dead local sets after cleanups | cleanup, size | `redundant-set-elimination` | Better exposure tracking to avoid late no-op runs | Late full walk |
| `Untee` | `untee.mbt` | split `local.tee` when needed by later passes | cleanup | `untee` | More targeted scheduling | Usually preparatory, not size-positive alone |
| `LoopInvariantCodeMotion` | `loop_invariant_code_motion.mbt` | hoist loop-invariant expressions | speed | `licm` | Better effect-cache sharing | Not default-scheduled today |
| `ConstHoisting` | `const_hoisting.mbt` | hoist repeated literals into locals | size, speed | closest family `const-hoisting` | Profitability based on bytes, not just counts | Not in default pipeline |

### Global, type, and module passes

| Pass | File | Purpose | Class | Closest Binaryen equivalent | Missing Binaryen-style optimization | Redundant work / cost risk |
| --- | --- | --- | --- | --- | --- | --- |
| `DuplicateFunctionElimination` | `duplicate_function_elimination.mbt` | merge byte-identical functions | size | `duplicate-function-elimination` | Better byte-size profitability integration with later passes | Full-module compare |
| `RemoveUnused` | `remove_unused.mbt` | remove unused module elements under configurable envelope | cleanup, size | `remove-unused` | More targeted sub-modes from scheduler summaries | Full-module reachability sweep |
| `RemoveUnusedModuleElements` | `remove_unused.mbt` | remove unused functions/globals/types/etc | cleanup, size | `remove-unused-module-elements` | Change-summary gating after global/post passes | Full-module sweep |
| `RemoveUnusedNonFunctionElements` | `remove_unused.mbt` | trim unused non-function module elements | cleanup, size | `remove-unused` submode | Same as above | Full-module sweep |
| `RemoveUnusedTypes` | `remove_unused_types.mbt` | remove dead type definitions | cleanup, size | `remove-unused-types` | Better integration with type-merging/finalizing summaries | Full type-graph walk |
| `MemoryPacking` | `memory_packing.mbt` | pack data segments and memory layout | size | `memory-packing` | Tighter emitted-byte reporting | Module-wide and potentially expensive |
| `OnceReduction` | `once_reduction.mbt` | inline or simplify once-only patterns | size, speed | `once-reduction` | Better post-change cleanup gating | Barrier pass |
| `TypeRefining` | `type_refining.mbt` | refine GC/reference types | cleanup, size | `type-refining` | Better sharing with later type passes | Full-module type analysis |
| `SignaturePruning` | `signature_pruning.mbt` | remove unused function params/results | size | `signature-pruning` | Better cooperation with DAE summaries | Full-module signature walk |
| `SignatureRefining` | `signature_refining.mbt` | refine function signatures after type info improves | size, cleanup | `signature-refining` | Better byte-size profitability and reuse of prior analyses | Large module runner |
| `GlobalRefining` | `global_refining.mbt` | refine global types/values | cleanup, size | `global-refining` | Better handoff to simplify-globals and remove-unused | Barrier pass |
| `GlobalTypeOptimization` | `global_type_optimization.mbt` | shrink global types | size | `global-type-optimization` | Better sharing with refining passes | Barrier pass |
| `ConstantFieldPropagation` | `constant_field_propagation.mbt` | propagate known struct field values | size, speed | `cfp` | Wider Binaryen-style `cfp-reftest` coverage is still absent | Analysis+rewrite barrier |
| `ConstantFieldNullTestFolding` | `constant_field_propagation.mbt` | fold known-null ref tests | cleanup, size | narrow subset of `cfp-reftest` | Wider ref-test/ref-cast folding | Separate barrier pass after CFP |
| `GlobalStructInference` | `global_struct_inference.mbt` | infer more precise global struct shapes | analysis, cleanup | closest family `global-struct-inference` | More direct reuse by later GC passes | Barrier pass |
| `GlobalStructInferenceDescCast` | `global_struct_inference.mbt` | descriptor-aware variant of above | analysis, cleanup | same family | Same as above | Same as above |
| `AbstractTypeRefining` | `abstract_type_refining.mbt` | refine abstract heap types | cleanup, size | `abstract-type-refining` | More targeted reruns after actual type changes | Barrier pass |
| `Unsubtyping` | `unsubtyping.mbt` | normalize away subtype complexity where legal | cleanup, size | `unsubtyping` | Better gating from prior type-change summaries | Barrier pass |
| `TypeGeneralizing` | `type_generalizing.mbt` | generalize types to expose later merges | cleanup | `type-generalizing` | Better scheduler placement feedback from later size deltas | Barrier pass |
| `TypeFinalizing` | `type_finalizing.mbt` | finalize types for smaller/cleaner output | cleanup, size | `type-finalizing` | Better coupling with remove-unused-types | Barrier pass |
| `TypeUnFinalizing` | `type_finalizing.mbt` | undo finalization to unlock transforms | cleanup | `type-unfinalizing` | Better proof that rerun is relevant | Barrier pass |
| `TypeMerging` | `type_merging.mbt` | merge compatible type definitions | size | `type-merging` | Better precomputed shape summaries and gating | Expensive module barrier |
| `MinimizeRecGroups` | `minimize_rec_groups.mbt` | split/minimize recursion groups for type size | size | closest family `minimize-rec-groups` | Better interaction with type-merging / reorder-types | Heavy module graph work |
| `ReorderTypes` | `reorder_types.mbt` | reorder types canonically for compact output | size | `reorder-types` | Run only when type graph actually changes | Full type rewrite |
| `SimplifyGlobals` | `simplify_globals.mbt` | fold/propagate/remove global traffic | cleanup, size | `simplify-globals` | More reuse of earlier global analyses | Multiple internal phases |
| `SimplifyGlobalsOptimizing` | `simplify_globals.mbt` | stronger simplify-globals mode | cleanup, size | `simplify-globals-optimizing` | Same as above | Same as above |
| `GlobalEffects` | `global_effects.mbt` | generate/analyze global effect facts | analysis | `generate-global-effects` family | Better sharing as reusable analysis result | Currently standalone |
| `PropagateGlobalsGlobally` | `simplify_globals.mbt` | apply known globals to more module sections | cleanup, size | closest family simplify-globals/global-refining | More integration with default scheduler | Not default-scheduled |
| `Inlining` | `inlining.mbt` | ordinary function inlining | speed, size | `inlining` | Better byte-aware profitability and change-summary feedback | Expensive barrier pass |
| `InliningOptimizing` | `inlining.mbt` | stronger optimization-oriented inlining | speed, size | `inlining-optimizing` | Same as above | Can introduce large cleanup debt |
| `InlineMain` | `inlining.mbt` | inline the main entrypoint where profitable | size | `inline-main` | Better interaction with remove-unused | Not default-scheduled |
| `DeadArgumentElimination` | `dead_argument_elim.mbt` | remove dead params/results | size | `dae` | Better analysis reuse with signature pruning/refining | Large module runner |
| `DeadArgumentEliminationOptimizing` | `dead_argument_elim.mbt` | DAE with immediate cleanup sequence | size, cleanup | `dae-optimizing` | Change-summary-driven cleanup instead of fixed cleanup trio | Hardcoded DCE/Vacuum/CodeFolding followup |
| `MergeSimilarFunctions` | `merge_similar_functions.mbt` | merge near-identical functions | size | `merge-similar-functions` | More byte-size-aware profitability and lower overhead site bookkeeping | Large barrier pass; correctness blocker remains |
| `DuplicateImportElimination` | `duplicate_import_elimination.mbt` | merge duplicate imports | size | closest family duplicate-import-elimination | Better integration with remove-unused | Small module sweep |
| `ReorderGlobals` | `reorder_globals.mbt` | reorder globals for size | size | `reorder-globals` | Gate on actual global-order opportunity | Full rewrite |
| `ReorderGlobalsAlways` | `reorder_globals.mbt` | force global reorder even in weaker modes | size | `reorder-globals` | Same as above | Same as above |
| `ReorderFunctions` | `reorder_functions.mbt` | reorder functions for compact layout | size | `reorder-functions` | Gate on call graph / reachability changes | Full-module rewrite |
| `ReorderFunctionsByName` | `reorder_functions.mbt` | deterministic name-based reorder | analysis, cleanup | closest family reorder-functions | Mainly determinism, not size | Not a size-first pass |
| `Directize(true/false)` | `directize.mbt` | convert indirect calls to direct calls | size, speed | `directize` | Better follow-up cleanup summary | Barrier pass |
| `Monomorphize` | `monomorphize.mbt` | specialize generic/reference-heavy call patterns | speed, size | `monomorphize` | Better profitability and cleanup sequencing | Barrier pass |
| `MonomorphizeAlways` | `monomorphize.mbt` | aggressive monomorphization mode | speed, size | `monomorphize-always` | Same as above | Same as above |
| `GUFA` | `gufa.mbt` | global unboxing / flow analysis for GC refs | analysis, size | `gufa` | Better pipeline-level change summaries | Full-module analysis |
| `GUFAOptimizing` | `optimize.mbt` + `gufa.mbt` | GUFA plus cleanup sequence | analysis, cleanup | `gufa-optimizing` | First-class pass wrapper with metrics instead of hidden composite | Composite barrier implemented in scheduler |
| `GUFACastAll` | `gufa.mbt` | stronger GUFA cast mode | analysis | `gufa-cast-all` | Same as above | Not default-scheduled |

### Lowering, legalization, and specialized transforms

| Pass | File | Purpose | Class | Closest Binaryen equivalent | Missing Binaryen-style optimization | Redundant work / cost risk |
| --- | --- | --- | --- | --- | --- | --- |
| `AlignmentLowering` | `alignment_lowering.mbt` | split unaligned memory ops into safe aligned pieces | legalization, cleanup | `alignment-lowering` | Module/function early exits and unchanged-subtree preservation | Walks all functions even when no misaligned ops exist |
| `AvoidReinterprets` | `avoid_reinterprets.mbt` | remove avoidable reinterpret pairs | cleanup, size | `avoid-reinterprets` | Better coupling with instruction cleanup | Mostly straightforward |
| `I64ToI32Lowering` | `i64_to_i32_lowering.mbt` | lower `i64` ABI/ops to `i32` pairs | legalization | `i64-to-i32-lowering` | Better cleanup debt summary and targeted reruns | Large module barrier |
| `DeNaN` | `de_nan.mbt` | canonicalize NaNs for deterministic output | cleanup, legalization | `de-nan` | Better scheduling only when FP ops exist | Module-shaped wrapper remains barrier |
| `Asyncify` | `asyncify.mbt` | asyncify transform | legalization | `asyncify` | Better fast path for modules with no async candidates | Large barrier transform |
| `MemoryPacking` | `memory_packing.mbt` | pack data memory layout | size | `memory-packing` | Better before/after emitted-byte reporting | Module-wide |
| `OnceReduction` | `once_reduction.mbt` | lower one-shot control/data patterns | cleanup | `once-reduction` | Better change gating | Barrier pass |
| `ReReloop` | `re_reloop.mbt` | reconstruct structured control | legalization, cleanup | `relooper` family | Better integration when flatten-like rewrites are used | Specialized, not default |
| `LowerToExpr` | `lower_to_expr.mbt` | lower typed IR to plain expr form | support | lower/finalize support, not Binaryen optimize pass | None | Not part of optimize scheduling |
| `LiftToTexpr` | `lift_to_texpr.mbt` | lift code into typed IR | support | runner support, not Binaryen optimize pass | More stable benchmarking hooks around lift cost | Mandatory optimizer pre-step |

## Initial Binaryen Comparison Notes

- The default pipelines intentionally track Binaryen’s no-DWARF default ordering at a high level.
- The largest remaining parity gaps are not pass names. They are pass-internal cost models, analysis reuse, and change-summary gating.
- The most important currently explicit Binaryen-style omission in the default scheduler is still the absence of `string-gathering` in the global post pipeline.
- `ConstantFieldNullTestFolding` is an honest split from Binaryen’s broader `cfp-reftest`; Starshine currently covers the known-null subset only.
- `GUFAOptimizing` is a scheduler composite rather than a first-class standalone pass implementation.
- Several Starshine-specific modes are intentionally narrower or more debug-friendly than a direct Binaryen clone:
- `SimplifyLocals` has multiple exposed variants and local-validation salvage logic.
- `Vacuum` has degraded-mode fallback logic and indexed metadata caches that are Starshine-specific.
- The optimize runner already diverges from Binaryen by using scheduler segments and a stacked function executor, but it still lacks pass-summary metrics strong enough to justify schedule decisions empirically.

## Initial Cross-Pass Audit

### What currently looks strong

- The optimizer already has a real scheduler, not a flat pass loop.
- Several passes already carry useful internal timing and trace counters.
- `SimplifyLocals`, `Vacuum`, `LocalCSE`, `OptimizeInstructions`, `RemoveUnusedBrs`, and `CodeFolding` already expose the right cost centers for deeper work.
- The default pipeline generally has the right shape for cleanup after rewrite.
- The repo already has deep targeted regression coverage for the highest-risk passes.

### Current inefficiency risks by priority

- `SimplifyLocals` is the clearest hot-path target.
- Source evidence: `sinkables : Map[Int, SLSinkableInfo]`, `reads_by_local : Map[Int, Set[Int]]`, `writes_by_local : Map[Int, Set[Int]]`, repeated fixpoint cycles, structural effects caching, and local rewrite validation/salvage in the hot path.
- Expected impact: both runtime and size.
- Runtime: dense arrays, dirty-index clearing, fused summaries, and cheaper validation should materially reduce cost on large local-heavy functions.
- Size: better throughput makes it cheaper to keep the strong `SimplifyLocals` slots in the pipeline and to preserve exposed shrink opportunities for later `Vacuum` and `MergeBlocks`.
- `Vacuum` is the second clear target.
- Source evidence: whole-function shape scan, seed phase, optimize phase, final check, large indexed metadata cache, degraded fallback mode, and an unresolved correctness blocker.
- Expected impact: both runtime and size.
- Runtime: the pass needs less full-function reseeding and less subtree rebuilding.
- Size: better immediate cleanup after local/lowering passes directly affects final module size.
- `AlignmentLowering` is a smaller but high-signal cleanup target.
- Source evidence: pass-through logic exists for already-correct ops, but there is no visible module-level or function-level early exit in the runner contract; the pass still walks every function body.
- Expected impact: mostly runtime, with some secondary size benefit by reducing cleanup debt.
- `MergeBlocks`, `RemoveUnusedBrs`, and `CodeFolding` remain likely follow-on performance work.
- Source evidence: file size, repeated rounds, existing timing harnesses, and backlog timing numbers.
- Expected impact: mostly runtime first, with size wins if earlier canonicalization feeds them better.
- Scheduler gating is underdeveloped.
- Current state: only repeated no-op `Vacuum` is skipped.
- Missing: summaries for “locals changed”, “control structure changed”, “types changed”, “memory ops rewritten”, and “module graph changed”.

## Passes Most Likely To Need Immediate Engineering Work

### `SimplifyLocals`

- Current strengths:
- Broad behavior coverage, including result-structuring, tee formation, branch-value handling, late canonicalization, and local rewrite validation/salvage.
- Existing targeted regressions already cover `ID-C1` through `ID-F4`.
- Current inefficiencies:
- hot-path `Map[Int, ...]` and `Map[Int, Set[Int]]` usage where local bounds are known
- repeated cycle-level rescans and multiple helper traversals
- structural effect-cache lookup cost in the main rewrite path
- validation/salvage work performed inside the rewrite pipeline
- expensive work even on functions with no practical opportunity
- Planned durable fixes:
- array-backed local-index storage
- dirty-index clearing instead of full resets
- fused summary collection
- stronger per-function no-op prechecks
- staged validation for risky rewrites only
- benchmark coverage for dense locals, deep control, invalidation churn, and high-local-count stress

### `Vacuum`

- Current strengths:
- good cache instrumentation
- indexed metadata path for types, effects, break scans, and wrapper rebasing
- degraded mode to bound pathological cases
- Current inefficiencies:
- whole-function seed/optimize/final cycle even for mostly-clean functions
- conservative subtree rebuilding
- cost remains dominated by full-tree organization rather than parent-local reprocessing
- correctness blocker means some defensive logic is still broad and expensive
- Planned durable fixes:
- parent worklist or at least changed-node requeue model
- centralized purity/effect metadata reuse
- stronger cheap skip logic for no-op functions
- immediate cleanup-focused benchmarks

### `AlignmentLowering`

- Current strengths:
- correctness coverage is already broad
- aligned operations already pass through unchanged
- Current inefficiencies:
- no module-level “no memory ops” skip
- no function-level candidate summary
- lowering introduces wrapper debt that is deferred to later cleanup
- Planned durable fixes:
- module/function fast paths
- avoid rebuilding unaffected nodes
- stage cleanup so lowered patterns are friendlier to `Vacuum`

## Measurement Infrastructure Gaps

- Existing state:
- several individual passes emit timings and counters under trace
- `optimize.mbt` now reports runner-level pass start/done lines with changed status, function visit/change counts, instruction counts, and split transform vs validation timing
- there is no stable pass-metrics record returned or printed for branch-to-branch comparison
- Missing baseline infrastructure:
- full-pipeline emitted wasm size before/after from inside the optimizer runner
- one-command benchmark harness for single passes, full pipeline, and fixed corpora now lives behind `bun make benchmark-optimize`
- self-optimization benchmark command suitable for the user to run locally on large artifacts

### Benchmark Harness Commands

- Full default baseline on examples plus the existing optimized CLI artifact:
  `bun make benchmark-optimize --build-native-release --preset optimize --corpus examples --corpus dist-optimized`
- Single-pass or short sequence benchmark:
  `bun make benchmark-optimize --build-native-release --passes simplify-locals,vacuum --corpus dist-optimized`
- Spec-style fixed corpus:
  `bun make benchmark-optimize --build-native-release --preset optimize --corpus spec-sanity`
- User-run self-optimization-sized artifact:
  `bun make benchmark-optimize --build-native-release --preset optimize --corpus self-opt-debug`

The harness uses CLI trace output, reports per-input wasm byte deltas, aggregates per-pass elapsed time and change metrics, and supports repeated runs for branch-to-branch comparison. The `self-opt-debug` command is intentionally documented for user execution instead of being run automatically here.

## Current Benchmark Inputs Available In Repo

- `_build/wasm/debug/build/cmd/cmd.wasm`: main self-optimization-sized local artifact when built.
- `tests/node/dist/starshine-debug-wasi.wasm`
- `tests/node/dist/starshine-optimized-wasi.wasm`
- `tests/node/dist/starshine-self-optimized-wasi.wasm`
- `tests/spec/*.wast`: large external-style corpus for text-to-module batch measurements.
- `src/passes/merge_blocks_parity_wbtest.mbt`: existing fixed-corpus timing harness pattern worth reusing.

## Measurement And Refactor Plan

1. Extend `optimize.mbt` with stable pass-metric collection and trace emission.
2. Add a benchmark harness that can run one pass, the default function pipeline, and fixed corpora.
3. Capture a baseline on in-repo corpora before changing pass behavior.
4. Refactor `SimplifyLocals` first with red/green tests and microbenchmarks.
5. Refactor `Vacuum` next, then scheduling/gating, then `AlignmentLowering`.
6. Re-run the benchmark harness after each major change and append results here.

## Remaining Audit Work

- Fill in measured per-pass cost and size deltas after instrumentation lands.
- Update each high-priority pass section with implemented fixes and benchmark deltas.
- Add explicit scheduler gating recommendations backed by branch-local measurements.
- Compare non-default passes to Binaryen more deeply where they become active priorities.
- Keep this document as the source of truth for remaining pass work once the first refactors land.
