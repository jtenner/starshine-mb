---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0781-2026-06-20-heap-store-optimization-swap-constructor-global.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` immutable descriptor swap ordering

Question: does Starshine match Binaryen `version_130` for `trySwap(...)` when the constructor operand is an immutable descriptor `global.get` and the skipped root writes unrelated mutable global state?

## Finding

No, before this slice Starshine overblocked this `trySwap(...)` family.

Binaryen folds a `struct.set` into `struct.new_desc` when the constructor's descriptor operand is an immutable `global.get` and the intervening blocker is an unrelated mutable `global.set`. This is the swap-side counterpart to the earlier descriptor-movement finding: immutable descriptor globals do not impose an ordering barrier, while mutable descriptor globals can.

Starshine's prior `trySwap(...)` fix from `0781` summarized constructor operand effects with raw HOT effect masks. That correctly blocked a mutable-global read crossing a later mutable-global write, but it also treated an immutable descriptor `global.get` as global state. The result was a missed Binaryen-compatible fold, not an intentional Starshine win.

## Binaryen probe

Input:

```wat
(module
  (rec
    (type $S (descriptor $D) (struct (field (mut i32))))
    (type $D (describes $S) (struct)))
  (import "env" "desc" (global $desc (ref (exact $D))))
  (global $g (mut i32) (i32.const 0))
  (func (result i32)
    (local $x (ref null $S))
    (local.set $x
      (struct.new_desc $S
        (i32.const 2)
        (global.get $desc)))
    (global.set $g (i32.const 9))
    (struct.set $S 0
      (local.get $x)
      (i32.const 7))
    (struct.get $S 0 (local.get $x))))
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-swap-desc-immutable-global-set.wat \
  -o .tmp/hso-probe-swap-desc-immutable-global-set.opt.wat
```

Observed output moves `global.set` before the rewritten constructor and removes `struct.set`, leaving `struct.new_desc` with field value `7` and the immutable descriptor `global.get`.

Agent classification: source-backed Binaryen behavior; Starshine had a parity gap because it missed this fold.

## Starshine fix

Added focused test-first coverage:

- `heap-store-optimization folds immutable descriptor global across unrelated global.set`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

failed exactly the new test: Starshine retained `struct.set`.

Implementation:

- threaded `module_ctx` into HSO root-swap legality helpers;
- changed `hso_struct_new_operand_effect_mask(...)` to summarize constructor child effects through `hso_desc_operand_effects_for_node(...)`, so immutable global operands are pure when module context proves immutability;
- preserved the previous `0781` mutable-global constructor operand blocker because mutable globals still produce a non-pure constructor operand effect mask.

Focused post-fix result:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
Total tests: 54, passed: 54, failed: 0.
```

Additional validation for the behavior-changing slice:

```text
moon fmt
moon test src/passes
Total tests: 2892, passed: 2892, failed: 0.

moon build --target native --release --target-dir target src/cmd
```

The native build passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.

Full workspace validation also passed:

```text
moon info
moon test
Total tests: 6251, passed: 6251, failed: 0.
```

`moon info` passed with existing generator warnings.

Direct compare:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-immutable-descriptor-swap-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 200 \
  --keep-going-after-command-failures
```

Result: requested `10000`, compared `9977`, normalized `9977`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `23`; cache wasm-smith `5000/0`, Binaryen `9977/0`, Binaryen failures `23/0`. Agent classification: no HSO behavior mismatch or output drift requiring classification; command failures are Binaryen/oracle boundaries already seen in prior HSO lanes.

## Status

This closes one additional `trySwap(...)` descriptor operand directionality gap. HSO-G remains open for broader constructor operand memory/table/effect combinations, final-element and constructor-ping-pong rejections, and HOT wrapper peeling/flattening drift. HSO-D also remains open for non-swap descriptor operand expression coverage.
