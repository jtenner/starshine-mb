---
kind: workflow
status: working
last_reviewed: 2026-07-02
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../raw/research/1402-2026-07-02-heap2local-genvalid-profile-start.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `heap2local` Fuzzing Profile

Regular direct lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --out-dir .tmp/pass-fuzz-heap2local --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Dedicated GenValid aggregate: `heap2local-all`.

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --gen-valid-profile heap2local-all --out-dir .tmp/pass-fuzz-heap2local-genvalid-all-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Aliases accepted by GenValid profile lookup: `heap2local`, `heap-to-local`, `h2l`, `heap2local-closeout`, and `heap2local-all-profiles`.

## Profile leaves

- `heap2local-struct`: local-held fresh struct candidates with `struct.new` / `struct.new_default`, `struct.set`, `struct.get`, owner locals, and local-copy-shaped traffic.
- `heap2local-array`: constant-size local-held array candidates with `array.new_default`, `array.new_fixed`, constant-index `array.get`, and `array.set`.
- `heap2local-ref`: direct fresh-reference folds with `ref.as_non_null`, `ref.eq`, and `ref.test` over fresh struct allocations.

The aggregate samples all three leaves and records the selected leaf through the normal composite-profile manifest `selected_profile` field. Use that field when triaging generated mismatches so struct scalarization, array lowering, and ref-fold families stay separated.

## Current smoke status

A 2026-07-02 first aggregate smoke after profile config fixes, `.tmp/pass-fuzz-heap2local-genvalid-all-1000-aggregate-config-fix`, compared `278/1000` before hitting the mismatch cap: `67` normalized matches, `211` mismatches, zero command/validation/generator/property failures, selected profiles `heap2local-struct=131`, `heap2local-array=75`, and `heap2local-ref=72` before cap. Treat these as open behavior-parity gaps; do not use the profile as a green signoff lane until the mismatch families are reduced or fixed.

A follow-up slice reduced `case-000001` (`selected_profile=heap2local-struct`) to repeated same-owner fresh struct allocations with a self-copy write. Starshine now scalarizes that generated family and removes residual `struct.new`, `struct.new_default`, `struct.get`, and `struct.set` traffic. Replay `.tmp/pass-fuzz-heap2local-case000001-after-sequential-owner` still reports a raw mismatch (`1/1`, zero failures) because Binaryen preserves extra local/default-value/drop debris while Starshine emits a smaller scalarized form. Agent classification: **behavior-parity improvement plus residual output-shape/local-debris drift**, not the original true GC-scalarization parity gap. A 100-case struct leaf smoke, `.tmp/pass-fuzz-heap2local-struct-100-after-sequential-owner`, compared `100/100`: `18` normalized and `82` mismatches, zero failures; every saved Starshine mismatch had no residual `struct.new`, `struct.get`, or `struct.set`. A 100-case aggregate smoke, `.tmp/pass-fuzz-heap2local-all-100-after-sequential-owner`, compared `100/100`: `22` normalized, `78` mismatches, zero failures, selected profiles `heap2local-struct=49`, `heap2local-array=22`, and `heap2local-ref=29`. Array and direct-ref leaves still need family-specific reduction/classification.

## Known exclusions

The first dedicated profile intentionally focuses on validator-accepted H2L opportunities. It does not yet force nondefaultable-local repair, broad descriptor-cast traffic, escapes through calls/returns, mixed branch/select provenance, dynamic array sizes, dynamic array indexes, or atomic/RMW/cmpxchg corner cases. Those are audit targets only after focused source review and validator-surface proof.

## Required signoff use

For ordinary H2L audit signoff, use `heap2local-all` as the pass-specific GenValid lane in addition to regular GenValid, explicit wasm-smith, and the broad random-all-profiles lane.
