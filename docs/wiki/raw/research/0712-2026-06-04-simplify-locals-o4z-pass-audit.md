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

## Current classification

- Direct generated parity: green on the refreshed 1000-case native-binary audit lane, with `0` mismatches and `2` Binaryen/tool command failures.
- Test completeness: improved by adding the missing `try_table` nonthrowing-positive / may-throw-negative EH boundary pair.
- Implementation completeness: no new semantic bug found in this audit pass.
- Runtime completeness: this audit did not rerun a large artifact timing lane. Existing wiki evidence still classifies whole-command or artifact-frontier runtime under the existing simplify-locals performance pages and `[WALL]001` unless a future run proves the pass itself owns a regression.

## Remaining work before closing `[O4Z-AUDIT-SL]`

- Scale direct compare back to the standard `10000`-case lane if this slice is being closed rather than merely started.
- Refresh late `SL` slot / neighborhood evidence when the surrounding O4z queue is ready.
- Recheck artifact timing only if the audit owner wants to update or retire the existing value-carrier / raw-lane performance frontier.
- Continue coordinating raw gate boundary work with `[AUDIT002-F]` and `[AUDIT002-G]`; this audit added EH semantic coverage, not raw-threshold boundary tests.
