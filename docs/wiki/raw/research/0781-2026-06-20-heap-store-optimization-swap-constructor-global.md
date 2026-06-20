---
kind: research
status: active
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0780-2026-06-20-heap-store-optimization-descriptor-global-call.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` swap constructor/global ordering

Question: does Starshine match Binaryen `version_130` for `trySwap(...)` when the constructor being pushed downward reads mutable global state and the skipped root writes that global?

## Finding

No, before this slice Starshine over-swapped one `trySwap(...)` family.

Binaryen `version_130` uses `firstEffects.orderedBefore(secondEffects)` in `trySwap(...)`, where `firstEffects` belongs to the earlier `local.set(struct.new ...)` and `secondEffects` belongs to the skipped root. A constructor operand `global.get $g` must remain before a later mutable `global.set $g`, so Binaryen does not push the constructor set past the global write and therefore does not fold the later `struct.set`.

Starshine's prior swap check considered only the blocker root and target-local hazards. It therefore moved a `local.set(struct.new (global.get $g) ...)` past a later `global.set $g`, then folded a following `struct.set` into the constructor. That changed which global value initialized the old field.

## Binaryen probe

Input:

```wat
(module
  (type $S (struct (field (mut i32)) (field (mut i32))))
  (global $g (mut i32) (i32.const 0))
  (func (result i32)
    (local $x (ref null $S))
    (local.set $x
      (struct.new $S
        (global.get $g)
        (i32.const 2)))
    (global.set $g (i32.const 9))
    (struct.set $S 1
      (local.get $x)
      (i32.const 7))
    (struct.get $S 1 (local.get $x))))
```

Command:

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-swap-constructor-global-get.wat \
  -o .tmp/hso-probe-swap-constructor-global-get.opt.wat
```

Observed output retains `struct.new` with `global.get`, then `global.set`, then `struct.set`. Agent classification: source-backed Binaryen behavior; Starshine had a behavior gap, not acceptable representation drift.

A control probe with `struct.new_default` followed by `global.set` folds in Binaryen, so the barrier is the constructor operand's global read ordered before the later global write, not a blanket rejection of `global.set` blockers.

## Starshine fix

Added focused test-first coverage:

- `heap-store-optimization keeps global.set before constructor global.get`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

failed exactly the new test: Starshine output had moved `global.set` before the rewritten `struct.new` and removed `struct.set`.

Implementation:

- added `hso_struct_new_operand_effect_mask(...)` to summarize constructor operand effects for swap legality;
- changed `hso_root_can_swap_before_local_struct_new(...)` to reject a swap when constructor operand effects are ordered before the blocker effects;
- passed the active `struct_new_id` into normal and block-wrapped swap checks;
- retained existing positive coverage for pure/default constructors swapping across unrelated `global.set`, `memory.size`, table-size, local-set, and block-wrapped readonly roots.

Focused post-fix result:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
Total tests: 53, passed: 53, failed: 0.
```

Additional validation for the behavior-changing slice:

```text
moon test src/passes
Total tests: 2891, passed: 2891, failed: 0.

moon fmt && moon build --target native --release --target-dir target src/cmd
```

The native build passed with the existing unused-function warnings in `src/passes/pass_manager.mbt`.

Full workspace validation also passed:

```text
moon info && moon test
moon info passed with existing generator warnings.
moon test: Total tests: 6250, passed: 6250, failed: 0.
```

Direct compare:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-swap-constructor-global-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 200 \
  --keep-going-after-command-failures
```

Result: requested `10000`, compared `9977`, normalized `9977`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `23` (`binaryen-rec-group-zero=22`, `binaryen-bad-section-size=1`), cache wasm-smith `5000/0`, Binaryen `9977/0`, Binaryen failures `23/0`. Agent classification: no HSO behavior mismatch or output drift requiring classification; command failures are Binaryen/oracle boundaries already seen in prior HSO lanes.

## Status

This closes one concrete `trySwap(...)` directionality gap. HSO-G remains open for other swap operands/effects, final-element and constructor-ping-pong rejections, and HOT wrapper peeling/flattening drift.
