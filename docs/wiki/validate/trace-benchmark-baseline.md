---
kind: comparison
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/validation/2026-05-20-validation-trace-benchmark-source-refresh.md
  - ../raw/research/0010-2026-03-18-validate-trace-baseline.md
  - ../../../src/validate_trace/main.mbt
  - ../../../src/validate_trace/main_wbtest.mbt
  - ../../../src/validate/validate.mbt
  - ../../../scripts/lib/validate-task.ts
  - ../../../scripts/test/task-family-commands.ts
related:
  - ../tooling/validation-gates.md
  - ../tooling/tracing-playbook.md
  - ./module-validation-phases.md
  - ./ref-func-declarations.md
  - ./diagnostics-and-invalid-repro.md
  - ./fuzz-hardening.md
---

# Validation Trace Benchmark Baseline

## Overview

The validation trace benchmark is Starshine's stable way to watch **where validator time goes** across a small checked-in corpus set. It is not a portable wall-clock benchmark. The durable facts are the emitted `phase_totals`, `helper_totals`, corpus names, and hotspot shapes captured in [`../raw/research/0010-2026-03-18-validate-trace-baseline.md`](../raw/research/0010-2026-03-18-validate-trace-baseline.md), refreshed against current source ownership in [`../raw/validation/2026-05-20-validation-trace-benchmark-source-refresh.md`](../raw/validation/2026-05-20-validation-trace-benchmark-source-refresh.md).

Use this page when a validator change might move work between phases, add a new validation phase, change function-body scanning cost, or alter the `ref.func` declaration-source model. Use [`module-validation-phases.md`](module-validation-phases.md) for the canonical phase order and trace-line vocabulary, [`../tooling/validation-gates.md`](../tooling/validation-gates.md) for command syntax, and [`../tooling/tracing-playbook.md`](../tooling/tracing-playbook.md) for the shared tracing contract.

## Command Shape And Wrapper Flow

The public command is:

```sh
bun validate trace-benchmark [--repeat n] [--corpus name]... [--target target] [--list-corpora]
```

Current wrapper flow:

