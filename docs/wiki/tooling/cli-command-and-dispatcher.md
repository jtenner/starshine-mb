---
kind: workflow
status: supported
last_reviewed: 2026-10-28
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/README.md
  - https://github.com/WebAssembly/binaryen/blob/main/src/tools/wasm-opt.cpp
  - ../../../src/cli/cli.mbt
  - ../../../src/cli/cli_test.mbt
  - ../../../src/cli/glob.mbt
  - ../../../src/cmd/cmd.mbt
  - ../../../src/cmd_gc/main.mbt
  - ../../../node/internal/bulk-cli-host.js
  - ../../../src/cmd/cmd_wbtest.mbt
  - ../../../src/cmd/cmd_native_wbtest.mbt
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/memory_packing.mbt
  - ../../../src/passes/code_pushing.mbt
  - ../../../src/passes/optimize_instructions.mbt
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

Starshine's CLI is a local command layer inspired by Binaryen's `wasm-opt` shape: read one or more Wasm modules, combine command-line/config/environment options, run an ordered queue of passes or inspection steps, validate the result, and write wasm output. The high-level upstream orientation comes from Binaryen's README and `wasm-opt` tool source, but exact Starshine behavior is defined by the local packages:

- [`src/cli/cli.mbt`](../../../src/cli/cli.mbt) parses flags, input globs, formats, optimization level flags, tracing, trap mode, closed-world mode, and output targets.
- [`src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt) merges CLI/config/environment settings, resolves input files, lowers text input to binary modules, dispatches ordered pipeline steps, validates, encodes, records resolved trap mode, and writes outputs.
- [`src/passes/optimize.mbt`](../../../src/passes/optimize.mbt) owns the pass registry categories, preset expansion, hot/module pass routing, and final optimizer validation.

Do not infer behavior from Binaryen's full `wasm-opt --help` surface. Starshine intentionally implements a smaller but explicit command contract with its own diagnostics and debug steps. The 2026-06-04 source audit in research note 0707 rechecked the current Binaryen CLI orientation sources and local dispatcher code; it also records the current local `--stdin` gap described below.

## Wasm GC file adapter

On October 11, 2026, the Wasm GC command began using the same filesystem
callbacks as the linear-memory Wasm command. Before this change, its default
`CmdIO` had no file reader or writer, so a file optimization returned an error.
The shared test first failed on Wasm GC, then passed with an exact
`i32.const 40; i32.const 2; i32.add -> i32.const 42` output assertion.

The host must provide the imported `__moonbit_fs_unstable` functions and the
`__moonbit_time_unstable.now` clock. Wago therefore needs a MoonBit host plugin
for this CLI artifact. This host interface is separate from the optimizer.
Sources: [adapter and entry point](../../../src/cmd/cmd.mbt),
[file optimization test](../../../src/cmd/cmd_wbtest.mbt).

## Caught O4z and trusted compiler facts

When the conservative caught-O4z path returns its prepared input, the command
retains materialized trusted facts and removes consumed fact metadata. It
selects the already encoded prepared result when Trust preparation changed
the module. Ignore and Hints keep their existing raw-input selection. A
red-first command test checks all three policies and verifies the trusted
body instructions and absent consumed metadata. See [command selection](../../../src/cmd/cmd.mbt)
and [fact-policy regression](../../../src/cmd/o4z_caught_facts_regression_wbtest.mbt).

## Candidate byte proofs and terminal returns

The three provisional O4z candidate selectors retain the existing workers'
validation proofs for their exact encoded bytes. Labels are unique and the
candidate row is append-only. Stable size ties keep worker order. Shorter
unproved bytes still require validation; later cleanup products have no
inherited proof. This shares an existing proof within one portfolio run.
It does not cache custom encoder callbacks or certify bytes after replacement.

Terminal-return normalization allocates the function row only after it finds
a candidate. Prefix copying keeps imported-function offsets and row order.
Batch validation remains authoritative; an invalid fallthrough body restores
its original return. No-candidate inputs keep their original module and avoid
the row copy. [Regression tests](../../../src/cmd/o4z_portfolio_work_regression_wbtest.mbt)
assert exact output, ties, shorter invalid bytes, invalid fallthrough, input
ownership and copied rows. [Measurements](tracing-playbook.md#october-15-shared-batch-and-statement-work)
cover the combined build; they do not isolate each selector's time or memory.
The compatibility GC main now traps after a command error so Moonrun returns a
nonzero process status. Its prior main silently ignored that error.
The shared test first failed on Wasm GC, then passed with an exact
`i32.const 40; i32.const 2; i32.add -> i32.const 42` output assertion.

The compatibility entry point in `src/cmd` still uses
`__moonbit_fs_unstable` and `__moonbit_time_unstable.now`, as required by Moonrun.
For bulk transfers, build [`src/cmd_gc`](../../../src/cmd_gc/main.mbt). Its host
uses exported linear memory and three scalar functions under `__starshine_cli_v1`:
`request`, `response`, and `exit`, plus the clock. Read/write data crosses the host
boundary in four calls total, rather than one call for each byte.

[`tools/run-gc-cli.mjs`](../../../tools/run-gc-cli.mjs) runs it on Node or Bun.
[`tools/wago-host`](../../../tools/wago-host/README.md) supplies the same protocol
through Wago. Arguments exclude the program name. Requests/responses are
synchronous and instance-local; no guest re-entry or borrowed-memory retention is
allowed. Responses start with a status byte: 0 success, 1 UTF-8 error, 2 missing
environment value. Binary data follows the status. A write packet starts with a
four-byte little-endian UTF-8 path length, then path bytes and file bytes.

The runtime tests cover binary/Unicode data, truncated packets, missing input,
response capacity and nonzero command exits. The old filesystem imports retained
by unused default closures are bound to explicit traps in these runners; a full
O4z run uses only the bulk protocol. See the
[completed measurements](tracing-playbook.md#october-11-2026-bulk-host-and-wago-fixes).
Sources: [compatibility adapter](../../../src/cmd/cmd.mbt),
[bulk host](../../../node/internal/bulk-cli-host.js),
[host and command tests](../../../node/test/bulk-cli-host.test.mjs).

## Command Shape

```text
starshine [flags] [passes/debug-steps] <input...>
starshine spec [-g|--glob] <tests/spec/*.wast ...>
```

Common module-run flags:

| Surface | Contract | Owner |
| --- | --- | --- |
| Input paths | Positional arguments are input globs/paths; `--` stops option parsing; `STARSHINE_INPUT` can append more inputs after trivial help/version handling. Current `--stdin` is parsed and merged but does **not** create an input file or read bytes; without at least one glob/path the dispatcher returns `NoInputFiles`. | `src/cli/cli.mbt`, `src/cmd/cmd.mbt`, `docs/wiki/tooling/cli-command-and-dispatcher.md` |
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

`--optimize` and `--shrink` are both pass flags and optimize-level hints. Raw `-O...` / `--optimize-level` / `--shrink-level` values update the effective numeric levels. If no explicit pass flags are present, the dispatcher synthesizes one default pass name from levels: `shrink` wins when the shrink level is nonzero, otherwise `optimize` wins when the optimize level is nonzero. If any explicit pass/debug flag exists, the explicit queue is used as written. The Wasm O4z encoded-size portfolio is enabled only when the resolved queue is nonempty and consists exclusively of `optimize` and/or `shrink`; mixed explicit queues such as `shrink -> vacuum` run exactly their requested pass contract without portfolio candidates. O4z keeps the original input as a fallback candidate. It validates that input only if all smaller candidates fail validation; selecting a valid optimized result does not validate the larger input again.

The portfolio's final validity selection is stable and size ordered. Candidates are considered by ascending encoded byte length, ties retain generation order, and validation stops at the first valid candidate. This is equivalent to validating every candidate and then taking the stable minimum, while avoiding decode and whole-module validation of larger candidates once a smaller valid result is established. An invalid shortest candidate still falls through to the next-shortest candidate. Original-module hazard facts are captured before passes can mutate shared arrays; the original input is decoded again only when an original-dependent cleanup candidate needs a separate copy. Normal O4z defers final module validation to this encoded-candidate check, avoiding a second full-module validation of the optimized result. Caught try-table forced-input runs and `--debug-serial-passes` keep eager final validation; debug mode also retains the separate post-encode decode/validation safety path.

On native builds, the final-precompute, global-refining, and scalar-final cleanup candidates run in isolated child processes because they consume the same immutable optimized module and have no ordering dependency. The parent collects results in declaration order, so generation-order tie behavior is unchanged. A worker that produces no candidate records that outcome explicitly; an abnormal exit, fork failure, write failure, or unreadable result reruns that job serially instead of silently dropping coverage. WASM, wasm-gc, JavaScript, and LLVM targets retain the exact serial path. Successfully returned worker candidates carry an explicit validation proof because each worker decodes and validates the actual bytes after encoding; validating only the pre-encoding module is not sufficient for this proof boundary. Final selection may reuse that encoded-byte proof, but every shorter unproved candidate is still decoded and validated before it can win.

Both local presets currently expand to the same implemented mixed module/hot pass sequence in [`optimize_preset_passes(...)`](../../../src/passes/optimize.mbt) and [`shrink_preset_passes(...)`](../../../src/passes/optimize.mbt). The deeper Binaryen `-O` / no-DWARF comparison lives in [`../binaryen/no-dwarf-default-optimize-path.md`](../binaryen/no-dwarf-default-optimize-path.md) and the pass namespace map lives in [`../ir2/registry-map.md`](../ir2/registry-map.md).

### Optimizer machine reports

The native command owns three mutually exclusive JSON report flags:

- `--emit-runtime-interface-json <input>` decodes exactly one module and writes `starshine.optimizer-runtime-interface.v1`, including typed imports/exports, resource limits, support classifications, feature facts, start presence, and deterministic hashes;
- `--emit-expanded-pass-queue-json [optimizer flags] <input>` writes `starshine.optimizer-expanded-pass-queue.v1` from the same module-aware scheduler expansion used by execution, retaining repeated pass slots; and
- `--emit-optimizer-thresholds-json [optimizer tuning flags]` writes `starshine.optimizer-threshold-registry.v1` from resolved `OptimizeOptions` without requiring an input.

Module reports stop after decode and do not optimize or emit Wasm output. Threshold reporting still runs normal CLI/config/environment option resolution. Multiple report flags or multiple inputs for a module report fail closed. The Bun semantic harness uses the runtime-interface report in production; `bun fuzz list-optimizer-thresholds` consumes the threshold report instead of duplicating defaults.

### Trap-mode flags are options, not passes

`--trap-mode <allow|never>`, `--traps-never-happen`, and `--traps-may-happen` are parsed as optimizer options, not scheduled pass names. [`src/cli/cli_test.mbt`](../../../src/cli/cli_test.mbt) locks both sides: mixed-case values are accepted, missing/invalid values are rejected, `--traps-never-happen --traps-may-happen` resolves by last flag wins, and trap-mode toggles are omitted from `resolve_pass_flags(...)` so a neighboring explicit pass such as `--flatten` remains the scheduled item.

Command/config/environment merge follows the general option precedence above: CLI, then environment, then config. Config accepts both `optimize.trapMode` / `optimize.trap-mode` style values and boolean `options.trapsNeverHappen` / `options.traps-never-happen` style values. The resolved boolean is stored in `OptimizeOptions`, written into `CmdRunSummary.traps_never_happen`, included in trace option lines, and preserved in post-encode repro hints when set.

Important current caveat: `--traps-never-happen` is not merely report vocabulary. Current local owner sources show pass-local consumers in `memory-packing`, `code-pushing`, and `optimize-instructions`; each still needs its own contract and tests before it is used as parity evidence. The flag is not a global validator setting or blanket permission to relax arbitrary trap-sensitive rewrites. The shared trap vocabulary and Binaryen-vs-Starshine split lives in [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md).

Some hot passes have trace-labeled conservative fallbacks for pathological module or function shapes. For example, `ssa-nomerge`, `simplify-locals`, `optimize-instructions`, `precompute`, and `code-pushing` can skip very large, structured, or branch-heavy shapes rather than risk an unsafe transform, abort, OOM, or non-terminating self-optimization run; these are no-op fallbacks, not silent pass-name acceptance.

### Ordered utility steps

Utility steps split the optimization queue into segments:

```text
starshine --dump before.wat --print-func 42 --vacuum --validate --dump after.wasm input.wasm
```

The dispatcher flushes pending optimizer passes before each utility step. That means dumps, prints, validation checkpoints, and `extract-functions` observe the module at exactly that point in the queue, not only before or after the whole run. The focused print-step source audit is research note 0711; it checked the current parser, dispatcher, help, and command tests behind the details below.

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

A no-op wasm input with at least one pass may reuse original input bytes when
every optimizer segment returns the same physical module object, encoding
cleanup has no work, debug-serial post-encode validation is off, and the input
format was wasm. The command records the identity result at each segment
boundary and accumulates it across utility-separated segments, before later
value movement can obscure it. A regression covers a changed first segment and
an unchanged final segment. A separately rebuilt but structurally equal module
takes the normal encoding path. This identity rule avoids a recursive
whole-module equality walk on deep valid input. Text inputs never reuse original
bytes because the output contract is binary wasm.

An October 15 survey runs every 28 pass spellings shown by the current command
help over the same valid NaN-bearing wasm input. Twenty-seven no-op pass results
preserve the exact 41 input bytes. `flatten` is the sole active transform and
emits a valid 47-byte result, so accumulated change state also blocks input-byte
reuse when a pass changes the module. This bounded survey does not replace
active fixtures for every transform family. Local evidence is under
`.tmp/report-optimization-20261014/noop-byte-reuse-current/`.

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
- If a pass starts or stops consuming `OptimizeOptions.traps_never_happen`, update the pass dossier, [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md), compare-pass classification guidance, command tests, and the relevant local owner/test citations together.
- Any new printable item kind needs coordinated changes to CLI help, `cmd_is_supported_print_kind(...)`, `cmd_resolve_pipeline_print_entry(...)`, the ordered stderr log test, this page, and whichever focused wiki page owns the selector's name source or index space.

## Optimizer correctness tooling boundary

The semantic campaign commands are routed as strict `bun fuzz` siblings rather than Starshine module flags:

```text
bun fuzz compare-pass ... --semantic-oracle node-v2
bun fuzz list-optimizer-thresholds [--seed=<value>]
bun fuzz prove-rewrites <contracts.json> [--solver z3] [--out-dir <dir>]
bun fuzz replay-optimizer <failure-dir|manifest.json>
bun fuzz promote-optimizer <failure-dir>
```

`list-optimizer-thresholds` emits `starshine.optimizer-threshold-registry.v1` from the current `InliningOptions::new` defaults and deterministic `N-1/N/N+1` groups. `prove-rewrites` reads declarative integer contracts, runs reduced-width exhaustive checking, invokes Z3 when available, and persists SMT-LIB plus versioned JSON results. These commands do not alter the Starshine module queue or locked preset order.

The integer proof model `wasm-integer-bitvectors-v2` checks consistent operand,
result and variable widths (1–64 bits), modulo arithmetic, masked shift counts,
and the first integer trap class in operand evaluation order. Only 32/64-bit
contracts use the `wasm-integer` domain; narrower checks are explicitly
`reduced-bitvector` evidence. Exhaustive checking admits at most 20 input bits,
reports checked assignments, and blocks empty domains. Functional preconditions
are supported only by exhaustive checking over immutable input values; SMT
deliberately rejects them until a declarative premise format exists. Memory,
FP, references, control, extensions and comparisons are outside this model.

`prove-rewrites` is a qualification gate: it writes reports before returning
nonzero for a counterexample or blocked proof. Empty batches reject. Solver
absence, timeout, error and unknown remain distinct blocked reasons; each solver
process has a deadline, successful status output must be exact, and models are
requested separately only after `sat`. Proof v2 records the semantic model,
SMT obligation hash and solver version, with declared-variable witnesses in
hexadecimal, binary or decimal form. The representative positive inputs are
[`scalar-rewrite-contracts.json`](../../../tests/optimizer/scalar-rewrite-contracts.json);
[`scalar-rewrite-counterexamples.json`](../../../tests/optimizer/scalar-rewrite-counterexamples.json)
must return nonzero while preserving witnesses. Rule-body hashes in the positive
fixture require requalification when the source changes. These are pure
expression contracts, not proofs of effectful producer sharing or rewrite
installation. The [actual Wasm boundary test](../../../scripts/lib/optimizer-integer-wasm-boundaries.test.ts)
independently executes the represented operations. See the
[WebAssembly numeric semantics](https://webassembly.github.io/spec/core/exec/numerics.html).

An earlier plan treated the runtime-interface, expanded pass-queue, and threshold reports as pending. The current report flags above supersede that plan. The semantic harness requests the runtime interface from Starshine.

## WasmGC runner argument prefix

MoonBit core `0.1.20261012` documents `@env.args()` as including the executable
prefix. The WasmGC main entry now removes that prefix, as the native and WASI
entries already do. Otherwise `moonrun` passes the program path to the module
parser as an extra input and the requested output is never written.

The [entry-point regression](../../../scripts/test/wasmgc-cli-args.ts) runs the
prebuilt WasmGC CLI with and without the runner's `--` separator. It requires
the requested constant-folding pass to run, validates both outputs, executes
them in V8, and checks byte identity. It failed before the one-line repair and
passes afterward. Run it after `moon build --target wasm-gc --release src/cmd`
with `bun scripts/test/wasmgc-cli-args.ts _build/wasm-gc/release/build/cmd/cmd.wasm`.

## Sources

- 2026-06-04 print-utility routing audit: research note 0711
- 2026-06-04 dispatcher/stdin source audit: research note 0707
- Upstream CLI orientation: <https://github.com/WebAssembly/binaryen/blob/main/README.md>, <https://github.com/WebAssembly/binaryen/blob/main/src/tools/wasm-opt.cpp>
- Parser/config/glob code: [`../../../src/cli/cli.mbt`](../../../src/cli/cli.mbt), [`../../../src/cli/glob.mbt`](../../../src/cli/glob.mbt), [`../../../src/cli/cli_test.mbt`](../../../src/cli/cli_test.mbt)
- Dispatcher/codegen/validation code: [`../../../src/cmd/cmd.mbt`](../../../src/cmd/cmd.mbt), [`../../../src/cmd/cmd_wbtest.mbt`](../../../src/cmd/cmd_wbtest.mbt), [`../../../src/cmd/cmd_native_wbtest.mbt`](../../../src/cmd/cmd_native_wbtest.mbt)
- Pass registry and presets: [`../../../src/passes/optimize.mbt`](../../../src/passes/optimize.mbt), [`../ir2/registry-map.md`](../ir2/registry-map.md), [`../binaryen/passes/index.md`](../binaryen/passes/index.md)
- Related workflows: [`./cli-startup-path.md`](./cli-startup-path.md), [`./validation-gates.md`](./validation-gates.md), [`./fuzz-runner.md`](./fuzz-runner.md), [`./tracing-playbook.md`](./tracing-playbook.md)

## R1-13 positional preprocessing boundary — 2026-10-28

Confirmed against unchanged master `3d1deec7cecf1caaf65b42799777ff52ef210245`.
The original finding and limits were read from
`6422a44b155026bdbadfac86289c20958fdc21d3:docs/wiki/tooling/2026-10-25-code-review-r1.md`.
Only its two R1-13 tests were copied unchanged from
`src/cmd/hunt_r1_tooling_boundaries_20261025_wbtest.mbt`; other findings are
outside this repair.

Before any product edit, the JS build succeeded with:

```sh
PATH=/data/home/.moon/bin:$PATH moon test src/cmd/hunt_r1_tooling_boundaries_20261025_wbtest.mbt --target js -j 1 --build-only
```

Bun executed the generated `cmd.whitebox_test.js` with selection
`{"package":"jtenner/starshine/cmd","file_and_index":[["hunt_r1_tooling_boundaries_20261025_wbtest.mbt",[{"start":0,"end":2}]]]}`.
Both structured results failed: the parser returned
`["--always-inline-max-function-size=7.wasm"]` instead of `["-aimfs=7.wasm"]`;
the extractor returned `["--"]` instead of
`["--", "--emit-optimizer-thresholds-json"]`. Direct runner exit zero did not
mean success. No Node executable was available; Bun supplied the JS runtime.

The expanded red checkpoint builds both touched test files with the same
command plus `src/cli/cli_test.mbt`. Structured results: CLI 56/57 pass,
command 0/4 pass. New cases cover all six aliases, all three report flags,
repeated separators, pre-boundary mode retention, mutual exclusion and the
real command adapter reading literal paths. Product sources remain unchanged
at this checkpoint. Sources: [parser tests](../../../src/cli/cli_test.mbt),
[command tests](../../../src/cmd/hunt_r1_tooling_boundaries_20261025_wbtest.mbt).

The repair moves short-alias expansion below the parser's positional-only
branch and gives report extraction its own positional-only state. Extraction
retains the separator and copies the complete suffix, including later `--`
tokens, without matching report flags. Pre-boundary aliases, repeated report
flags and conflicting-report rejection retain their original behavior.
Sources: [parser](../../../src/cli/cli.mbt),
[report extraction](../../../src/cmd/optimizer_reports.mbt).

This is an argument-processing correctness repair, with no optimizer/pass,
Wasm output, public API or report serialization change. Both scans remain
linear in argument count with the same output arrays. Required costs are one
Boolean state and at most two simple boundary checks per pre-boundary token
in report extraction; suffix tokens bypass three report-name matches and
six-alias expansion. No module-sized state or new I/O is added. This supports
a perf-neutral scope assessment, not a measured timing claim. No benchmarks,
fuzzing, Binaryen comparison, full test suite or native executable run are
part of this borrowed-machine validation.

Final validation (serialized Moon commands, one build worker):

```sh
PATH=/data/home/.moon/bin:$PATH moon test src/cli/cli_test.mbt src/cmd/hunt_r1_tooling_boundaries_20261025_wbtest.mbt --target js -j 1 --build-only
bun _build/js/debug/test/cli/cli.blackbox_test.js '{"package":"jtenner/starshine/cli","file_and_index":[["cli_test.mbt",[{"start":0,"end":57}]]]}'
bun _build/js/debug/test/cmd/cmd.whitebox_test.js '{"package":"jtenner/starshine/cmd","file_and_index":[["hunt_r1_tooling_boundaries_20261025_wbtest.mbt",[{"start":0,"end":4}]]]}'
PATH=/data/home/.moon/bin:$PATH moon build -j 1
```

Both build commands exited zero. A temporary compact Bun driver ran equivalent
per-index selections and required the expected structured-result count and
zero failure messages: CLI **57/57**, command **4/4**. The full default-target
build compiled the workspace, including the Wasm command entry points.
`moon fmt` succeeded; unrelated baseline formatting was restored. The attempted
`moon info -j 1` was rejected because this installed subcommand has no `-j`
option; no interface generation is claimed. Reviewed `.mbti` diff: empty;
public signatures are unchanged. The existing executable-package dependency
warning for `cmd_gc` remains. Generated `_build` outputs and temporary local
runner/log files are removed after validation; committed tests and this record
retain the evidence. Other R1 findings remain outside scope.
