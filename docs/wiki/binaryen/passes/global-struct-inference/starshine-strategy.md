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

`global-struct-inference` is an **active module pass** in Starshine. After the 2026-06-03 O4z audit, it implements the upstream **open-world direct immutable-global** subset, but it is still much narrower than full Binaryen closed-world `gsi` origin reasoning.

The local pass does all of these today:

- accepts the `closed_world` dispatcher flag but does not require it for the direct-global fast path
- scans only defined immutable globals as candidate sources
- accepts top-level `struct.new*` initializer families
- materializes a small value vocabulary (`i32`, `v128`, `ref.null`, `ref.func`, `global.get`, `string.const`, default values)
- rewrites only immediate `global.get` + `struct.get*` instruction pairs, including open-world direct-global reads
- preserves nullable-trap behavior with `ref.as_non_null` + `drop`
- rebuilds changed functions only

It does **not** yet implement the broader upstream origin-analysis contract.

The 2026-06-03 O4z audit revalidation kept the upgraded subset semantically green against Binaryen under the refreshed harness: 9975 / 10000 compared cases, 9975 normalized matches, and 0 mismatches, with 25 Binaryen/tool command failures. The audited debug artifact was canonical-equal and Starshine was faster pass-local (`0.349 ms` versus Binaryen `2.815 ms`).

## Exact local code map

| Surface | Why it matters |
| --- | --- |
| `src/passes/global_struct_inference.mbt:2` | summary string and local user-facing description |
| `src/passes/global_struct_inference.mbt:110` | candidate field-value harvesting from trusted global initializers |
| `src/passes/global_struct_inference.mbt:152` | accepted top-level global initializer families |
| `src/passes/global_struct_inference.mbt:250` | folded global-field expression builder and packed-field repair |
| `src/passes/global_struct_inference.mbt:310` | recursive body walk that rewrites immediate `global.get` + `struct.get*` pairs |
| `src/passes/global_struct_inference.mbt:419` | cheap pre-scan used to skip unchanged functions |
| `src/passes/global_struct_inference.mbt:497` | public module-pass entrypoint for the open-world direct-global subset |
| `src/passes/global_struct_inference_test.mbt:28-242` | open-world direct-global positives, nullable-trap preservation, packed/default/descriptor constructor coverage, unsafe-global negatives, and non-global producer negative test |
| `src/passes/pass_manager.mbt:12308-12309` | module-pass dispatch into `global_struct_inference_run_module_pass(mod_, options.closed_world)` |
| `src/passes/optimize.mbt:279-280` | registry entry and summary wiring |
| `src/passes/optimize.mbt:310` | `optimize` preset placement after `global-refining` |
| `src/passes/optimize.mbt:326` | `shrink` preset placement after `global-refining` |

## What the local pass does today

### 1. It runs the direct-global fold in open world

The current Starshine entrypoint runs the direct immutable-global fold even when `closed_world` is false.
This closes the largest old narrowing versus Binaryen for the direct-global fast path, while leaving the broader closed-world candidate-map analysis unimplemented.

### 2. It only trusts a tiny origin family

The local pass only accepts defined immutable globals whose values are visibly constructed in the initializer.
It does not build Binaryen's `typeGlobals` map, propagate candidate globals up a subtype graph, or reason about locals and params as origins.

### 3. It rewrites only the immediate read pair

The local rewrite surface is the direct adjacent pair:

```wat
(global.get $g)
(struct.get* ...)
```

It does not currently rewrite arbitrary operands, select between two values, or un-nest nested operands into fresh globals.

### 4. It preserves null traps explicitly

Nullable globals still emit the original reference plus `ref.as_non_null` and `drop` before the folded value.
That keeps the visible trap behavior honest even though the analysis is narrow.

### 5. It is cheap-scan first, rebuild-on-change

The pass pre-scans for rewrite candidates, rebuilds only changed functions, and returns the original module unchanged when nothing matches.

## What the local pass does not do

Compared with upstream Binaryen `version_129`, Starshine currently does **not** implement:

- closed-world `typeGlobals` candidate analysis
- subtype poisoning and upward candidate propagation
- local/param-origin rewrites
- one-vs-two-unique-value `select(ref.eq(...))` synthesis
- non-constant operand un-nesting into fresh globals
- `ref.get_desc`
- sibling `gsi-desc-cast` rewrites
- explicit `ReFinalize`-style repair after type refinement
- atomic-get-specific proof families

Those are real capability gaps, not just documentation wording differences.

## Why the gap matters

The local pass is already useful for the saved artifact slot and for a small direct-global contract.
But it should not be described as if it were the full upstream `gsi` algorithm.

The upstream contract is about trusted origin restriction plus value grouping, not just a direct constant fold.

## Porting order for future expansion

If Starshine grows toward the full Binaryen contract, preserve the current subset while adding the missing layers in this order:

1. closed-world candidate-global reasoning for local and param reads
2. subtype poisoning and upward propagation
3. one-vs-two unique value `select` synthesis
4. non-constant operand un-nesting
5. `ref.get_desc`, descriptor-cast, and atomic-get family coverage
6. explicit typed-AST repair/refinalization

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
