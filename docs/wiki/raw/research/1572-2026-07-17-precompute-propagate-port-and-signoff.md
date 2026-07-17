---
kind: research
status: retained
last_reviewed: 2026-07-17
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/Precompute.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/precompute-propagate-partial.wast
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/precompute-propagate_all-features.wast
  - ../../../../src/passes/precompute.mbt
  - ../../../../src/passes/precompute_propagate_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_precompute_propagate_tests.mbt
related:
  - ../../binaryen/passes/precompute-propagate/index.md
  - ../../binaryen/passes/precompute-propagate/fuzzing.md
  - ../../binaryen/passes/precompute-propagate/starshine-strategy.md
  - ../../binaryen/passes/precompute/index.md
---

# `precompute-propagate` public port and signoff

## Scope

This slice ports Binaryen `version_130`'s second public precompute spelling, `precompute-propagate`, on top of Starshine's already accepted plain-`precompute` base contract. It does not silently broaden plain `precompute` into Binaryen's complete interpreter/GC evaluator; inherited plain-pass release boundaries remain inherited boundaries.

## Implemented contract

- Public hot-pass descriptor and summary under the exact name `precompute-propagate`.
- Registry, dispatcher, CLI/harness allowlist, and public `.mbti` exposure.
- One SSA-backed local-fact solve before one bounded plain-precompute evaluator run.
- Agreement across reaching values, defaultable-local entry constants, direct `local.tee`, unbranched block fallthrough, unary/binary evaluation of propagated operands, and constant-selected `if` fallthrough.
- Differing reaching constants and parameter entry values remain conservative.
- Both aggressive top-level precompute slots now use `precompute-propagate`.
- DAE and inlining nested optimization use the same public implementation; the private `precompute-propagate-prefix` fork was removed.

## TDD and safety findings

The focused suite in `src/passes/precompute_propagate_test.mbt` was written red-first and now covers nine boundaries:

1. behavior plain `precompute` leaves local-carried;
2. agreeing branch definitions;
3. differing branch definitions;
4. default-init zero merged with explicit zero;
5. tee and block fallthrough;
6. nested result-`if` branch writes after default init;
7. nested result-`if` branch writes after a prior constant fact;
8. high-local/large-lowered fail-closed behavior;
9. the one-solve/one-rerun stopping rule.

Two artifact-driven safety gaps were found and fixed:

- The first self-optimization attempt produced invalid function `2641`, because public propagation bypassed plain precompute's `locals > 64 && instructions > 500` lowered-function guard. `run_hot_pipeline_raw_precompute(...)` now applies the same load/call/set, large-lowered, and SIMD/parser/`br_table` safety gates to both public family members before allowing the propagating variant into HOT.
- HOT SSA currently omits some branch-local writes nested inside result-producing `if` expressions from the post-expression merge. The first valid self-optimization run exposed an unsound `local.get 3 -> i32.const 0` replacement in absolute function `28`. Propagation now fails closed for locals written in result-`if` arms and refuses a direct default-init origin whenever that local has any write in the function. Focused tests cover both stale-default and stale-prior-fact forms.

## Binaryen `version_130` direct evidence

The oracle executable was downloaded into the workspace and reported:

```text
wasm-opt version 130 (version_130)
```

The official `precompute-propagate_all-features.wast` fixture was replayed directly. Starshine now matches the propagation-specific dead-loop/default/merge behavior. Remaining raw WAT differences in that fixture are inherited plain-precompute shape differences, usually stronger Starshine control or dead-local cleanup; the dead-loop constant-get gap found during development was fixed by constant-selected `if` fallthrough reasoning plus transparent value-block cleanup.

## Final fuzz matrix

All commands used the rebuilt `_build/native/release/build/cmd/cmd.exe`, the workspace Binaryen v130 executable, `--jobs auto`, persistent default cache, and the established plain-precompute normalizers `drop-consts`, `local-cleanup-debris`, and `unreachable-control-debris`. Mismatch reduction was disabled because the final gating lanes were expected to be zero-mismatch or had already classified stable wasm-smith witnesses.

### Regular GenValid

Directory: `.tmp/pass-fuzz-precompute-propagate-v130-final-genvalid-100000`

- requested/compared: `100000/100000`
- normalized: `19160`
- cleanup-normalized: `80840`
- mismatches: `0`
- validation/generator/property/command failures: `0/0/0/0`
- Binaryen cache: `100000` hits, `0` misses

