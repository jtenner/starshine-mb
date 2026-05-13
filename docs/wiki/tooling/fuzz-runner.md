---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../raw/research/0003-2026-03-12-fuzz-migration.md
  - ../../../src/fuzz/main.mbt
  - ../../../src/fuzz/main_wbtest.mbt
  - ../../../src/fuzz/invalid_repro.mbt
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../scripts/test/task-family-commands.ts
related:
  - ./validation-gates.md
  - ../validate/fuzz-hardening.md
  - ../fuzzing/generator-coverage-ledger.md
  - ./tracing-playbook.md
  - ../../../AGENTS.md
---

# Fuzz Runner Workflow

## Overview

Starshine has two related fuzz entry surfaces:

1. [`moon run src/fuzz -- ...`](../../../src/fuzz/main.mbt), the MoonBit-owned suite runner and artifact emitter.
2. [`bun fuzz run ...`](../../../scripts/lib/fuzz-task.ts), the task wrapper that forwards the supported MoonBit runner surface with target and Moon executable options.

Use these for broad randomized exploration, artifact emission, and validator-rejection repro capture. Keep deterministic reductions, helper invariants, and focused regressions in normal package tests; heavy randomized loops should not move back into `moon test`. For the higher-level validation gate that calls this runner after `moon info`, `moon fmt`, `moon check`, and `moon test`, see [`validation-gates.md`](./validation-gates.md).

The current runner is intentionally small at the command layer and broad at the suite layer: every run is identified by a suite, profile, seed, and optional output mode, and special artifact commands are explicit top-level commands rather than hidden suite names.

## Runnable Suites And Profiles

The live suite inventory is owned by [`fuzz_active_suite_names()`](../../../src/fuzz/main.mbt) and locked by [`src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt):

| Suite | Purpose |
| --- | --- |
| `wast-roundtrip` | WAST parse/lower/roundtrip coverage. |
| `wat-roundtrip` | WAT parse/print stability coverage. |
| `validate-valid` | Valid-module generation plus direct validator checks and profile-dependent WAT companion checks. |
| `validate-invalid-ast` | AST-level invalid mutation coverage. |
| `validate-invalid-binary` | Byte-level invalid or validator-rejected binary coverage. |
| `validate-invalid-text` | Inline malformed/invalid/unlinkable text coverage. |
| `validate-invalid-spec-seed` | Curated `tests/spec` assertion replay coverage. |
| `binary-roundtrip` | Binary decode/encode stability coverage. |
| `cmd-harness` | Command-pipeline harness coverage. |

`all` is the default suite and runs every active suite in inventory order with the same profile and seed. There are currently **no reserved suite ids**; `--list-suites` still prints `active\t<name>` lines so a future reserved lane can be represented without changing the output format.

Profiles are `smoke`, `ci`, and `stress`. Each suite owns its own attempt counts and strategy floors for those profile names, so an unknown profile error should come from the selected suite rather than from a preflight registry that might hide suite-specific diagnostics.

## Seed, Output, And Run Result Contract

The plain run form accepts positional arguments or flags:

```text
moon run src/fuzz -- [suite] [profile] [seed]
moon run src/fuzz -- --seed <int64> --output text|jsonl
bun fuzz run --suite <name> --profile <name> --seed <int64> --jsonl
```

Important invariants:

- Missing suite/profile defaults to `all smoke`.
- Missing seed uses a time-derived signed `Int64` seed; logged output always includes the resolved signed seed.
- Seeds accept decimal or `0x...` forms; `--seed` and positional seed are mutually exclusive.
- Text output lines use `suite=<name> profile=<profile> seed=<seed> attempts=<n> pass=true elapsed_ms=<ms>`.
- JSONL output emits the same facts as one JSON object per suite result.

Preserve this result contract when adding suites so CI logs, repro reports, and long-running compare tasks can remain machine-readable.

## Artifact Commands

### Coverage-forced valid batches

`--emit-gen-valid-batch` emits deterministic validated `.wasm` files named `gen-valid-000001.wasm`, `gen-valid-000002.wasm`, and so on:

```text
moon run src/fuzz -- --emit-gen-valid-batch --count <n> --seed <uint64> --out-dir <dir>
bun fuzz run --emit-gen-valid-batch --count <n> --seed <uint64> --out-dir <dir>
```

The batch config is [`GenValidConfig::binaryen_oracle_coverage_forced_default()`](../../../src/fuzz/main.mbt), not the default natural generator. This makes the emitted corpus useful for Binaryen-oracle pass comparison while keeping imports, memories, tables, globals, tags, elems, datas, SIMD, ref-types, and similar features constrained to the current portable comparison subset.

### Invalid repro bundles

The MoonBit runner also exposes the shared invalid-repro builder:

```text
moon run src/fuzz -- --emit-invalid-repro \
  --suite <suite|ast|binary|text|spec-seed> \
  --strategy <stable-id> \
  --seed <uint64> \
  --attempt <n> \
  --out-dir <dir> \
  [--profile <name>]
```

It routes through [`build_invalid_fuzz_failure_report_by_suite_and_stable_id(...)`](../../../src/fuzz/invalid_repro.mbt), so full suite names and short source-kind aliases share the same metadata and artifact layout described on [`validate/fuzz-hardening.md`](../validate/fuzz-hardening.md). As of this review, [`bun fuzz run`](../../../scripts/lib/fuzz-task.ts) forwards `--emit-gen-valid-batch` but does **not** expose `--emit-invalid-repro`; call the MoonBit runner directly for persisted invalid repro bundles.

## Bun Wrapper And Compare-Pass Split

[`bun fuzz run`](../../../scripts/lib/fuzz-task.ts) is a strict wrapper around `moon run src/fuzz` for the ordinary runner commands. It adds:

- `--target <target>` / `--target=<target>` for Moon target selection, defaulting to `wasm-gc`.
- `--moon <path>` / `--moon=<path>` for overriding the Moon executable.
- `--suite`, `--profile`, `--seed`, `--output`, `--jsonl`, `--help`, `--list-suites`, `--list-profiles`, and `--emit-gen-valid-batch` forwarding.

`bun fuzz compare-pass ...` is a sibling subcommand, not a `src/fuzz` suite. It delegates to [`scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts), which may call `src/fuzz --emit-gen-valid-batch` internally for generated inputs before invoking Starshine and Binaryen pass comparisons. Use it for optimizer parity signoff, not for validator-suite coverage.

## Maintenance Guidance

- Add or extend a named `src/fuzz` suite for new broad randomized work; keep `moon test` deterministic and fast.
- Update [`src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt) whenever the suite inventory, command parser, result format, or artifact command contract changes.
- Keep [`scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts) aligned with wrapper forwarding behavior for `bun fuzz run` and `bun fuzz compare-pass`.
- If a suite emits persisted failures, include enough metadata to replay from `suite`, `profile`, `seed`, and attempt/strategy identity.
- Serialize Moon commands in automation because `_build/.moon-lock` is shared.
- When widening validator invalid lanes, update [`validate/fuzz-hardening.md`](../validate/fuzz-hardening.md) for strategy/repro semantics and this page only for runner command shape.

## Sources

- Historical extraction note: [`../raw/research/0003-2026-03-12-fuzz-migration.md`](../raw/research/0003-2026-03-12-fuzz-migration.md)
- MoonBit runner and command tests: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt), [`../../../src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt)
- Invalid repro dispatcher: [`../../../src/fuzz/invalid_repro.mbt`](../../../src/fuzz/invalid_repro.mbt)
- Bun wrapper and pass compare task: [`../../../scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts), [`../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts)
- Wrapper command tests: [`../../../scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts)
