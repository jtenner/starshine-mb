---
kind: research
status: supported
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0844-2026-06-20-heap-store-optimization-cross-family-store-swap.md
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO `br_table` swap wrapper coverage

Question: do Binaryen `version_130` and Starshine treat `br_table`-ending wrapper roots like the previously covered branch-containing wrappers for `heap-store-optimization` swap legality?

## Answer

Yes for the probed surfaces.

- Binaryen folds a fresh-struct store when a constructor `memory.size` operand must cross a `block` root that performs an ordinary cross-family `table.set` and then exits through `br_table`.
- Binaryen keeps the later `struct.set` when a constructor `memory.size` operand would need to cross a `block` root that performs same-effect-family `memory.fill` and then exits through `br_table`.
- Starshine already matched both observed behaviors. This slice added focused coverage only; no implementation change was needed.

This narrows HSO-G's HOT wrapper-peeling surface for explicit `br_table` wrappers without changing the broader rule: cross-family ordinary stores can be crossed when their effects are unordered with the constructor operand, while same-effect-family memory/table bulk roots remain no-fold barriers.

## Binaryen probes

Local oracle:

```text
wasm-opt version 130 (version_130)
```

Probe commands:

```sh
wasm-opt --all-features --heap-store-optimization -S .tmp/hso-br-table-wrapper-probe2/memory-size-table-set-br-table.wat -o .tmp/hso-br-table-wrapper-probe2/memory-size-table-set-br-table.opt.wat
wasm-opt --all-features --heap-store-optimization -S .tmp/hso-br-table-wrapper-probe2/memory-size-memory-fill-br-table.wat -o .tmp/hso-br-table-wrapper-probe2/memory-size-memory-fill-br-table.opt.wat
grep -E 'memory.size|table.set|struct.set|struct.new|br_table' .tmp/hso-br-table-wrapper-probe2/memory-size-table-set-br-table.opt.wat
grep -E 'memory.size|memory.fill|struct.set|struct.new|br_table' .tmp/hso-br-table-wrapper-probe2/memory-size-memory-fill-br-table.opt.wat
```

Observed optimized markers:

```text
--- positive ---
   (table.set $t
   (br_table $exit $exit
   (struct.new $pair
    (memory.size)
--- negative ---
   (struct.new $pair
    (memory.size)
   (memory.fill
   (br_table $exit $exit
  (struct.set $pair 1
```

Interpretation:

- The cross-family ordinary-store wrapper preserved `table.set` and `br_table`, removed `struct.set`, and folded the later field value into `struct.new`.
- The same-effect-family memory-fill wrapper preserved `memory.fill`, `br_table`, and `struct.set`.

## Starshine coverage

Added focused tests in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds memory.size constructors across br_table-wrapped table stores`
- `heap-store-optimization keeps memory.size constructors before br_table-wrapped memory.fill`

The first test proves the positive cross-family ordinary-store `br_table` wrapper surface. The second proves the same-effect-family memory-bulk barrier still blocks the fold through a `br_table` wrapper.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 197, passed: 197, failed: 0.
```

No native rebuild or direct compare was run because this was coverage-only and changed no implementation behavior.

## Follow-up

HSO-G remains open. Remaining useful coverage should avoid repeating already-covered wrappers and instead probe distinct swap operands/effect families or harder control-flow roots. Final closeout still needs early/late O4z slot evidence, the final direct 100000-case compare, and explicit boundary wording for any accepted non-goal.
