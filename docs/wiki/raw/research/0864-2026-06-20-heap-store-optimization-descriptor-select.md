---
kind: research
status: active
created: 2026-06-20
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0785-2026-06-20-heap-store-optimization-descriptor-if.md
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` descriptor `select` operands

Question: does Starshine match Binaryen `version_130` when a `struct.new_desc` descriptor operand is a typed `select` of immutable descriptor globals?

## Answer

Not before this slice. Binaryen folds a moved call-valued `struct.set` into `struct.new_desc` when the descriptor operand is a typed `select` whose arms are immutable descriptor globals and whose condition is pure. Starshine previously summarized descriptor `select` operands with the generic HOT effect mask, so immutable descriptor `global.get` children looked like a global-state barrier and the later `struct.set` was retained.

This is a Binaryen behavior-parity fix, not a Starshine output-parity exception. The descriptor `select` case is the expression-form counterpart to the earlier descriptor `if` slice: HSO needs descriptor-aware effect summaries for expression children so immutable descriptor globals and descriptor locals do not become false barriers, while real call/trap/write effects remain barriers.

## Binaryen `version_130` probe

Probe fixture: `.tmp/hso-probe-desc-select-call.wat`.

```sh
wasm-opt --all-features \
  .tmp/hso-probe-desc-select-call.wat \
  --heap-store-optimization \
  -S \
  -o .tmp/hso-probe-desc-select-call.opt.wat

grep -n "struct.set\|struct.new_desc\|select\|call\|global.get" \
  .tmp/hso-probe-desc-select-call.opt.wat
```

Observed grep:

```text
14:   (struct.new_desc $pair
15:    (call $helper
19:    (select (result (ref (exact $desc)))
20:     (global.get $descg)
21:     (global.get $descg2)
```

Binaryen removed the later `struct.set`, moved the helper call into the replaced constructor field, and preserved the typed descriptor `select` as the descriptor operand.

Agent classification: source-backed Binaryen behavior; Starshine had a parity gap because it missed the fold.

## Starshine implementation

Changed `src/passes/heap_store_optimization.mbt`:

- extended `hso_desc_operand_effects_for_node(...)` for `HotOp::Select`;
- descriptor `select` operands now summarize each child with the descriptor-aware effect helper, mirroring the safe child-expression part of descriptor `if` handling;
- immutable descriptor globals remain movement-pure for HSO descriptor barriers, while non-descriptor child effects are still preserved by recursive child summaries.

## Tests

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization moves call value before select-wrapped immutable descriptor globals`.

Red-first result:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
Total tests: 223, passed: 222, failed: 1.
```

The new test retained `struct.set` before the implementation change.

After the implementation, the focused HSO suite passed:

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
Total tests: 223, passed: 223, failed: 0.
```

## Validation

Commands run after the final change:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-select-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --keep-going-after-command-failures
```

Results:

- `moon info`: passed with existing unused-value warnings in `src/validate/gen_valid*.mbt`.
- `moon fmt`: passed.
- Focused HSO tests: `223/223` passed.
- `moon test src/passes`: `2851/2851` passed.
- Native `src/cmd` build: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct compare: requested `10000`, compared `10000`, normalized matches `10000`, compare-normalized matches `0`, mismatches `0`, validation failures `0`, property failures `0`, generator failures `0`, command failures `0`.
- Cache: wasm-smith `0/0`, Binaryen `10000/0`, Binaryen failures `0/0`.

Agent classification: no remaining mismatch or output-drift family in this behavior-changing slice.

## Remaining work

This closes one more HSO-D descriptor-expression parity gap. HSO-D/E/F/G/H/I/J remain open for broader arbitrary descriptor expressions, moved-value/later-field hazard combinations, more in-function branch/catch negatives, remaining swap/wrapper variants, explicit non-goal wording, allocation-heavy performance evidence, final O4z slot/neighborhood replay, and final 100000-case closeout.
