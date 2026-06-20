---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0780-2026-06-20-heap-store-optimization-descriptor-global-call.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` descriptor local/block operands

Question: after the `version_130` directional descriptor movement refresh, does Starshine match Binaryen when the `struct.new_desc` descriptor operand is not a bare immutable `global.get`?

## Answer

Not before this slice. Binaryen `version_130` folds a moved call into `struct.new_desc` when the descriptor operand is either:

- a block-wrapped immutable descriptor `global.get`, or
- a descriptor `local.get` populated earlier in the function.

Starshine already handled the bare immutable descriptor `global.get` case from `0780`, but it still used the raw HOT effect mask for descriptor wrapper expressions and descriptor `local.get`. That overblocked movement of a later call value into the constructor and left the `struct.set` behind.

This slice extends descriptor operand effect classification narrowly:

- descriptor `local.get` is treated as movement-pure for HSO descriptor barriers;
- descriptor `block` wrappers are summarized from their contents with the same descriptor-aware rules, so an immutable global wrapped by a value block no longer becomes a coarse global-state barrier;
- mutable globals, calls, traps, writes, and other non-pure roots still keep their ordinary HOT effects.

The focused tests failed before the implementation and pass after the fix.

## Binaryen `version_130` probes

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-desc-block-global-call.wat \
  -o .tmp/hso-probe-desc-block-global-call.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-desc-localget-call.wat \
  -o .tmp/hso-probe-desc-localget-call.opt.wat
```

Observed behavior: both optimized WAT files contain `struct.new_desc` with the moved `call $helper` as the replacement field operand and no remaining `struct.set` for that write. The block/global case keeps the descriptor-producing block as the descriptor operand; the local-get case keeps the earlier descriptor local initialization and uses `local.get $d` as the descriptor operand.

## Starshine implementation

Changed `src/passes/heap_store_optimization.mbt`:

- added `hso_desc_operand_effects_for_region(...)`;
- extended `hso_desc_operand_effects_for_node(...)` to treat descriptor `LocalGet` as pure and to recurse through descriptor `Block` wrappers.

This preserves the existing `0780` mutable-global negative because mutable `global.get` still falls back to `hso_effects_for_node(...)`.

## Tests

Added focused tests in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization moves call value before block-wrapped immutable descriptor global`
- `heap-store-optimization moves call value before descriptor local.get`

The first red run showed both tests failing with a retained `struct.set`. After the implementation, focused HSO tests passed `59/59`.

## Validation

Commands run:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon fmt && moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-local-block-10000-final \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --keep-going-after-command-failures
```

Results:

- focused HSO tests: `59/59` passed;
- `moon fmt`: passed;
- native `src/cmd` build: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`;
- direct compare: requested `10000`, compared `9977`, normalized `9977`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `23`;
- command-failure classes: `binaryen-rec-group-zero=22`, `binaryen-bad-section-size=1`;
- cache: wasm-smith `5000/0`, Binaryen `9977/0`, Binaryen failures `23/0`.

Agent classification: no behavior mismatch and no output drift requiring classification in this slice. The command failures are Binaryen/oracle boundaries already seen in prior HSO lanes.

## Remaining work

This closes one HSO-D descriptor-expression gap, but HSO is not complete. Remaining active work includes later-field directional barriers beyond the reduced call/trap cases, target-local and moved-value hazards, control-flow / exception skip-local-set exactness, final-element and table swap coverage, explicit non-goals, O4z slot/neighborhood evidence, performance/raw fast-skip refresh, and final 100000-case closeout.
