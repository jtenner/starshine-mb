---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/research/0003-2026-03-12-fuzz-migration.md
  - ../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md
  - ../../../src/fuzz/main.mbt
  - ../../../src/fuzz/main_wbtest.mbt
  - ../../../src/fuzz/invalid_repro.mbt
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../scripts/test/task-family-commands.ts
related:
  - ./validation-gates.md
  - ./pass-fuzz-compare.md
  - ../validate/fuzz-hardening.md
  - ../validate/diagnostics-and-invalid-repro.md
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
| `wast-validate-roundtrip` | WAST AST print/parse/lower/validate reporting, including lower and validation failure counters. |
| `gen-valid-wat-validate-roundtrip` | GenValid lib-module generation through the first-class WAT text printer, WAT parse, WAST-to-lib lowering, and validation counters. |
| `validate-valid` | Valid-module generation plus direct validator checks and profile-dependent WAT companion checks. |
| `validate-invalid-ast` | AST-level invalid mutation coverage. |
| `validate-invalid-binary` | Byte-level invalid or validator-rejected binary coverage. |
| `validate-invalid-text` | Inline malformed/invalid/unlinkable text coverage. |
| `validate-invalid-spec-seed` | Curated `tests/spec` assertion replay coverage in smoke; dynamic committed-spec static-assertion sampling in CI/stress. |
| `binary-roundtrip` | Binary decode/encode stability coverage. |
| `cmd-harness` | Command-pipeline harness coverage. |

`all` is the default suite and runs every active suite in inventory order with the same profile and seed. There are currently **no reserved suite ids**; `--list-suites` still prints `active\t<name>` lines so a future reserved lane can be represented without changing the output format.

Runner suite profiles are still `smoke`, `ci`, and `stress`. Each suite owns its own attempt counts and strategy floors for those profile names, so an unknown profile error should come from the selected suite rather than from a preflight registry that might hide suite-specific diagnostics. These suite-profile names are separate from the lower-level GenValid generator-profile taxonomy in [`gen_valid.mbt`](../../../src/validate/gen_valid.mbt), which now names reusable generator configs such as `natural-small`, `coverage-forced-all-features`, `binaryen-oracle-portable`, `mutation-seed-rich`, `pass-fuzz-stress`, and focused heavy profiles for imports, GC, SIMD, memory, and control.

The invalid AST and invalid binary suites additionally accept a `+seeds=<set>` / `+seed-profiles=<set>` modifier after the base profile. The default is still `rich`, preserving existing smoke/CI/stress behavior. `mixed` / `all` expands to `minimal,repro,small-natural,small-coverage-forced,natural,coverage-forced,rich`, and callers can pass an explicit comma-separated subset such as `smoke+seed-profiles=minimal,natural,rich`; the suite multiplies the base attempt count by the selected seed-profile count and reports per-profile attempts in JSON details.

The `cmd-harness` suite additionally accepts `+`-separated modifiers after the base suite profile so optimizer-pipeline fuzzing can choose a generator profile and a stable pass profile without inventing new top-level suite names. Supported modifiers are `gen=<gen-valid-profile>` / `generator=<gen-valid-profile>`, `passes=none|cleanup|optimize-core|each-pass|common-clusters|default-pipeline`, `idempotence` / `opt-idempotence` for an optimize-rerun check, and `codec-idempotence` / `encode-decode-idempotence` for a decode/encode stability check. `passes=each-pass` expands the current executable hot/module pass registry while excluding presets, boundary-only/removed entries, and no-inline policy marker passes that require patterns; `passes=common-clusters` runs an affordable cleanup/control-flow hot-pass cluster without the heavier optimize-instructions, DAE, inlining, local module-pass, or late-tail module-pass profiles; `passes=default-pipeline` expands the current `optimize` preset into explicit pass names so failure metadata and minimization see the real scheduled sequence. For example:

```text
moon run src/fuzz -- cmd-harness smoke+gen=natural-small+passes=cleanup+codec-idempotence --seed 0x5eed
```

The lower-level [`run_cmd_fuzz_harness(...)`](../../../src/cmd/fuzz_harness.mbt) API exposes the same generator-profile, pass-profile, and idempotence controls directly and includes those labels in persisted failure metadata. Generated-case failures also persist the resolved GenValid config label, the generator attempt count for that module, and the generated module's feature facts so repro triage can see which profile/config surface produced the failing bytes. Optimizer failures also record a minimized pass list: the minimizer now tries chunk removal before the final single-pass cleanup so dependent pass-prefix/suffix noise can be stripped even when no individual pass is removable on its own.

## Seed, Output, And Run Result Contract

The plain run form accepts positional arguments or flags:

