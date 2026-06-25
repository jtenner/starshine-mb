# Heap Store Optimization Profile Mutable Descriptor Old-Field Boundary

## Context

The HSO behavior matrix has focused coverage for result-typed `try_table` boundaries where a descriptor operand is a mutable descriptor global: Binaryen preserves the constructor, wrapper call, mutable descriptor read, and later `struct.set` because moving the descriptor read across the catchable call would be unsafe. The dedicated GenValid profile did not yet emit a mutable descriptor-global root or combine that boundary with old-field side-effect preservation.

## Change

Extended the HSO GenValid profile with a deterministic mutable descriptor-global boundary:

- the coverage-forced profile now gives defined global `1` an exact descriptor reference type and a `struct.new_default` initializer when a descriptor type is available;
- that descriptor global is mutable only for the HSO profile;
- the generated body creates a descriptor-bearing object whose overwritten field value is `memory.grow`, preserving an old-field side effect;
- the descriptor operand is `global.get` of the mutable descriptor global;
- a catchable result-typed `try_table` direct-call wrapper follows the constructor assignment; and
- a later same-local `struct.set` remains after the wrapper.

Strengthened the HSO profile artifact test red-first to require `global.get` in the decoded artifact. It failed before the generator emitted the mutable descriptor-global root and passed afterward.

## Evidence

- Red-first `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed in the HSO profile artifact test because the generated function lacked `global.get`.
- After the generator update, `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed: `92/92`.
- `moon fmt` passed.
- `moon build --target-dir target --target native --release src/cmd` passed and refreshed `target/native/release/build/cmd/cmd.exe`; existing `src/passes/pass_manager.mbt` unused-function warnings remained.
- Dedicated profile smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-mutable-desc-old-field-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - Result: compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `0` hits / `20` misses.
- Direct smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-mutable-desc-old-field-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`
  - Result: compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Classification

This is generated-profile coverage expansion for a source-backed boundary, not final HSO-D/E/G closeout. It keeps the focused `1011` mutable descriptor call boundary and old-field preservation families represented in the aggregate profile, with no new raw mismatch family beyond the already documented `local-cleanup-debris` normalizer.

Remaining generated gaps include call-valued old-field roots, broader mutable descriptor old-field call/ref-call variants, exact descriptor `ref.cast`, broader descriptor/control surfaces, performance, and final HSO-B/D/E/F/G/H/I/J closeout.
