---
kind: research
status: completed
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

The direct v131 lit admission inventory began at `.tmp/precompute-v131-lit-matrix/status.tsv` and is extended by `.tmp/precompute-v131-full-fixture-matrix/result.json`. Shared function types, descriptor casts, stringref, shared-GC atomic reads/RMW operations, GC backing-array multibyte loads/stores, exact regular cast branches, legacy `try`/`rethrow`, continuation types, and stack-switching instructions are now represented and admitted. The official ref-func, descriptor, GC atomic/RMW, GC multibyte, GC loop, stack-switching, relaxed-SIMD, and propagating-partial fixtures match normalized Binaryen v131 output. All nine immutable-GC split modules match normalized output except module 0's already classified smaller dead/unreachable cleanup. The official general-GC binary remains valid and smaller at `1040` bytes versus Binaryen `1060`. Admission is no longer the primary blocker; the remaining broad fixture gap is plain `precompute_all-features.wast` control-produced values, arbitrary branch flow, effect reconstruction, and broader refinalization.

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
17. fresh allocation identity through `local.tee` reference aliases for aggregate reads and lengths, while retaining the alias write before the folded constant;
18. plain raw scalar cleanup around reachable `atomic.fence`, plus orphan scalar/Nop cleanup before `unreachable`, typed Nop/unreachable block flattening, and empty `try_table` body stabilization;
19. legacy `try` representation, tagged/catch-all/delegate binary codec and typechecking, recursive validation/encoding support, first-class `rethrow`, and conservative raw preservation for the precompute family;
20. continuation composite types (`0x5D`), `cont` / `nocont`, resume-handler immediates, and `cont.new`, `cont.bind`, `suspend`, `resume`, `resume_throw`, `resume_throw_ref`, and `switch` (`0xE0`-`0xE6`), with byte-for-byte preservation of the official stack-switching fixture;
21. recursive deterministic partial evaluation through select conditions, nested immutable global/fresh struct reads, non-null tests, reference identity, and typed `ref.func` emission;
22. deterministic SIMD constant evaluation for `f32x4.max` and `i32x4.splat`, while relaxed SIMD remains deliberately unfurled;
23. one exact enclosing-result loop-break fold and first-class known-heap evaluation separated from emitability.

Effect retention remains conservative and source-backed: exact parents and effect blocks reconstruct ordered local/global writes, while raw control folds retain trapping and effectful prefixes through stack-aware sequence proofs. Calls, branches, returns, traps, and unsupported arbitrary combinations are preserved unchanged unless the evaluator can reconstruct them without reordering. This fail-closed boundary is covered by the v131 fixture and generated matrices rather than treated as an open output-shape gap.

## Closeout classification

The reopened source-backed families are closed for the Binaryen v131 pass contract. Raw control evaluation now folds constant `br_if` values through numeric, `if`, `select`, block, loop, reference, and discarded-parent contexts while preserving trapping/effectful prefixes and exact label depth. Terminal-prefix reconstruction uses stack-aware root boundaries, and a regression guards the conditional self-exit case that must not be mistaken for an unconditional outer transfer. The official all-features residuals are therefore measured Starshine wins rather than open `Flow` gaps: plain Starshine is `375` canonical bytes versus Binaryen `485`, and propagation is `411` versus `482`. The retained plain differences remove only pure abandoned operands, unreachable operators, redundant branch scaffolding, dead declarative `ref.func` support, and dead local traffic while retaining the trapping conversion and all three global writes. The propagating differences are constant-`if`, local-write, and local-allocation cleanup with the same observable writes and results.

All nine immutable-GC split modules now match exactly. The partial fixtures remain valid and strictly smaller where they differ; stack switching and deterministic/relaxed SIMD boundaries remain exact. Conservative legacy-EH and stack-switching preservation is the correct behavior boundary because the interpreter must not execute exceptional suspension control merely to claim output-shape parity.

The official v131 `precompute-strings.wast` now decodes, optimizes, re-encodes, and validates end-to-end. All value-producing cases match the oracle; retained textual differences are either smaller removal of dropped constants/scratch locals or equivalent simplification of the two intentionally non-emittable surrogate-splitting slices. Immediate fresh mutable WTF-16 arrays fold to the same `string.const` results as Binaryen.

Focused evidence at the latest checkpoint is green: binary roundtrips include continuation, stack-switching, and rethrow coverage; focused precompute-family tests pass `106/106`; `moon test src/passes` passes `5912/5912`; full `moon test` passes `9399/9399`; `moon fmt`, `moon check`, `moon info`, and `git diff --check` pass; and the native release CLI validates the expanded official fixture matrix. A fresh v131 `precompute-all` smoke at `.tmp/pass-fuzz-precompute-v131-post-stack-partial-1000` compares `1000/1000` with `921` direct and `79` cleanup-normalized matches, zero mismatches, and zero validation/property/generator/command failures. Exact normalized v131 matches now include shared `ref.func`, descriptor, shared-GC atomic/RMW, GC multibyte, GC loop, stack switching, relaxed SIMD, propagating partial evaluation, and eight of nine immutable-GC split modules; the ninth retains only the established smaller cleanup shape. The general-GC fixture validates end to end with only the classified smaller/local-cleanup shapes above. The official `precompute-effects` fixture now also decodes, validates, runs both plain and propagating variants, and re-encodes. Its only residual shapes are `local.set` versus Binaryen's `drop(local.tee)` and removal of a dropped constant; canonical Starshine output is `178` versus Binaryen `185` bytes for propagation and `176` versus `185` for plain precompute.

