# CLI dispatcher stdin gap and source audit

- Date: 2026-06-04
- Target living page: [`docs/wiki/tooling/cli-command-and-dispatcher.md`](../../tooling/cli-command-and-dispatcher.md)
- Reason: the CLI dispatcher page had not been reviewed since 2026-05-19 and its broad `--stdin` wording could be read as working input support even though current local dispatcher code only preserves the parsed flag.

## Sources checked

Primary / upstream orientation:

- Binaryen README on `main`: <https://github.com/WebAssembly/binaryen/blob/main/README.md>
  - Current README still frames `wasm-opt` as the optimizer that receives WebAssembly input, accepts options/passes, can print/output results, and supports ordered examples such as `-O --intrinsic-lowering -O`.
- Binaryen `src/tools/wasm-opt.cpp` on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/tools/wasm-opt.cpp>
  - Current source still builds an `OptimizationOptions` object for `wasm-opt` with an example `wasm-opt input.wasm -O3 -o output.wasm`, and registers output/printing/fuzzing/pass-option CLI surfaces.

Local Starshine source:

- [`src/cli/cli.mbt`](../../../../src/cli/cli.mbt)
- [`src/cli/cli_test.mbt`](../../../../src/cli/cli_test.mbt)
- [`src/cmd/cmd.mbt`](../../../../src/cmd/cmd.mbt)
- [`src/cmd/cmd_wbtest.mbt`](../../../../src/cmd/cmd_wbtest.mbt)
- [`src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt)

## Findings

- The Binaryen upstream shape has not changed in a way that affects Starshine's local page: it remains a useful orientation source for `input + options + ordered pass queue + output/printing`, not an exact compatibility contract.
- Starshine's parser accepts `--stdin`, records `CliParseResult.read_stdin`, and requires `--format <wasm|wat|wast>` unless help/version exits first. The public config schema also carries `inputs.stdin`.
- Current Starshine command dispatch merges `read_stdin` by OR across config and CLI; the environment overlay currently contributes only its default `false`. The execution path resolves concrete `input_files` only from `input_globs` through `resolve_input_files_with_glob(...)`. No `CmdIO` stdin reader exists, and no synthetic `-` or `<stdin>` input is appended when `read_stdin` is true.
- Consequence: `starshine --stdin --format wat` with no file/glob reaches `CmdError::NoInputFiles`; `--stdin` plus a real file/glob processes the file/glob and does not read stdin. Treat this as a documented current local gap, not as a Binaryen compatibility fact.
- The rest of the page's main dispatcher model remains source-supported: config/env/CLI precedence, pass/utility-step queueing, preset synthesis from `-O`/`--shrink-level`, boundary-only/removed pass rejection, debug-serial post-encode validation, and spec subcommand handoff.

## Follow-up

If Starshine wants working stdin input, the implementation should add an explicit `CmdIO` byte-source (or a documented `read_file("-")` convention), tests proving `--stdin --format ...` creates exactly one input even with no globs, output naming rules for stdin, and help/config docs that distinguish file inputs from stdin inputs.
