---
kind: concept
status: supported
last_reviewed: 2026-07-26
sources:
  - ../../../raw/research/1574-2026-07-18-precompute-binaryen-v131-parity-reopen.md
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

The public Binaryen-compatible member landed on July 17, 2026. This page records its maintained behavior, safety, and signoff contract after the July 26 correctness-repair renewal.

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
- no-local control-only cleanup through the same shared raw path as plain `precompute`, with type-indexed block/loop arity resolution, multivalue branch-payload preservation, parameterized-block flattening refusal, nested cleanup fixpoints, and exact pure-reference drop cleanup;
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

The renewed July 26, 2026 v131 evidence is:

- regular GenValid: `.tmp/pass-fuzz-precompute-propagate-v131-renewal-closeout-regular-100000`, `100000/100000`, `41287` direct and `58713` cleanup-normalized, zero mismatches or failures;
- dedicated `precompute-all`: `.tmp/pass-fuzz-precompute-propagate-v131-renewal-closeout-dedicated-10000`, `10000/10000`, `6423` direct and `3577` cleanup-normalized, zero mismatches or failures;
- random all-profiles: `.tmp/pass-fuzz-precompute-propagate-v131-renewal-closeout-random-all-10000`, `10000/10000`, `4578` direct, `2959` cleanup-normalized, `2135` smaller dead-read/control cleanup wins, and `328` reachable-fence preservation differences; net canonical delta `-24,119` bytes;
- wasm-smith: `.tmp/pass-fuzz-precompute-propagate-v131-renewal-closeout-wasm-smith-10000`, `9956` comparable, `9954` direct, two classified Starshine wins, and `44` Binaryen-only tool failures;
- runtime/idempotence: `.tmp/pass-fuzz-precompute-propagate-v131-renewal-closeout-runtime-idempotence-500`, `500/500` idempotence, `475` Node-supported executions, `25` unsupported GC/reference cases, and zero property, validation, command, or semantic failures;
- focused tests: `92/92` shared public precompute, `16/16` propagating public, `16/16` white-box, and `161/161` GenValid profile tests;
- native identities: Starshine SHA-256 `bb7b38e57b927de9a57d5f427101051c84326d1618071653f539b62b9321cf65`; Binaryen v131 SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`.

The two wasm-smith differences preserve a reachable `atomic.fence` that Binaryen removes and retain a seven-byte-smaller exact local-value form. Fresh debug-WASI evidence at `.tmp/self-opt-precompute-propagate-v131-renewal-closeout` validates both outputs: Starshine canonical output is `5,134,293` bytes versus Binaryen `5,230,996`, saving `96,703` bytes. Seven timing-only samples give pass-local medians `1,204.796 ms` versus `725.132 ms` (`1.661x`). The first canonical difference is defined `23` / absolute `50`, where Starshine preserves valid result-typed return-dominated control and Binaryen refinalizes it to void control plus explicit trailing `unreachable`.

## Status rule

The public propagation member and shared v131 evaluator are closed at Binaryen-v131-or-better behavior parity. Reopen for a semantic/validation failure, a pass-owned size-losing family without measured benefit, a new source-backed evaluator gap, or a pass-local regression beyond `2x` Binaryen. Do not call smaller validated structural differences parity bugs merely because the WAT differs.