### Dedicated propagation profile

Profile: `precompute-propagate-local-facts`

Directory: `.tmp/pass-fuzz-precompute-propagate-v130-final-profile-10000`

- requested/compared: `10000/10000`
- normalized: `0`
- cleanup-normalized: `10000`
- mismatches: `0`
- validation/generator/property/command failures: `0/0/0/0`
- Binaryen cache: `10000` hits, `0` misses

The profile emits agreeing and differing merges, default-init reads, direct and block-fallthrough tees, bounded chained evaluation, and a parameter boundary in each generated module. Focused generator tests prove the stable name/aliases, limits, validation, and trigger floor.

### Broad pass-fuzz stress

Profile: `pass-fuzz-stress`

Directory: `.tmp/pass-fuzz-precompute-propagate-v130-final-pass-fuzz-stress-10000`

- requested/compared: `10000/10000`
- normalized: `1921`
- cleanup-normalized: `8079`
- mismatches: `0`
- validation/generator/property/command failures: `0/0/0/0`
- Binaryen cache: `10000` hits, `0` misses

This is the broad fourth lane used by the accepted plain-precompute closeout contract.

### Explicit wasm-smith

Directory: `.tmp/pass-fuzz-precompute-propagate-v130-final-wasm-smith-10000`

- requested/compared: `10000/9956`
- normalized: `9951`
- cleanup-normalized: `3`
- mismatches: `2`
- validation/generator/property failures: `0/0/0`
- command failures: `44`
  - `39` Binaryen zero-sized-rec-group parser failures
  - `1` Binaryen invalid-tag-index failure
  - `1` Binaryen table-index-out-of-range failure
  - `3` Binaryen bad-section-size failures
- wasm-smith cache: `10000` hits, `0` misses
- Binaryen cache: `9956` hits, `0` misses; failure cache `44` hits

Agent classification of the two mismatches:

- `case-003694-wasm-smith`: **Starshine size win / exact local replay**. Binaryen repeats an `f64.const` after storing the exact bits in a scratch local; Starshine reloads that unchanged scratch local. Canonical size is `74` bytes for Starshine versus `81` for Binaryen, with no intervening operation.
- `case-006523-wasm-smith`: **accepted Starshine correctness boundary inherited from plain precompute**. Binaryen erases a reachable `atomic.fence` before a branch-to-function-end; Starshine preserves the ordering barrier in a self-exiting block. This is the same focused-test-backed boundary recorded by the plain-precompute closeout.

## Exploratory random-all-profiles lane

`.tmp/pass-fuzz-precompute-propagate-v130-all-profiles-10000` was intentionally run even though the plain-precompute dossier uses `pass-fuzz-stress` for its fourth release-gating lane. It hit the mismatch cap after `4767/10000` compared cases: `1522` normalized, `1234` cleanup-normalized, `2011` raw mismatches, and no failures.

The mismatches were concentrated in profiles designed for other passes:

- `491` `ssa-nomerge-smoke`
- `425` `ssa-nomerge-parity`
- `485` `coverage-forced-portable`
- `271` duplicate-import-elimination function cases
- `230` duplicate-import-elimination nonfunction cases
- `109` `heap2local-ref`

This was the preliminary random-all classification before the follow-up parity slice. It included stronger Starshine cleanup plus size-losing branch-wrapper, coverage/atomic, and evaluator-breadth families. The follow-up section below supersedes that size assessment with a completed `10000/10000` lane in which every remaining mismatch is canonically smaller for Starshine.

## Follow-up parity-gap closure

The original closeout above was followed immediately by a focused gap-closure slice. The reduced witnesses under `.tmp/precompute-propagate-gap-witnesses` now have these outcomes:

| Family | Final outcome |
|---|---|
| result-`if` agreeing arm writes | exact Binaryen v130 canonical match |
| high-local large-lowered function | exact match through conservative raw local propagation |
| exact scalar evaluator breadth | exact match for the reduced safe integer/floating witness |
| partial parent computation through `select` | Starshine performs the requested fold and is `3` canonical bytes smaller than direct Binaryen `precompute-propagate` |
| fresh GC identity | exact match |
| immutable fresh-struct read | exact match |
| self-hosted nested condition tee | folded through a selected structured raw path; former defined `4` / absolute `31` difference closed |

