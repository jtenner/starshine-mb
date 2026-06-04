---
kind: source-refresh
status: supported
last_reviewed: 2026-06-04
sources:
  - https://moonbitlang.github.io/moon/commands.html
  - https://github.com/moonbitlang/moon/blob/main/docs/manual/src/commands.md
  - ../../../src/cmd/cmd.mbt
  - ../../../src/passes/perf.mbt
  - ../../../src/validate_trace/main.mbt
  - ../../../src/validate_trace/main_wbtest.mbt
  - ../../../src/validate/validate.mbt
  - ../../../scripts/lib/validate-task.ts
  - ../../../scripts/test/task-family-commands.ts
---

# Tracing And Validation Benchmark Source Refresh

Capture date: 2026-06-04.

Purpose: refresh the shared tracing playbook and validation trace benchmark pages against the current Starshine command, optimizer-perf, validator-trace, and Bun-wrapper sources, while keeping the upstream Moon command/manual boundary explicit.

## Primary and local sources checked

- Official Moon command manual, `commands.html`, plus the source markdown in `moonbitlang/moon`. Used only for the upstream `moon run` command-shape context and target forwarding vocabulary; Starshine's `bun validate trace-benchmark` accepted targets and subcommand flags remain local script policy.
- `src/cmd/cmd.mbt`:
  - `parse_tracing_level_name(...)` accepts only `pass`, `phase`, and `helper`.
  - `--tracing <pass|phase|helper>`, `STARSHINE_TRACING`, and config `tracing` merge into a CLI trace level; CLI wins over environment, which wins over config.
  - `STARSHINE_OPTIMIZE_MAX_PASSES` truncates the scheduled pass queue by prefix length before optimizer dispatch and emits a `pass_limit` trace line when active.
  - `cmd_trace_emit(...)` writes command traces to stderr as `[trace] <message>`.
  - Command traces cover run/options/effective-pass setup, per-input read/lower/decode, copy-noop, pass count, optimizer segments, debug steps, validation, encoding, post-encode validation, and output writes.
- `src/passes/perf.mbt`:
  - `HotPerfSession` gates timing, checkpoint, counter, and optional dump output.
  - Timer lines are `perf:timer name=<name> elapsed_us=<n> total_us=<n>`.
  - Counter lines are `perf:counters label=<label> node_allocs=<n> child_span_allocs=<n> side_table_allocs=<n> region_splices=<n> cfg_builds=<n> dataflow_builds=<n> traversal_visits=<n>`.
  - Dump lines are opt-in and currently cover HOT function snapshots and CFG summaries.
- `src/validate_trace/main.mbt`:
  - Fixed corpora remain `deep-control`, `wide-locals`, `large-codesec`, and `ref-func-heavy`.
  - `run_validate_trace_benchmark(...)` deduplicates repeated `--corpus` values, defaults to all fixed corpora, rejects unknown corpus names, and requires positive repeat counts.
  - Each corpus run captures validator trace lines, requires `phase_totals` and `helper_totals`, carries optional `hotspots`, and prints a stable four-line block per corpus.
- `src/validate_trace/main_wbtest.mbt` and `scripts/test/task-family-commands.ts` pin the corpus roster, summary-line contract, list-corpora behavior, repeated-corpus parsing, wrapper forwarding, and nondefault target forwarding.
- `scripts/lib/validate-task.ts` owns `bun validate trace-benchmark` parsing and forwards to `moon run --target <target> src/validate_trace -- ...`; it validates targets through Starshine's local wrapper whitelist before invoking Moon.

## Current reconciliation

- The old tracing playbook was too compact for the current two-lane trace surface. There are now separate command/optimizer trace lines from `starshine --tracing ...` and validator trace-benchmark lines from `src/validate_trace`.
- Both surfaces still share the same durable principles: disabled tracing must stay cheap, output is compact key/value-ish text, wall-clock values are local evidence rather than portable semantic claims, and tests should piggyback on functional or command-contract behavior instead of becoming trace-only telemetry.
- The validation trace benchmark still uses the March baseline snapshot as historical baseline evidence. This refresh updates source ownership and interpretation, not the numeric baseline.

## Supersession and uncertainty

- This refresh supersedes the source-routing parts of `2026-05-20-validation-trace-benchmark-source-refresh.md` for tracing and wrapper ownership. It does not replace the March emitted baseline snapshot in `raw/research/0010-2026-03-18-validate-trace-baseline.md`.
- The meaning of `phase_totals`, `helper_totals`, and `hotspots` remains tied to `src/validate/validate.mbt`. If validator phase names or helper buckets change, refresh the focused validation phase page and benchmark baseline together.
- Upstream Moon may accept command forms or targets that Starshine's Bun wrappers reject. Treat wrapper target acceptance as local policy until `scripts/lib/task-runtime.ts` and wrapper tests change.
