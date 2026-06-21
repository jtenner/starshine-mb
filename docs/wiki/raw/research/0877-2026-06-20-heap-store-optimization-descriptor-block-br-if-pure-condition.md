# Heap Store Optimization Descriptor Block `br_if` Pure-Condition Fold

## Summary

Binaryen `version_130` folds a later call-valued `struct.set` into a fresh `struct.new_desc` when the descriptor operand is a value-producing `block` that contains a `br_if` with pure condition/value operands. Starshine previously kept the `struct.set` because descriptor-effect summarization treated `drop(br_if ...)` through the generic effect mask, retaining contained control as an ordering barrier. This slice teaches descriptor operand effect summarization to inspect branch and `drop` children so contained pure control remains reorderable while effectful branch conditions still block.

## Binaryen oracle

Probe file: `.tmp/hso-probe-descriptor-block-br-if-pure-cond-call-value.wat`.

Command:

```sh
wasm-opt --version && \
wasm-opt --all-features \
  .tmp/hso-probe-descriptor-block-br-if-pure-cond-call-value.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-descriptor-block-br-if-pure-cond-call-value.opt.wat && \
grep -E "struct.set|struct.new_desc|br_if|call|global.get|block|drop|i32.const" \
  .tmp/hso-probe-descriptor-block-br-if-pure-cond-call-value.opt.wat
```

Result:

- Local oracle: `wasm-opt version 130 (version_130)`.
- Binaryen removed `struct.set`.
- Binaryen kept the descriptor `block` / `br_if` and placed the moved `call $helper (i32.const 1)` as the replacement field value inside `struct.new_desc` before the later field and descriptor operand.

This complements `0876`, where the same descriptor-block shape with a call-valued `br_if` condition preserved `struct.set`.

## Starshine gap and fix

Red-first focused test:

- `heap-store-optimization folds through descriptor block br_if with pure condition`

Initial result:

```text
Total tests: 234, passed: 233, failed: 1.
```

The failed output still contained `struct.set`.

Implementation change:

- `src/passes/heap_store_optimization.mbt`
  - `hso_desc_operand_effects_for_node(...)` now summarizes branch children instead of returning zero for the whole branch unconditionally.
  - `Drop` in descriptor operands now summarizes its child with the descriptor-specific effect splitter rather than the generic effect mask.

The branch-child recursion preserves the `0876` negative: a call-valued `br_if` condition contributes call effects and continues to block moving a call-valued store across the descriptor operand. Pure branch operands contribute no ordering effect, matching Binaryen's fold.

## Validation

Focused validation after the fix:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 234, passed: 234, failed: 0.
```

Additional signoff:

```sh
moon fmt && \
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt && \
moon build --target native --release src/cmd && \
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-block-br-if-pure-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- `moon fmt`: passed.
- Focused HSO tests: `234/234` passed.
- Native `src/cmd` build: passed with pre-existing `pass_manager.mbt` unused-function warnings.
- Direct compare: compared `10000/10000`; normalized matches `10000`; mismatches `0`; validation failures `0`; property failures `0`; generator failures `0`; command failures `0`; Binaryen cache `10000` hits / `0` misses.

## Classification

- Family: HSO-D/E descriptor operand branch-effect split.
- Previous Starshine behavior: behavior-parity gap; Starshine overblocked a Binaryen fold.
- New Starshine behavior: matches Binaryen for pure descriptor block `br_if` conditions while preserving the effectful call-condition boundary from `0876`.

## Reopening criteria

Reopen if a future Binaryen oracle keeps `struct.set` for pure contained descriptor `br_if` operands, if Starshine folds an effectful branch-condition descriptor shape such as `0876`, or if broader branch operands expose target-local, global, trap, catch, or escaping-control hazards not captured by descriptor-specific effect summarization.
