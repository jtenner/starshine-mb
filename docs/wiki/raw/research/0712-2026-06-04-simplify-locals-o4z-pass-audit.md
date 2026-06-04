---
kind: research
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../binaryen/passes/simplify-locals/index.md
  - ../../binaryen/passes/simplify-locals/starshine-hot-ir-strategy.md
  - ../../binaryen/passes/simplify-locals/implementation-map.md
  - ../../binaryen/passes/simplify-locals/parity.md
  - ../../binaryen/passes/simplify-locals/validation-and-signoff.md
  - ../../binaryen/passes/simplify-locals/wat-shapes.md
  - ../../../../src/passes/simplify_locals.mbt
  - ../../../../src/passes/simplify_locals_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../agent-todo.md
---

# Simplify-Locals O4z Pass Audit

## Scope

Audited active v0.1.0 slice `[O4Z-AUDIT-SL]` for `simplify-locals` after the completed `local-cse` audit. The audit checked public wiring, HOT/raw implementation ownership, source-backed test coverage, direct generated parity evidence, and missing coverage that should be added before the slice is closed.

## Why this pass was chosen

`agent-todo.md` lists `simplify-locals` immediately after the detailed `[O4Z-AUDIT-LCSE]` entry in the O4z per-pass audit queue. Its scope covers local sinking, tee synthesis, structure-result rewrites, dead writes, raw gate thresholds, value-carrier spills, and late cleanup interactions.

## Current implementation map

- `src/passes/simplify_locals.mbt` owns the active HOT pass, including sinkable-state tracking, effect ordering, structure rewrites, equivalent cleanup, and dead-write cleanup.
- `src/passes/pass_manager.mbt` owns raw exact-instruction rewrites, raw skip gates, lowered cleanup, pass dispatch, and large-module skip behavior.
- `src/passes/optimize.mbt` registers `simplify-locals` as a hot pass and includes it in the canonical `optimize` / `shrink` preset after `local-cse` and before `merge-blocks`.
- Existing focused coverage spans `src/passes/simplify_locals_test.mbt`, `src/passes/pass_manager_wbtest.mbt`, `src/passes/perf_test.mbt`, and `src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt`.

## Direct compare evidence

Built the native CLI:

```sh
moon build --target native --release src/cmd
```

Result: succeeded with existing unused-helper warnings in `src/passes/pass_manager.mbt`.

The canonical target-path command from the pass checklist could not run in this workspace because this Moon build writes the native binary under `_build/native/...`, not `target/native/...`:

```sh
bun scripts/pass-fuzz-compare.ts \
  --pass simplify-locals \
  --count 1000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-simplify-locals-audit-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result: `0/1000` compared, `35` Starshine command failures, all due to `ENOENT` for the missing `target/native/release/build/cmd/cmd.exe`. Agent classification: harness/binary-path failure, not a pass semantic result.

Reran with the actual built native binary:

```sh
bun scripts/pass-fuzz-compare.ts \
  --pass simplify-locals \
  --count 1000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-simplify-locals-audit-1000-native \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result:

- compared cases: `998/1000`
- normalized matches: `998`
- compare-normalized matches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `2`
- mismatches: `0`

The two command failures are recorded in the summary as `command-class.binaryen-rec-group-zero`. Agent classification: Binaryen/tool parser/canonicalization failures, not Starshine semantic mismatches.

Closeout reran the requested `10000`-case direct lane with the actual native binary path:

```sh
bun scripts/pass-fuzz-compare.ts \
  --pass simplify-locals \
  --count 10000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-simplify-locals-audit-10000 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result: `6764/10000` compared, `6764` normalized matches, `0` cleanup-normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `20` command failures. The run stopped at the default max-failure threshold because command failures count toward that threshold by default. Command-failure classes were `17` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`. Agent classification: Binaryen/tool parser/canonicalization failures, not Starshine semantic mismatches.

A keep-going rerun used the same direct pass, seed, jobs, and native binary, but kept command failures out of the max-failure budget so the full request could complete:

```sh
bun scripts/pass-fuzz-compare.ts \
  --pass simplify-locals \
  --count 10000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-simplify-locals-audit-10000-keepgoing \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --keep-going-after-command-failures
```

Result:

- compared cases: `9975/10000`
- normalized matches: `9975`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `25`
- mismatches: `0`

Command-failure classes were `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`. Agent classification: Binaryen/tool parser/canonicalization failures, not Starshine semantic mismatches. The compare harness did not report pass-local timings for this lane.

## Late `SL` neighborhood evidence

The closeout also refreshed the generated late-neighborhood lane around the current public local cleanup cluster:

```sh
bun scripts/pass-fuzz-compare.ts \
  --pass local-cse \
  --pass simplify-locals \
  --pass merge-blocks \
  --count 10000 \
  --seed 0x5eed \
  --out-dir .tmp/pass-fuzz-sl-late-neighborhood-audit-10000-keepgoing \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --keep-going-after-command-failures
```

Result:

- compared cases: `9975/10000`
- normalized matches: `9975`
- cleanup-normalized matches: `0`
- compare-normalized matches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `25`
- mismatches: `0`

