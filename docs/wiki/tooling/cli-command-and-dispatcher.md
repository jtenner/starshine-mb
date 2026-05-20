---
kind: workflow
status: supported
last_reviewed: 2026-05-19
sources:
  - ../raw/binaryen/2026-05-19-wasm-opt-cli-contract.md
  - ../../../src/cli/cli.mbt
  - ../../../src/cli/cli_test.mbt
  - ../../../src/cli/glob.mbt
  - ../../../src/cmd/cmd.mbt
  - ../../../src/cmd/cmd_wbtest.mbt
  - ../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/pass_manager_wbtest.mbt
  - ../../../README.md
related:
  - ./cli-startup-path.md
  - ./fuzz-runner.md
  - ./tracing-playbook.md
  - ./validation-gates.md
  - ../wast/static-assertion-harness.md
  - ../ir2/registry-map.md
  - ../binaryen/passes/index.md
  - ../binaryen/no-dwarf-default-optimize-path.md
---

# CLI Command And Dispatcher Contract

## Overview

Starshine's CLI is a local command layer inspired by Binaryen's `wasm-opt` shape: read one or more Wasm modules, combine command-line/config/environment options, run an ordered queue of passes or inspection steps, validate the result, and write wasm output. The upstream shape is documented in the Binaryen source snapshot [`../raw/binaryen/2026-05-19-wasm-opt-cli-contract.md`](../raw/binaryen/2026-05-19-wasm-opt-cli-contract.md), but exact Starshine behavior is defined by the local packages:

