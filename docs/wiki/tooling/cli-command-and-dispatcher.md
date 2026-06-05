---
kind: workflow
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/research/0711-2026-06-04-cli-print-utility-routing.md
  - ../raw/research/0707-2026-06-04-cli-dispatcher-stdin-gap-and-source-audit.md
  - ../raw/validation/2026-06-04-trap-mode-routing-source-refresh.md
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
  - ../binary/custom-and-name-sections.md
  - ../wast/identifier-name-and-annotation-authoring.md
  - ../validate/import-export-and-external-type-matching.md
  - ../validate/runtime-trap-semantics.md
  - ../ir2/registry-map.md
  - ../binaryen/passes/index.md
  - ../binaryen/no-dwarf-default-optimize-path.md
---

# CLI Command And Dispatcher Contract

## Overview

Starshine's CLI is a local command layer inspired by Binaryen's `wasm-opt` shape: read one or more Wasm modules, combine command-line/config/environment options, run an ordered queue of passes or inspection steps, validate the result, and write wasm output. The upstream shape is documented in the Binaryen source snapshot [`../raw/binaryen/2026-05-19-wasm-opt-cli-contract.md`](../raw/binaryen/2026-05-19-wasm-opt-cli-contract.md), but exact Starshine behavior is defined by the local packages:

