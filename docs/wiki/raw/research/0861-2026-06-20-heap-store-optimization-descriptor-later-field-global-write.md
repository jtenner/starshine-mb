---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../../src/passes/heap_store_optimization.mbt
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0860-2026-06-20-heap-store-optimization-descriptor-later-field-global-conflict.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
---

# `heap-store-optimization` descriptor later-field global write barriers

Question: how does Binaryen `version_130` handle a descriptor constructor where a later constructor field writes a mutable global and the moved `struct.set` value reads or writes either that same global or an unrelated mutable global?

## Answer

Local `wasm-opt version 130 (version_130)` probes show the same directional same-global split as the earlier later-field global-read slice, but with the later constructor field as the writer:

- Binaryen folds when the later constructor field writes `$g0` and the moved value reads unrelated `$g1`.
- Binaryen preserves `struct.set` when the later constructor field writes `$g0` and the moved value reads `$g0`; folding would make the moved field read the pre-constructor value instead of the value written by the later field.
- Binaryen folds when the later constructor field writes `$g0` and the moved value writes unrelated `$g1`.
- Binaryen preserves `struct.set` when both later field and moved value write `$g0`; folding would reverse the final global write order.

Starshine initially failed the two unrelated-global positives added from these probes: the exact global-conflict scan was correct, but the later-field block's effect mask still carried structural control debris, so the existing global-only movement allowance did not fire. The fix normalizes barrier and moved masks through the same control-skipping rule used by `hso_reorder_effect_mask(...)` before applying `hso_nodes_can_reorder(...)`'s global-only allowance. Same-global conflicts still fail the preflight conflict scan and keep the later `struct.set`.

## Probe commands

```sh
for f in .tmp/hso-probe-desc-later-field-set-{unrelated-read,same-read,unrelated-write,same-write}.wat; do
  wasm-opt "$f" --heap-store-optimization -all -S -o - \
    | tee "${f%.wat}.opt.wat"
done
```

Observed behavior:

- `.tmp/hso-probe-desc-later-field-set-unrelated-read.wat`: Binaryen folded `global.get $g1` into field `0` before the later field's `global.set $g0`.
- `.tmp/hso-probe-desc-later-field-set-same-read.wat`: Binaryen preserved `struct.set` so the moved `global.get $g0` still observes the constructor field write.
- `.tmp/hso-probe-desc-later-field-set-unrelated-write.wat`: Binaryen folded the moved `global.set $g1; i32.const 11` block into field `0` before the later field's unrelated `global.set $g0` block.
- `.tmp/hso-probe-desc-later-field-set-same-write.wat`: Binaryen preserved `struct.set` so the later field's `global.set $g0` still happens before the moved value's `global.set $g0`.

## Starshine change

Added focused tests:

- `heap-store-optimization folds descriptor store across unrelated later-field global write`
- `heap-store-optimization keeps descriptor store before same later-field global write and read`
- `heap-store-optimization folds descriptor store across unrelated later-field and moved global writes`
- `heap-store-optimization keeps descriptor store before same later-field and moved global writes`

The two unrelated-global tests failed before implementation because Starshine left `struct.set` in place. The implementation keeps the previous precise same-global conflict check and changes `hso_nodes_can_reorder(...)` to remove non-skipping structural control from the supplied barrier/moved masks before testing the global-only reorder allowance.

## Validation

```text
wasm-opt .tmp/hso-probe-desc-later-field-set-*.wat --heap-store-optimization -all -S -o -
# Binaryen folded unrelated read/write cases and preserved same-global read/write cases.

moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
# red-first before implementation: unrelated-global read/write positives failed, 217/219 passed.

moon fmt
# passed

moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
# Total tests: 219, passed: 219, failed: 0.

moon test src/passes
# Total tests: 2847, passed: 2847, failed: 0.

moon build --target native --release src/cmd
# passed with existing pass_manager unused-function warnings

moon info
# passed with existing gen_valid / gen_valid_ssa warnings

moon test
# Total tests: 6160, passed: 6160, failed: 0.

bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-later-global-write-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 --keep-going-after-command-failures
# Compared 10000/10000; normalized matches 10000; mismatches 0; command/validation/property/generator failures 0.
```

## Backlog impact

This narrows HSO-D/E for descriptor later-field global write ordering. HSO-D remains open for arbitrary descriptor expressions, later-field directional barriers beyond the covered local/global read/write cases, broader default/descriptor old-field combinations, and broader old-field negatives. HSO-E remains open for descriptor/later-field hazard combinations beyond direct target-local read/write, local-read positives, and the covered global read/write splits.
