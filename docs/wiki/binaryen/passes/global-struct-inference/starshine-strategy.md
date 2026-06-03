---
kind: concept
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md
  - ../../../raw/research/0529-2026-05-06-global-struct-inference-direct-revalidation.md
  - ../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md
  - ../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md
  - ../../../../../src/passes/global_struct_inference.mbt
  - ../../../../../src/passes/global_struct_inference_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-analysis-and-unnesting.md
  - ./wat-shapes.md
  - ./parity.md
  - ./starshine-hot-ir-strategy.md
  - ../global-struct-inference-desc-cast/index.md
  - ../global-refining/index.md
  - ../ssa-nomerge/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine strategy for `global-struct-inference`

Use this page with the upstream contract in [`./binaryen-strategy.md`](./binaryen-strategy.md), the source/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), the shape catalog in [`./wat-shapes.md`](./wat-shapes.md), the closed-world/un-nesting guide in [`./closed-world-analysis-and-unnesting.md`](./closed-world-analysis-and-unnesting.md), and the current local implementation detail page in [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md).

## Current Starshine status

`global-struct-inference` is an **active module pass** in Starshine. After the 2026-06-03 O4z audit plus the follow-up closed-world fact, exact single-candidate, one-value multi-candidate, two-value singleton-group, subtype-propagated supertype-value, un-nesting/descriptor, and subtype-propagated origin slices, it implements the upstream **open-world direct immutable-global** subset, builds a subtype-aware closed-world candidate/poison fact table, consumes exact and subtype-propagated single-candidate local/param origin rewrites when the replacement global has a validation-safe reference type, folds exact and subtype-propagated local/param reads when every safe candidate yields the same materializable field value, and emits exact or subtype-propagated `select(ref.eq(...))` rewrites when two materializable values have one singleton candidate group. It is still narrower than full Binaryen closed-world `gsi` origin rewriting.

The local pass does all of these today:

- accepts the `closed_world` dispatcher flag but does not require it for the direct-global fast path
- scans only defined immutable globals as direct-global candidate sources
- in closed-world mode, builds an internal candidate-global/poison fact table that includes immutable top-level origins, excludes mutable and too-broad global declarations, poisons function-local allocations, poisons nested global-initializer allocations, propagates poisoned child types to parents, and propagates child candidates upward to parent types
- in closed-world mode, rewrites exact or parent/supertype local/param `struct.get*` origins when there is one safe candidate and the candidate global's declared reference heap type is a subtype of the read type
- in closed-world mode, folds exact or parent/supertype local/param `struct.get*` reads to a single materializable value when safe direct or subtype-propagated candidates all expose the same field payload after packed-field repair
- in closed-world mode, synthesizes exact or parent/supertype local/param two-value `select(ref.eq(...))` rewrites when exactly two materializable field values exist and one value group has exactly one candidate global
- accepts top-level `struct.new*` initializer families
- materializes a small value vocabulary (`i32`, `v128`, `ref.null`, `ref.func`, `global.get`, `string.const`, default values)
- rewrites only immediate `global.get` + `struct.get*` instruction pairs, including open-world direct-global reads
- preserves nullable-trap behavior with `ref.as_non_null` plus either `drop` for value/origin folds or the `ref.eq` condition path for two-value selects
- rebuilds changed functions only

It now uses subtype-propagated facts for parent-typed origin rewrites, one-value folds, and singleton-tested two-value rewrites. Parent/supertype origin rewrites are deliberately guarded by the candidate global's declared reference heap type so too-broad `eqref` globals remain unchanged instead of producing invalid `struct.get*` operands. Small modules support un-nesting of selected pure non-constant field operands into fresh immutable globals plus reorder-globals repair, but large modules deliberately keep the materializable-only path to preserve pass-local runtime.

