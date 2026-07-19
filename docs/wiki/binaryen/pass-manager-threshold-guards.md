---
kind: decision
status: supported
last_reviewed: 2026-07-19
sources:
  - ../../../src/passes/pass_manager.mbt
  - ../../../src/passes/pass_manager_threshold_wbtest.mbt
  - ../../../src/passes/remove_unused_brs_test.mbt
  - ../../../src/passes/simplify_locals_test.mbt
  - ../../../src/passes/perf_test.mbt
related:
  - ./passes/remove-unused-brs/index.md
  - ./passes/simplify-locals/index.md
  - ./passes/late-pipeline-dispatch.md
---

# Pass-Manager Threshold Guards

## Policy

`src/passes/pass_manager.mbt` contains numeric gates for three different purposes. They must not be treated interchangeably.

| Class | Meaning | Change rule |
| --- | --- | --- |
| **Correctness** | Avoids a path whose lowering, validation, stack-shape, or unchecked-execution assumptions are not proved for the matched shape. | Widen only after a red-first semantic/validation fixture and proof that the formerly excluded path is valid. |
| **Performance** | Avoids expensive lift, analysis, rewrite, validation, or nested cleanup for an empirically no-op or disproportionately costly shape. The original function/module is preserved. | Widen or remove only with behavior tests plus pass-local/artifact timing. |
| **Algorithmic bound** | Bounds an internal search, fixed point, signature probe, or local rewrite window. It is part of the algorithm rather than a pass-level skip policy. | Test with the owning transform; do not classify it as a module/function skip merely because it is numeric. |

Threshold traces for audited `remove-unused-brs` and `simplify-locals` guards append `guard=correctness` or `guard=performance` after the stable `reason=...` token. Unclassified ordinary no-candidate and other pass traces remain unchanged.

## Inventory

### Cross-pass and dispatcher gates

| Owner | Gate | Class | Current purpose |
| --- | --- | --- | --- |
| Vacuum nested value cleanup | visited nodes `> 2048` | Performance/resource | Stops broad nested value-expression traversal; large functions rely on raw vacuum preclean plus root-region HOT cleanup. |
| `dead-code-elimination` | defined locals `> 1000` | Performance | Skips the HOT path for the existing large-local no-op family and traces `large-local-dce-noop`. |
| `merge-blocks` | locals `> 128` and instructions `> 1000` | Performance | Avoids the known large local-heavy artifact no-op family. |
| `code-pushing` | locals `> 128` and instructions `> 1000`; broader fallback locals `> 512` or instructions `> 5000` | Performance | Bounds expensive raw/HOT admission for large lowered bodies. |
| `optimize-instructions` coarse facts | locals `> 1024`; or locals `> 64` and instructions `> 500`, plus narrower structured count envelopes | Performance with explicit parity reopening criteria | Represents raw no-op boundaries, not Binaryen transforms. The `RawOiCoarseNoopSkipFact` comment owns the reopening rule. |
| Oversized-local repair | locals `> 50000` | Performance/resource | Selects only extreme definitions for a dedicated coalesce-locals repair lane. |
| DAE nested cleanup | touched count `> 8`; module functions `> 100`; touched locals `> 128` or instructions `> 1000` | Performance, active backlog | Avoids artifact-scale nested reruns. `[O4Z-DAE]001` / `[O4Z-NESTED]001` still require narrowing or removing these guards with evidence. |
| SGO nested cleanup | touched locals `> 192` or instructions `> 1000` | Performance, active nested-scheduler boundary | Filters expensive touched functions while separately recognizing large unreachable tails. |

The fixed-point limits such as `pass_count < 3`, bounded signature collection lengths, minimum pattern lengths, and local transform arity limits are algorithmic bounds. They remain owned by their individual transforms and are not pass-level skip guards covered by `[AUDIT]002`.

### `remove-unused-brs`

The raw RUB gate matrix is an empirical no-op recognizer. “Large” and “moderate” numbers describe measured artifact families; they are not WebAssembly semantics. The SIMD parser and unchecked call-mesh families are correctness/writeback guards.

