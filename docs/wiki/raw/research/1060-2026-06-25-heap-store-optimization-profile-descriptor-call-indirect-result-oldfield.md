# Heap Store Optimization Profile Descriptor Call-Indirect Result Old-Field

Date: 2026-06-25

## Summary

Extended the dedicated `heap-store-optimization` GenValid profile with the descriptor-bearing `call_indirect` sibling of the call-result old-field family. The new root uses the HSO-only no-param `(result i32)` helper type through `call_indirect` as the overwritten field-0 value, a pure `ref.null eq` second field, and a pure `struct.new_default` descriptor operand before `struct.new_desc`. A later same-local field-0 `struct.set` uses marker `i32.const I32(145)`.

This narrows the generated descriptor call-result old-field gap beyond the pure direct-call root from `1058` and the mutable-descriptor direct-call root from `1059`.

## TDD

- Red focused profile floor: `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt -p 'heap-store-optimization profile records GC store opportunities'` failed because marker `i32.const I32(145)` was absent.
- Green focused profile floor: the same command passed after adding the descriptor `call_indirect` root.

## Validation

- `moon fmt` passed.
- `moon build --target-dir target --target native --release src/cmd` passed and refreshed the explicit native compare binary. Existing `src/passes/pass_manager.mbt` unused-function warnings remained.
- Dedicated profile smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-call-indirect-result-oldfield-profile-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: compared `20/20`, normalized matches `0`, compare-normalized matches `20`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `0` hits / `20` misses.
- Direct smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-call-indirect-result-oldfield-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: compared `1000/1000`, normalized matches `1000`, compare-normalized matches `0`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Backlog impact

This leaves the generated descriptor `call_ref` result root and tail-call old-field variants open. It does not close HSO-D/E/F/G/H/I/J or final closeout.
