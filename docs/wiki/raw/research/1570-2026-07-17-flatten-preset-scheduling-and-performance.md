---
kind: research
status: supported
last_reviewed: 2026-07-17
sources:
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/fuzzing.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/passes/flatten.mbt
  - ../../../../src/passes/flatten_test.mbt
related:
  - ./1569-2026-07-17-flatten-public-parity-closeout.md
  - ./1568-2026-07-13-o4z-backlog-reconstruction.md
---

# `flatten` preset scheduling and current performance

## Scope

This note records the first public preset scheduling of Starshine `flatten`, the validation boundary exposed by that scheduling review, and a current pass-local timing comparison against pinned Binaryen v130.

## Scheduler placement

Both `optimize_preset_passes(...)` and `shrink_preset_passes(...)` now begin their function-pass neighborhood with:

```text
duplicate-function-elimination
remove-unused-module-elements
memory-packing
once-reduction
global-refining
global-struct-inference
ssa-nomerge
flatten
simplify-locals-notee-nostructure
local-cse
dead-code-elimination
```

This restores Binaryen's aggressive local-cleanup ordering after `ssa-nomerge`. The two Starshine presets remain identical. `src/passes/registry_test.mbt` locks the exact prefix in both arrays.

The red-first scheduler test initially observed `dead-code-elimination` immediately after `ssa-nomerge`; focused registry results moved from `9/10` to `10/10` after inserting the trio. A final readiness assertion then exposed that `simplify_locals_notee_nostructure_exact_neighborhood_ready()` incorrectly expected `local-cse` to be a HOT pass; the predicate now correctly requires its registered module-pass category.

This change covers the top-level public preset. Reconciliation of optimizing nested reruns remains tracked separately because DAE, inlining, and simplify-globals do not yet share one final O4z function-pipeline expansion.

## Legacy WAST validation-scaffold boundary

The first direct replay of the historical candidate-dense WAT corpus exposed a Starshine-only validation failure. Starshine's WAST frontend cannot preserve executable legacy `try` in `@lib`; it lowers legacy text to a static validation scaffold consisting of:

- an outer result block ending in `unreachable`;
- a same-typed body-check block;
- one result-check loop per catch, optionally wrapped in `drop`.

Running ordinary flatten rewrites independently on those scaffold controls voided the block and loop result channels and produced stack underflow. This is not a Binaryen legacy-EH transform discrepancy over equivalent internal input: Binaryen retains executable legacy EH, while Starshine's frontend representation is only a syntax/type-check scaffold.

A red-first public-pipeline regression failed at `269/270`. `flatten_run(...)` now recognizes that exact frontend-only block/loop/unreachable shape before mutation and returns unchanged. The focused suite is green at `270/270` through direct `flatten`, `optimize`, and `shrink`; whitebox coverage is `228/228` and rejects a mixed-result block/loop lookalike. Real manually constructed HOT `Try` nodes remain on the existing owner-specific flatten path; the guard rejects the scaffold check quickly when it sees a real HOT try.

## Pass-local benchmark

### Corpus and method

The benchmark reuses the historical candidate-dense contract:

- 120 functions total;
- 40 one-multiply-child call-argument families;
- 40 two-multiply-child families;
- 40 deeper two-multiply-plus-constant families;
- each function contains the scalar terminal `br_table` / legacy-try ownership shape used by the prior checkpoint.

Starshine used the maintained temporary native-release benchmark source at `.tmp/flatten-iteration13-representative-bench-source.mbt`. Each run prebuilt the HOT functions, performed five warmup batches, and measured 20 direct `flatten_run(...)` batches. Four runs produced 80 measured samples.

Binaryen used `/mise/installs/http-binaryen/130/binaryen-version_130/bin/wasm-opt`, confirmed as `wasm-opt version 130 (version_130)`, over `.tmp/flatten-impact-corpus/candidate-dense.wat`. After five warmups, 80 separate `BINARYEN_PASS_DEBUG=1 --all-features --flatten` runs supplied the internal pass timer, excluding parse and final-validation wall time.

### Results

| Lane | Median | Range | Ratio to Binaryen |
| --- | ---: | ---: | ---: |
| Starshine native release | 1,140 us | 1,086..1,839 us | 4.00x |
| Binaryen v130 | 285.236 us | 239.149..401.413 us | 1.00x |

The four Starshine per-run medians were `1,271.5`, `1,098`, `1,127.5`, and `1,142 us`; the pooled 80-sample median is reported above to reduce run-order and thermal sensitivity.

The repository acceptance ceiling is `2 * Binaryen`, or `570.472 us` for this session. Starshine's `1,140 us` median is almost exactly twice that ceiling and therefore does **not** pass the performance target.

The older durable checkpoint was `970.5 us` versus Binaryen `266.05 us` (`3.65x`). The new session is approximately `17.5%` slower in absolute Starshine time and `4.00x` rather than `3.65x` relative to Binaryen. Because both tools and host conditions moved between sessions, this is a current qualification result rather than proof that one specific code slice caused the full difference.

## Final validation

- `src/passes/flatten_test.mbt`: `270/270`
- `src/passes/flatten_wbtest.mbt`: `228/228`
- `src/passes/registry_test.mbt`: `10/10`
- full `moon test`: `9,302/9,302`
- `moon fmt`: green
- `moon info`: green with existing warnings
- `bun validate readme-api-sync`: green
- `bun validate full --profile ci --target wasm-gc`: green, including `5,000` valid-module checks, invalid AST/binary/text lanes, `86,820` binary roundtrips, and `4,096` command-harness attempts

## Decision

- Schedule the top-level aggressive trio as explicitly requested and protect its exact order with tests.
- Keep `[O4Z-FLAT]001` open: current pass-local performance misses the repository target.
- Do not label the current timing acceptable without either measured optimization to `<=570.472 us` on this contract or an explicit reviewed performance exception.
- Preserve the existing behavior compare contract while profiling; semantic breadth must not be traded away for the timing target.