| Stable trace reason / helper | Primary threshold boundary | Class |
| --- | --- | --- |
| `large-result-br-table-dispatch-ladder-noop` | leading void-block depth `>= 32`, blocks `>= 32`, one `br_table` | Performance |
| `large-value-if-branch-ladder-noop` | locals `1..4`, roots `<= 2`, depth `>= 8`, instructions `600..3000` | Performance |
| `large-drop-heavy-branch-ladder-noop` | locals `400..550`, instructions `1600..8000`, bounded call/set/tee/if/block/branch/drop envelope | Performance |
| `large-typed-br-table-encoder-ladder-noop` | locals `1024..5000`, depth `>= 32`, instructions `3000..200000` | Performance |
| `large-void-if-return-ladder-noop` | locals `>= 700`, instructions `>= 4000`, call/set/tee/if/return minima | Performance |
| `moderate-control-ladder-noop` | locals `180..700` and one of two bounded control envelopes | Performance |
| `structured-return-ladder-noop` | locals `20..96`, instructions `80..1200`, bounded return/control envelope | Performance |
| `unique-loop-select-return-ladder-noop` | locals `48..64`, instructions `140..480`, exact one-loop/one-select/one-`br_if` shape | Performance |
| `large-local-dispatch-noop` | locals `> 96`, instructions `> 1000`, nested dispatch depth `>= 12` with at least eight `br_if`s | Performance |
| `refcount-payload-parser-noop` | O4z, locals `>= 128`, calls `>= 8`, sets `>= 20`, `if`s `>= 4` | Performance |
| `simd-parser-br-table-stack-hazard-noop` | locals `20..40`, instructions `8000..20000`, bounded parser-stack-switch envelope | Correctness |
| `unchecked-moderate-call-mesh-noop` | final validation disabled; locals `24..96`, instructions `400..640`, bounded call/control envelope, no child-value-if or prefix-guard candidate | Correctness |

`pass_manager_threshold_wbtest.mbt` locks strict/inclusive edges for large local dispatch, O4z refcount parsing, SIMD parser hazards, and unchecked call meshes. Existing public/performance tests lock the emitted RUB reasons for the larger fixture families.

### `simplify-locals`

The module cutoff and named artifact-shape envelopes are performance policy. `root-local-set-stack-hazard-noop` and `unchecked-small-structured-call-mesh-noop` are correctness boundaries. The validator-heavy names are still performance guards: they preserve the original function to avoid costly or unprofitable processing rather than accepting invalid output.

| Family | Primary boundaries | Class |
| --- | --- | --- |
| Whole module | defined functions `>= 2048` | Performance |
| Raw ladder rewrite admission | locals `16..512`, structured control, instructions `<= 12000`, then large/small/sparse density minima | Performance admission |
| Giant generic function | locals `>= 1500`, structured control, instructions `>= 2000` | Performance |
| Giant structured call-heavy | locals `>= 352`, instructions `>= 256`, `if >= 80`, sets `>= 176`, gets `>= 384`, calls `>= 240` | Performance |
| Giant structured local churn | locals `>= 600`, instructions `>= 1500`, `if >= 96`, sets `>= 384`, gets `>= 768`, calls `16..96` | Performance |
| Giant validator call-heavy | locals `>= 1024`, instructions `>= 8000`, `if >= 256`, blocks `>= 64`, loops `>= 4`, sets/calls `>= 1024`, gets `>= 2048` | Performance |
| Unchecked small call mesh | locals `<= 8`, instructions `192..384`, bounded structured call/control envelope, exact tails `0` | Correctness |
| Root stack hazard | structure/size-sensitive stack hazard, including locals `>= 16` or instructions `>= 128`; global-state sibling locals `>= 64` or instructions `>= 512` | Correctness |
| Remaining named parser/decode/encode/transformer/branch-dense/block-rich/call-dense/low-local/multivalue envelopes | Exact ranges live in adjacent `*_stats` predicates and are classified by stable trace reason | Performance |

The white-box threshold suite locks `2047/2048/2049`, `1499/1500`, `1999/2000`, unchecked `8/9` and `191/192`, and giant-validator `1023/1024` boundaries. Existing `simplify_locals_test.mbt` and `perf_test.mbt` fixtures continue to protect actual rewrite/skip behavior and trace routing.

## Maintenance Rules

1. Give every new pass-level numeric skip a stable reason and a declared correctness/performance class.
2. Add a bounded `threshold - 1`, `threshold`, and `threshold + 1` test for the primary size boundary. Use pure stats tests for artifact-scale shapes; do not add giant synthetic modules to the default suite merely to count instructions.
3. A correctness guard needs semantic/validation evidence before widening. A performance guard needs behavior plus timing evidence.
4. Keep ordinary “no candidates” fast paths unclassified unless they also impose a size/shape threshold.
5. Update this page, the classifier, and the owning pass dossier together when a guard is added, removed, or reclassified.

## Sources

- Runtime policy and trace classification: [`../../../src/passes/pass_manager.mbt`](../../../src/passes/pass_manager.mbt)
- Focused pure boundary tests: [`../../../src/passes/pass_manager_threshold_wbtest.mbt`](../../../src/passes/pass_manager_threshold_wbtest.mbt)
- RUB public trace/behavior tests: [`../../../src/passes/remove_unused_brs_test.mbt`](../../../src/passes/remove_unused_brs_test.mbt) and [`../../../src/passes/perf_test.mbt`](../../../src/passes/perf_test.mbt)
- SimplifyLocals public trace/behavior tests: [`../../../src/passes/simplify_locals_test.mbt`](../../../src/passes/simplify_locals_test.mbt) and [`../../../src/passes/perf_test.mbt`](../../../src/passes/perf_test.mbt)
