# Heap Store Optimization Profile Catchable `call_indirect`

## Context

The dedicated `heap-store-optimization` GenValid profile already covered catchable result-typed `try_table` wrappers containing direct `call` and typed-function-reference `call_ref` roots. Generated `call_indirect` wrappers remained open even though the HSO behavior inventory has source-backed direct and old-field indirect-call boundaries, including catchable result-wrapper families.

## Change

Extended `src/validate/gen_valid.mbt` so the HSO profile emits a deterministic catchable result-typed wrapper with:

- a `memory.size`-seeded fresh `struct.new` assigned to the same local;
- a local `block` containing `try_table (result i32)` with a local `catch_all`;
- `i32.const 0` plus `call_indirect` through table `0` using the current no-param/no-result function type;
- a dropped wrapper result; and
- a later same-local `struct.set` that Binaryen keeps conservative because the wrapper contains a catchable indirect call.

Strengthened `src/fuzz/main_wbtest.mbt` red-first to require `call_indirect` in the decoded HSO profile artifact. The focused fuzz test failed before the generator update and passed after the new root was added.

## Evidence

- Red-first `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed in `emit gen-valid heap-store-optimization profile records GC store opportunities` because the profile artifact lacked `call_indirect`.
- After the generator update, `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` passed: `92/92`.
- `moon fmt` passed.
- `moon build --target-dir target --target native --release src/cmd` passed and refreshed `target/native/release/build/cmd/cmd.exe`; the existing `src/passes/pass_manager.mbt` unused-function warnings remained.
- Dedicated profile smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-catchable-call-indirect-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures`
  - Result: compared `20/20`; normalized matches `0`; compare-normalized matches `20`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `0` hits / `20` misses.
- Direct smoke:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-catchable-call-indirect-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures`
  - Result: compared `1000/1000`; normalized matches `1000`; compare-normalized matches `0`; validation/property/generator/command failures `0`; mismatches `0`; Binaryen cache `1000` hits / `0` misses.

## Classification

This is generated-profile coverage expansion, not final behavior closure. It covers the remaining catchable result-wrapper indirect-call opcode sibling in the aggregate HSO profile and keeps the existing `local-cleanup-debris` normalizer classification for Binaryen-retained `nop` vs Starshine nop-free folded-store output. No new raw mismatch family was observed.

Mutable descriptor result-wrapper old-field variants, call-valued generated old-field variants, broader catchable descriptor wrappers, exact descriptor `ref.cast`, broader descriptor/control surfaces, and HSO-D/E/F/G/H/I/J closeout work remain open.
