---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0785-2026-06-20-heap-store-optimization-descriptor-if.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# HSO descriptor block-branch operand parity

Question: after descriptor `local.get`, block-wrapped immutable globals, and pure descriptor `if` expressions, does Binaryen also fold through descriptor `block` expressions that branch to their own result label?

## Binaryen probe

Fixture: `.tmp/hso-probe-desc-block-branch-global-call.wat`.

Shape:

- `struct.new_desc $pair` uses a descriptor operand:
  - `(block (result (ref (exact $desc))) (global.get $descg) (br 0) (global.get $descg))`
- the later `struct.set` writes field `0` with `(call $helper (i32.const 1))`.

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-desc-block-branch-global-call.wat \
  -o .tmp/hso-probe-desc-block-branch-global-call.opt.wat
```

Observed grep:

```text
13:   (struct.new_desc $pair
14:    (call $helper
19:     (br $block
```

Binaryen folds the moved call into `struct.new_desc` and removes the `struct.set`; the descriptor block's self-targeting branch remains inside the descriptor expression.

A const-value variant (`.tmp/hso-probe-desc-block-branch-global-const.wat`) also folded and preserved the descriptor branch.

## Starshine gap and fix

Before this slice, Starshine summarized descriptor `block` operands by OR-ing region root effects. That preserved the internal branch control bit, so a moved call value looked ordered after the descriptor and Starshine kept the `struct.set`.

Added a red-first focused test:

- `heap-store-optimization moves call value before block-branch immutable descriptor global`

Initial focused run failed with `61/62` passing and retained `struct.set`.

The implementation now treats branch instructions inside descriptor operand summaries as non-barrier effects for this source-backed descriptor-block family, matching Binaryen's observed release-oracle fold. The descriptor block aggregate also clears control from contained control effects before comparing it with the moved store value.

## Validation

Focused and standard slice commands:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon fmt && moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt && moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-block-branch-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --keep-going-after-command-failures
```

Results:

- Focused HSO tests: `62/62` passed.
- `moon fmt`: passed.
- Native `src/cmd` build: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct 10000-case compare: requested `10000`, compared `9977`, normalized `9977`, compare-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `23` (`binaryen-rec-group-zero=22`, `binaryen-bad-section-size=1`; Binaryen failures `23` hits / `0` misses from cached oracle failures), cache wasm-smith `5000/0`, Binaryen `9977/0`, Binaryen failures `23/0`.

## Remaining risk

This closes only the source-backed descriptor block self-branch fold family. Descriptor expressions with branches/casts that target outer labels, `br_on_cast` / `br_on_cast_fail`, loops, traps, and catch/exception paths still need dedicated Binaryen probes and focused positives/negatives before HSO-D/F/G can close.