- [`src/cli/cli.mbt`](../../../src/cli/cli.mbt) parses flags, input globs, formats, optimization level flags, tracing, trap mode, closed-world mode, and output targets.
- [`src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt) merges CLI/config/environment settings, resolves input files, lowers text input to binary modules, dispatches ordered pipeline steps, validates, encodes, and writes outputs.
- [`src/passes/optimize.mbt`](../../../src/passes/optimize.mbt) owns the pass registry categories, preset expansion, hot/module pass routing, and final optimizer validation.

Do not infer behavior from Binaryen's full `wasm-opt --help` surface. Starshine intentionally implements a smaller but explicit command contract with its own diagnostics and debug steps.

## Command Shape

```text
starshine [flags] [passes/debug-steps] <input...>
starshine spec [-g|--glob] <tests/spec/*.wast ...>
```

Common module-run flags:

| Surface | Contract | Owner |
| --- | --- | --- |
| Input paths | Positional arguments are input globs/paths; `--` stops option parsing; `STARSHINE_INPUT` can append more inputs after trivial help/version handling. | `src/cli/cli.mbt`, `src/cmd/cmd.mbt` |
| Input formats | `.wasm` is default when no format can be inferred; `.wat` / `.wast` can be inferred or forced with `--format`; `--stdin` requires `--format`. | `src/cli/cli.mbt`, `src/cmd/cmd.mbt` |
| Text lowering | Host adapter lowering is tried first; if unavailable, Starshine falls back to in-process WAT/WAST parse/lower/encode. | `src/cmd/cmd.mbt`, `src/cmd/cmd_wbtest.mbt` |
| Outputs | No explicit output rewrites each input path in place, with `.wat` / `.wast` defaulting to `.wasm`; `--out` is single-file only; `--out-dir` preserves per-input basenames; `--stdout` writes bytes to stdout. | `src/cli/cli.mbt`, `src/cmd/cmd.mbt` |
| Globbing | `--glob` separates literal inputs from wildcard patterns, expands via the host candidate list, de-duplicates, and keeps deterministic ordering. | `src/cli/glob.mbt`, `src/cmd/cmd.mbt` |
| Spec subcommand | `starshine spec` / `starshine spec-runner` runs WAST spec files through the static WAST spec harness and returns a `CmdRunSummary` with `resolved_passes=["spec"]` on success; the printed suite summary separates `passed`, `skipped`, and `failed` files, so do not treat known-unsupported or known-mismatch skips as green conformance. See [`../wast/static-assertion-harness.md`](../wast/static-assertion-harness.md) for the static-assertion/runtime-skip and skip-policy boundary. | `src/cmd/cmd.mbt`, `src/spec_runner/` |

## Configuration And Precedence

The dispatcher builds three views and then merges them:

1. explicit CLI args;
2. environment overlay; and
3. JSON config from `--config`, `STARSHINE_CONFIG`, or default [`starshine.config.json`](../../../src/cli/cli.mbt).

The precedence is not one global rule for every field. Keep these distinctions intact:

| Field family | Effective precedence | Notes |
| --- | --- | --- |
| Inputs | Config inputs, then environment inputs, then CLI inputs are appended during merge; `STARSHINE_INPUT` can also append after base CLI parse. | This makes config/default inputs usable while still allowing CLI additions. |
| Pass flags | CLI pass flags override config pass lists; config pass lists override environment pass overlays. | This prevents stale `STARSHINE_PASSES` from silently adding work when a config already chooses passes. |
| Optimize flags | CLI optimize flags override environment optimize flags; environment optimize flags override config optimize flags. | `STARSHINE_OLEVEL` is intended as a temporary local override. |
| Outputs | CLI outputs, then environment outputs, then config outputs. | Multiple inputs plus `--out <file>` is rejected as ambiguous. |
| Trap/closed-world/low-memory/monomorphize/tracing | CLI, then environment, then config. | The summary records the resolved values for downstream debugging. |
| Debug-serial mode | Boolean OR across CLI, environment, and config. | Any source can force safer per-pass validation. |
| Config path | explicit CLI, then `STARSHINE_CONFIG`, then default file if present. | A missing explicit/env config is fatal; an absent default config is ignored. |

Tests in [`src/cmd/cmd_wbtest.mbt`](../../../src/cmd/cmd_wbtest.mbt) cover the high-risk precedence cases: CLI passes overriding config, config pass lists blocking env overlays, env optimize/trap overlays overriding config, default config loading, inline config JSON, and config read errors.

## Pass Queue, Presets, And Debug Steps

The CLI parser accepts unknown kebab-case long flags as candidate pass flags, but the command dispatcher validates them against [`pass_registry_category(...)`](../../../src/passes/optimize.mbt). Valid pipeline items are:

- active hot passes;
- active module passes;
- presets (`optimize`, `shrink`);
- ordered debug/utility steps (`dump=...`, `print-*`, `validate`, `extract-functions=...`); and
- no-inline pattern flags whose base pass is recognized by the registry.

Boundary-only and removed registry names are intentionally tracked for planning, but they are not runnable. This is why docs should say "registered as boundary-only" or "removed from the active hot pipeline" instead of calling those passes silently unsupported.

### Preset and `-O` behavior

`--optimize` and `--shrink` are both pass flags and optimize-level hints. Raw `-O...` / `--optimize-level` / `--shrink-level` values update the effective numeric levels. If no explicit pass flags are present, the dispatcher synthesizes one default pass name from levels: `shrink` wins when the shrink level is nonzero, otherwise `optimize` wins when the optimize level is nonzero. If any explicit pass/debug flag exists, the explicit queue is used as written.

Both local presets currently expand to the same implemented mixed module/hot pass sequence in [`optimize_preset_passes(...)`](../../../src/passes/optimize.mbt) and [`shrink_preset_passes(...)`](../../../src/passes/optimize.mbt). The deeper Binaryen `-O` / no-DWARF comparison lives in [`../binaryen/no-dwarf-default-optimize-path.md`](../binaryen/no-dwarf-default-optimize-path.md) and the pass namespace map lives in [`../ir2/registry-map.md`](../ir2/registry-map.md).

### Ordered utility steps

Utility steps split the optimization queue into segments:

```text
starshine --dump before.wat --print-func 42 --vacuum --validate --dump after.wasm input.wasm
```

The dispatcher flushes pending optimizer passes before each utility step. That means dumps, prints, validation checkpoints, and `extract-functions` observe the module at exactly that point in the queue, not only before or after the whole run.

| Step | Behavior |
| --- | --- |
| `--dump <file.wasm|file.wat>` | Writes the current module state as binary wasm or printed WAT. |
| `--print-{type,func,import,table,memory,global,export,tag,elem,data} <name|index>` | Logs one selected item to stderr; names come from the structured name section or import/export fields where applicable. |
| `--validate` | Validates the current module state and includes offending function text when available. |
| `--extract-functions <index,index,...>` | Replaces the current module with a safe minimal module rooted at selected functions through RUME extraction. |

## Validation And Encoding Invariants

The command pipeline intentionally validates at multiple layers:

1. decode input bytes to a structured module;
2. run ordered pass segments with final validation disabled inside each segment because command-level utility steps need to interleave with them;
3. validate the final module before encoding;
4. encode output bytes; and
5. when `--debug-serial-passes` is enabled, decode and validate the encoded output too.

If a pass segment or validation step fails, `CmdError::OptimizeFailed` preserves multiline diagnostics. If post-encode validation fails in debug-serial mode, the error appends a reproducible command hint that includes active pass flags, levels, trap mode, closed-world mode, and low-memory options.

A no-op wasm input with at least one pass may reuse original input bytes when the optimized module equals the decoded input module, debug-serial post-encode validation is off, and the input format was wasm. Text inputs never reuse original bytes because the output contract is binary wasm.

## Tracing And Debug Limits

`--tracing <pass|phase|helper>` or `STARSHINE_TRACING` enables command-level trace lines and passes the matching trace level into the optimizer. `STARSHINE_OPTIMIZE_MAX_PASSES` truncates the scheduled pass queue by prefix length, including `0` for a decode/encode baseline. `--debug-serial-passes` switches the optimizer options to validate after each pass segment and disables stacked function-pass execution, prioritizing debuggability over throughput.

Use [`tracing-playbook.md`](./tracing-playbook.md) for trace-line shape and [`validation-gates.md`](./validation-gates.md) for signoff commands. Do not add trace-only tests; change existing command or pass contract tests when the shape changes.

## Edge Cases And Maintenance Rules

- Help/version are fast-path early exits for a single `--help` / `-h` / `--version` / `-V`; they must not probe `STARSHINE_INPUT` or config.
- `--stdin` without `--format` is invalid except when help/version exits first.
- `--out <file>` with multiple resolved inputs is ambiguous and must fail before processing inputs.
- Candidate long pass flags must be kebab-case; non-kebab unknown long flags are parse errors before registry lookup.
- Help output intentionally lists only runnable hot passes and presets. Module passes may still be runnable when known to the registry, but help is kept focused.
- Boundary-only and removed pass names should stay visible in wiki dossiers and registry maps but not in CLI help.
- Any new command flag needs parser coverage in `src/cli/cli_test.mbt` or command coverage in `src/cmd/cmd_wbtest.mbt`; any new pass category or preset change also needs `src/passes/optimize.mbt` and registry/preset docs refreshed.

## Sources

- Upstream CLI shape: [`../raw/binaryen/2026-05-19-wasm-opt-cli-contract.md`](../raw/binaryen/2026-05-19-wasm-opt-cli-contract.md)
- Parser/config/glob code: [`../../../src/cli/cli.mbt`](../../../src/cli/cli.mbt), [`../../../src/cli/glob.mbt`](../../../src/cli/glob.mbt), [`../../../src/cli/cli_test.mbt`](../../../src/cli/cli_test.mbt)
- Dispatcher/codegen/validation code: [`../../../src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt), [`../../../src/cmd/cmd_wbtest.mbt`](../../../src/cmd/cmd_wbtest.mbt), [`../../../src/cmd/cmd_native_wbtest.mbt`](../../../src/cmd/cmd_native_wbtest.mbt)
- Pass registry and presets: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt), [`../ir2/registry-map.md`](../ir2/registry-map.md), [`../binaryen/passes/index.md`](../binaryen/passes/index.md)
- Related workflows: [`./cli-startup-path.md`](./cli-startup-path.md), [`./validation-gates.md`](./validation-gates.md), [`./fuzz-runner.md`](./fuzz-runner.md), [`./tracing-playbook.md`](./tracing-playbook.md)