```text
moon run src/fuzz -- [suite] [profile] [seed]
moon run src/fuzz -- --seed <int64> --output text|jsonl
moon run src/fuzz -- cmd-harness smoke --seed 0x10 --seed-count 64 --shard-index 0 --shard-count 4 --report-json .tmp/fuzz-report.json
bun fuzz run --suite <name> --profile <name> --seed <int64> --jsonl
```

Important invariants:

- Missing suite/profile defaults to `all smoke`.
- Missing seed uses a time-derived signed `Int64` seed; logged output always includes the resolved signed seed.
- Seeds accept decimal or `0x...` forms; `--seed` and positional seed are mutually exclusive.
- `--seed-count <n>` performs a deterministic seed sweep from the resolved base seed through `base + n - 1` using wrapping `UInt64` arithmetic mapped back to signed `Int64` output.
- `--shard-index <i> --shard-count <n>` runs only seed ordinals where `ordinal % shard_count == shard_index`; defaults are `0/1`, and `shard_index` must be less than `shard_count`.
- Text output lines keep the single-seed contract `suite=<name> profile=<profile> seed=<seed> attempts=<n> pass=true elapsed_ms=<ms>`. Sweep/sharded runs append `seed_index`, `seed_count`, `shard_index`, and `shard_count` fields.
- JSONL output emits one JSON object per suite result, including sweep/shard metadata. Suites with first-class ledgers also include a `details` object: `validate-valid` reports validated count, generator config label, feature counters, and configured feature floors; `wat-roundtrip` reports successful/stable roundtrips plus module print, parse, roundtrip-print, unstable-text, script-render, and no-module-command counts; `wast-validate-roundtrip` reports WAST AST print, parse, lower, and validation counts plus failure categories; `gen-valid-wat-validate-roundtrip` reports GenValid generated, printed, parsed, lowered, validated, and failure-category counts for the lib-module-to-WAT lane; invalid AST/binary/text/spec-seed suites report per-strategy or per-seed counters with stable ids and expected-rejection counts; invalid AST/binary details also include selected seed profiles and per-profile attempt counts. `validate-invalid-spec-seed` also includes a `dynamic` details object with scanned/attempted/matched counts and matched feature-family names for CI/stress dynamic spec sampling.
- `--report-json <path>` writes a single summary object with `suite`, `profile`, `base_seed`, sweep/shard configuration, aggregate `run_count`, and the per-suite `runs` array. The same `details` objects used by JSONL are embedded per run. The path must be explicit; the runner does not create a standard output directory for ordinary fuzz runs yet.

Preserve this result contract when adding suites so CI logs, repro reports, and long-running compare tasks can remain machine-readable.

## Artifact Commands

### Coverage-forced valid batches

`--emit-gen-valid-batch` emits deterministic validated `.wasm` files named `gen-valid-000001.wasm`, `gen-valid-000002.wasm`, and so on:

```text
moon run src/fuzz -- --emit-gen-valid-batch --count <n> --seed <uint64> --out-dir <dir> \
  [--gen-valid-profile <profile>] [--require-feature <label[:min]>] \
  [--exclude-feature <label>] [--max-attempts <n>] [--manifest <path>]
bun fuzz run --emit-gen-valid-batch --count <n> --seed <uint64> --out-dir <dir> \
  [--gen-valid-profile <profile>] [--require-feature <label[:min]>] \
  [--exclude-feature <label>] [--max-attempts <n>] [--manifest <path>]
```

The default batch config is [`GenValidConfig::binaryen_oracle_coverage_forced_default()`](../../../src/fuzz/main.mbt), now also named by the `binaryen-oracle-portable` / `pass-fuzz-stress` GenValid profiles, not the default natural generator. This makes the emitted corpus useful for Binaryen-oracle pass comparison while keeping imports, memories, tables, globals, tags, elems, datas, SIMD, ref-types, and similar features constrained to the current portable comparison subset. A sibling `binaryen-oracle-relaxed-simd` profile keeps those nonportable surfaces disabled but turns `v128`, relaxed SIMD, and typed body generation on for tool-compatible relaxed-SIMD batch emission. The batch writer creates `--out-dir` before writing artifacts.

`--gen-valid-profile` selects any named GenValid profile, `--require-feature` keeps only selected modules that advance the requested feature floor, `--exclude-feature` skips candidates that contain the named feature key, and `--max-attempts` bounds the candidate stream. `--manifest <path>` is opt-in and writes a JSON manifest with the generator name, seed, requested profile, required/excluded feature filters, aggregate feature stats, and one record per emitted `.wasm` file including file name, seed, index, config label, attempt count, validation status, and feature facts. Feature labels use the stable coverage-ledger strings accepted by [`validate_valid_feature_floor_by_label(...)`](../../../src/validate/validate.mbt), such as `v128` or `mems:2`.