The implementation added safe integer division/remainder, floating arithmetic/comparisons, nontrapping unary/conversion cleanup, rotate folding, partial `select` evaluation, fresh allocation identity and `ref.test`, immutable fresh-struct reads, result-`if` phi/direct-condition handling, and conservative raw propagation for guarded structured functions. Raw loop evaluation invalidates every loop-written local before entering the body and retains only exact loop invariants; a focused regression test preserves this rule.

Reachable `atomic.fence` remains an intentional correctness boundary. Starshine folds independent scalar debris around the fence but does not copy Binaryen v130's observed fence deletion.

Broader string operations, general `Flow`-aware break/return interpretation, complete heap-cache/array evaluation, side-effecting child retention, emitability separation, and final type refinalization remain shared evaluator architecture work. The completed random-all lane does not identify any of them as a size-losing family.

## Final fuzz matrix

The post-gap-close final artifacts are:

- `.tmp/pass-fuzz-precompute-propagate-gap-close-final4-genvalid-100000`: `100000/100000`, zero mismatches/failures;
- `.tmp/pass-fuzz-precompute-propagate-gap-close-final3-profile-10000`: `10000/10000`, zero mismatches/failures;
- `.tmp/pass-fuzz-precompute-propagate-gap-close-final4-stress-10000`: `10000/10000`, zero mismatches/failures;
- `.tmp/pass-fuzz-precompute-propagate-gap-close-final4-wasm-smith-10000`: `9956/10000` compared, the same two classified differences, zero validation/property failures, and `44` Binaryen parser/tool failures;
- `.tmp/pass-fuzz-precompute-propagate-gap-close-final3-random-all-10000`: `10000/10000` compared, `2973` raw mismatches, all `2973` canonically smaller for Starshine and none equal-sized or larger.

The random-all families are limited to stronger Starshine cleanup/import shapes: `965` `ssa-nomerge-smoke`, `945` `ssa-nomerge-parity`, `546` duplicate function-import elimination, and `517` duplicate nonfunction-import elimination cases. The earlier coverage-forced-portable and heap/GC size losses are gone.

The two wasm-smith differences remain:

1. a smaller exact scratch-local replay;
2. reachable `atomic.fence` preservation versus Binaryen's removal.

The one-solve/one-evaluator-rerun stopping rule also remains intentional and matches the public Binaryen pass contract.

## Final self-optimization and performance evidence

Correctness artifact: `.tmp/self-opt-precompute-propagate-gap-close-memorygrow`

Repeated benchmark: `.tmp/benchmark-precompute-propagate-gap-close-final-2026-07-17/benchmark-summary.json`

The benchmark uses the `11,699,041`-byte self-hosted debug Wasm input, one warmup, 15 separate measured processes per tool, the explicit release Starshine binary, and Binaryen `version_130`.

| Metric | Starshine | Binaryen v130 | Result |
|---|---:|---:|---:|
| pass-local median | `694.444 ms` | `505.591 ms` | Binaryen `1.374x` faster; Starshine remains below the `2x` ceiling |
| pass-local mean | `692.686 ms` | `508.305 ms` | Binaryen faster after evaluator broadening |
| pass-local min-max | `666.603-725.760 ms` | `493.438-538.979 ms` | stable non-overlapping ranges |
| whole-command median | `7,330.096 ms` | `1,110.672 ms` | Binaryen `6.600x` faster end to end |
| canonical output | `4,585,973` bytes | `4,666,022` bytes | Starshine `80,049` bytes / `1.716%` smaller |

The pass-local regression relative to the original narrow implementation is the measured cost of evaluator and guarded raw-propagation breadth. It remains within the maintained `<2x` contract and must not be hidden by the whole-command metric.

The former first difference at defined `4`, absolute `31` is closed. The first canonical difference is now defined `24`, absolute `51`: Starshine retains valid result-typed control, while Binaryen refinalizes the same unreachable paths to void and inserts extra `unreachable` nodes. The Starshine module validates and is smaller overall, so this is retained as a Starshine output-shape win rather than forced textual parity.

## Status conclusion

`precompute-propagate` is a public, scheduled, fuzzed, self-hosted pass with its reduced parity-gap set closed and no size-losing mismatches in the completed random-all matrix. Reopen for semantic failure, a new size-losing family, focused source-backed evaluator evidence, or pass-local performance beyond `2x` Binaryen. Do not regress smaller valid Starshine output merely to match Binaryen text.