The 2026-06-03 O4z audit revalidation kept the upgraded subset semantically green against Binaryen under the refreshed harness: 9975 / 10000 compared cases, 9975 normalized matches, and 0 mismatches, with 25 Binaryen/tool command failures. The audited debug artifact was canonical-equal and Starshine was faster pass-local (`0.349 ms` versus Binaryen `2.815 ms`). The exact single-candidate local/param follow-up also stayed green at 9975 / 10000 compared, 0 mismatches, and canonical-equal debug-artifact timing with Starshine/Binaryen pass-local `0.371 ms` / `5.017 ms`. The one-value multi-candidate follow-up used a prebuilt native Starshine binary plus `--jobs auto`, stayed green at 9975 / 10000 compared with 0 mismatches and 25 Binaryen/tool command failures, and kept the debug artifact canonical-equal with Starshine/Binaryen pass-local `0.440 ms` / `3.275 ms`. The two-value singleton-group follow-up used the same explicit native parallel lane, stayed green at 9975 / 10000 compared with 0 mismatches and 25 Binaryen/tool command failures, and kept the debug artifact canonical-equal with Starshine/Binaryen pass-local `0.695 ms` / `3.087 ms`. The subtype-propagated parent one/two-value follow-up also used `--jobs auto` plus the prebuilt native binary, stayed green at 9975 / 10000 compared with 0 mismatches and 25 Binaryen/tool command failures, and kept the debug artifact canonical-equal with Starshine/Binaryen pass-local `0.376 ms` / `3.106 ms`. The subtype-propagated origin follow-up again reached 9975 / 10000 compared, 9975 normalized matches, 0 mismatches, and 25 known Binaryen/tool command failures; the debug artifact was canonical-equal with Starshine/Binaryen pass-local `0.356 ms` / `2.827 ms`.

## Exact local code map

| Surface | Why it matters |
| --- | --- |
| `src/passes/global_struct_inference.mbt:2` | summary string and local user-facing description |
| `src/passes/global_struct_inference.mbt:20-460` | closed-world fact table, allocation poisoning, safe candidate-origin filters, subtype poison/candidate propagation, exact direct candidate extraction, and exact single-candidate extraction |
| `src/passes/global_struct_inference.mbt:530-1088` | guarded small-module un-nesting request collection, fresh-global synthesis, initializer repair, and forced reorder-globals repair |
| `src/passes/global_struct_inference.mbt:1091-1186` | candidate field-value harvesting from trusted global initializers and accepted top-level global initializer families |
| `src/passes/global_struct_inference.mbt:1189-2059` | exact/subtype-propagated local/param origin helpers, exact and subtype-aware one-value local fold helpers, exact and subtype-aware two-value singleton-group select helpers, folded global-field expression builders, candidate-subtype checks, and packed-field repair |
| `src/passes/global_struct_inference.mbt:2063-2287` | recursive body walk that rewrites immediate `global.get` + `struct.get*` pairs, exact/subtype-propagated single-candidate `local.get` + `struct.get*` origin pairs, exact/subtype-propagated one-value local folds, and exact/subtype-propagated two-value singleton-group local selects |
| `src/passes/global_struct_inference.mbt:2290-2504` | cheap pre-scan used to skip unchanged functions |
| `src/passes/global_struct_inference.mbt:2507-2606` | public module-pass entrypoint; builds closed-world exact single-candidate and propagated candidate facts when requested, then runs direct-global and local-origin/value/select rewrites |
| `src/passes/global_struct_inference_test.mbt:28-621` | open-world direct-global positives, nullable-trap preservation, packed/default/descriptor constructor coverage, unsafe-global negatives, exact single-candidate local/param positives, exact/subtype-propagated one-value and two-value local positives, and open-world/ambiguous/non-materializable/poisoned/unsafe local-origin negatives |
| `src/passes/global_struct_inference_wbtest.mbt:1-240` | white-box closed-world fact-table coverage for top-level candidates, mutable/anyref exclusions, function-local poisoning, nested-global poisoning, subtype poison propagation, no-global-section poison propagation, and upward candidate propagation/order |
| `src/passes/pass_manager.mbt:12308-12309` | module-pass dispatch into `global_struct_inference_run_module_pass(mod_, options.closed_world)` |
| `src/passes/optimize.mbt:279-280` | registry entry and summary wiring |
| `src/passes/optimize.mbt:310` | `optimize` preset placement after `global-refining` |
| `src/passes/optimize.mbt:326` | `shrink` preset placement after `global-refining` |

## What the local pass does today

### 1. It runs the direct-global fold in open world

The current Starshine entrypoint runs the direct immutable-global fold even when `closed_world` is false.
This closes the largest old narrowing versus Binaryen for the direct-global fast path. The pass now also constructs a closed-world fact table when `closed_world` is true and consumes exact-type single-candidate facts for local/param origin rewrites plus exact and subtype-propagated facts for one-value and two-value local/param rewrites.

### 2. It only trusts a tiny origin family

