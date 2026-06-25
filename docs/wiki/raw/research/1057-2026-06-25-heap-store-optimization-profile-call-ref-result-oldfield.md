# Heap Store Optimization Profile Call-Ref Result Old-Field

Date: 2026-06-25
Oracle: Binaryen `version_130` via `wasm-opt --heap-store-optimization`

## Summary

The dedicated `heap-store-optimization` GenValid profile now includes a true `call_ref` result old-field root. This closes the typed-function-reference generated-profile sibling left open after `1054` and `1056`: the overwritten constructor field is produced directly by `ref.func` / `call_ref` to the HSO-only no-param `(result i32)` helper, not by the older void-call wrapper families.

The new root is plain-struct and non-descriptor. Descriptor/mutable-descriptor and tail-call result old-field generated variants remain open.

## Test-first evidence

I first tightened the focused HSO profile feature-floor test to require marker `i32.const I32(142)`. The red run failed before implementation while showing the existing direct-call marker `140`, `call_indirect` result marker `141`, and older void `call_ref` wrapper roots. That red run distinguished the missing true `call_ref` result old-field root from the already-covered call-ref wrapper family.

After implementation, the focused test passed.

## Implementation

`src/validate/gen_valid.mbt` now emits this deterministic root when the HSO-only no-param `(result i32)` helper is present:

- `ref.func` for the helper function;
- `call_ref` using the helper function type;
- the returned `i32` as constructor field `0`;
- a later same-local same-field `struct.set` with marker `i32.const 142`.

This generated root complements the direct-call marker `140` and `call_indirect` marker `141` while preserving the older catchable void-call wrapper roots.

## Validation

- Red focused floor: `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt -p 'heap-store-optimization profile records GC store opportunities'` failed before implementation because `i32.const I32(142)` was absent.
- Green focused floor: same command passed after implementation.
- `moon fmt` passed.
- `moon build --target-dir target --target native --release src/cmd` passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Dedicated HSO profile smoke: `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-call-ref-result-oldfield-profile-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `20/20`, normalized `0`, compare-normalized `20`, mismatches/failures `0`, Binaryen cache `0` hits / `20` misses.
- Direct smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-call-ref-result-oldfield-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `1000/1000`, normalized `1000`, mismatches/failures `0`, Binaryen cache `1000` hits / `0` misses.

## Remaining work

Generated true descriptor/mutable-descriptor and tail-call result old-field variants remain open. The exact descriptor `ref.cast` surface remains separately blocked by Starshine decode/local support (`1048`).
