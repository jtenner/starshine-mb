---
kind: workflow
status: supported
last_reviewed: 2026-07-26
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_memory_packing_tests.mbt
  - ../../../../../src/passes/memory_packing_test.mbt
  - ./parity.md
---

# `memory-packing` Fuzzing Profile

## Current oracle and binaries

The post-repair closeout uses:

- official `binaryen-version_131-x86_64-linux.tar.gz`, verified SHA-256 `b5bf1f0eaf17c63ee588ff7a5954dc8f6ce2c26989051c66f24dfe9ece3e46db`, containing `wasm-opt version 131 (version_131)` with extracted-binary SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`;
- `_build/native/release/build/cmd/cmd.exe`, SHA-256 `d1da69250cf22c0b93f2180e82e742bc6936e80152b8dd53289a241383db2750`;
- the default persistent `.tmp/pass-fuzz-cache`;
- `--jobs auto` and explicit `--wasm-opt-bin` / `--starshine-bin` paths on every lane.

## Regular GenValid lane

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass memory-packing --out-dir .tmp/pass-fuzz-memory-packing-regular-100000-postrepair --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Result: `100000/100000` normalized matches, zero cleanup-normalized matches, mismatches, command failures, validation failures, generator failures, or property failures. Binaryen cache: `317` hits / `99683` misses.

## Dedicated `memory-packing-all` lane

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass memory-packing --gen-valid-profile memory-packing-all --out-dir .tmp/pass-fuzz-memory-packing-dedicated-10000-postrepair --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Result: `10000/10000` normalized matches and zero failures. Selected leaves:

- `memory-packing-active`: `3750`;
- `memory-packing-passive`: `3750`;
- `memory-packing-legacy-eh`: `2500`.

The aggregate is defined in `src/validate/gen_valid.mbt`, tested in `src/validate/gen_valid_memory_packing_tests.mbt`, and included in `random-all-profiles`. Every leaf emits a valid profitable zero range. The active leaf varies the offset by seed; the passive leaf exercises split `memory.init` replacement; the legacy-EH leaf places passive users in protected and catch-all bodies. Binaryen cache: `9170` hits / `830` misses.

Imported overlap remains option-sensitive and is still locked by focused fixtures because compare-pass does not forward `zero_filled_memory` as part of a GenValid profile. The focused suite covers imported zero/nonzero tramplers, out-of-bounds bailouts, maximal memory64, and the exact `2^64` endpoint.

## Random all-profiles lane

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass memory-packing --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-memory-packing-random-all-10000-postrepair --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Result: `10000/10000` normalized matches and zero failures. The lane selected `249` active, `236` passive, and `151` legacy-EH memory-packing leaves among the broader composite. Binaryen cache: `6044` hits / `3956` misses.

## Explicit wasm-smith lane

```sh
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass memory-packing --out-dir .tmp/pass-fuzz-memory-packing-wasm-smith-10000-postrepair --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures
```

Result: `9956/10000` compared, `9955` normalized matches, one raw mismatch, zero validation/generator/property failures, and `44` Binaryen-only command failures:

- `39` empty recursion-group failures;
- `3` bad-section-size failures;
- `1` invalid-tag-index failure;
- `1` table-index-out-of-range failure.

The sole residual is the previously recorded `case-009332-wasm-smith`: it has no data section and differs only because Starshine retains one extra unreachable `drop` shell. Agent classification: pass-independent representation drift, not a `memory-packing` semantic or transform-family mismatch. wasm-smith cache: `10000` hits / `0` misses; Binaryen cache: `106` hits / `9850` misses, failure cache `0` hits / `44` misses.

## Focused behavior coverage

The focused pass suite covers:

- active and passive profitability thresholds, including Binaryen's passive metadata/referrer overhead formula and edge threshold;
- exact stack-aware destination extraction around `table.set`, `array.copy`, `br_on_null`, `ref.test_desc`, and `ref.cast_desc_eq`;
- decoded legacy `try` protected/catch user discovery and rewriting while preserving handler shape;
- source-order trampling and imported in-bounds policy;
- trap preservation, memory64 bounds, names, segment limits, data-count repair, GC data-user boundaries, and drop-state globals.

## O4z evidence

The prior rebuilt slot-3 replay remains canonical and normalized equal at `4,954,978` bytes. Pass-local timing was `101.821ms` Starshine versus `61.168ms` Binaryen (`1.66x`, inside the repository `2x` target); whole-command time was `776.671ms` versus `520.314ms`.
