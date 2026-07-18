---
kind: research
status: complete
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/wasm-interpreter.h
  - ../../../../src/passes/precompute.mbt
  - ../../../../src/passes/precompute_test.mbt
  - ../../../../src/passes/precompute_wbtest.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_precompute_propagate_tests.mbt
  - ../../../../.tmp/binaryen-version-130/Precompute.cpp
  - ../../../../.tmp/binaryen-version-130-bin/bin/wasm-opt
  - ../../../../.tmp/pass-fuzz-precompute-gap-close-final4-aggregate-10000/result.json
  - ../../../../.tmp/pass-fuzz-precompute-gap-close-final4-plain-aggregate-10000/result.json
  - ../../../../.tmp/pass-fuzz-precompute-gap-close-final4-regular-10000/result.json
  - ../../../../.tmp/pass-fuzz-precompute-gap-close-final4-stress-10000/result.json
  - ../../../../.tmp/pass-fuzz-precompute-gap-close-final4-wasm-smith-10000/result.json
  - ../../../../.tmp/pass-fuzz-precompute-gap-close-final4-random-all-10000/result.json
  - ../../../../.tmp/pass-fuzz-precompute-gap-close-final4-runtime-1000/result.json
  - ../../../../.tmp/benchmark-precompute-gap-close-final2-2026-07-18/benchmark-summary.json
related:
  - ../../binaryen/passes/precompute/index.md
  - ../../binaryen/passes/precompute/fuzzing.md
  - ../../binaryen/passes/precompute/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/precompute-propagate/index.md
  - ../../binaryen/passes/precompute-propagate/fuzzing.md
  - ../../binaryen/passes/precompute-propagate/starshine-port-readiness-and-validation.md
  - ./1572-2026-07-17-precompute-propagate-port-and-signoff.md
---

# Precompute returned values, fresh arrays, and effect retention

## Scope

This follow-up reopens only Binaryen-backed shared-evaluator gaps found after the public `precompute-propagate` port was committed. It does not change the one-local-solve/one-evaluator-rerun propagation contract.

The reduced witnesses were:

- `.tmp/precompute-remaining-unary-witness.wat`: returned integer count/rotate, floating unary/min, and conversion values;
- `.tmp/precompute-remaining-array-witness.wat`: immutable `array.new_fixed`/`array.get` and `array.new_default`/`array.len`;
- `.tmp/precompute-remaining-child-retention.wat`: a constant parent fed by `local.tee` whose write must survive;
- `.tmp/precompute-remaining-multiparent-select.wat`: repeated parent evaluation through a `select`.

Before this slice, Binaryen v130 reduced the first witness from `123` to `115` canonical bytes and the array witness from `65` to `48`, while Starshine retained the operations. The child-retention witness was equal-sized at `41` bytes, but Binaryen exposed the final constant for downstream passes.

## Implementation

### Returned scalar values

The shared raw/HOT evaluator now emits exact returned constants for:

- `i32`/`i64` `clz`, `ctz`, and `popcnt`;
- `i32`/`i64` `rotl` and `rotr`;
- floating `abs`, `neg`, `ceil`, `floor`, `trunc`, ties-to-even `nearest`, and `sqrt`;
- floating `min`, `max`, and `copysign`, including signed-zero selection;
- integer/float conversions, reinterpretations, sign extensions, wraps, promotes/demotes, trapping conversions when in range, and saturating conversions.

Floating tests cover NaNs, infinities, signed zero, subnormals, ties-to-even, reversed signed-zero `max`, arithmetic NaNs, and NaN promote/demote. For the NaN-producing v130 oracle shapes checked here, Starshine emits the same canonical quiet-NaN bit patterns as Binaryen. Bit-preserving `abs`, `neg`, reinterpret, and `copysign` paths continue to operate on exact payload bits. Unsigned `f64 -> i64` truncation above `2^63` uses an explicit high-bit decomposition rather than target-dependent native `Double::to_uint64`, matching Binaryen at `2^63` and the largest in-range representable value below `2^64`.

Unary parent evaluation was added beside the existing binary `select` parent path, so repeated parents such as `eqz(add(select(...), const))` can reach a stable arm-wise result.

### Fresh immutable aggregates

The evaluator now folds statically in-bounds immutable reads and lengths for fresh, unaliased:

- `array.new`, `array.new_default`, and `array.new_fixed`;
- `array.get`, `array.get_s`, `array.get_u`, and `array.len`;
- `struct.new` and `struct.new_default` field reads;
- packed signed/unsigned array and struct reads.

The implementation remains deliberately allocation-local. It rejects negative dynamic lengths, statically out-of-bounds reads, and lengths at or above Binaryen v130's interpreter `DataLimit`. For the 64-bit v130 oracle, the first rejected length is `44,739,242` (`1 GiB / sizeof(Literal)` with 24-byte literals); focused and generated tests cover `44,739,241` as the last folded length and `44,739,242` as the first retained length. It does not claim a general alias-aware heap cache, allocation identity through arbitrary locals, mutable aggregate reasoning, or nested interior-reference emitability.

### Effect-preserving exact parents

When an exact unary or binary parent consumes a constant-valued `local.tee`, Starshine now preserves the write as `local.set` and exposes the folded parent constant in a result block. This is implemented in both the raw stack path and HOT path, so plain `precompute` and public `precompute-propagate` share the behavior.

