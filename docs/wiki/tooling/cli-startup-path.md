---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/research/0092-2026-04-16-cli-startup-performance-issues.md
  - ../raw/research/0707-2026-06-04-cli-dispatcher-stdin-gap-and-source-audit.md
  - ../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md
  - ../../../src/cli/cli.mbt
  - ../../../src/cli/glob.mbt
  - ../../../src/cli/glob_test.mbt
  - ../../../src/cmd/cmd.mbt
  - ../../../src/cmd/cmd_wbtest.mbt
  - ../../../src/passes/optimize.mbt
related:
  - ./cli-command-and-dispatcher.md
  - ./tracing-playbook.md
  - ./fuzz-runner.md
  - ./o4z-debug-startup-trap.md
  - ../../README.md
---

# CLI Startup Path

## Overview

Use this page when debugging **startup cost** or early CLI behavior before ordinary module decoding, optimization, validation, and output writing begin. For the full `starshine` command contract, pass queue, print/dump/validate utility steps, config precedence, stdin caveat, and trap-mode routing, use [`cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md). This page keeps the smaller performance-sensitive path visible so future command changes do not accidentally reintroduce expensive work into help/version or no-input flows.

Beginner model: CLI startup has three layers.

1. **Parse enough flags to know whether the command exits immediately.** `--help` / `-h` and `--version` / `-V` should not read files, resolve globs, probe configuration, or touch optimizer state.
2. **Build a merged command view only for real runs.** Positional inputs, `STARSHINE_INPUT`, optional config JSON, mode-relevant environment variables, pass flags, optimize levels, and outputs are merged in [`run_cmd_with_adapter(...)`](../../../src/cmd/cmd.mbt).
3. **Resolve normalized input paths.** Literal paths are kept in command order, wildcard patterns expand only when `--glob` is enabled, and matching uses the normalized/bucketed glob helper in [`src/cli/glob.mbt`](../../../src/cli/glob.mbt).

The 2026-04-16 startup audit is historical now: pass-registry lookup is cached, help text is prebuilt, `parse_olevel_text` parses raw `O` forms directly, and `parse_env_overlay` only probes mode-relevant variables. The live startup cost center is path handling: normalization, candidate enumeration, glob bucketing, deduplication, and sorting.

## Current Startup Flow

| Step | Code owner | Performance/correctness invariant | Test evidence |
| --- | --- | --- | --- |
| Single-argument trivial exit | [`cmd_try_trivial_startup_exit(...)`](../../../src/cmd/cmd.mbt) | Bare `--help`, `-h`, `--version`, or `-V` returns before runtime preparation, config lookup, `STARSHINE_INPUT`, or optimizer setup. | [`run_cmd_with_adapter fast-paths bare --help without env probing`](../../../src/cmd/cmd_wbtest.mbt), [`run_cmd_with_adapter fast-paths bare --version without env probing`](../../../src/cmd/cmd_wbtest.mbt). |
| Parse and normalize CLI layer | [`parse_cli_args(...)`](../../../src/cli/cli.mbt), [`normalize_parse_result_paths(...)`](../../../src/cmd/cmd.mbt) | Inputs and output/config paths are normalized once as they enter the merged command view. `--stdin` still requires `--format` unless help/version exits first. | CLI parser tests in [`src/cli/cli_test.mbt`](../../../src/cli/cli_test.mbt) plus command exit-code tests in [`src/cmd/cmd_wbtest.mbt`](../../../src/cmd/cmd_wbtest.mbt). |
| Parsed help/version exit | [`run_cmd_with_adapter(...)`](../../../src/cmd/cmd.mbt) | Help/version can still win after parsing a larger flag set such as `--help --stdin`, preventing `STARSHINE_INPUT` and config/env probing. | [`run_cmd_with_adapter exits on parsed help before STARSHINE_INPUT probing`](../../../src/cmd/cmd_wbtest.mbt). |
| `STARSHINE_INPUT` append | [`parse_starshine_input_env(...)`](../../../src/cli/cli.mbt), [`run_cmd_with_adapter(...)`](../../../src/cmd/cmd.mbt) | Environment inputs append to already parsed CLI inputs only after help/version are ruled out. Native wiring is covered, but this is an input-source feature, not a config replacement. | [`run_cmd reads STARSHINE_INPUT from native environment`](../../../src/cmd/cmd_wbtest.mbt). |
| Config and environment overlay | [`resolve_config_path(...)`](../../../src/cmd/cmd.mbt), [`parse_env_overlay(...)`](../../../src/cmd/cmd.mbt), [`merge_parse_results(...)`](../../../src/cmd/cmd.mbt) | `parse_env_overlay` probes only variables that can still affect the run: for example, stale `STARSHINE_PASSES` is skipped when CLI or config already fixes pass flags, and output variables are skipped when CLI output is present. | [`run_cmd_with_adapter skips irrelevant env overlay probes`](../../../src/cmd/cmd_wbtest.mbt) records the expected reduced lookup list for a fully specified CLI command. |
| Input resolution | [`resolve_input_files_with_glob(...)`](../../../src/cmd/cmd.mbt), [`expand_globs_with_adapter(...)`](../../../src/cli/glob.mbt) | Literal inputs are deduped early; wildcard patterns enumerate candidates only when `--glob` is enabled; resulting matches are normalized, sorted, deduped, and appended after literals. | [`src/cli/glob_test.mbt`](../../../src/cli/glob_test.mbt) covers separator normalization, `**`, `?`, drive/absolute scopes, deterministic sorting, and overlap dedupe. |
| Pipeline handoff | [`resolve_effective_pass_flags(...)`](../../../src/cmd/cmd.mbt), [`src/passes/optimize.mbt`](../../../src/passes/optimize.mbt) | Only after input files exist does startup compute default `optimize`/`shrink` synthesis, `STARSHINE_OPTIMIZE_MAX_PASSES`, and optimizer options. | Dispatcher and registry tests in [`src/cmd/cmd_wbtest.mbt`](../../../src/cmd/cmd_wbtest.mbt) and [`src/passes/optimize.mbt`](../../../src/passes/optimize.mbt). |

## Path Normalization And Glob Shape

[`normalize_cli_path(...)`](../../../src/cli/glob.mbt) is intentionally local and conservative; it does not ask the host filesystem to canonicalize symlinks or case. It rewrites only the command-layer string shape:

```text
./src\\foo//bar/../main.wasm  ->  src/foo/main.wasm
C:/repo/src/../test/a.wat      ->  C:/repo/test/a.wat
```

Important details for future tuning:

- Backslashes become `/` so command behavior is stable across Windows-style and POSIX-style inputs.
- Repeated separators and `.` segments are removed.
- `..` pops the previous segment when safe; relative leading `..` is preserved.
- Drive prefixes such as `C:` and absolute paths stay in distinct scopes. A pattern for `C:/src/*.wasm` must not match `D:/src/a.wasm`, and `/src/*.wasm` must not match `src/a.wasm`.
- Empty normalized paths become `.`.

`expand_globs(...)` then compiles both patterns and candidates into normalized segment arrays. It keeps two broad buckets (relative and absolute), further buckets absolute candidates by drive/prefix, and optionally indexes by the first literal segment of the pattern. That lets common patterns such as `src/**/*.wasm` avoid scanning obviously unrelated first-segment candidates after the one unavoidable filesystem candidate enumeration.

Output ordering is deliberate:

1. candidate paths are normalized, deduped, and sorted;
2. patterns are evaluated in input pattern order;
3. overlapping matches keep first-pattern stability while preventing duplicate output paths;
4. command-level input resolution appends glob matches after literal inputs.

## What Not To Regress

- **Do not probe env/config for trivial exits.** Bare help/version should return with empty `CmdRunSummary` inputs/outputs and no environment lookups.
- **Do not make parser-only flags read files.** `--stdin` is still parsed/configured but not wired as a byte source in the dispatcher; the current gap belongs to [`cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md), not this startup-cost page.
- **Do not make broad env overlays unconditional.** `STARSHINE_PASSES`, `STARSHINE_OPTIMIZE`, output variables, and similar overlays should stay conditional on whether they can still affect the merged result.
- **Do not move heavy randomized or filesystem-wide work into `moon test`.** Keep deterministic startup invariants in command/glob tests; use CLI benchmarks or tracing for broader performance investigation.
- **Do not use Binaryen `wasm-opt` startup behavior as a local contract.** Binaryen is useful orientation for the broader CLI shape, but Starshine's startup path is defined by the files above and by [`cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md).