- [`src/cli/cli.mbt`](../../../src/cli/cli.mbt) parses flags, input globs, formats, optimization level flags, tracing, trap mode, closed-world mode, and output targets.
- [`src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt) merges CLI/config/environment settings, resolves input files, lowers text input to binary modules, dispatches ordered pipeline steps, validates, encodes, records resolved trap mode, and writes outputs.
- [`src/passes/optimize.mbt`](../../../src/passes/optimize.mbt) owns the pass registry categories, preset expansion, hot/module pass routing, and final optimizer validation.

Do not infer behavior from Binaryen's full `wasm-opt --help` surface. Starshine intentionally implements a smaller but explicit command contract with its own diagnostics and debug steps. The 2026-06-04 source audit in [`../raw/research/0707-2026-06-04-cli-dispatcher-stdin-gap-and-source-audit.md`](../raw/research/0707-2026-06-04-cli-dispatcher-stdin-gap-and-source-audit.md) rechecked the current Binaryen CLI orientation sources and local dispatcher code; it also records the current local `--stdin` gap described below.

## Command Shape

```text
starshine [flags] [passes/debug-steps] <input...>
starshine spec [-g|--glob] <tests/spec/*.wast ...>
```

Common module-run flags:

| Surface | Contract | Owner |
| --- | --- | --- |
| Input paths | Positional arguments are input globs/paths; `--` stops option parsing; `STARSHINE_INPUT` can append more inputs after trivial help/version handling. Current `--stdin` is parsed and merged but does **not** create an input file or read bytes; without at least one glob/path the dispatcher returns `NoInputFiles`. | `src/cli/cli.mbt`, `src/cmd/cmd.mbt`, `../raw/research/0707-2026-06-04-cli-dispatcher-stdin-gap-and-source-audit.md` |
| Input formats | `.wasm` is default when no format can be inferred; `.wat` / `.wast` can be inferred or forced with `--format`; `--stdin` currently requires `--format` at parse time even though stdin bytes are not yet materialized by the dispatcher. | `src/cli/cli.mbt`, `src/cmd/cmd.mbt` |
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
| Stdin flag | Boolean OR across config `inputs.stdin` and CLI `--stdin` after parse-time format checking; the parsed environment overlay currently contributes only its default `false`. | Current execution ignores the merged flag when building `input_files`; treat it as parsed-but-not-wired until a stdin byte source lands. |
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

### Trap-mode flags are options, not passes

`--trap-mode <allow|never>`, `--traps-never-happen`, and `--traps-may-happen` are parsed as optimizer options, not scheduled pass names. [`src/cli/cli_test.mbt`](../../../src/cli/cli_test.mbt) locks both sides: mixed-case values are accepted, missing/invalid values are rejected, `--traps-never-happen --traps-may-happen` resolves by last flag wins, and trap-mode toggles are omitted from `resolve_pass_flags(...)` so a neighboring explicit pass such as `--flatten` remains the scheduled item.

Command/config/environment merge follows the general option precedence above: CLI, then environment, then config. Config accepts both `optimize.trapMode` / `optimize.trap-mode` style values and boolean `options.trapsNeverHappen` / `options.traps-never-happen` style values. The resolved boolean is stored in `OptimizeOptions`, written into `CmdRunSummary.traps_never_happen`, included in trace option lines, and preserved in post-encode repro hints when set.

Important current caveat: the 2026-06-04 trap-mode routing refresh found no current Starshine pass implementation that consumes `OptimizeOptions.traps_never_happen` to relax trap-sensitive rewrites. Treat the flag as command/config/report vocabulary and future pass-option plumbing unless a pass-specific Starshine strategy page documents local TNH behavior. The shared trap vocabulary and Binaryen-vs-Starshine split lives in [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md), sourced through [`../raw/validation/2026-06-04-trap-mode-routing-source-refresh.md`](../raw/validation/2026-06-04-trap-mode-routing-source-refresh.md).

Some hot passes have trace-labeled conservative fallbacks for pathological module or function shapes. For example, `ssa-nomerge`, `simplify-locals`, `optimize-instructions`, `precompute`, and `code-pushing` can skip very large, structured, or branch-heavy shapes rather than risk an unsafe transform, abort, OOM, or non-terminating self-optimization run; these are no-op fallbacks, not silent pass-name acceptance.

### Ordered utility steps

Utility steps split the optimization queue into segments:

```text
starshine --dump before.wat --print-func 42 --vacuum --validate --dump after.wasm input.wasm
```

The dispatcher flushes pending optimizer passes before each utility step. That means dumps, prints, validation checkpoints, and `extract-functions` observe the module at exactly that point in the queue, not only before or after the whole run. The focused print-step source audit is [`../raw/research/0711-2026-06-04-cli-print-utility-routing.md`](../raw/research/0711-2026-06-04-cli-print-utility-routing.md); it checked the current parser, dispatcher, help, and command tests behind the details below.

| Step | Behavior |
| --- | --- |
| `--dump <file.wasm|file.wat>` | Writes the current module state as binary wasm or printed WAT. Only `.wasm` and `.wat` paths are accepted. |
| `--print-{type,func,import,table,memory,global,export,tag,elem,data} <name|index>` | Logs one selected item to stderr at that exact queue point. The CLI parser accepts the `print-` shape and a non-empty selector, but the dispatcher owns this ten-kind allowlist; unsupported `--print-foo` is rejected as an unknown pass flag. |
| `--validate` | Validates the current module state and includes offending function text when available. |
| `--extract-functions <index,index,...>` | Replaces the current module with a safe minimal module rooted at selected functions through RUME extraction. |

Print selectors intentionally support both fast numeric debugging and name-based lookup. For the authoring-layer split between WAST `$` ids, lowered structured `NameSec` entries, and source-only ids that do not survive as printable names, use [`../wast/identifier-name-and-annotation-authoring.md`](../wast/identifier-name-and-annotation-authoring.md).

- `71` and `(71)` both select absolute index `71`.
- Any other selector is a name.
- Type, function, table, memory, global, tag, element, and data name lookups use the structured [`NameSec`](../binary/custom-and-name-sections.md) maps. Source `$` ids are only available if they survived lowering or binary decode into those maps. Index selectors remain reliable when name maps are absent.
- Import name lookup uses the import payload, not the name section: `field` selects the first matching field name, while `module.field` selects an exact `(module, field)` pair.
- Export name lookup uses the public export name string and shares the duplicate-name invariant documented in [`../validate/import-export-and-external-type-matching.md`](../validate/import-export-and-external-type-matching.md).
- Function indices are absolute imported-prefix `FuncIdx` values. `--print-func 0` may therefore select an imported function when function imports are present; local body ordinals are not a separate selector space.

The stderr log shape is part of the debugging contract, not a wasm output stream. For each input, the first print emits `Log: <input>`, every print gets an increasing entry number, labels look like `Func[0 main]` when a name is available, and bodies are indented. A missing item or name/index mismatch fails the command as `OptimizeFailed("print <kind>: no item matched selector ...")`; a stderr write failure reports `OutputWriteFailed("stderr print log ...")`. Keep `src/cli/cli_test.mbt` and the command-level `run_cmd_with_adapter prints ordered log entries to stderr and sees post-pass state` test in sync with any selector or log-shape change.

## Validation And Encoding Invariants

The command pipeline intentionally validates at multiple layers:

1. decode input bytes to a structured module;
2. run ordered pass segments with final validation disabled inside each segment because command-level utility steps need to interleave with them; compatible adjacent hot passes may be stacked per function so the scheduler does not materialize a full module between those passes;
3. validate the final module before encoding;
4. encode output bytes; and
5. when `--debug-serial-passes` is enabled, decode and validate the encoded output too.

If a pass segment or validation step fails, `CmdError::OptimizeFailed` preserves multiline diagnostics. If post-encode validation fails in debug-serial mode, the error appends a reproducible command hint that includes active pass flags, levels, trap mode, closed-world mode, and low-memory options.

A no-op wasm input with at least one pass may reuse original input bytes when the optimized module equals the decoded input module, debug-serial post-encode validation is off, and the input format was wasm. Text inputs never reuse original bytes because the output contract is binary wasm.

## Tracing And Debug Limits

`--tracing <pass|phase|helper>` or `STARSHINE_TRACING` enables command-level trace lines and passes the matching trace level into the optimizer. `STARSHINE_OPTIMIZE_MAX_PASSES` truncates the scheduled pass queue by prefix length, including `0` for a decode/encode baseline. Normal command runs enable stacked function-pass scheduling for compatible adjacent hot passes; `--debug-serial-passes` switches the optimizer options to validate after each pass segment and disables stacked function-pass execution, prioritizing debuggability over throughput.

Use [`tracing-playbook.md`](./tracing-playbook.md) for trace-line shape and [`validation-gates.md`](./validation-gates.md) for signoff commands. Do not add trace-only tests; change existing command or pass contract tests when the shape changes.

## Edge Cases And Maintenance Rules

- Help/version are fast-path early exits for a single `--help` / `-h` / `--version` / `-V`; they must not probe `STARSHINE_INPUT` or config.
- `--stdin` without `--format` is invalid except when help/version exits first.
- Current `--stdin` support is parser/config plumbing only: there is no `CmdIO` stdin byte source, no synthetic stdin input path, and no stdin output-name rule. A no-glob `--stdin --format wat` command therefore fails as `NoInputFiles` today, while `--stdin --format wat file.wat` processes `file.wat`.
- `--out <file>` with multiple resolved inputs is ambiguous and must fail before processing inputs.
- Candidate long pass flags must be kebab-case; non-kebab unknown long flags are parse errors before registry lookup.
- Help output intentionally lists only runnable hot passes and presets. Module passes may still be runnable when known to the registry, but help is kept focused.
- Boundary-only and removed pass names should stay visible in wiki dossiers and registry maps but not in CLI help.
- Any new command flag needs parser coverage in `src/cli/cli_test.mbt` or command coverage in `src/cmd/cmd_wbtest.mbt`; any new pass category or preset change also needs `src/passes/optimize.mbt` and registry/preset docs refreshed.
- If a pass starts consuming `OptimizeOptions.traps_never_happen`, update the pass dossier, [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md), compare-pass classification guidance, command tests, and the trap-mode raw source bridge together.
- Any new printable item kind needs coordinated changes to CLI help, `cmd_is_supported_print_kind(...)`, `cmd_resolve_pipeline_print_entry(...)`, the ordered stderr log test, this page, and whichever focused wiki page owns the selector's name source or index space.

## Sources

- 2026-06-04 print-utility routing audit: [`../raw/research/0711-2026-06-04-cli-print-utility-routing.md`](../raw/research/0711-2026-06-04-cli-print-utility-routing.md)
- 2026-06-04 dispatcher/stdin source audit: [`../raw/research/0707-2026-06-04-cli-dispatcher-stdin-gap-and-source-audit.md`](../raw/research/0707-2026-06-04-cli-dispatcher-stdin-gap-and-source-audit.md)
- 2026-06-04 trap-mode routing refresh: [`../raw/validation/2026-06-04-trap-mode-routing-source-refresh.md`](../raw/validation/2026-06-04-trap-mode-routing-source-refresh.md)
- Upstream CLI shape: [`../raw/binaryen/2026-05-19-wasm-opt-cli-contract.md`](../raw/binaryen/2026-05-19-wasm-opt-cli-contract.md)
- Parser/config/glob code: [`../../../src/cli/cli.mbt`](../../../src/cli/cli.mbt), [`../../../src/cli/glob.mbt`](../../../src/cli/glob.mbt), [`../../../src/cli/cli_test.mbt`](../../../src/cli/cli_test.mbt)
- Dispatcher/codegen/validation code: [`../../../src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt), [`../../../src/cmd/cmd_wbtest.mbt`](../../../src/cmd/cmd_wbtest.mbt), [`../../../src/cmd/cmd_native_wbtest.mbt`](../../../src/cmd/cmd_native_wbtest.mbt)
- Pass registry and presets: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt), [`../ir2/registry-map.md`](../ir2/registry-map.md), [`../binaryen/passes/index.md`](../binaryen/passes/index.md)
- Related workflows: [`./cli-startup-path.md`](./cli-startup-path.md), [`./validation-gates.md`](./validation-gates.md), [`./fuzz-runner.md`](./fuzz-runner.md), [`./tracing-playbook.md`](./tracing-playbook.md)
