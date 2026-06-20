---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0786-2026-06-20-heap-store-optimization-descriptor-block-branch.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO descriptor loop operand parity

Question: after descriptor blocks and pure descriptor `if` expressions, does Binaryen fold through a descriptor `loop` operand when the loop body has no internal branch/control barrier?

## Binaryen probes

Positive fixture: `.tmp/hso-probe-desc-loop-global-call.wat`.

Shape:

- `struct.new_desc $pair` uses a descriptor operand:
  - `(loop (result (ref (exact $desc))) (global.get $descg))`
- the later `struct.set` writes field `0` with `(call $helper (i32.const 1))`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-desc-loop-global-call.wat \
  -o .tmp/hso-probe-desc-loop-global-call.opt.wat
```

Observed grep:

```text
13:   (struct.new_desc $pair
14:    (call $helper
18:    (loop (result (ref (exact $desc)))
```

Binaryen folds the moved call into `struct.new_desc` and removes the `struct.set`; the descriptor loop remains as the descriptor operand.

Negative fixture: `.tmp/hso-probe-desc-loop-self-branch-call.wat`.

Shape:

- descriptor operand is `(loop (result (ref (exact $desc))) (br 0) (global.get $descg))`
- the later field value is again a helper call.

Observed grep after Binaryen:

```text
13:   (struct.new_desc $pair
16:    (loop $label (result (ref (exact $desc)))
17:     (br $label)
22:  (struct.set $pair 0
24:   (call $helper
```

Binaryen keeps the `struct.set` for the self-branching loop/control-barrier shape.

## Starshine gap and fix

Before this slice, Starshine treated descriptor `Block` and `If` wrappers specially, but `Loop` descriptor operands still used the raw HOT node effect summary. That left a control bit on a branchless loop wrapper and overblocked the Binaryen-positive fold.

Added red-first focused test:

- `heap-store-optimization moves call value before loop-wrapped immutable descriptor global`

Initial focused run failed with `62/63` passing and retained `struct.set` for the new positive.

The implementation now summarizes descriptor `Loop` operands like descriptor `Block` only when the loop body has no branch, terminator, or nested control barrier. In that branchless-loop case it recursively summarizes the loop body and clears control bits before comparing with the moved field value. A matching negative test locks the Binaryen self-branching descriptor loop behavior:

- `heap-store-optimization keeps struct.set when descriptor loop branches to itself`

This is intentionally narrow: descriptor loops with actual branch/control behavior remain barriers until separately probed and classified.

## Validation

Commands run before commit:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon fmt && moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt && moon build --target native --release src/cmd
```

Results:

- Red-first focused run after adding only the positive test: `62/63` passed; the new test failed because Starshine retained `struct.set`.
- After implementation and adding the negative: focused HSO tests `64/64` passed.
- `moon fmt`: passed.
- Native `src/cmd` build: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.

Per explicit user instruction in the active thread, the ordinary 10000-case direct compare was skipped for this slice. A compare command was started and then aborted at the user's request before a result summary was produced; do not count it as signoff evidence.

## Remaining risk

This closes only branchless descriptor loops and the self-branching descriptor-loop negative. Broader arbitrary descriptor expressions remain open: loops with outer branches, `ref.cast` / descriptor casts, `br_on_cast` / `br_on_cast_fail`, trapping descriptor-producing expressions, and exception paths still need source-backed probes and tests before HSO-D/F can close.
