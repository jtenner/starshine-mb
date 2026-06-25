# Heap Store Optimization Profile Descriptor Call-Result Old-Field

Date: 2026-06-25
Oracle: Binaryen `version_130` via `wasm-opt --heap-store-optimization`

## Summary

The dedicated `heap-store-optimization` GenValid profile now includes a descriptor-bearing true direct-call-result old-field root. This narrows the generated descriptor old-field gap left after the plain direct/indirect/ref result roots (`1054`, `1056`, `1057`).

The overwritten constructor field is produced directly by the HSO-only no-param `(result i32)` helper call. The descriptor operand is pure (`struct.new_default` for the descriptor type), so the root exercises descriptor `struct.new_desc` old-field preservation without mixing in mutable-descriptor or catchable result-wrapper barriers.

## Test-first evidence

I first tightened the focused HSO profile feature-floor test to require marker `i32.const I32(143)`. The red run failed before implementation while showing the existing plain result markers `140`, `141`, and `142`, plus existing descriptor roots. That red run proved the generated profile did not yet contain a descriptor-bearing true call-result old-field root.

After implementation, the focused test passed.

## Implementation

`src/validate/gen_valid.mbt` now emits this descriptor root inside the descriptor-constructor profile slice:

- direct `call` to the HSO-only no-param `(result i32)` helper;
- `ref.null eq` for the second described-struct field;
- pure `struct.new_default` descriptor operand;
- `struct.new_desc` for the described type;
- local materialization followed by a later same-field `struct.set` marker `i32.const 143`.

This keeps generated descriptor call-result old-field coverage separate from the mutable-descriptor result-wrapper old-field roots from `1045`/`1055`.

## Validation

- Red focused floor: `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt -p 'heap-store-optimization profile records GC store opportunities'` failed before implementation because `i32.const I32(143)` was absent.
- Green focused floor: same command passed after implementation.
- `moon fmt` passed.
- `moon build --target-dir target --target native --release src/cmd` passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Dedicated HSO profile smoke: `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-call-result-oldfield-profile-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `20/20`, normalized `0`, compare-normalized `20`, mismatches/failures `0`, Binaryen cache `0` hits / `20` misses.
- Direct smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-call-result-oldfield-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `1000/1000`, normalized `1000`, mismatches/failures `0`, Binaryen cache `1000` hits / `0` misses.

## Remaining work

Generated mutable-descriptor call-result old-field variants and tail-call result old-field variants remain open. The exact descriptor `ref.cast` HSO surface remains blocked by Starshine decode/local support (`1048`) and is not closed by this pure-descriptor generated root.
