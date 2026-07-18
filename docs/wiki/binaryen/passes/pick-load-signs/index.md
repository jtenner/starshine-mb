---
kind: entity
status: supported
starshine_status: active
last_reviewed: 2026-07-18
sources:
  - ../../../raw/research/1572-2026-07-18-pick-load-signs-version-131-behavior-audit.md
  - ../../../raw/research/0784-2026-06-20-pick-load-signs-modern-signoff-refresh.md
  - ../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/PickLoadSigns.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/pick-load-signs_sign-ext.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ./fuzzing.md
  - ../../no-dwarf-default-optimize-path.md
---

# `pick-load-signs`

## Role

`pick-load-signs` chooses the signed or unsigned opcode for a narrow load when every read of the receiving local proves a consistent extension width.

Binaryen `version_131` remains intentionally small:

- exact non-tee `local.set(load ...)` producers;
- i32 direct signed extension and signed shift-pair evidence;
- i32 right-hand low masks for unsigned evidence;
- all-use recognition, width agreement, atomic exclusion, and signed-weighted voting.

The upstream helper contract is effectively i32-only.

## Starshine status

Starshine is **closed at Binaryen-v131-or-better behavior parity**.

It covers every upstream transform and bailout and retains five broader evidence families:

1. commuted i32 masks;
2. i32 unsigned shift pairs;
3. i64 direct signed extensions;
4. i64 low masks;
5. i64 signed and unsigned shift pairs.

For those extra families, PLS now removes the redundant extension expression after proving every possible value source is a matching rewritten narrow load. Across the 16 retained width/family probes, Starshine canonical output is `1` to `7` bytes smaller than Binaryen per function and runtime results match for negative boundary values.

Exact simple forms use a raw pass-manager rewrite path. Representative 2,000-function workloads run faster than Binaryen v131 (`6.21-7.36 ms` Starshine versus `6.94-8.18 ms` Binaryen).

## Final evidence

- regular GenValid: `100000/100000` exact normalized;
- wasm-smith: `9956/10000` compared, `9955` exact normalized, one cleanup-normalized PLS-unrelated debris mismatch, `44` Binaryen/tool failures;
- `pick-load-signs-all`: `10000/10000`, with `6452` exact matches and `3548` measured smaller-output Starshine wins;
- scheduled `pick-load-signs -> precompute`: `10000/10000`, with `5300` exact matches and `4700` smaller Starshine outputs;
- `random-all-profiles`: `10000/10000` exact normalized;
- focused passes: `5857/5857`;
- validation package: `1704/1704`;
- full suite: `9333/9333`.

The dedicated profile now exposes all previously hidden mutating families. See [`./parity.md`](./parity.md) for classification and [`./fuzzing.md`](./fuzzing.md) for profile composition.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md): exact upstream algorithm.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md): upstream owner/test map.
- [`./wat-shapes.md`](./wat-shapes.md): positive, bailout, and retained Starshine-win shapes.
- [`./starshine-strategy.md`](./starshine-strategy.md): concise local code map.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md): HOT/use-def and raw-path details.
- [`./parity.md`](./parity.md): final classification and signoff.
- [`./fuzzing.md`](./fuzzing.md): dedicated profile and replay commands.

## Reopening rule

Reopen if Binaryen changes the v131 contract, a retained cleanup loses its source-completeness proof, canonical output stops winning, performance exceeds the `2x` target, or runtime/fuzzing finds a semantic mismatch.