Command-failure classes matched the direct keep-going lane: `22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`. Agent classification: Binaryen/tool parser/canonicalization failures. No semantic, representation, size-losing, validation, or unknown/risky mismatch family was present in this generated late-neighborhood lane. The compare harness did not report pass-local timings.

## Artifact replay note

The checked-in debug artifact was absent in this worktree, so closeout rebuilt the local debug artifact with:

```sh
moon build --target wasm
cp _build/wasm/debug/build/cmd/cmd.wasm tests/node/dist/starshine-debug-wasi.wasm
wasm-tools validate --features all tests/node/dist/starshine-debug-wasi.wasm
```

The generated artifact validated and was about `6.7M`, but a direct `self-optimize-compare` attempt for `--simplify-locals` did not produce compare results. Current Starshine skips direct `simplify-locals` over that generated artifact via `pass[simplify-locals]:skip-large-module reason=large-module-simplify-locals-noop funcs=6874`, and the compare helper currently treats that `skip-large-module` trace as missing pass timing because it only recognizes pass timers or `skip-raw`. This is a harness/artifact/raw-gate caveat, not a direct-pass semantic mismatch. The older accepted value-carrier/local-spill artifact frontier remains the durable large-artifact context, and any renewed large-artifact timing or threshold work belongs under `[WALL]001` or `[AUDIT002-F]` / `[AUDIT002-G]` unless a new reduced semantic bug appears.

## Coverage audit findings

The source/wiki review found that core simplify-locals coverage is broad for:

- single-use local sinking
- tee synthesis
- trapping load ordering
- memory-write barriers
- source-local write barriers
- sibling call-argument ordering
- loop-header pending-value barriers
- block / if / one-armed-if / loop structure-result rewrites
- equivalent-copy and dead-write cleanup
- raw validator, multivalue, and artifact-scale skip/rewrite families

The most obvious missing source-backed focused coverage was the `try_table` EH boundary pair from `wat-shapes.md`:

1. nonthrowing values may sink into a `try_table` body
2. may-throw producers must stay outside a `try_table` body, because moving them inside would change catch behavior

Added focused tests in `src/passes/simplify_locals_test.mbt`:

- `simplify-locals sinks nonthrowing values into try_table bodies`
- `simplify-locals keeps may-throw producers outside try_table bodies`

No implementation change was needed. These tests are behavioral guards, not telemetry-only checks: the positive locks a legal EH-region sink, and the negative locks a semantic catch-boundary barrier.

## Focused test evidence

```sh
moon test src/passes
```

Before adding the tests, baseline passed `1579/1579`.

After adding the two `try_table` tests and running the focused pass package check:

```sh
moon fmt
moon test src/passes
```

Result: `1581/1581` tests passed.

Final quick gate for this audit slice:

```sh
moon info
moon fmt
moon test
```

Result: `moon info` completed, `moon fmt` completed, and `moon test` passed `4766/4766`.

Closeout repeated the standard quick gate after the final docs/backlog refresh:

```sh
moon info
moon fmt
moon test
```

Result: `moon info` completed with `moon: no work to do`, `moon fmt` completed with `moon: no work to do`, and `moon test` passed `4766/4766`.

## Closeout classification

- Direct generated parity: green on the refreshed direct keep-going `10000`-request native-binary audit lane, with `9975` normalized matches, `0` cleanup-normalized matches, `0` mismatches, and `25` Binaryen/tool command failures.
- Late-neighborhood generated parity: green on `local-cse -> simplify-locals -> merge-blocks`, with `9975` normalized matches, `0` cleanup-normalized matches, `0` mismatches, and `25` Binaryen/tool command failures.
- Mismatch classification: no semantic-safe/size-winning, representation-only, size-losing, unknown/risky, validation-failure, or true-semantic-mismatch families appeared. All saved failure dirs in the closeout lanes are agent-classified Binaryen/tool parser/canonicalization failures.
- Test completeness: improved by adding the missing `try_table` nonthrowing-positive / may-throw-negative EH boundary pair.
- Implementation completeness: no new semantic bug found in this audit pass; no implementation change was needed after the coverage addition.
- Runtime completeness: this closeout did not refresh a successful large-artifact timing lane. The generated debug artifact currently hits the pass-manager large-module skip and a `self-optimize-compare` timing-parser caveat. Existing wiki evidence still classifies whole-command or artifact-frontier runtime under the simplify-locals performance pages and `[WALL]001` unless a future run proves the pass itself owns a regression.

## Closure disposition

`[O4Z-AUDIT-SL]` is closed for the v0.1.0 per-pass audit gate.

Raw-threshold boundary work was intentionally not folded into this slice. The remaining simplify-locals raw gate coverage belongs to `[AUDIT002-F]` / `[AUDIT002-G]` and should cover small structured call-mesh gates, giant validator / no-structure gates, practical `±1` thresholds, and public-pipeline fixtures with trace reasons. New shrink candidates or exact artifact carrier cleanups should be filed separately from semantic fixes unless they reduce to an observable correctness bug.
