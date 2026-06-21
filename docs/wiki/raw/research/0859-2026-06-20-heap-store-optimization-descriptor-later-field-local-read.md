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

# `heap-store-optimization` descriptor later-field local-read movement

Question: does Binaryen `version_130` allow a call-valued `struct.set` to fold into an earlier `struct.new_desc` field when a later constructor field reads the target local?

## Answer

Yes. A local `wasm-opt version 130 (version_130)` probe showed Binaryen folds the later `struct.set` into `struct.new_desc` even when a later constructor field contains a `local.get` of the same target local. The target-local read is in a constructor operand that already executes before the fresh-struct `local.set` in the original program; the moved value itself does not read or write the target local, so Binaryen's target-local hazard does not apply.

Starshine initially missed this fold because its reorder check treated any local-state barrier as ordered before a moved call. That was too conservative for local reads that cannot observe caller-local changes from a call. Starshine now ignores local-only or local/control-only barriers when the moved value has no local-state effects, while preserving the existing moved-value target-local hazards.

## Probe command

```sh
wasm-opt .tmp/hso-probe-desc-later-field-target-local-read.wat \
  --heap-store-optimization -all -S -o - \
  | tee .tmp/hso-probe-desc-later-field-target-local-read.opt.wat
```

Observed behavior:

- Binaryen rewrote the constructor's field `0` to the moved `(call $side)` value.
- Binaryen preserved the later field's `block` containing `drop(local.get $p)` as field `1`.
- Binaryen removed the later `struct.set`.

## Starshine change

Added a red-first focused test:

- `heap-store-optimization folds descriptor store despite later field target-local read`

The test failed before implementation because Starshine kept the later `struct.set`. The fix is in `hso_nodes_can_reorder(...)`: local-only or local/control-only barriers no longer block moving a value that has no local-state effects.

## Validation

```text
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
# red-first before implementation: new test failed, 212/213 passed

moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
# Total tests: 213, passed: 213, failed: 0.
moon test src/passes
# Total tests: 2841, passed: 2841, failed: 0.
moon build --target native --release src/cmd
# passed with existing pass_manager unused-function warnings
moon info
# passed with existing gen_valid unused-value warnings
moon test
# Total tests: 6154, passed: 6154, failed: 0.
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-later-local-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
# Compared 10000/10000; normalized matches 10000; mismatches 0; command failures 0.
```

## Backlog impact

This closes one HSO-D/E overlap around descriptor constructors plus later-field target-local reads. HSO-D remains open for arbitrary descriptor expressions, remaining later-field directional barriers, broader default/descriptor old-field combinations, and broader old-field negatives. HSO-E remains open for descriptor/later-field hazard combinations beyond this local-read positive and the direct descriptor target-local read/write negatives from `0857`/`0858`.
