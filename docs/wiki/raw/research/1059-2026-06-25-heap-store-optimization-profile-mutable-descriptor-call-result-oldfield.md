# Heap Store Optimization Profile Mutable Descriptor Call-Result Old-Field

Date: 2026-06-25

## Summary

Extended the dedicated `heap-store-optimization` GenValid profile with a mutable-descriptor direct-call-result old-field root. The new generated shape is distinct from:

- `1058`'s pure-descriptor direct-call-result root, whose descriptor operand is a pure `struct.new_default`; and
- `1045` / `1055` mutable-descriptor result-wrapper old-field boundaries, whose old field is not a true helper call result in the generated profile.

The new root builds `struct.new_desc` from a no-param `(result i32)` helper call as field 0, `ref.null eq` as field 1, and a mutable exact-descriptor `global.get` as the descriptor operand, then performs a later same-local field-0 `struct.set` with marker `i32.const I32(144)`.

## TDD

- Red focused profile floor: `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt -p 'heap-store-optimization profile records GC store opportunities'` failed because marker `i32.const I32(144)` was absent.
- Green focused profile floor: the same command passed after adding the generated root.

## Validation

- `moon fmt` passed.
- `moon build --target-dir target --target native --release src/cmd` passed and refreshed the explicit native compare binary. Existing `src/passes/pass_manager.mbt` unused-function warnings remained.
- Dedicated profile smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-mutable-desc-call-result-oldfield-profile-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: compared `20/20`, normalized matches `0`, compare-normalized matches `20`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `0` hits / `20` misses.
- Direct smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-mutable-desc-call-result-oldfield-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: compared `1000/1000`, normalized matches `1000`, compare-normalized matches `0`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Backlog impact

This narrows the generated true call-result old-field gap to descriptor `call_indirect` / `call_ref` result roots and tail-call siblings. It does not close HSO-D/E/F/G/H/I/J or final closeout.
