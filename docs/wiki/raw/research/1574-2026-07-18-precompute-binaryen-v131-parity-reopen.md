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

The direct v131 lit admission inventory is recorded at `.tmp/precompute-v131-lit-matrix/status.tsv`. Shared function types, descriptor casts, stringref, shared-GC atomic reads/RMW operations, GC backing-array multibyte loads/stores, and exact regular `br_on_cast` / `br_on_cast_fail` heap operands are now represented and admitted. The official `precompute-ref-func.wast`, `precompute-desc.wast`, `precompute-gc-atomics.wast`, `precompute-gc-atomics-rmw.wast`, and `precompute-gc-multibyte.wast` fixtures decode, optimize, validate, and match normalized Binaryen v131 output. The official `precompute-gc.wast` binary now also decodes, optimizes, validates, and re-encodes; its remaining textual differences are local-write/effect-shape cleanup and smaller unreachable canonicalization, with current encoded output `1040` bytes for Starshine versus `1060` for Binaryen. Remaining admission boundaries are legacy `try` in `precompute-effects.wast` plus continuation types and stack-switching opcodes.

## First reopened behavior slices

Red-first focused tests now cover and implementation closes:

1. two ordered `local.tee` children under a foldable parent;
2. nested local/global writes under value blocks, retained in source evaluation order while exposing the parent constant;
3. a `local.get` that reads a `local.tee` earlier in the same expression;
4. a genuine entry-default read before a later local write in `precompute-propagate`, using SSA origin rather than rejecting every written local;
5. immediate fresh `array.new_fixed i16` plus `string.new_wtf16_array`, emitting `string.const` only for a valid selected UTF-16 range, including supplementary scalar encoding and rejection of unpaired surrogates;
6. immutable fresh struct/array values transported through exact SSA local identities, including repeated field reads, array reads/lengths, and allocation-identity `ref.eq` while rejecting distinct-identity phi merges;
7. non-shared `ref.func` return flow through transparent blocks;
8. the v131 stringref binary/type surface used by `precompute-strings.wast`: the current `0x67` string heap type, measure/concat/equality, `string.as_wtf16`, code-unit reads, slices, and their binary opcodes;
9. direct v131 WTF-16 string interpretation with canonical supplementary encoding, invalid-surrogate emitability rejection, and `stringref <: externref` matching;
10. shared type metadata and the `0x65` shared composite wrapper used by the official shared `ref.func` fixture;
11. descriptor heap metadata, exact descriptor cast branch opcodes `0x25` / `0x26`, immutable global GC identity, descriptor extraction, and typed branch-produced values;
12. shared-GC atomic order/immediate preservation plus Binaryen-compatible folding of unordered and provably unshared `acqrel` reads;
13. GC backing-array multibyte load/store representation and binary immediates;
14. exact regular cast-branch heap operands, including `0x62` exact type-index decoding/encoding and exactness preservation through validation, HOT lowering, and rewrites;
15. nullable-null cast/test/trapping aggregate behavior, first-child and transparent-block unreachable collapse, constant void `br_if`, terminal self-loop flow, and constant `select` folding with selected effects retained;
16. exact cast-target block-result refinalization for the admitted single-branch/unreachable-tail shape;
17. fresh allocation identity through `local.tee` reference aliases for aggregate reads and lengths, while retaining the alias write before the folded constant.

The effect-retention implementation remains conservative: it recognizes exact unary/binary parents and effect blocks containing ordered constant local/global writes. Branching, calls, traps, and arbitrary effectful expression reconstruction remain open until they have dedicated flow/effect proofs.

## Active parity fronts

- legacy `try` admission for the official effects fixture, then full effect-child retention and general control `Flow` outcomes;
- nested immutable aggregate reads, loop/safe-merge identities, and temporary speculative heap caches beyond exact local/global allocation identities;
- reference/function constants and explicit known-value-versus-emitability handling beyond the admitted shared `ref.func`, descriptor, and string cases;
- continuation types and stack-switching instruction admission;
- remaining string operations outside the v131 precompute fixture and additional `array.new` / `array.new_data` immediate string construction shapes;
- broader type refinalization after arbitrary break/control replacement beyond the admitted exact cast-target block shape;
- v131-specific GenValid/runtime leaves and the required four-lane closeout;
- self-optimization and repeated performance comparison against v131.

The official v131 `precompute-strings.wast` now decodes, optimizes, re-encodes, and validates end-to-end. All value-producing cases match the oracle; retained textual differences are either smaller removal of dropped constants/scratch locals or equivalent simplification of the two intentionally non-emittable surrogate-splitting slices. Immediate fresh mutable WTF-16 arrays fold to the same `string.const` results as Binaryen.

Focused evidence at the latest checkpoint is green: binary roundtrips `107/107`; `precompute_wbtest.mbt` `9/9`; `precompute_test.mbt` `66/66`; `precompute_propagate_test.mbt` `15/15`; full `moon test` `9378/9378`; `moon info`; native release CLI builds; and exact normalized v131 matches for the shared `ref.func`, descriptor, shared-GC atomic/RMW, and GC multibyte fixtures. The general-GC fixture now validates end to end with only the classified smaller/local-cleanup shapes above. Fresh v131 comparison lanes complete `10000/10000` `precompute-all` (`7340` direct plus `2660` local-cleanup-normalized), `10000/10000` regular (`3723` direct plus `6277` cleanup-normalized), `10000/10000` stress with the same split, and `1000/1000` runtime/idempotence (`921` direct plus `79` cleanup-normalized, zero property or semantic failures). Those lanes predate the latest exact-cast/control/refinalization tranche and require smoke/requalification before closeout. The first random-all attempt stopped at `50` cases on `28` structural differences and remains open for normalizer/classification work; it is not closeout evidence. The existing warnings are unrelated unused-field/reserved-name/pass-manager warnings.

This note is an active contract, not a closeout. Keep `[O4Z-PCP131]001` open until every broad source-backed family is implemented or reduced to a narrow user-approved boundary.
