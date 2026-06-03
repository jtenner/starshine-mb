---
kind: research
status: supported
created: 2026-06-03
sources:
  - ../../binaryen/passes/once-reduction/index.md
  - ../../binaryen/passes/once-reduction/parity.md
  - ../../binaryen/passes/once-reduction/starshine-hot-ir-strategy.md
  - ../../../../src/passes/once_reduction.mbt
  - ../../../../src/passes/once_reduction_test.mbt
  - ../../../../agent-todo.md
---

# Once Reduction O4z Deep Audit

## Question

Audit active v0.1.0 slice `[O4Z-AUDIT-OR]` for `once-reduction`: pass-level correctness, broader code-shape coverage, Binaryen-parity-oriented safe improvements, and pass-local runtime evidence.

## Implementation conclusions

This slice keeps Starshine's local recursive once-bit implementation, but expands the safe Binaryen-facing subset:

- `or_find_once_global(...)` now recognizes the once prologue when it is wrapped in a single top-level `block`, matching the important Binaryen IR body-root shape more closely than the previous flat-only boundary array matcher.
- `or_optimize_once_bodies(...)` now handles empty and single-call top-level-block once bodies in the same narrow way it already handled flat four- and five-instruction wrappers.
- Defined no-param/no-result functions annotated `@binaryen.idempotent` now participate as fake once roots for direct-call elimination and call-summary propagation.
- Imported `@binaryen.idempotent` functions remain a conservative local boundary: the annotation is recorded by the parser/lowering layer, but this audit does not use it to remove imported calls.
- Repeated direct calls to singleton-summary once functions now skip redundant whole-bitset union work; empty once wrappers also skip the dataflow/rewrite loop and are left to final body cleanup. This reduces synthetic many-wrapper pass time without changing semantics.

The upstream parity boundary is still explicit: Starshine does not implement Binaryen's CFG / immediate-dominator optimizer, broad all-control-flow precision, or imported-idempotent call treatment in this slice.

## Test coverage added

New focused coverage in `src/passes/once_reduction_test.mbt` includes:

- top-level-block once prologue recognition
- no-param/no-result `@binaryen.idempotent` direct-call elimination
- idempotent call-summary propagation through a caller
- typed idempotent negative coverage
- unannotated imported function negative coverage
- annotated imported function boundary coverage
- imported once-global negative coverage
- extra once-global read negative coverage
- table element plus `ref.func` escape coverage for direct repeated calls
- empty top-level-block once-body cleanup

The table / `ref.func` case is intentionally classified as safe direct-call elimination, not a function-escape bailout: the direct second call is redundant because the first direct call sets the private once bit; the escaped function reference remains intact.

## Direct oracle evidence

Baseline smoke before behavior changes:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass once-reduction --out-dir .tmp/pass-fuzz-once-reduction-audit-baseline-1000
```

The command exited nonzero because the harness stopped on command failures without `--keep-going-after-command-failures`, but it wrote a usable summary: `998 / 1000` compared, `998` normalized matches, `0` mismatches, and `2` Binaryen zero-sized-recursion-group parser/canonicalization command failures.

Post-change smoke:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass once-reduction --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-once-reduction-audit-current-1000-keepgoing
```

Result: `998 / 1000` compared, `998` normalized matches, `0` mismatches, `0` validation failures, and `2` command failures.

Post-change 10000-request lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass once-reduction --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-once-reduction-audit-current-10000-keepgoing
```

Result: `9975 / 10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, and `25` command failures. Failure classes were:

- `22` Binaryen zero-sized recursion group parser/canonicalization failures
- `1` Binaryen bad-section-size command failure
- `1` Binaryen table-index-out-of-range command failure
- `1` Binaryen invalid-tag-index command failure

Agent classification: these are tool/Binaryen command failures, not Starshine semantic mismatches. No semantic mismatch family was observed.

Follow-up after the incremental singleton-summary allocation-pressure change reran the same 10000-request lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass once-reduction --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-once-reduction-perf-final-10000
```

Result: `9975 / 10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, and `25` command failures. The agent classification remains tool/Binaryen command failures, not Starshine semantic mismatches.

## Pass-local performance evidence

Benchmark fixtures were generated under `.tmp/or-audit-benches/fixtures/` and run with the release native Starshine CLI plus Binaryen `wasm-opt --debug`.

Starshine sample command shape:

