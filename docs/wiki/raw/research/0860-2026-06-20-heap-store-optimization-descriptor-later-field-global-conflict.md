---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
---

# `heap-store-optimization` descriptor later-field global conflict

Question: how does Binaryen `version_130` handle a descriptor constructor where a later constructor field reads a mutable global and the moved `struct.set` value writes either the same or an unrelated mutable global?

## Answer

Local `wasm-opt version 130 (version_130)` probes show a directional split:

- Binaryen folds when the later constructor field reads mutable global `$g0` and the moved value writes unrelated mutable global `$g1`. The moved side effect can be placed in the constructor field for the target `struct.set` without changing the later field's observed value.
- Binaryen keeps `struct.set` when the later constructor field reads `$g0` and the moved value writes the same `$g0`. Moving the write into the earlier constructor field would make the later field read the new value instead of the original value.

Starshine initially failed the same-global negative after adding focused coverage. It folded the store and, during the first attempted fix, also exposed a mutation-order hazard: value-block prefix peeling removed the `global.set` before the later-field legality check rejected the fold. Starshine now checks same-global ordering conflicts before any value-block prefix mutation, includes peeled prefix roots in later-field/descriptor reorder checks, and allows unrelated global-only movement only when the precise same-global conflict scan is clean.

## Probe commands

```sh
wasm-opt .tmp/hso-probe-desc-later-field-unrelated-global-write.wat \
  --heap-store-optimization -all -S -o - \
  | tee .tmp/hso-probe-desc-later-field-unrelated-global-write.opt.wat

wasm-opt .tmp/hso-probe-desc-later-field-same-global-write.wat \
  --heap-store-optimization -all -S -o - \
  | tee .tmp/hso-probe-desc-later-field-same-global-write.opt.wat
```

Observed behavior:

- `.tmp/hso-probe-desc-later-field-unrelated-global-write.wat`: Binaryen moved the `global.set $g1; i32.const 9` block into field `0`, preserved the later `global.get $g0` as field `1`, and removed `struct.set`.
- `.tmp/hso-probe-desc-later-field-same-global-write.wat`: Binaryen preserved the later `struct.set` so the constructor's field `1` still reads `$g0` before the candidate value writes `$g0`.

## Starshine change

Added focused tests:

- `heap-store-optimization folds descriptor store across unrelated later-field global read`
- `heap-store-optimization keeps descriptor store before same later-field global read`

The same-global test failed before implementation because Starshine moved `global.set` before `global.get`. The fix adds exact global read/write conflict checks for `hso_nodes_can_reorder(...)` and pre-checks descriptor/later-field barriers before mutating block-valued store values. The same helper is also applied to peeled value-prefix roots so effectful prefix roots cannot escape the later-field/descriptor legality proof.

## Validation

```text
wasm-opt .tmp/hso-probe-desc-later-field-unrelated-global-write.wat --heap-store-optimization -all -S -o -
# Binaryen folded the unrelated-global case.
wasm-opt .tmp/hso-probe-desc-later-field-same-global-write.wat --heap-store-optimization -all -S -o -
# Binaryen kept struct.set in the same-global case.

moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
# red-first before implementation: same-global test failed, 214/215 passed

moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
# Total tests: 215, passed: 215, failed: 0.
```

```text
moon test src/passes
# Total tests: 2843, passed: 2843, failed: 0.
moon build --target native --release src/cmd
# passed with existing pass_manager unused-function warnings
moon info
# passed with existing gen_valid/gen_valid_ssa warnings
moon test
# Total tests: 6156, passed: 6156, failed: 0.
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-later-global-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
# Compared 10000/10000; normalized matches 10000; mismatches 0; command/validation/property/generator failures 0.
```

## Backlog impact

This narrows HSO-D/E by covering descriptor later-field global conflicts with precise same-global ordering. HSO-D remains open for arbitrary descriptor expressions, remaining later-field directional barriers, broader default/descriptor old-field combinations, and broader old-field negatives. HSO-E remains open for descriptor/later-field hazard combinations beyond direct target-local read/write, local-read positives, and this global read/write split.