For the reduced witness, Binaryen emits `drop(local.tee(...)); i32.const 3` at `41` bytes. Starshine emits `local.set ...; i32.const 3` at `40` bytes. The write and evaluation order are preserved while the result becomes directly reusable.

This is not a general side-effect retention engine. Global writes, calls, traps, branches, multiple effectful children, and speculative cross-control reconstruction still require the broader Binaryen-style `EffectAnalyzer`/`Flow` architecture.

## GenValid coverage

Three deterministic returned-value leaves were added to the `precompute-all` aggregate and to `random-all-profiles` through that aggregate:

- `precompute-scalar-values` returns representative count/rotate, floating edge, conversion, reinterpretation, sign-extension, and saturation results;
- `precompute-gc-values` returns fresh immutable array and struct values, including packed reads and default constructors;
- `precompute-effectful-values` returns an exact parent over `local.tee`.

The `precompute-propagate` and `precompute-propagate-closeout` compatibility aliases now select the aggregate. The exact `precompute-propagate-local-facts` name remains the dedicated propagation-consensus leaf.

Focused generator tests validate the modules and assert that the new instruction families are actually present.

## Oracle and fuzz results

All lanes used Binaryen `version_130`, `_build/native/release/build/cmd/cmd.exe`, parallel workers, and the persistent cache.

| Lane | Result |
|---|---|
| Expanded scalar returned-value leaf | `100/100` exact normalized matches, no failures |
| Expanded GC returned-value leaf | `100/100` exact normalized matches, no failures |
| Effectful returned-value leaf | `100/100` cleanup-normalized matches, no failures |
| Plain `precompute` aggregate | `10000/10000`; `7340` normalized, `2660` cleanup-normalized, `0` mismatches/failures |
| `precompute-propagate` aggregate | `10000/10000`; `7306` normalized, `2694` cleanup-normalized, `0` mismatches/failures |
| Regular GenValid | `10000/10000`; `1915` normalized, `8085` cleanup-normalized, `0` mismatches/failures |
| `pass-fuzz-stress` | `10000/10000`; `1921` normalized, `8079` cleanup-normalized, `0` mismatches/failures |
| wasm-smith | `9956/10000`; `9951` normalized, `3` cleanup-normalized, the same `2` classified differences, `44` Binaryen parser/tool failures |
| Random all profiles | `10000/10000`; `4664` normalized, `2602` cleanup-normalized, `2734` raw differences, no failures |

The wasm-smith differences are unchanged:

1. `case-003694-wasm-smith`: smaller equivalent Starshine scratch-local replay, `74` versus `81` bytes.
2. `case-006523-wasm-smith`: intentional reachable `atomic.fence` preservation, `63` versus Binaryen's `56` bytes.

All `2734` random-all differences are canonically smaller for Starshine; none are equal-sized or larger. Families:

- `ssa-nomerge-smoke`: `920`;
- `ssa-nomerge-parity`: `916`;
- duplicate function-import elimination: `657`;
- duplicate nonfunction-import elimination: `241`.

The `1000`-case aggregate runtime/idempotence lane had `1000/1000` idempotence matches, `955` runtime-checked cases, `45` unsupported runtime cases, and zero runtime semantic mismatches or property failures.

## Performance and artifact result

One warmup plus 15 measured runs on `tests/node/dist/starshine-debug-wasi.wasm` produced:

- Starshine pass-local median: `782.394 ms`;
- Binaryen v130 pass-local median: `540.976 ms`;
- Starshine ratio: `1.446x` Binaryen, within the maintained `<2x` ceiling;
- Starshine whole-command median: `7,799.692 ms`;
- Binaryen whole-command median: `1,204.678 ms`;
- whole-command ratio: `6.475x`.

Canonical output is now:

- Starshine: `4,585,838` bytes;
- Binaryen: `4,666,022` bytes;
- Starshine smaller by `80,184` bytes (`1.718%`).

Compared with the July 17 checkpoint, the evaluator additions reduce Starshine's canonical self-optimization output by another `135` bytes. Pass-local median rises from `694.444` to `782.394 ms`; this remains below the pass's `2x` reopening threshold. Whole-command median changes from `7,330.096` to `7,799.692 ms`.

## Validation

- `moon fmt`: passed;
- `moon info`: passed with existing warnings;
- `moon test`: `9352/9352`;
- `moon check --target wasm-gc`: passed;
- `moon test --target wasm-gc`: `9352/9352`;
- focused `precompute_test.mbt`: `51/51`;
- focused `precompute_wbtest.mbt`: `3/3`;
- focused GenValid profile tests: `4/4`;
- `bun validate readme-api-sync`: passed;
- `bun validate full --profile ci --target wasm-gc --moon /mise/installs/http-moonbit/rolling/bin/moon`: passed after one transient `moon info` subprocess failure; direct `moon info` and the immediate full-gate rerun both passed;
- `git diff --check`: passed after documentation finalization.

## Remaining architecture scope

The confirmed returned-value scalar, fresh immutable-array/default-struct, repeated unary-`select`, and single-`local.tee` child-retention witnesses are closed.

Remaining shared evaluator work is now narrower:

- strings and WTF-16 emitability;
- general `Flow`-aware break/return interpretation;
- alias-aware heap caching, allocation identity through locals, and nested immutable aggregate reads;
- general effect/trap/branch/global-write/call retention across multiple children;
- known-value versus emitability separation;
- final type refinalization.

These are architecture slices, not known Starshine-larger mismatch families in the completed matrix.
