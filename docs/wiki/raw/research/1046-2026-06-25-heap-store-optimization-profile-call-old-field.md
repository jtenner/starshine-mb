# Heap Store Optimization Profile Call-Containing Old Field

## Context

The HSO behavior matrix has source-backed focused coverage for preserving overwritten old-field side effects while folding later same-field stores. Generated profile coverage still lacked a compact call-containing old-field root.

The current HSO profile intentionally keeps generated functions no-param/no-result, so this slice uses a value-producing `block (result i32)` containing a void direct `call` followed by an `i32.const`. This is a generated approximation of the call-valued old-field family: the overwritten constructor field expression contains call effects and produces the field value, so HSO must preserve the call if it folds the later store.

## Change

Extended `src/validate/gen_valid.mbt` with a deterministic plain-struct root:

- field `0` is supplied by `block (result i32)` containing a no-param/no-result direct `call` followed by `i32.const`;
- field `1` is `ref.null eq`;
- the fresh `struct.new` is stored in the HSO target local; and
- a later same-local `struct.set` overwrites field `0`.

Strengthened `src/fuzz/main_wbtest.mbt` red-first to require `block I32` in the decoded HSO profile artifact. The focused fuzz test failed before the generator update and passed afterward.

## Evidence

- Red-first `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed in the HSO profile artifact test because the generated function lacked `block I32`.
- After the generator update, `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed: `92/92`.
- `moon fmt` passed.
- `moon build --target-dir target --target native --release src/cmd` passed and refreshed `target/native/release/build/cmd/cmd.exe`; existing `src/passes/pass_manager.mbt` unused-function warnings remained.
- Dedicated profile smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-call-old-field-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - Result: compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `0` hits / `20` misses.
- Direct smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-call-old-field-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`
  - Result: compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Classification

This is generated-profile coverage expansion for a call-containing old-field family, not a claim that every call-valued old-field variant is generated. The profile's no-result function shape means direct call results, `call_indirect` results, `call_ref` results, descriptor old-field call variants, and tail-call old-field boundaries remain focused-test backed rather than generated-profile backed.

No new mismatch family was observed beyond the documented `local-cleanup-debris` normalizer.
