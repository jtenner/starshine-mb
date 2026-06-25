# Heap Store Optimization Profile Call-Indirect Result Old-Field

Date: 2026-06-25
Oracle: Binaryen `version_130` via `wasm-opt --heap-store-optimization`

## Summary

The dedicated `heap-store-optimization` GenValid profile now includes a true `call_indirect` result old-field root. This closes one generated-profile sibling left open by `1047`/`1054`: the overwritten constructor field is produced directly by `call_indirect` to the HSO-only no-param `(result i32)` helper type, not by the older value-block approximation from `1046`.

The new generated root is intentionally plain-struct and non-descriptor: it separates indirect call-result old-field coverage from the direct-call marker added in `1054` and leaves generated `call_ref`, descriptor/mutable-descriptor, and tail-call result old-field variants open.

## Test-first evidence

I first tightened the HSO profile feature-floor test in `src/fuzz/main_wbtest.mbt` to require the new later-store marker `i32.const I32(141)`. Before the generator change, the focused test failed while showing the existing direct-call marker `i32.const I32(140)` and the older void `call_indirect` wrapper roots. That red run proves the new assertion distinguishes this generated true indirect-call-result old-field root from both `1046` and `1054`.

After implementation, the same focused test passed.

## Implementation

`src/validate/gen_valid.mbt` now reuses the HSO-only no-param `(result i32)` helper function type and emits:

- `i32.const 0`
- `call_indirect` using the helper type and table `0`
- the returned `i32` as constructor field `0`
- a later same-local same-field `struct.set` with marker `i32.const 141`

This gives the pass-comparison harness deterministic generated evidence that HSO preserves the indirect call result as an overwritten old field before considering the later same-field store.

## Validation

- Red focused floor: `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt -p 'heap-store-optimization profile records GC store opportunities'` failed before implementation because `i32.const I32(141)` was absent.
- Green focused floor: same command passed after implementation (`92/92` package count reported by Moon for the filtered run).
- `moon fmt` passed.
- `moon build --target-dir target --target native --release src/cmd` passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Dedicated HSO profile smoke: `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-call-indirect-result-oldfield-profile-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `20/20`, normalized `0`, compare-normalized `20`, mismatches/failures `0`, Binaryen cache `0` hits / `20` misses.
- Direct smoke: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-call-indirect-result-oldfield-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` compared `1000/1000`, normalized `1000`, mismatches/failures `0`, Binaryen cache `1000` hits / `0` misses.

## Remaining work

Generated true `call_ref` result old-field roots remain open, as do descriptor/mutable-descriptor and tail-call result old-field generated variants. This note narrows the `1047` blocker only for the plain `call_indirect` result-old-field generated family.