```sh
_build/native/release/build/cmd/cmd.exe --once-reduction --tracing pass --out <out.wasm> <input.wasm>
```

Binaryen sample command shape:

```sh
wasm-opt <input.wasm> --once-reduction --all-features --debug -o <out.wasm>
```

Median pass-local timings over 9 samples after the singleton-summary and empty-wrapper scan skip changes:

| Fixture | Starshine median | Binaryen median | Result |
| --- | ---: | ---: | --- |
| many-repeated-calls | `192 us` | `107.192 us` | Starshine is about `1.8x` Binaryen pass time, within the 2x local target. |
| block-root-repeated-calls | `113 us` | `58.159 us` | Starshine is about `1.94x` Binaryen pass time, within the 2x local target. |
| many-independent-once | `4646 us` | `156.905 us` | Starshine remains much slower on this synthetic many-wrapper stress; this is attributed to the current Env / whole-module candidate and summary setup costs in the local recursive implementation, not to a semantic mismatch. |

Earlier samples before the empty-wrapper skip measured the many-independent fixture at `20766 us` Starshine median, so this slice reduced that stress by about `4.5x`, but it did not close the gap to Binaryen's CFG-backed implementation.

Follow-up in the allocation-pressure slice found that the remaining synthetic slowdown was not primarily `Env::new().with_module(mod_)`; it was the fixed-point loop rebuilding a fresh singleton-summary bitset and rescanning every function summary on every iteration plus once more before rewrite. On `many-independent-once`, that meant repeatedly checking about `801 * 800` singleton bits even though almost all summaries were unchanged empty once wrappers. The fix keeps the singleton-summary flags incrementally: initialize direct once roots as singleton summaries, and only recompute a function's singleton flag when that function's summary actually changes. The same slice also reuses precomputed initial function once sets for analysis and rewrite entry state instead of allocating a fresh entry bitset at every call site.

After this follow-up, the same Starshine command shape measured these pass-local medians:

| Fixture | Previous Starshine median | Follow-up Starshine median | Binaryen median from `results-final` | Result |
| --- | ---: | ---: | ---: | --- |
| many-repeated-calls | `192 us` | `207 us` over 21 samples | `107.192 us` | Still within the 2x local target; tiny-fixture jitter dominates the small delta. |
| many-independent-once | `4646 us` | `230 us` over 21 samples | `156.905 us` | About `20.2x` faster than the prior Starshine median and about `1.47x` Binaryen's recorded median. |
| block-root-repeated-calls | `113 us` | `116 us` over 21 samples | `58.159 us` | Effectively unchanged and still near the 2x local target; local reruns showed alternating `~105-165 us` samples on this tiny fixture. |

Follow-up artifact path:

- Starshine timing run after incremental singleton summaries and initial-set reuse: `.tmp/or-perf-after-initial-reuse/summary.json`

Artifact paths from the original audit:

- first post-idempotent timing run: `.tmp/or-audit-benches/results-after/summary.json`
- final timing run after the empty-wrapper skip: `.tmp/or-audit-benches/results-final/summary.json`

## Moon signoff evidence

Commands run:

```sh
moon test src/passes
moon build --target native --release src/cmd
moon info
moon fmt --check
```

Results:

- `moon test src/passes`: `1481` tests passed, `0` failed after the final focused test cleanup.
- `moon build --target native --release src/cmd`: completed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon info`: crashed in the local Moon tool with `index out of bounds: the len is 36 but the index is 8329485`; this is a tool crash, not a pass failure.
- `moon fmt --check`: failed because this Moon version reports repo-wide formatter / migration drift, starting with `moon.mod.json`, `src/cli/moon.pkg`, `src/binary/api.mbt`, and other unrelated files. No formatter rewrite was applied.

A full `moon test` was also run in the same audit thread and should be read together with the final signoff summary.

## Remaining risks and deferred scope

- Starshine still uses a recursive instruction-array proof rather than Binaryen's CFG / immediate-dominator optimizer.
- Imported idempotent annotations remain a conservative local boundary until the exact upstream import semantics are source-confirmed and accepted for Starshine.
- The many-independent-once synthetic stress remains slower than Binaryen despite the local improvement; a deeper performance slice would need to reduce Env/setup and summary bitset costs rather than merely skip singleton unions.
- The direct compare harness did not produce semantic mismatches, but it also did not specifically generate `@binaryen.idempotent` annotation fixtures; focused tests carry that behavior.