Callers that need generation diagnostics can use [`gen_valid_module_result(...)`](../../../src/validate/gen_valid.mbt) instead of the compatibility `Module`-only wrapper. The result-bearing API reports the stable config label, retry attempt count, feature facts for successful modules, and the last validation message/candidate on failure. The fuzz package also exposes [`emit_gen_valid_batch_artifacts_with_manifest(...)`](../../../src/fuzz/main.mbt), which preserves the existing `.wasm` artifact names while returning an in-memory manifest with file name, seed, index, config label, attempts, validation status, and feature facts for each generated input. The compare-pass `gen-valid` path now asks the batch emitter to write `inputs/gen-valid/manifest.json` next to the saved inputs so downstream triage can inspect generated-input facts without regenerating the batch.

For local coverage-guided selection, [`emit_gen_valid_batch_artifacts_until_features(...)`](../../../src/fuzz/main.mbt) generates a bounded candidate stream from an explicit `GenValidConfig`, keeps only modules that contribute to required feature floors and do not hit excluded feature keys, and returns the selected artifacts, manifest entries, aggregate `GenValidFeatureStats`, floor failures, attempt count, and skipped-candidate count. Use [`validate_valid_feature_floor_by_label(...)`](../../../src/validate/validate.mbt) and [`validate_valid_feature_actual_count_by_label(...)`](../../../src/validate/validate.mbt) when a caller needs stable string labels instead of constructing ledger enum values directly.

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

It routes through [`build_invalid_fuzz_failure_report_by_suite_and_stable_id(...)`](../../../src/fuzz/invalid_repro.mbt), so full suite names and short source-kind aliases share the same metadata and artifact layout summarized on [`validate/fuzz-hardening.md`](../validate/fuzz-hardening.md) and specified in [`validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md). As of this review, [`bun fuzz run`](../../../scripts/lib/fuzz-task.ts) forwards `--emit-gen-valid-batch` but does **not** expose `--emit-invalid-repro`; call the MoonBit runner directly for persisted invalid repro bundles.

## Bun Wrapper And Compare-Pass Split

[`bun fuzz run`](../../../scripts/lib/fuzz-task.ts) is a strict wrapper around `moon run src/fuzz` for ordinary suite commands:

- `--target <target>` / `--target=<target>` (default `wasm-gc`).
- `--moon <path>` / `--moon=<path>`.
- `--suite`, `--profile`, `--seed`, `--seed-count`, `--shard-index`, `--shard-count`, `--report-json`, `--output`, `--jsonl`, `--help`, `--list-suites`, `--list-profiles`, and `--emit-gen-valid-batch` forwarding, including batch `--gen-valid-profile`, `--require-feature`, `--exclude-feature`, and `--max-attempts` options.

`bun fuzz compare-pass ...` is a sibling entrypoint, not a `src/fuzz` suite. It delegates to [`scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts), which may call `src/fuzz --emit-gen-valid-batch` internally for generated inputs before invoking Starshine, `wasm-tools`, and Binaryen.

Use compare-pass for optimizer parity signoff or failure-replay workflows, not broad fuzz-suite coverage. The detailed command, generator, normalization, failure-class, replay, and `--jobs` contract now lives in [`pass-fuzz-compare.md`](pass-fuzz-compare.md); keep this page focused on the ordinary `src/fuzz` runner and wrapper split.

## Maintenance Guidance

- Add or extend a named `src/fuzz` suite for new broad randomized work; keep `moon test` deterministic and fast.
- Update [`src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt) whenever the suite inventory, command parser, result format, or artifact command contract changes.
- Keep [`scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts) aligned with wrapper forwarding behavior for `bun fuzz run` and `bun fuzz compare-pass`.
- If a suite emits persisted failures, include enough metadata to replay from `suite`, `profile`, `seed`, and attempt/strategy identity.
- Serialize Moon commands in automation because `_build/.moon-lock` is shared.
- When widening validator invalid lanes, update [`validate/fuzz-hardening.md`](../validate/fuzz-hardening.md) for strategy/repro summary, [`validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md) for stage/family/artifact semantics, and this page only for runner command shape.

## Sources

- Historical extraction note: [`../raw/research/0003-2026-03-12-fuzz-migration.md`](../raw/research/0003-2026-03-12-fuzz-migration.md)
- MoonBit runner and command tests: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt), [`../../../src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt)
- Invalid repro dispatcher: [`../../../src/fuzz/invalid_repro.mbt`](../../../src/fuzz/invalid_repro.mbt)
- Bun wrapper and pass compare task: [`../../../scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts), [`../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts)
- Wrapper command tests: [`../../../scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts), [`../../../scripts/test/pass-fuzz-compare-command.ts`](../../../scripts/test/pass-fuzz-compare-command.ts)
