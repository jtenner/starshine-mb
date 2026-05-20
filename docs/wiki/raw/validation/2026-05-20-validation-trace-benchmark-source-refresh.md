---
kind: raw-source-manifest
status: supported
last_reviewed: 2026-05-20
sources:
  - https://docs.moonbitlang.com/en/latest/toolchain/moon/commands.html
  - ../../../../src/validate_trace/main.mbt
  - ../../../../src/validate_trace/main_wbtest.mbt
  - ../../../../src/validate/validate.mbt
  - ../../../../scripts/lib/validate-task.ts
  - ../../../../scripts/test/task-family-commands.ts
  - ../research/0010-2026-03-18-validate-trace-baseline.md
related:
  - ../../validate/trace-benchmark-baseline.md
  - ../../validate/module-validation-phases.md
  - ../../tooling/validation-gates.md
  - ../../tooling/tracing-playbook.md
---

# Validation Trace Benchmark Source Refresh - 2026-05-20

This manifest refreshes the source map behind the durable validation trace benchmark page. It does **not** replace the March baseline numbers in [`../research/0010-2026-03-18-validate-trace-baseline.md`](../research/0010-2026-03-18-validate-trace-baseline.md); it records how to interpret and maintain them against current repository code.

## External source checked

- MoonBit command-line help, latest docs, `moon run`: <https://docs.moonbitlang.com/en/latest/toolchain/moon/commands.html>
  - Checked that `moon run [OPTIONS] <PACKAGE_OR_MBT_FILE> [ARGS]...` remains the official command shape and that `--target <TARGET>` includes `wasm-gc`, `native`, `wasm`, `js`, `llvm`, and upstream `all`.
  - Starshine's local `bun validate trace-benchmark` wrapper still deliberately narrows target acceptance through its own target whitelist, as documented in [`../../tooling/validation-gates.md`](../../tooling/validation-gates.md).

## Starshine sources checked

- [`src/validate_trace/main.mbt`](../../../../src/validate_trace/main.mbt)
  - Defines the four fixed corpora: `deep-control`, `wide-locals`, `large-codesec`, and `ref-func-heavy`.
  - Builds those corpora directly as `@lib.Module` values, runs `@validate.validate_module_with_trace(..., trace_all_funcs=true)`, extracts the last `phase_totals`, `helper_totals`, and optional `hotspots` lines, and prints one stable block per corpus.
  - CLI parsing accepts `--repeat <n>`, `--repeat=<n>`, repeated `--corpus <name>`, `--list-corpora`, and help. Unknown corpora fail before running validation.
- [`src/validate_trace/main_wbtest.mbt`](../../../../src/validate_trace/main_wbtest.mbt)
  - Pins the corpus-name roster, summary-line capture contract, unknown-corpus failure, repeated-corpus CLI parsing, and list-corpora command.
- [`src/validate/validate.mbt`](../../../../src/validate/validate.mbt)
  - Owns phase timing names and totals (`typesec`, `importsec`, `funcsec`, `tablesec`, `memsec`, `tagsec`, `globalsec`, `elemsec`, `datasec`, `datacnt`, `datacnt_requirement`, `startsec`, `exportsec`, `ref_func_declarations`, `codesec`, `namesec`).
  - Emits `helper_totals body_ms=... body_calls=...` from function-body validation timing.
  - Keeps up to eight function-body hotspot records, sorted by body time, with `f<ordinal>:body=<us>:locals=<n>:top=<n>` payloads.
- [`scripts/lib/validate-task.ts`](../../../../scripts/lib/validate-task.ts)
  - Implements the public wrapper: `bun validate trace-benchmark [--repeat n] [--corpus name] [--target target] [--moon path] [--list-corpora]`.
  - Forwards to `moon run --target <target> src/validate_trace -- ...`, defaulting to `wasm-gc` and applying Starshine's local target whitelist.
- [`scripts/test/task-family-commands.ts`](../../../../scripts/test/task-family-commands.ts)
  - Pins wrapper command construction, including repeated `--corpus` forwarding and nondefault target forwarding.
- [`docs/wiki/raw/research/0010-2026-03-18-validate-trace-baseline.md`](../research/0010-2026-03-18-validate-trace-baseline.md)
  - Stores the March committed baseline blocks. Use them as a shape and phase-total baseline, not as machine-independent wall-clock truth.

## Durable conclusions

1. The benchmark is a **validator trace contract**, not a general system benchmark. Long-lived interpretation should focus on emitted phase totals, helper totals, corpus identity, and hotspot shape.
2. `elapsed_ms` is operator context only. It can move because of host load, MoonBit backend, runtime changes, and measurement resolution.
3. Corpus names are public maintenance vocabulary because both the Moon package white-box tests and Bun wrapper tests pin them.
4. Phase names are public maintenance vocabulary because the trace page, module-validation phase map, and baseline parser all depend on them. Rename, merge, or split phases only with synchronized docs and tests.
5. The current corpus set intentionally covers different validator pressure points: deep nested control, many locals/instructions, many code bodies, and many `ref.func` declaration sources.
6. No new WebAssembly semantic source was needed for this refresh. The update is about Starshine's benchmark harness and command path; official WebAssembly validation semantics remain covered by the focused validator and WAST source manifests.
