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

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

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

## Binaryen 132 descriptor renewal

`binaryen132-descriptor-branches` covers both branch polarities, exactness,
nullable targets, null descriptors and unreachable sources. Seed bit 5 adds the
v132 non-nullable-local regression: a descriptor block traps while producing a
reference, and local-subtyping must retain the uninhabitable `(ref none)` result.
The bounded [generator tests](../../../../../src/validate/gen_valid_descriptor_branches_wbtest.mbt)
and [pass tests](../../../../../src/passes/binaryen132_descriptor_test.mbt) also
check extra label payloads and operand calls. A label payload is borrowed from
the surrounding stack and must not be evaluated again by a branch replacement.
A reachable branch out of the descriptor-producing block prevents a false
nonreturning proof. External execution is unavailable for this proposal; record
structural validation separately when renewing the dedicated 10,000-case lane.

### September 15 unused type-group repair

Narrowed modules now prune unused whole recursion groups and singleton types
under a conservative reference-surface guard. Group identities and type/field
names are preserved; only smaller validated candidates are accepted. Four
red-first pass regressions and all 95 local-subtyping tests pass.
[Proof and limits](../../../ir2/architecture-rules.md#local-subtyping-unused-type-group-repair).
Native aggregate renewal remains pending; do not replace historical counts yet.

### No-change cleanup follow-up

The first 10,000-case v132 renewal exposed dead signatures in modules where no
local narrowed. Cleanup now runs at the fixed point even without a type change.
The pass and dispatcher regressions first failed with four/three types instead
of one. The remaining i31 admission and dead-return continuation regressions
are separate pending repairs; renewed aggregate evidence follows those fixes.

### i31 cleanup admission follow-up

The shared type-remap guard now admits `ref.i31`, which has no type index.
The pass and dispatcher fixtures first retained three type entries instead of
two; cleanup now prunes the dead recursive group while preserving the i31
conditional. All 97 other local-subtyping tests pass; the separate dead-return
regression remains red. Final fuzz renewal must also cover both precompute
variants because they share this guard.
