---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO core chain coverage refresh

Question: after the descriptor-loop slices, are the core repeated-store and wrong-local chain boundaries explicitly covered by focused Starshine tests?

## Coverage added

Added two focused HSO tests for Binaryen source/lit families that were already in Starshine's intended behavior surface:

- `heap-store-optimization folds repeated stores with the last value in the constructor`
  - Builds `local.set(struct.new)` followed by two `struct.set` writes to the same field on the same local.
  - Expects the final value to appear in the folded constructor, the earlier overwritten value to disappear, and no `struct.set` to remain.
- `heap-store-optimization keeps struct.set for a different target local`
  - Builds a fresh constructor in `local0`, but performs the later `struct.set` through `local1`.
  - Expects the `struct.set` to remain, locking the wrong-local no-fold boundary.

These are coverage-only additions for `[O4Z-AUDIT-HSO-C]`; no implementation behavior changed.

## Ref.cast descriptor probe note

A Binaryen probe for a descriptor operand shaped as exact descriptor `ref.cast` (`.tmp/hso-probe-desc-ref-cast-call.wat`) showed Binaryen `version_130` retaining the later `struct.set`:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-desc-ref-cast-call.wat \
  -o .tmp/hso-probe-desc-ref-cast-call.opt.wat
```

Observed grep included `struct.new_desc`, `ref.cast`, `global.get`, `struct.set`, and the moved-value `call`.

A matching Starshine focused test was attempted but removed because the current local direct instruction surface cannot express the exact target type for `ref.cast`; `Instruction::ref_cast(nullable, HeapType)` pretty-prints a non-exact target, and validation rejects that as a `struct.new_desc` descriptor operand. The binary CLI replay also failed to decode the exact-cast probe with `DecodeAt(InvalidS33Range, 71, 34)`. Treat descriptor exact `ref.cast` coverage as an open local surface/decode blocker, not a user-approved HSO behavior non-goal.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `67/67` passed.

No native rebuild or direct compare was required for this coverage-only slice because there was no implementation behavior change. The preceding descriptor-loop outer-branch behavior slice already has a post-handoff native build and green direct 10000-case compare in `0788`.

## Remaining risk

`[O4Z-AUDIT-HSO-C]` still needs a broader review against the dedicated Binaryen lit chain cases before it can close. Descriptor exact casts remain open due to local representation/decode limits; broader descriptor casts, `br_on_cast` / `br_on_cast_fail`, trapping descriptor-producing expressions, later-field barriers, target/control hazards, and O4z slot/neighborhood evidence remain active audit work.