## Debugging And Signoff Checklist

When a startup-path change lands:

1. Update or add deterministic tests in [`src/cmd/cmd_wbtest.mbt`](../../../src/cmd/cmd_wbtest.mbt) or [`src/cli/glob_test.mbt`](../../../src/cli/glob_test.mbt) before changing behavior.
2. Check that bare `--help` / `--version` still avoid env probing and still return zero exit codes through `run_cmd_exit_code_with_adapter(...)`.
3. Check that parsed help wins over otherwise-invalid runtime-only combinations such as `--help --stdin`.
4. For path/glob changes, cover separators, `.` / `..`, `**`, `?`, drive prefixes, absolute-vs-relative separation, deterministic sorting, and duplicate suppression.
5. For real performance investigations, use the CLI benchmark entry documented in [`../../README.md`](../../README.md) and route trace-line interpretation through [`tracing-playbook.md`](./tracing-playbook.md). Record durable findings in a numbered research note under [`../raw/research/`](../raw/research/) only when the result should survive the run.

## Current Follow-up Surface

- Use the archived audit [`../raw/research/0092-2026-04-16-cli-startup-performance-issues.md`](../raw/research/0092-2026-04-16-cli-startup-performance-issues.md) for the older hotspot list and historical fixes; this living page is the compact current contract.
- Use [`../raw/research/0707-2026-06-04-cli-dispatcher-stdin-gap-and-source-audit.md`](../raw/research/0707-2026-06-04-cli-dispatcher-stdin-gap-and-source-audit.md) and [`cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md) for the parsed-but-not-wired `--stdin` gap. Do not mix stdin byte-source work with path/glob startup tuning unless both are intentionally in scope.
- The repaired `o4z` debug-startup trap has a dedicated living page in [`o4z-debug-startup-trap.md`](./o4z-debug-startup-trap.md) and a historical source note in [`../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md`](../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md). Keep runtime trap correctness separate from startup latency.
- If startup traces regress, check `normalize_cli_path`, `expand_globs`, and the `cmd_wbtest` fast-path coverage before widening the search to parser or optimizer code.

## Sources

- Archived startup audit: [`../raw/research/0092-2026-04-16-cli-startup-performance-issues.md`](../raw/research/0092-2026-04-16-cli-startup-performance-issues.md)
- Dispatcher/stdin source audit: [`../raw/research/0707-2026-06-04-cli-dispatcher-stdin-gap-and-source-audit.md`](../raw/research/0707-2026-06-04-cli-dispatcher-stdin-gap-and-source-audit.md)
- Debug-startup trap archive: [`../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md`](../raw/research/0693-2026-06-01-o4z-debug-startup-func3750.md)
- CLI parser and path/glob code: [`../../../src/cli/cli.mbt`](../../../src/cli/cli.mbt), [`../../../src/cli/glob.mbt`](../../../src/cli/glob.mbt), [`../../../src/cli/glob_test.mbt`](../../../src/cli/glob_test.mbt)
- Command dispatcher and tests: [`../../../src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt), [`../../../src/cmd/cmd_wbtest.mbt`](../../../src/cmd/cmd_wbtest.mbt)
- Pass registry handoff: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt)
- Full command contract: [`./cli-command-and-dispatcher.md`](./cli-command-and-dispatcher.md)
