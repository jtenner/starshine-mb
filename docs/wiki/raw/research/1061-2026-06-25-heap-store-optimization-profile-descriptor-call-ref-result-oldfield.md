# Heap Store Optimization Profile Descriptor Call-Ref Result Old-Field

Date: 2026-06-25

## Summary

Extended the dedicated `heap-store-optimization` GenValid profile with the descriptor-bearing `call_ref` sibling of the call-result old-field family. The new root uses `ref.func` / `call_ref` to the HSO-only no-param `(result i32)` helper as the overwritten field-0 value, a pure `ref.null eq` second field, and a pure `struct.new_default` descriptor operand before `struct.new_desc`. A later same-local field-0 `struct.set` uses marker `i32.const I32(146)`.

This completes the generated pure-descriptor direct/indirect/ref call-result old-field trio (`1058`, `1060`, `1061`) while leaving true generated tail-call old-field variants as separate work.

## TDD

- Red focused profile floor: `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt -p 'heap-store-optimization profile records GC store opportunities'` failed because marker `i32.const I32(146)` was absent.
- Green focused profile floor: the same command passed after adding the descriptor `call_ref` root.

## Validation

- `moon fmt` passed.
- `moon build --target-dir target --target native --release src/cmd` passed and refreshed the explicit native compare binary. Existing `src/passes/pass_manager.mbt` unused-function warnings remained.
- Dedicated profile smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-call-ref-result-oldfield-profile-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: compared `20/20`, normalized matches `0`, compare-normalized matches `20`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `0` hits / `20` misses.
- Direct smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-desc-call-ref-result-oldfield-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: compared `1000/1000`, normalized matches `1000`, compare-normalized matches `0`, validation/property/generator/command failures `0`, mismatches `0`, Binaryen cache `1000` hits / `0` misses.

## Backlog impact

Generated true call-result old-field coverage now includes plain direct, plain `call_indirect`, plain `call_ref`, pure-descriptor direct, mutable-descriptor direct, pure-descriptor `call_indirect`, and pure-descriptor `call_ref` roots. Generated tail-call old-field variants remain open. This does not close HSO-D/E/F/G/H/I/J or final closeout.