The local direct rewrite still accepts only defined immutable globals whose values are visibly constructed in the initializer.
The closed-world analysis now builds the first local `typeGlobals`-shaped fact table: top-level immutable candidate globals are grouped by created struct type, mutable and equality-incomparable global declarations are excluded, function-local `struct.new*` allocations poison their type, nested non-top-level global-initializer `struct.new*` allocations poison their type, poisoned child types poison parents, and child candidate globals propagate upward to parent types in deterministic global-index order. It now reasons about locals and params for exact and subtype-propagated single-candidate origin rewrites, exact and subtype-propagated one-value folds, and exact and subtype-propagated two-value singleton-group selects.

### 3. It rewrites only the immediate read pair

The local rewrite surface is still adjacent-pair shaped. It handles the direct pair:

```wat
(global.get $g)
(struct.get* ...)
```

and, in closed world only, exact-type local/param pairs:

```wat
(local.get $x)
(struct.get* ...)
```

by either replacing the local reference operand with a trap-preserving block that yields one safe exact or subtype-propagated global candidate, consuming the pair and yielding one shared materializable value after preserving the original null trap, or consuming the pair and yielding a typed `select` guarded by `ref.eq` against the singleton candidate global. The origin, value, and select paths can consume subtype-propagated parent candidate sets; the pass still does not rewrite arbitrary operands or un-nest large-module nested operands into fresh globals.

### 4. It preserves null traps explicitly

Nullable globals and one-value local folds still emit the original reference plus `ref.as_non_null` and `drop` before the folded value. Two-value local selects put the original local reference through `ref.as_non_null` on the `ref.eq` condition path before selecting between materialized values. That keeps the visible trap behavior honest even though the analysis is narrow.

### 5. It is cheap-scan first, rebuild-on-change

The pass pre-scans for rewrite candidates, rebuilds only changed functions, and returns the original module unchanged when nothing matches.

## What the local pass does not do

Compared with upstream Binaryen `version_129`, Starshine currently does **not** implement:

- full closed-world `typeGlobals` candidate consumption beyond exact/subtype-propagated local/param one-global origins and exact or subtype-propagated one-value/two-value direct-candidate rewrites
- sibling `gsi-desc-cast` rewrites
- explicit `ReFinalize`-style repair after type refinement beyond validation-preserving replacement typing
- atomic-get-specific proof families, because no local struct atomic-get opcode exists yet
- unbounded large-module un-nesting; the local un-nesting/ref.get_desc surfaces are guarded to small modules to keep the debug artifact pass-local budget green

Those are real capability gaps, not just documentation wording differences.

## Why the gap matters

The local pass is already useful for the saved artifact slot and for a small direct-global contract.
But it should not be described as if it were the full upstream `gsi` algorithm.

The upstream contract is about trusted origin restriction plus value grouping, not just a direct constant fold.

## Porting order for future expansion

If Starshine grows toward the full Binaryen contract, preserve the current subset while adding the missing layers in this order:

1. broaden non-constant operand un-nesting beyond the current small-module pure-scalar/read-gated subset only if pass-local runtime remains green
2. implement the sibling `gsi-desc-cast` pass only as a separately scheduled boundary-to-active slice
3. add atomic-get family coverage after Starshine has a local struct atomic-get opcode surface
4. add explicit typed-AST repair/refinalization if future rewrites need more than validation-preserving replacement typing

## Related pages

- [`./index.md`](./index.md) - folder overview
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - upstream algorithm and current-main freshness layer
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - owner-file, helper, lit-test, and local code-map detail
- [`./closed-world-analysis-and-unnesting.md`](./closed-world-analysis-and-unnesting.md) - hard upstream analysis half
- [`./wat-shapes.md`](./wat-shapes.md) - concrete before/after shapes
- [`./parity.md`](./parity.md) - current compare state and remaining gaps
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) - current local implementation detail page
- [`../global-struct-inference-desc-cast/index.md`](../global-struct-inference-desc-cast/index.md) - sibling descriptor-cast pass dossier
- [`../global-refining/index.md`](../global-refining/index.md) - nearby scheduler neighbor
- [`../ssa-nomerge/index.md`](../ssa-nomerge/index.md) - later local-cleanup neighbor

## Sources

- [`../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md`](../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md)
- [`../../../raw/research/0529-2026-05-06-global-struct-inference-direct-revalidation.md`](../../../raw/research/0529-2026-05-06-global-struct-inference-direct-revalidation.md)
- [`../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md`](../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md)
- [`../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md`](../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md)
- [`../../../raw/research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md`](../../../raw/research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md)
- [`../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md`](../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md)
- [`../../../../../src/passes/global_struct_inference.mbt`](../../../../../src/passes/global_struct_inference.mbt)
- [`../../../../../src/passes/global_struct_inference_test.mbt`](../../../../../src/passes/global_struct_inference_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
