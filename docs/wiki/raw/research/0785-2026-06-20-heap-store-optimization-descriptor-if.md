---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/binaryen-strategy.md
  - ../../binaryen/passes/heap-store-optimization/starshine-hot-ir-strategy.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0784-2026-06-20-heap-store-optimization-descriptor-local-block.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` descriptor `if` operands

Question: does Starshine match Binaryen `version_130` when a `struct.new_desc` descriptor operand is an `if` expression rather than a bare `global.get`, descriptor `local.get`, or block wrapper?

## Answer

Not before this slice. Binaryen folds a moved call value into `struct.new_desc` when the descriptor operand is an `if` whose condition is pure and whose branches both produce immutable descriptor globals. Starshine still used a coarse HOT effect summary for descriptor `if` expressions, so the branch `global.get`s made the whole descriptor operand look like a global-state barrier and left the later `struct.set` in place.

This slice extends descriptor operand effect classification narrowly:

- descriptor `if` operands summarize their children and then/else regions with the same descriptor-aware rules used for descriptor locals, immutable descriptor globals, and block wrappers;
- pure `if` conditions plus immutable descriptor-global branches are movement-pure for HSO descriptor barriers;
- a descriptor `if` condition that calls still keeps its call effects, so a later moved call is not reordered before it.

The positive focused test failed before implementation and passes after the fix. The negative focused test records Binaryen's call-condition barrier.

## Binaryen `version_130` probes

```sh
wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-desc-if-global-call.wat \
  -o .tmp/hso-probe-desc-if-global-call.opt.wat

wasm-opt --all-features --heap-store-optimization -S \
  .tmp/hso-probe-desc-if-cond-call-value-call.wat \
  -o .tmp/hso-probe-desc-if-cond-call-value-call.opt.wat
```

Observed behavior:

- pure-condition descriptor `if`: Binaryen removed the later `struct.set` and placed the moved `call $helper` in the field operand of `struct.new_desc`;
- call-condition descriptor `if`: Binaryen retained the later `struct.set`, preserving the original call ordering.

## Starshine implementation

Changed `src/passes/heap_store_optimization.mbt`:

- extended `hso_desc_operand_effects_for_node(...)` for `HotOp::If`;
- descriptor `if` child expressions and then/else regions are summarized with `hso_desc_operand_effects_for_node(...)` / `hso_desc_operand_effects_for_region(...)`, preserving ordinary call/trap/write effects while avoiding false barriers for immutable descriptor globals and descriptor locals inside the control expression.

## Tests

Added focused tests in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization moves call value before if-wrapped immutable descriptor globals`
- `heap-store-optimization keeps struct.set when descriptor if condition calls`

The first red run failed with a retained `struct.set`. After the implementation, focused HSO tests passed `61/61`.

## Validation

Commands run:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon fmt && moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt && moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-if-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --keep-going-after-command-failures
```

Results:

- red-first focused HSO run: `60/61` passed; new pure descriptor-`if` positive retained `struct.set`;
- final focused HSO tests: `61/61` passed;
- `moon fmt`: passed;
- native `src/cmd` build: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`;
- direct compare: requested `10000`, compared `9977`, normalized `9977`, cleanup-normalized `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `23`;
- command-failure classes: `binaryen-rec-group-zero=22`, `binaryen-bad-section-size=1`;
- cache: wasm-smith `5000/0`, Binaryen `9977/0`, Binaryen failures `23/0`.

Agent classification: no behavior mismatch and no output drift requiring classification in this slice. The command failures are Binaryen/oracle boundaries already seen in prior HSO lanes.

## Remaining work

This closes one more HSO-D descriptor-expression gap. Broader arbitrary descriptor expressions still need probes, especially loop/block-with-branch boundaries, `ref.cast`/`br_on_cast` descriptor-producing expressions, and trapping descriptor-producing expressions. The broader HSO audit remains open for later-field barriers, target-local/moved-value hazards, control-flow skip-local-set exactness, final-element/table swap coverage, explicit non-goals, O4z slot/neighborhood evidence, performance/raw fast-skip refresh, and final 100000-case closeout.
