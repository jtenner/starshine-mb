---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0409-2026-04-26-type-ssa-port-readiness.md
  - ../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/typecheck.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./created-exact-types-control-values-and-signature-rewrites.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../type-merging/index.md
  - ../type-refining/index.md
---

# Starshine Port Readiness And Validation For `type-ssa`

Use this page after reading the corrected upstream strategy in [`./binaryen-strategy.md`](./binaryen-strategy.md) and the current local status in [`./starshine-strategy.md`](./starshine-strategy.md).

## Current decision point

Starshine should not accidentally implement a stale `type-ssa` model. A future port must target Binaryen's corrected allocation-subtype pass:

1. find selected GC allocation instructions,
2. prove their original heap types are not exact-observed,
3. prove the allocations are interesting,
4. create fresh private heap subtypes,
5. retag only the selected allocation results,
6. refinalize/validate all affected expression types.

That is module/type-section work. It is not a HOT-only local-flow rewrite and it is not the implemented [`../ssa-nomerge/index.md`](../ssa-nomerge/index.md) pass.

## Step 0: registry honesty

Today `type-ssa` is absent from every local pass registry lane:

- boundary-only names: [`src/passes/optimize.mbt#L127-L144`](../../../../../src/passes/optimize.mbt#L127-L144)
- removed names: [`src/passes/optimize.mbt#L147-L155`](../../../../../src/passes/optimize.mbt#L147-L155)
- active entries and presets: [`src/passes/optimize.mbt#L158-L275`](../../../../../src/passes/optimize.mbt#L158-L275)

Before adding mutating code, choose one policy:

- keep it upstream-only and unknown,
- add a boundary-only entry with an explicit rejection message,
- or add an active experimental module pass with focused tests.

Do not add tests that expect Binaryen-compatible `--type-ssa` output while the registry still treats the name as unknown.

## Step 1: analyzer-only candidate discovery

The first useful implementation slice is a no-rewrite analyzer.

It should find these allocation families:

- `struct.new`,
- `struct.new_default`,
- `array.new`,
- `array.new_data`,
- `array.new_elem`,
- `array.new_fixed`.

Local prerequisite surfaces:

- instruction representation: [`src/lib/types.mbt#L734-L748`](../../../../../src/lib/types.mbt#L734-L748)
- constructor helpers: [`src/lib/types.mbt#L4050-L4103`](../../../../../src/lib/types.mbt#L4050-L4103)
- WAT lowering for struct allocation: [`src/wast/lower_to_lib.mbt#L2414-L2421`](../../../../../src/wast/lower_to_lib.mbt#L2414-L2421)
- type definition lowering, including subtype metadata: [`src/wast/lower_to_lib.mbt#L308-L429`](../../../../../src/wast/lower_to_lib.mbt#L308-L429)
- typechecker dispatch for struct/array allocation: [`src/validate/typecheck.mbt#L3276-L3294`](../../../../../src/validate/typecheck.mbt#L3276-L3294)

The analyzer should produce a reportable classification before it mutates anything: candidate, disallowed, uninteresting, unsupported module-code surface, or unsupported descriptor/describee surface.

## Step 2: exact-observation blockers

A fresh subtype is unsafe when code can observe exact heap identity. The analyzer must conservatively block old heap types that appear in exact-sensitive places:

- exact `ref.cast` targets,
- exact `ref.test` targets,
- exact function result types,
- exact global types,
- exact element-segment types,
- exact child constraints that force an original heap type to remain exact.

Validation tests should include both positive allocations and a same-module exact test/cast that prevents splitting the original type.

## Step 3: interestingness rules

Only split allocations that carry useful facts. Start with the source-backed families that are easiest to test:

- default struct construction,
- constants in struct fields or array elements,
- globals in fields or elements,
- an operand type narrower than the declared field/element type,
- `array.new_data` / `array.new_elem`,
- `array.new_fixed` only when all elements are interesting.

Negative tests should include boring operands, unreachable allocation sites, final types, open-disabled types, and descriptor/describee families.

## Step 4: type-section rewrite

The first mutating slice should be narrow: one private struct allocation type, no descriptors, no exact-observed old type, and no module-code table-initializer case.

Required behavior:

- append or rebuild a valid rec group containing the fresh private subtype,
- keep the old heap type available as the fresh subtype's supertype,
- preserve type names only as a non-semantic readability detail,
- avoid creating fresh types for final or non-open old types,
- keep `type-merging` / `remove-unused-types` interactions in mind but do not rely on them to repair invalid output.

## Step 5: allocation retagging and validation

The visible rewrite is at the allocation instruction, not at later `local.get`, `global.get`, call operand, or return sites.

After retagging:

- the allocation result should be exact non-null fresh type,
- parent expression types must still validate as subtypes of declared result contexts,
- globals, module code, and element segments must still typecheck,
- the output must roundtrip through WAT and binary paths before fuzzing.

## Binaryen oracle ladder

Use the official Binaryen fixture families before general fuzzing:

1. reduced `struct.new` fresh-subtype positive,
2. reduced default-constructor positive,
3. reduced refined-operand positive,
4. reduced `array.new_data` / `array.new_elem` positives,
5. reduced all-interesting `array.new_fixed` positive,
6. exact-observed old-type bailout,
7. final / non-open type bailout,
8. boring allocation bailout,
9. descriptor/describee bailout,
10. module-code/global/element-surface smoke.

Only after those pass should Starshine compare against `wasm-opt --type-ssa` and then run broad pass-targeted fuzzing.

## Explicit non-goals for the first port

The first Starshine slice should not attempt:

- stale created-type propagation through `local.get`, `global.get`, `block`, `if`, or `try` values,
- direct-call operand/result retagging from a remembered allocation map,
- table-initializer support before Binaryen's TODO surface is resolved or deliberately mirrored,
- descriptor/describee fresh subtype support,
- automatic preset insertion.

## Readiness summary

Starshine has enough GC instruction and validation plumbing to write analyzer tests today, but not enough dedicated infrastructure to claim a faithful port. The missing hard pieces are exact-observation analysis, valid fresh rec-group construction, allocation-result retagging, and refinalization-grade validation across function and module-code surfaces.