1. [`scripts/lib/validate-task.ts`](../../../scripts/lib/validate-task.ts) parses the Bun command, defaults `--target` to `wasm-gc`, applies Starshine's local target whitelist, and forwards to Moon.
2. The forwarded command is `moon run --target <target> src/validate_trace -- ...`.
3. [`src/validate_trace/main.mbt`](../../../src/validate_trace/main.mbt) builds each requested corpus directly as an `@lib.Module`, runs `validate_module_with_trace(..., trace_all_funcs=true)`, and prints one block per corpus.
4. [`src/validate_trace/main_wbtest.mbt`](../../../src/validate_trace/main_wbtest.mbt) pins the fixed corpus roster, summary-line capture contract, unknown-corpus rejection, repeated `--corpus` parsing, and `--list-corpora` behavior.
5. [`scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts) pins the Bun-to-Moon command forwarding shape, including repeated corpus forwarding and nondefault target forwarding.

The official MoonBit command source remains the upstream `moon run` manual, but the allowed target set for this repo's Bun wrapper is local policy. Do not infer that upstream `--target all` is accepted by `bun validate trace-benchmark`; that local distinction is tracked in [`../tooling/validation-gates.md`](../tooling/validation-gates.md).

## Output Contract

Each corpus block has this shape:

```text
corpus=<name> repeats=<n> elapsed_ms=<host-local total>
phase_totals <phase>_ms=<n> <phase>_calls=<n> ...
helper_totals body_ms=<n> body_calls=<n>
hotspots f<ordinal>:body=<us>:locals=<n>:top=<n> ...
```

Interpretation rules:

- `elapsed_ms` is useful operator context, but not a durable regression signal by itself.
- `phase_totals` is the main phase-level signal. Phase names come from [`validate_phase_totals_line()`](../../../src/validate/validate.mbt) and currently include `typesec`, `importsec`, `funcsec`, `tablesec`, `memsec`, `tagsec`, `globalsec`, `elemsec`, `datasec`, `datacnt`, `datacnt_requirement`, `startsec`, `exportsec`, `ref_func_declarations`, `codesec`, and `namesec` when those phases run.
- `helper_totals body_*` is the current function-body helper aggregate. It answers whether cost moved into or out of body typechecking.
- `hotspots` keeps the largest body-time samples, with function ordinal, body microseconds, local count, and top-level instruction count. Treat it as shape evidence, not an exact cross-machine duration.
- Missing `phase_totals` or `helper_totals` is a harness failure; [`run_validate_trace_benchmark(...)`](../../../src/validate_trace/main.mbt) rejects it.

## Corpus Map

| Corpus | Shape | Primary pressure point | Maintenance use |
| --- | --- | --- | --- |
| `deep-control` | One defined function with a 24-level resultful nested block chain and one parameter. | Deep expression/body validation and code-section timing. | Good first check for stack/label/control-flow validator changes. |
| `wide-locals` | One function with `384` `i32` locals, `384` local sets, and `384` local gets plus drops. | Local-index environment and large straight-line body scans. | Use when changing locals, variable instructions, body stack discipline, or local-index diagnostics. |
| `large-codesec` | `160` tiny defined functions sharing one type. | Section traversal and many-body overhead rather than one hot body. | Use when changing `FuncSec` / `CodeSec` matching, defined-function iteration, or per-body setup. |
| `ref-func-heavy` | `48` functions, function-reference globals, exports, declarative and passive element segments, table initializer, and many body `ref.func` uses. | `ref_func_declarations`, table/element/global declaration-source scanning, and body scanning. | Use when changing [`ref.func` declaration rules](ref-func-declarations.md), element payloads, exports, table initializers, or function-index remaps. |

## Baseline Snapshot

The committed March baseline was recorded with:

```sh
bun validate trace-benchmark --repeat 1
```

Default target: `wasm-gc`.

Keep the exact emitted blocks in the archived source note instead of duplicating every line here: [`../raw/research/0010-2026-03-18-validate-trace-baseline.md`](../raw/research/0010-2026-03-18-validate-trace-baseline.md). That note remains the baseline snapshot for later validator performance work.

Current high-level signals from that snapshot:

- `deep-control`: dominated by code-section and body validation work, plus a visible `datacnt_requirement` check on one deep function.
- `wide-locals`: low wall time but explicit local-width pressure, with `384` locals and `768` top-level instructions in the hotspot function.
- `large-codesec`: many tiny bodies stress section traversal more than per-body validation cost; the helper total records `160` body calls.
- `ref-func-heavy`: table-section work dominates in the archived run, with smaller supporting costs in code and data processing; interpret any future `ref_func_declarations` movement through [`ref-func-declarations.md`](ref-func-declarations.md).

## When To Refresh The Baseline

Refresh the archived baseline, this page, and [`module-validation-phases.md`](module-validation-phases.md) together when any of these change:

1. A validator phase is renamed, split, merged, added, or deleted.
2. `phase_totals`, `helper_totals`, or `hotspots` line format changes.
3. The fixed corpus set or corpus construction changes.
4. Function-body validation timing moves to a different helper bucket.
5. The `ref.func` declaration-source model changes in a way that affects `ref-func-heavy`.
6. Command forwarding changes in `bun validate trace-benchmark`, including default target or target whitelist behavior.

Do **not** refresh the baseline only because one machine's `elapsed_ms` changed. If a run is slower but phase totals and hotspot shape are stable, report it as local environment noise unless repeated evidence identifies a specific phase movement.

## Practical Regression Triage

When a trace run changes:

1. Compare corpus identity first. Make sure the same `--target`, `--repeat`, and `--corpus` set were used.
2. Compare `phase_totals` calls. A call-count change usually means phase structure or corpus shape changed, not just performance.
3. Compare phase milliseconds within one corpus. Ask which validation rule owns the moved phase, then use [`module-validation-phases.md`](module-validation-phases.md) to locate the code.
4. Compare `helper_totals body_calls`. If calls changed, inspect defined-function count or body traversal. If calls are stable but `body_ms` moved, inspect typechecking and body-size changes.
5. Compare hotspots. A different top function ordinal can reveal a corpus-construction change or a new per-function validator path.
6. Only after phase/helper/hotspot evidence is understood, discuss `elapsed_ms`.

## Sources

- Source refresh: [`../raw/validation/2026-05-20-validation-trace-benchmark-source-refresh.md`](../raw/validation/2026-05-20-validation-trace-benchmark-source-refresh.md)
- Archived benchmark snapshot: [`../raw/research/0010-2026-03-18-validate-trace-baseline.md`](../raw/research/0010-2026-03-18-validate-trace-baseline.md)
- Trace benchmark entrypoint and tests: [`../../../src/validate_trace/main.mbt`](../../../src/validate_trace/main.mbt), [`../../../src/validate_trace/main_wbtest.mbt`](../../../src/validate_trace/main_wbtest.mbt)
- Validator trace implementation: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt)
- Bun wrapper and command tests: [`../../../scripts/lib/validate-task.ts`](../../../scripts/lib/validate-task.ts), [`../../../scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts)
- Related wiki contracts: [`../tooling/validation-gates.md`](../tooling/validation-gates.md), [`../tooling/tracing-playbook.md`](../tooling/tracing-playbook.md), [`module-validation-phases.md`](module-validation-phases.md), [`ref-func-declarations.md`](ref-func-declarations.md), [`diagnostics-and-invalid-repro.md`](diagnostics-and-invalid-repro.md), [`fuzz-hardening.md`](fuzz-hardening.md)
