# Binaryen wasm-opt CLI Contract Source Snapshot

- Source family: Binaryen official repository documentation and tool source.
- Capture date: 2026-05-19.
- Source URLs:
  - <https://github.com/WebAssembly/binaryen/blob/main/README.md>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/tools/wasm-opt.cpp>
- Reason for capture: Starshine's CLI intentionally exposes a wasm-opt-like queue of input files, options, passes, `-O`/`-Oz`-style preset controls, and ordered transformation/inspection steps, but its dispatcher and validation guarantees are local. This source snapshot anchors the upstream CLI model without treating Binaryen's full option surface as implemented locally.

## Source-backed takeaways

- Binaryen documents `wasm-opt` as the tool that loads WebAssembly and runs Binaryen IR passes. The README's current tool section frames `wasm-opt` as receiving `.wasm` or `.wat` input, options, passes, output/printing choices, and `--help`-discoverable pass names.
- Binaryen's optimization overview says the optimizer can be run through `wasm-opt`, that default optimization pipelines are set up by pass-runner helper functions, and that optimization/shrink levels, trap assumptions, inlining heuristics, fast-math, and similar settings are pass options exposed by `wasm-opt --help`.
- Binaryen's README examples show repeated/ordered pass queues, including a pattern that optimizes, runs an intrinsic-lowering pass, then optimizes again. This supports documenting Starshine's ordered pass queue and ordered debug steps (`--dump`, `--print-*`, `--validate`, `--extract-functions`) as a deliberate local analogue rather than as a single preset-only command.
- Binaryen's current `src/tools/wasm-opt.cpp` still identifies the tool as a WebAssembly optimizer that loads code, optionally runs passes, and writes output. The source includes the command-line, optimization-options, pass-runner, binary I/O, Stack IR, and validator headers, confirming that the CLI is a host-facing orchestration layer over Binaryen's parser/pass/validator stack rather than the pass implementations themselves.

## Starshine-specific boundary

- Starshine does **not** claim full `wasm-opt` option compatibility. Local accepted flags, config/environment precedence, pass categories, debug checkpoints, text lowering fallback, and post-encode validation behavior are owned by `src/cli/cli.mbt`, `src/cmd/cmd.mbt`, `src/passes/optimize.mbt`, and their tests.
- Use this manifest only for the high-level upstream shape: input + options + ordered passes + print/output behavior. Use local source files for exact Starshine behavior.
