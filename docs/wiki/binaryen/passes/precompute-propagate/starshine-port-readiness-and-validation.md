---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../../raw/research/1573-2026-07-18-precompute-returned-values-arrays-and-effect-retention.md
  - ../../../raw/research/1572-2026-07-17-precompute-propagate-port-and-signoff.md
  - ../../../raw/research/0440-2026-05-04-precompute-propagate-current-main-recheck.md
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/precompute_propagate_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/validate/gen_valid.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-worklist-fallthrough-and-merge-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./fuzzing.md
  - ../precompute/index.md
---

# Starshine validation contract for `precompute-propagate`

The public Binaryen-compatible member landed on July 17, 2026. This page records its maintained behavior, safety, and signoff contract after the follow-up parity-gap closure.

## Implemented surfaces

- exact public registry/CLI/harness spelling;
- SSA-requiring hot-pass descriptor;
- agreeing reaching-value consensus and defaultable-local entry values;
- direct tee, unbranched block fallthrough, result-`if` phi consensus, and condition-tee facts used in selected arms;
- one propagation solve followed by one evaluator rerun;
- returned integer count/rotate values, safe integer division/remainder, deterministic floating unary/arithmetic/min/max/copysign, exact reinterpretation/sign extension/conversion, and trapping/saturating conversion folding when proven;
- repeated unary/binary parent evaluation through `select`;
- fresh GC allocation/null identity, exact fresh-allocation `ref.test`, immutable fresh struct/default-struct reads, and statically in-bounds immutable fresh array reads/lengths, including packed reads;
- narrow effect-preserving exact parent folds that rewrite a constant-valued `local.tee` to `local.set` before the result constant;
- conservative raw local propagation for owner-hazard, large-lowered, and selected structured `memory.grow` functions, including loop-invariant preservation and loop-carried-local invalidation;
- raw scalar/control cleanup around reachable `atomic.fence` without deleting the fence;
- both aggressive top-level PC slots and shared DAE/inlining nested-prefix use;
- dedicated `precompute-propagate-local-facts` GenValid profile.

## Required focused behavior

Keep direct tests for:

1. plain-versus-propagating distinction;
2. identical and differing reaching constants;
3. default-init consensus;
4. tee and block fallthrough;
5. one-solve/one-rerun boundedness;
6. stale-default and stale-prior result-`if` safety;
7. agreeing result-`if` arm writes and condition-tee facts;
8. high-local/large-lowered positive propagation;
9. returned scalar/floating edge, repeated partial-`select`, GC identity, `ref.test`, immutable fresh array/struct/default/packed reads, and single-tee effect-retention folds;
10. reachable atomic-fence preservation with surrounding raw cleanup;
11. raw loop invariants and loop-carried-local invalidation.

A required positive family must assert the transform, not merely successful validation. A retained boundary test must name the unsupported or invalid shape explicitly.

## Maintained safety boundaries

### Result-producing `if`

HOT SSA is accepted only when it provides a real phi for an arm-written local, or when a direct condition constant is proven for an arm read before any arm-local overwrite. Stale entry-default and stale prior definitions remain rejected. This closes the agreeing-arm and condition-tee gaps without reintroducing the former self-hosted stale-local bug.

### Raw structured propagation

Raw propagation is deliberately narrower than HOT evaluation. It is used where HOT ownership guards would otherwise skip useful work: owner-hazard functions, large lowered functions, and selected structured `memory.grow` functions. It must:

- invalidate every local written by a loop before evaluating the loop body;
- retain only loop-invariant facts across a backedge;
- merge branch-local facts by exact agreement;
- stop or clear stack facts at unsupported stack effects while preserving already proven local substitutions;
- never use a raw result that is unchanged merely to bypass the stronger HOT cleanup path.

### Atomics

A reachable `atomic.fence` is an ordering barrier. Starshine may fold independent values around it but does not copy Binaryen v130's observed fence deletion.

### Closed shared evaluator scope

The Binaryen-v131 shared evaluator contract is closed for both public variants. It covers scalar and floating evaluation, strings, descriptors, deterministic SIMD, partial selects, exact heap identities and nested immutable aggregates, value-carrying branch/control `Flow`, ordered local/global writes and trapping prefixes, explicit emitability, and narrow exact-cast refinalization. Legacy EH and stack switching are conservatively admitted and preserved rather than executed speculatively.

## Signoff ladder

### Focused

```sh
moon test --package jtenner/starshine/passes --file precompute_test.mbt
moon test --package jtenner/starshine/passes --file precompute_propagate_test.mbt
moon test --package jtenner/starshine/passes --file registry_test.mbt
moon test --package jtenner/starshine/passes --file optimize_test.mbt
moon test --package jtenner/starshine/validate --file gen_valid_precompute_propagate_tests.mbt
```

### Direct fuzz

Use Binaryen `version_131`, an explicitly rebuilt release native Starshine binary, parallel workers, the isolated v131 cache, and only the reviewed cleanup normalizers. The exact final lanes are recorded in [`./fuzzing.md`](./fuzzing.md).

### Artifact/performance

```sh
bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-opt-precompute-propagate-gap-close-memorygrow \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt \
  --canonicalize-binaryen-output \
  --precompute-propagate
```

Require external validity, no stale-local substitution, classification of the first canonical difference, and pass-local time below `2x` Binaryen. Whole-command overhead remains a separate tool-infrastructure metric.

## Current evidence

The final July 18, 2026 v131 evidence is:

- regular GenValid: `.tmp/pass-fuzz-precompute-propagate-v131-final-regular-100000`, `100000/100000`, `41287` direct and `58713` cleanup-normalized, zero mismatches or failures;
- dedicated `precompute-all`: `.tmp/pass-fuzz-precompute-propagate-v131-final-dedicated-10000`, `10000/10000`, `7306` direct and `2694` cleanup-normalized, zero mismatches or failures;
- random all-profiles: `.tmp/pass-fuzz-precompute-propagate-v131-final-random-all-10000`, `10000/10000`, `5076` direct, `2190` cleanup-normalized, and `2734` inspected unrelated SSA/duplicate-import differences; every difference is smaller by `2..18` bytes and saves `33,282` bytes total;
- wasm-smith: `.tmp/pass-fuzz-precompute-propagate-v131-final-wasm-smith-10000`, `9956` compared, `9951` direct, `2` cleanup-normalized, three classified Starshine wins, and `44` Binaryen tool failures;
- runtime/idempotence: `500/500`, zero property, validation, command, or semantic failures; unsupported Node GC/reference cases are separate;
- self-optimization: valid Starshine canonical output `4,581,251` bytes versus Binaryen `4,671,312`, saving `90,061` bytes;
- one-warmup/15-run pass-local medians: `1,042.358 ms` versus `525.378 ms`, ratio `1.984x`, within the required `2x` contract;
- full tests: `9415/9415`, with `moon fmt`, `moon check`, `moon info`, native release build, and `git diff --check` green.

The three wasm-smith differences preserve a reachable `atomic.fence` that Binaryen removes, retain a smaller exact local-value form, and remove nontrapping `memory.size` debris before `unreachable`. None is a semantic or size parity gap.

## Status rule

The public propagation member and shared v131 evaluator are closed at Binaryen-v131-or-better behavior parity. Reopen for a semantic/validation failure, a pass-owned size-losing family without measured benefit, a new source-backed evaluator gap, or a pass-local regression beyond `2x` Binaryen. Do not call smaller validated structural differences parity bugs merely because the WAT differs.
