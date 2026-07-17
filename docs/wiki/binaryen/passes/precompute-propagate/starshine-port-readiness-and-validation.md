---
kind: concept
status: supported
last_reviewed: 2026-07-17
sources:
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
- safe integer division/remainder, deterministic scalar floating arithmetic/comparisons, nontrapping unary/conversion cleanup, and rotate folding;
- partial parent evaluation through `select`;
- fresh GC allocation/null identity, exact fresh-allocation `ref.test`, and immutable fresh-struct field reads;
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
9. safe scalar, partial-`select`, GC identity, `ref.test`, and immutable-struct folds;
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

### Remaining shared evaluator scope

The reduced parity-gap witnesses for scalar folding, partial `select`, fresh GC identity, immutable `struct.get`, large local propagation, result-`if` consensus, and the self-hosted condition tee are closed. Broader string evaluation, general `Flow`-aware break/return interpretation, complete heap-cache/array evaluation, side-effecting child retention, emitability separation, and final type refinalization remain shared plain-`precompute` architecture work. They are not known size-losing families in the final random-all matrix.

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

Use Binaryen `version_130`, an explicitly rebuilt release native Starshine binary, parallel workers, the persistent cache, and the three reviewed normalizers. The exact final lanes are recorded in [`./fuzzing.md`](./fuzzing.md).

### Artifact/performance

```sh
bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/self-opt-precompute-propagate-gap-close-memorygrow \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --wasm-opt-bin .tmp/binaryen-version-130-bin/bin/wasm-opt \
  --canonicalize-binaryen-output \
  --precompute-propagate
```

Require external validity, no stale-local substitution, classification of the first canonical difference, and pass-local time below `2x` Binaryen. Whole-command overhead remains a separate tool-infrastructure metric.

## Current evidence

The final July 17, 2026 evidence is:

- regular GenValid: `100000/100000`, zero mismatches or failures;
- dedicated local-facts profile: `10000/10000`, zero mismatches or failures;
- `pass-fuzz-stress`: `10000/10000`, zero mismatches or failures;
- wasm-smith: `9956/10000` compared, two previously classified differences, zero validation/property failures, and `44` Binaryen parser/tool failures;
- random-all profiles: `10000/10000`, `2973` raw mismatches, all `2973` with smaller canonical Starshine output and none equal-sized or larger;
- all six original reduced behavior witnesses now match Binaryen exactly except partial `select`, where Starshine performs the requested fold and is smaller, and the structured self-hosted prefix witness, where Starshine is also smaller;
- valid self-optimization output: Starshine canonical `4,585,973` bytes versus direct Binaryen `4,666,022` bytes;
- repeated one-warmup/15-run benchmark: Starshine pass-local median `694.444 ms`, Binaryen `505.591 ms` (`1.374x` Binaryen advantage, within the `<2x` contract); whole-command medians `7,330.096 ms` and `1,110.672 ms` respectively;
- the former defined-function `4` / absolute-function `31` condition-tee gap is closed; the first canonical difference moves to defined `24` / absolute `51`, where Starshine retains valid result typing instead of Binaryen's larger unreachable/refinalized shape.

Detailed artifacts are under `.tmp/pass-fuzz-precompute-propagate-gap-close-final3-*`, `.tmp/pass-fuzz-precompute-propagate-gap-close-final4-*`, `.tmp/self-opt-precompute-propagate-gap-close-memorygrow`, and `.tmp/benchmark-precompute-propagate-gap-close-final-2026-07-17`.

## Status rule

The public propagation member, its reduced behavior-gap set, and its no-size-loss random-all matrix are closed. Reopen for a semantic failure, a size-losing mismatch, a focused evaluator family with Binaryen-backed evidence, or a pass-local regression beyond `2x` Binaryen. Do not call the remaining smaller structural differences parity bugs merely because the WAT differs.
