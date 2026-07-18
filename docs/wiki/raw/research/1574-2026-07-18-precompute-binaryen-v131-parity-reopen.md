---
kind: research
status: working
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_131
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/Precompute.cpp
  - ../../../../src/passes/precompute.mbt
  - ../../../../src/passes/precompute_test.mbt
  - ../../../../src/passes/precompute_wbtest.mbt
related:
  - ./1573-2026-07-18-precompute-returned-values-arrays-and-effect-retention.md
  - ../../../binaryen/passes/precompute/index.md
  - ../../../binaryen/passes/precompute-propagate/index.md
---

# Precompute Binaryen v131 parity reopen

## Scope

Binaryen `version_131`, released July 15, 2026, is now the direct oracle for plain `precompute` and `precompute-propagate`. The official x86_64 Linux archive is unpacked at `.tmp/binaryen-version-131-bin`; its executable reports `wasm-opt version 131 (version_131)`. The source archive is under `.tmp/binaryen-version-131-src`.

The v131 and previously captured v130 `src/passes/Precompute.cpp` files are byte-identical: both have SHA-256 `7cd012b9bd0e7afc878029115e6672b9e53f46cc485b8113a14511cefabd4143`. The oracle update therefore does not invalidate the prior scalar results, but a direct v131 source/lit review reopens the broader interpreter behaviors that the generated closeout did not exercise.

## Baseline

With the July 18 scalar/array follow-up still applied:

- v131 aggregate smoke `.tmp/pass-fuzz-precompute-v131-baseline-aggregate-200`: `200/200`, `156` normalized, `44` cleanup-normalized, zero mismatches or failures;
- v131 random-all smoke `.tmp/pass-fuzz-precompute-v131-baseline-random-all-200`: `200/200`, `93` normalized, `53` cleanup-normalized, `54` raw mismatches, zero validation/property/generator/command failures;
- after the first reopened fixes, `.tmp/pass-fuzz-precompute-v131-progress-aggregate-1000-localnorm` completes `1000/1000` with `747` normalized and `253` local-cleanup-normalized matches, zero mismatches, and zero validation/property/generator/command failures;
- `.tmp/pass-fuzz-precompute-v131-progress-random-all-1000` completes `1000/1000` with `497` normalized, `243` compare-normalized, and `260` raw structural differences; all `260` normalized wasm files are smaller for Starshine (`83` `ssa-nomerge-smoke`, `81` `ssa-nomerge-parity`, `69` duplicate-function-import, `27` duplicate-nonfunction-import cases), with zero validation/property/generator/command failures;
- comparisons use isolated cache `.tmp/pass-fuzz-cache-v131` so v130 oracle artifacts cannot mask v131 results.

The direct v131 lit admission inventory is recorded at `.tmp/precompute-v131-lit-matrix/status.tsv`. Several failures are currently parser/decoder/type-surface boundaries rather than pass output differences, including descriptors, shared types, stringref, stack switching, and selected GC atomic forms. Supported lit modules remain useful but are not sufficient to claim full parity.

## First reopened behavior slices

Red-first focused tests now cover and implementation closes:

1. two ordered `local.tee` children under a foldable parent;
2. nested local/global writes under value blocks, retained in source evaluation order while exposing the parent constant;
3. a `local.get` that reads a `local.tee` earlier in the same expression;
4. a genuine entry-default read before a later local write in `precompute-propagate`, using SSA origin rather than rejecting every written local;
5. immediate fresh `array.new_fixed i16` plus `string.new_wtf16_array`, emitting `string.const` only for a valid selected UTF-16 range, including supplementary scalar encoding and rejection of unpaired surrogates.

The effect-retention implementation remains conservative: it recognizes exact unary/binary parents and effect blocks containing ordered constant local/global writes. Branching, calls, traps, and arbitrary effectful expression reconstruction remain open until they have dedicated flow/effect proofs.

## Active parity fronts

- full v131 effect-child retention and control `Flow` outcomes;
- heap identity through locals and safe merges, immutable global/nested aggregate reads, and temporary speculative heap caches;
- reference/function constants and explicit known-value-versus-emitability handling;
- string operations and any required parser/binary/typecheck instruction surface beyond the already represented array new/encode forms;
- final type refinalization after break/control replacement;
- v131-specific GenValid/runtime leaves and the required four-lane closeout;
- self-optimization and repeated performance comparison against v131.

Focused formatting/build evidence at this checkpoint is green: `moon fmt`; `precompute_wbtest.mbt` `4/4`; `precompute_test.mbt` `55/55`; `precompute_propagate_test.mbt` `15/15`; and a refreshed native release CLI build. The existing warnings are unrelated unused-field/reserved-name/pass-manager warnings.

This note is an active contract, not a closeout. Keep `[O4Z-PCP131]001` open until every broad source-backed family is implemented or reduced to a narrow user-approved boundary.
