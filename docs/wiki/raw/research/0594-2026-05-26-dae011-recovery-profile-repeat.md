# DAE011 recovery profile repeat

Date: 2026-05-26

## Scope

Recovery run for `[DAE]011` after the timing-only helper landed. The task was to find any remaining DAE work and avoid unsafe edits in a workspace that already contains staged and unstaged non-DAE/SGO changes.

## Evidence

Commands run from `/home/jtenner/Projects/starshine-mb`:

```sh
bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --timing-only \
  --out-dir .tmp/dae011-recovery-profile-20260526
```

Result file: `.tmp/dae011-recovery-profile-20260526/result.json`.

Observed timings:

- Starshine whole command: `3263.053ms`
- Binaryen whole command: `1160.218ms`
- Starshine pass-local: `2876.963ms`
- Binaryen pass-local: `872.467ms`
- Starshine pass-local ratio: about `3.30x` Binaryen, still outside the `<= 2x` target.

A direct traced Starshine run was also checked:

```sh
target/native/release/build/cmd/cmd.exe \
  --tracing pass \
  --dead-argument-elimination-optimizing \
  --out .tmp/dae011-direct-trace.wasm \
  tests/node/dist/starshine-debug-wasi.wasm
```

It emitted only the aggregate pass timer:

```text
perf:timer name=pass:dead-argument-elimination-optimizing elapsed_us=2954776 total_us=2954776
```

So the current built binary can confirm the blocker is DAE pass-local time, but cannot attribute the cost inside DAE core, nested cleanup, or type pruning without adding detail timers/instrumentation.

## Classification

`[DAE]011` remains open. The current recovery evidence is a timing/profile attribution checkpoint, not a behavior change and not a semantic mismatch. The timing-only artifact intentionally skipped normalized-WAT comparison; no fuzz/compare mismatch classification was produced in this run.

## Next safe subtasks

1. Add focused DAE detail perf timers around:
   - `dae_run_core`,
   - DAE nested cleanup total and per nested pass,
   - `dae_prune_unused_simple_func_types`.
2. Add or update a focused perf test that proves `--dae-optimizing` with a perf session emits those detail timer names.
3. Re-run the timing-only artifact command and record which DAE-owned phase dominates before changing pass logic.
4. Only after attribution, choose a targeted optimization that avoids the known DAE cliffs: broad rescans, per-def bitmap churn, whole-module untouched cleanup, and selected-loop expansions.

## Validation

- The timing-only artifact command completed and wrote raw/canonical wasm outputs plus `result.json`.
- The direct `--tracing pass` run completed and wrote `.tmp/dae011-direct-trace.wasm`.
- No source behavior was changed in this note.
