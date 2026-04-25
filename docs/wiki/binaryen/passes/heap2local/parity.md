---
kind: comparison
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md
  - ../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md
  - ../../../raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md
  - ../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md
  - ../../../raw/research/0135-2026-04-20-heap2local-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./validation-fixups-and-special-cases.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../../../../../src/passes/heap2local.mbt
  - ../../../../../src/passes/heap2local_test.mbt
  - ../../../../../src/passes/heap2local_primary_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
---

# `heap2local` Binaryen Parity

## Durable Conclusions

- Binaryen `version_129` rewrites exclusive, nonescaping struct allocations and small eligible arrays into scalar locals.
- Arrays only enter the transform when the size is constant and `< 20`, the element type is local-representable, and indexed traffic stays constant.
- Safe flow-through cases include direct local owners, exclusive local-copy chains, direct tees, simple block or loop result flow, `ref.as_non_null`, `ref.eq`, `ref.test`, successful `ref.cast`, and descriptor-bearing `ref.get_desc` cases.
- Immediate Binaryen bailout families include escapes through calls or returns, mixed local provenance, `if`-mediated value mixing, and nonconstant array sizes or indexes. Do **not** list atomic array access as a generic upstream bailout: the source-backed Binaryen contract has atomic/RMW/cmpxchg handling when nonescape and exclusivity are proven, even though current Starshine's direct-array subset is narrower.
- Binaryen runs the array lowering first, then the struct rewrite, and each invocation is intentionally single-iteration.
- A 2026-04-25 current-main/code-map refresh found no teaching-relevant drift beyond the already-recorded narrow array/cmpxchg/unreachable-`ref.test` caveat and added the source/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

## Current In-Tree Status

- The explicit implementation lives in [`../../../../../src/passes/heap2local.mbt`](../../../../../src/passes/heap2local.mbt).
- Focused coverage lives in [`../../../../../src/passes/heap2local_test.mbt`](../../../../../src/passes/heap2local_test.mbt).
- The Binaryen-aligned primary suite lives in [`../../../../../src/passes/heap2local_primary_test.mbt`](../../../../../src/passes/heap2local_primary_test.mbt).
- Preset scheduling coverage lives in [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt).

The current Starshine slice covers the full in-tree primary suite:

- direct exclusive struct owners, local-copy chains, tees, and simple block-result flow
- `ref.as_non_null`, direct `ref.eq`, and successful `ref.cast`
- descriptor-bearing `struct.new_desc` and `struct.new_default_desc` plus `ref.get_desc`
- constant-size `array.new_default`, `array.new`, and `array.new_fixed`
- constant-index `array.get`, `array.get_s`, `array.get_u`, and `array.set`
- direct array `ref.test`
- bailout on parameter-backed mixed provenance

## Remaining Gap

- The remaining documented Binaryen gap is the non-nullable-local and refinalization fixup work Binaryen performs after successful rewrites.
- Wider no-DWARF optimize-path parity still depends on neighboring passes such as `optimize-casts`, `local-subtyping`, `coalesce-locals`, and `local-cse`.

## Current Evidence

- A `2026-04-11` `--pass heap2local` smoke rerun (200 mixed cases, `seed 0x5eed`) reports:
  - `199 / 200` compared
  - `199` normalized matches
  - `1` command failure (`binaryen-rec-group-zero`, `case-000029-wasm-smith`)
  - `0` mismatches
- The `2026-04-03` `10000`-case `gen-valid` compare remains in `result` form as a historical full-lane benchmark (still valid but not yet refreshed this round).

## Sources

- Current source/code-map manifest: [`../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md`](../../../raw/binaryen/2026-04-25-heap2local-current-main-and-code-map.md)
- Current follow-up note: [`../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md`](../../../raw/research/0365-2026-04-25-heap2local-current-main-and-code-map.md)
- Implementation/test-map page: [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- Archived research doc: [`../../../raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md`](../../../raw/research/0075-2026-04-03-heap2local-binaryen-comparison.md)
- Supplemental health rerun: [`../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md`](../../../raw/research/0078-2026-04-11-parity-smoke-rerun.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Heap2Local.cpp>
- Implementation: [`../../../../../src/passes/heap2local.mbt`](../../../../../src/passes/heap2local.mbt)
- Focused tests: [`../../../../../src/passes/heap2local_test.mbt`](../../../../../src/passes/heap2local_test.mbt)
- Primary parity suite: [`../../../../../src/passes/heap2local_primary_test.mbt`](../../../../../src/passes/heap2local_primary_test.mbt)
