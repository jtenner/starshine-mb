---
kind: workflow
status: supported
last_reviewed: 2026-07-26
sources:
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - ../../../../../src/passes/local_subtyping.mbt
  - ../../../../../src/passes/local_subtyping_test.mbt
  - ../../../tooling/pass-fuzz-compare.md
---

# `local-subtyping` fuzzing

## Dedicated family aggregate

Use `local-subtyping-all` for development and closeout. The aggregate records `selected_profile` and samples seven behavior families:

| Leaf | Weight | Covered behavior |
| --- | ---: | --- |
| `local-subtyping-straight-line` | 2 | dominating `local.set`, `local.tee`, and reads |
| `local-subtyping-structured` | 2 | dominated reads in branch-free block, loop, and if regions |
| `local-subtyping-unreachable-tail` | 1 | return plus syntactic unreachable-tail reads |
| `local-subtyping-lubs` | 2 | mixed i31/struct abstract LUB narrowing |
| `local-subtyping-iteration` | 2 | three-local repeated declaration refinement |
| `local-subtyping-null-bottom` | 1 | typed-null bottom plus exact concrete assignment LUB |
| `local-subtyping-control-refinalize` | 1 | i31-valued if and direct-branch block result refinalization |

Aliases `local-subtyping`, `local-subtyping-closeout`, `local-subtyping-all-profiles`, `ls`, and `ls-closeout` resolve to the aggregate.

## Final v131 matrix

All final lanes used seed and count shown below, `--jobs auto`, native Starshine SHA-256 `06641af9e76f29298ad0b892b5cf2519dd35470c05c1065799d98657845e57ff`, and explicit official `.tmp/binaryen-version-131/bin/wasm-opt` reporting `wasm-opt version 131 (version_131)` with SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

- Regular GenValid: `.tmp/pass-fuzz-local-subtyping-v131-closeout-regular-100000`; requested/compared `100000/100000`, normalized `100000`, zero mismatches or failures; Binaryen cache `10318` hits / `89682` misses.
- Explicit wasm-smith: `.tmp/pass-fuzz-local-subtyping-v131-closeout-wasm-smith-10000`; requested `10000`, compared `9956`, normalized `9955`, one raw mismatch, zero validation/generator/property failures, and `44` Binaryen-only command failures. Failure classes are `39` empty recursion groups, `3` bad section sizes, `1` invalid tag index, and `1` table index out of range. Case `009332` is pass-independent `drop(unreachable)` cleanup debris.
- Cleanup-classification replay: `.tmp/pass-fuzz-local-subtyping-v131-closeout-wasm-smith-10000-cleanup`; the same `9956` comparable cases produce `9955` normalized plus `1` cleanup-normalized match and zero mismatches; all Binaryen artifacts/failures were cache hits.
- Dedicated family aggregate: `.tmp/pass-fuzz-local-subtyping-v131-closeout-profile-10000`; requested/compared `10000/10000`, normalized `10000`, zero failures. Selected counts: straight-line `1865`, structured `1817`, unreachable-tail `890`, LUBs `1854`, iteration `1789`, null-bottom `886`, and control-refinalize `899`.
- Random all-profiles: `.tmp/pass-fuzz-local-subtyping-audit-random-all-10000-v2`; requested/compared `10000/10000`, normalized `10000`, zero failures; Binaryen cache `9456` hits / `544` misses. The lane selected every local-subtyping leaf, including `64` control-refinalize, `138` LUB, `150` iteration, and `66` null-bottom cases.

## Commands

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass local-subtyping --out-dir .tmp/pass-fuzz-local-subtyping-v131-closeout-regular-100000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass local-subtyping --out-dir .tmp/pass-fuzz-local-subtyping-v131-closeout-wasm-smith-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-subtyping --gen-valid-profile local-subtyping-all --out-dir .tmp/pass-fuzz-local-subtyping-v131-closeout-profile-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass local-subtyping --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-local-subtyping-audit-random-all-10000-v2 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --wasm-opt-bin .tmp/binaryen-version-131/bin/wasm-opt --max-failures 2000 --keep-going-after-command-failures --no-reduce-mismatches
```