Post-cleanup v131 lanes are current: `.tmp/pass-fuzz-precompute-v131-post-unreachable-aggregate-10000` completes `10000/10000` with `9132` direct and `868` local-cleanup-normalized matches; regular and `pass-fuzz-stress` each complete `10000/10000` with `6353` direct and `3647` cleanup-normalized matches; runtime/idempotence completes `1000/1000` with `921` direct and `79` cleanup-normalized matches, zero property failures, and zero semantic failures. The v131 wasm-smith lane `.tmp/pass-fuzz-precompute-v131-post-unreachable-wasm-smith-10000` compares `9956/10000`, with `9955` direct matches, one intentional Starshine correctness difference that retains a reachable `atomic.fence` before a branch-to-end, and 44 Binaryen command failures (`39` zero-length rec groups, one invalid tag index, one table index out of range, and three bad section sizes). The completed random-all lane `.tmp/pass-fuzz-precompute-v131-random-all-post-unreachable-10000` compares `10000/10000`: `4698` direct, `901` cleanup-normalized, and `4401` raw structural differences. Every raw difference is canonically smaller for Starshine by `2` to `45` bytes, with `65,918` aggregate bytes saved; the differences occur only in unrelated local/SSA/coalescing/subtyping/duplicate-import generator leaves and retain Starshine's proven dead discardable-read and constant-control cleanup. No larger output, validation failure, property failure, generator failure, or command failure remains in the lane. The existing warnings are unrelated unused-field/reserved-name/pass-manager warnings.

## Final v131 evidence

Both public variants completed the required direct matrix with explicit Binaryen v131 and `_build/native/release/build/cmd/cmd.exe`:

- plain regular GenValid: `.tmp/pass-fuzz-precompute-v131-final-regular-100000`, `100000/100000`, `63268` direct plus `36732` cleanup-normalized, zero mismatches or failures;
- plain dedicated `precompute-all`: `.tmp/pass-fuzz-precompute-v131-final-dedicated-10000`, `10000/10000`, `9132` direct plus `868` cleanup-normalized, zero mismatches or failures;
- plain random all-profiles: `.tmp/pass-fuzz-precompute-v131-final-random-all-10000`, `10000/10000`, `4698` direct, `901` cleanup-normalized, and `4401` inspected unrelated local/SSA/subtyping/coalescing/duplicate-import differences; all `4401` are smaller by `2..49` bytes and save `69,598` bytes total;
- plain wasm-smith: `.tmp/pass-fuzz-precompute-v131-final-wasm-smith-10000`, `9956` compared, `9955` direct, one intentional reachable-`atomic.fence` correctness win, and the same `44` Binaryen tool failures;
- propagating regular GenValid: `.tmp/pass-fuzz-precompute-propagate-v131-final-regular-100000`, `100000/100000`, `41287` direct plus `58713` cleanup-normalized, zero mismatches or failures;
- propagating dedicated `precompute-all`: `.tmp/pass-fuzz-precompute-propagate-v131-final-dedicated-10000`, `10000/10000`, `7306` direct plus `2694` cleanup-normalized, zero mismatches or failures;
- propagating random all-profiles: `.tmp/pass-fuzz-precompute-propagate-v131-final-random-all-10000`, `10000/10000`, `5076` direct, `2190` cleanup-normalized, and `2734` unrelated SSA/duplicate-import differences; every difference is smaller by `2..18` bytes and saves `33,282` bytes total;
- propagating wasm-smith: `.tmp/pass-fuzz-precompute-propagate-v131-final-wasm-smith-10000`, `9956` compared, `9951` direct, `2` cleanup-normalized, three classified differences, and `44` Binaryen tool failures. The differences are the reachable-fence correctness win, a smaller exact-local value form, and smaller removal of nontrapping `memory.size` debris before `unreachable`.

Runtime/idempotence samples complete `500/500` for each public variant with zero property, validation, generator, command, or semantic failures; Node records unsupported GC/reference cases separately. Self-optimization validates for both variants. Plain canonical output is `4,700,282` bytes versus Binaryen `4,674,334`; its one-warmup/15-run pass-local median is `27.317 ms` versus `142.883 ms` (`0.191x`). Propagating canonical output is `4,581,251` versus Binaryen `4,671,312`, saving `90,061` bytes; its median is `1,042.358 ms` versus `525.378 ms` (`1.984x`), inside the required `2x` threshold. The first self-hosted shape difference remains defined function `24` / absolute `51` and is not a semantic failure.

Final validation is `moon test src/passes` `5928/5928`, full `moon test` `9415/9415`, plus `moon fmt`, `moon check`, `moon info`, native release build, and `git diff --check`. `[O4Z-PCP131]001` is closed; reopen only for a semantic/validation failure, a pass-owned size loss without measured benefit, a newly identified source-backed v131 evaluator family, or pass-local regression beyond `2x` Binaryen.
