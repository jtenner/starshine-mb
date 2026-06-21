---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0780-2026-06-20-heap-store-optimization-descriptor-global-call.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` mutable descriptor-global barrier coverage

Question: does Starshine match Binaryen `version_130` for descriptor constructor operands that read a **mutable** descriptor global when the later store value is either pure or call-valued?

## Answer

Yes. Binaryen distinguishes the moved value's effects:

- a pure moved value can still fold into `struct.new_desc` across a mutable descriptor `global.get`; and
- a call-valued moved value keeps the later `struct.set`, because moving the call before the mutable descriptor read would reorder potentially observable global state/effects.

Starshine already matched both shapes. This slice adds focused HSO-D/E coverage only; no implementation behavior changed.

## Binaryen `version_130` probes

Pure moved-value probe: `.tmp/hso-probe-mutable-desc-const.wat`.

```sh
wasm-opt --all-features \
  .tmp/hso-probe-mutable-desc-const.wat \
  --heap-store-optimization \
  -S \
  -o .tmp/hso-probe-mutable-desc-const.opt.wat

grep -n "struct.set\|struct.new_desc\|global.get\|i32.const 9" \
  .tmp/hso-probe-mutable-desc-const.opt.wat
```

Observed grep:

```text
11:   (struct.new_desc $pair
12:    (i32.const 9)
14:    (global.get $descg)
```

Binaryen removed the later `struct.set`, moved the pure `i32.const 9` into field `0`, and preserved the mutable descriptor global read as the descriptor operand.

Call-valued moved-value probe: `.tmp/hso-probe-mutable-desc-call.wat`.

```sh
wasm-opt --all-features \
  .tmp/hso-probe-mutable-desc-call.wat \
  --heap-store-optimization \
  -S \
  -o .tmp/hso-probe-mutable-desc-call.opt.wat

grep -n "struct.set\|struct.new_desc\|call\|global.get" \
  .tmp/hso-probe-mutable-desc-call.opt.wat
```

Observed grep:

```text
13:   (struct.new_desc $pair
16:    (global.get $descg)
19:  (struct.set $pair 0
21:   (call $helper
```

Binaryen preserved the `struct.set` because the call-valued store cannot be moved before the mutable descriptor global read.

Agent classification: source-backed Binaryen behavior. This is not an output-parity exception; Starshine should and does match the observable fold/no-fold split.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds store across mutable descriptor global when moved value is pure`; and
- `heap-store-optimization keeps descriptor store when mutable descriptor global orders before moved call`.

Both tests passed on first run, confirming this was coverage-only progress.

## Validation

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

- Focused HSO tests: `228/228` passed.

No native rebuild or direct compare was run because this slice changed only focused coverage and documentation, and the new tests showed existing Starshine behavior already matched the local Binaryen `version_130` probes.

## Remaining work

This narrows HSO-D/E for mutable descriptor-global barriers but does not close those buckets. Arbitrary descriptor expressions, descriptor/later-field combinations beyond the covered local/global/trap/select/as-non-null families, descriptor `br_on_non_null` and exact descriptor `ref.cast` local-surface blockers, broader moved-value hazards, HSO-I performance, and final HSO-J closeout remain open.
