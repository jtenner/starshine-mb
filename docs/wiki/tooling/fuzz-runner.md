---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../raw/fuzzing/2026-06-05-text-differential-adapter-source-refresh.md
  - ../raw/wasm/2026-06-04-wast-static-harness-current-refresh.md
  - ../raw/research/0003-2026-03-12-fuzz-migration.md
  - ../raw/binaryen/2026-05-20-pass-fuzz-compare-tool-sources.md
  - ../../../src/fuzz/main.mbt
  - ../../../src/fuzz/main_wbtest.mbt
  - ../../../src/fuzz/invalid_repro.mbt
  - ../../../scripts/lib/fuzz-task.ts
  - ../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../scripts/lib/fuzz-coverage-delta-task.ts
  - ../../../scripts/lib/fuzz-summary-counters.ts
  - ../../../scripts/lib/fuzz-summary-counters.test.ts
  - ../../../scripts/test/task-family-commands.ts
  - ../../../scripts/test/fuzz-coverage-delta.ts
related:
  - ./validation-gates.md
  - ./pass-fuzz-compare.md
  - ./external-validator-adapters.md
  - ../fuzzing/recipe-schema.md
  - ../fuzzing/text-differential-adapters.md
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
3. [`bun fuzz coverage-delta ...`](../../../scripts/lib/fuzz-coverage-delta-task.ts), the report-diff helper for comparing two persisted fuzz summary JSON files.

Use these for broad randomized exploration, artifact emission, and validator-rejection repro capture. Keep deterministic reductions, helper invariants, and focused regressions in normal package tests; heavy randomized loops should not move back into `moon test`. For the higher-level validation gate that calls this runner after `moon info`, `moon fmt`, `moon check`, and `moon test`, see [`validation-gates.md`](./validation-gates.md).

The current runner is intentionally small at the command layer and broad at the suite layer: every run is identified by a suite, profile, seed, and optional output mode, and special artifact commands are explicit top-level commands rather than hidden suite names. Repeatable saved run shapes use the focused recipe schema in [`../fuzzing/recipe-schema.md`](../fuzzing/recipe-schema.md); this page owns what those parsed suite/profile/seed choices do once executed.

## Runnable Suites And Profiles

The live suite inventory is owned by [`fuzz_active_suite_names()`](../../../src/fuzz/main.mbt) and locked by [`src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt):

| Suite | Purpose |
| --- | --- |
| `wast-roundtrip` | WAST parse/lower/roundtrip coverage. |
| `wat-roundtrip` | WAT parse/print stability coverage. |
| `wast-validate-roundtrip` | WAST AST print/parse/lower/validate reporting, including lower and validation failure counters. |
| `gen-valid-wat-validate-roundtrip` | GenValid lib-module generation through the first-class WAT text printer, WAT parse, WAST-to-lib lowering, and validation counters. |
| `valid-multi-module-linking` | Historical suite id for generated valid multi-module WAST provider/consumer scripts. Current code parses the script, validates inline modules independently, and then runs the static WAST harness; `link_*` counters mean static script pass/fail/skip rather than real provider/consumer import resolution. The shared multi-module classifier distinguishes duplicate script module ids, duplicate `register` aliases, unlinkable assertion scripts, and validation/static-harness failures. |
| `validate-valid` | Valid-module generation plus direct validator checks and profile-dependent WAT companion checks. |
| `validate-valid-metamorphic` | GenValid source modules plus semantics-preserving transforms, including custom-section stress variants with empty, binary, UTF-8-name, and larger opaque payloads that must survive binary roundtrip validation. |
| `validate-invalid-ast` | AST-level invalid mutation coverage. |
| `validate-invalid-binary` | Byte-level invalid or validator-rejected binary coverage. |
| `validate-invalid-text` | Inline malformed/invalid/unlinkable text coverage. |
| `validate-invalid-text-dynamic` | GenValid-WAT dynamic mutation coverage for malformed, validation-rejected, and valid-before-link/unlinkable text specimens, including per-strategy source feature facts. |
| `validate-invalid-spec-seed` | Curated `tests/spec` assertion replay coverage in smoke; dynamic committed-spec static-assertion sampling in CI/stress. |
| `binary-roundtrip` | Binary decode/encode stability coverage, including the ordinary arbitrary-value matrix, explicit GenValid full-module encode/decode/validate profiles, byte-fuzz corruption profiles over generated valid binary modules, and an explicit boundary corpus profile. |
| `cmd-harness` | Command-pipeline harness coverage. |

`all` is the default suite and runs every active suite in inventory order with the same profile and seed. There are currently **no reserved suite ids**; `--list-suites` still prints `active\t<name>` lines so a future reserved lane can be represented without changing the output format.

Most runner suite profiles are still `smoke`, `ci`, and `stress`. Each suite owns its own attempt counts and strategy floors for those profile names, so an unknown profile error should come from the selected suite rather than from a preflight registry that might hide suite-specific diagnostics. The `wast-roundtrip` suite additionally accepts a single generation-mode modifier after the base profile: `+parser-stress` (the default arbitrary-module and script text surface), `+valid-only` (only count modules that parse, lower, and validate), `+static-assertions` (render generated static assertion scripts), `+scripts` (require arbitrary script rendering with module commands), and `+module-only` (skip the supplemental script pass to isolate module parse/print behavior). The `binary-roundtrip` suite additionally accepts `gen-valid-smoke`, `gen-valid-ci`, and `gen-valid-stress` profiles that generate validating GenValid modules, binary-encode them, decode the bytes, revalidate the decoded module, and prove the re-encoded decoded module is byte-stable after canonicalization. It also accepts `byte-fuzz-smoke`, `byte-fuzz-ci`, and `byte-fuzz-stress`; those profiles generate validating GenValid modules, apply deterministic random/structured byte corruptions, classify decode rejections versus decode-accepted cases, and require decode-accepted valid modules to re-encode into decodable bytes. The `boundary-smoke` profile runs a fixed corpus of high and edge-shaped binary values, including index LEB boundaries, memarg offsets/memory indices, SIMD lane immediates, blocktype forms, signed integer extremes, and signed-zero float/double immediates. The ordinary `smoke` / `ci` / `stress` arbitrary-value binary profiles now report exact instruction-, section-, and immediate-shape roundtrip counters alongside the aggregate count so coverage drift is visible without parsing the test source. These suite-profile names are separate from the lower-level GenValid generator-profile taxonomy in [`gen_valid.mbt`](../../../src/validate/gen_valid.mbt), which now names reusable generator configs such as `natural-small`, `coverage-forced-all-features`, `binaryen-oracle-portable`, `mutation-seed-rich`, `pass-fuzz-stress`, and focused heavy profiles for imports, GC, SIMD, memory, and control.

The invalid AST and invalid binary suites additionally accept a `+seeds=<set>` / `+seed-profiles=<set>` modifier after the base profile. The default is still `rich`, preserving existing smoke/CI/stress behavior. `mixed` / `all` expands to `minimal,repro,small-natural,small-coverage-forced,natural,coverage-forced,rich`, and callers can pass an explicit comma-separated subset such as `smoke+seed-profiles=minimal,natural,rich`; the suite multiplies the base attempt count by the selected seed-profile count and reports per-profile attempts in JSON details.

The `cmd-harness` suite additionally accepts `+`-separated modifiers after the base suite profile so optimizer-pipeline fuzzing can choose a generator profile and a stable pass profile without inventing new top-level suite names. Supported modifiers are `gen=<gen-valid-profile>` / `generator=<gen-valid-profile>`, `passes=none|cleanup|optimize-core|each-pass|common-clusters|default-pipeline`, `idempotence` / `opt-idempotence` for an optimize-rerun check, and `codec-idempotence` / `encode-decode-idempotence` for a decode/encode stability check. `passes=each-pass` expands the current executable hot/module pass registry while excluding presets, boundary-only/removed entries, and no-inline policy marker passes that require patterns; `passes=common-clusters` runs an affordable cleanup/control-flow hot-pass cluster without the heavier optimize-instructions, DAE, inlining, local module-pass, or late-tail module-pass profiles; `passes=default-pipeline` expands the current `optimize` preset into explicit pass names so failure metadata and minimization see the real scheduled sequence. For example:

```text
moon run src/fuzz -- cmd-harness smoke+gen=natural-small+passes=cleanup+codec-idempotence --seed 0x5eed
```

The lower-level [`run_cmd_fuzz_harness(...)`](../../../src/cmd/fuzz_harness.mbt) API exposes the same generator-profile, pass-profile, and idempotence controls directly and includes those labels in persisted failure metadata. Generated-case failures also persist the resolved GenValid config label, the generator attempt count for that module, and the generated module's feature facts so repro triage can see which profile/config surface produced the failing bytes. Optimizer failures also record a minimized pass list: the minimizer now tries chunk removal before the final single-pass cleanup so dependent pass-prefix/suffix noise can be stripped even when no individual pass is removable on its own.

Cmd-harness corpus tools also expose `FuzzCorpusDedupIndex`, a deterministic FNV-1a keyed hash index that records every source seed, attempt, generator profile, pass profile, stage, and duplicate decision under the emitted wasm hash. Keep that text index next to generated corpus artifacts when deduplicating so a retained hash can be traced back to all source seeds/profiles and duplicate decisions without regenerating the corpus.

The `[FUZ]1045A7` text differential runner is intentionally opt-in and is not part of the default `all` suite. `moon run src/fuzz -- text-differential smoke --seed 0x1045a7` and the `text-differential-smoke` recipe run a deterministic local WAT parse/print/reparse/lower matrix and report `adapter_unavailable` counts for WABT / `wasm-tools` text adapters when those external tools are not wired into the runner; unavailable tools are skipped evidence, not suite failures. Route the exact local matrix, TypeScript optional adapter scaffold, `wat2wasm` / `wasm-tools parse` command shapes, and text-vs-binary-validator split through [`../fuzzing/text-differential-adapters.md`](../fuzzing/text-differential-adapters.md).

The `[FUZ]1044*` binary differential helpers are intentionally opt-in command-harness support rather than ordinary suite success criteria. They classify Starshine decode/validate plus optional `wasm-tools`, WABT, and Binaryen validators into agree-valid, agree-invalid, proposal-gap, decoder-stage disagreement, validator-stage disagreement, tool-failure, unsupported-feature, and adapter-unavailable buckets; route exact adapter command lines and skip semantics through [`external-validator-adapters.md`](external-validator-adapters.md).

The `[FUZ]1052B` export-invocation matrix helpers are intentionally opt-in. Runtime-adapter execution can classify equal results, equal traps, unsupported runtimes, nondeterministic imports, and semantic mismatches, but `[FUZ]1052B10` keeps the default failure policy informational. Pass-fuzz `--runtime-execution node` now builds same-named export invocation rows for raw Starshine and Binaryen outputs before summarizing checked/unsupported/failed runtime counts; per-row report persistence remains a follow-up slice. Equal traps are smoke evidence for the invoked export path, not a broad semantic proof; route wording and mismatch classification through [`../validate/runtime-trap-semantics.md`](../validate/runtime-trap-semantics.md). `ExportInvocationFailurePolicy::fail_on_semantic_mismatch()` is the explicit gate for harnesses that want semantic mismatches to affect exit status; unsupported runtime and nondeterministic-import rows remain blocked/skipped classifications rather than hard failures under that policy.

## Seed, Output, And Run Result Contract

The plain run form accepts positional arguments or flags:

```text
moon run src/fuzz -- [suite] [profile] [seed]
moon run src/fuzz -- --seed <int64> --output text|jsonl
moon run src/fuzz -- cmd-harness smoke --seed 0x10 --seed-count 64 --shard-index 0 --shard-count 4 --report-json .tmp/fuzz-report.json --out-dir .tmp/fuzz-run
bun fuzz run --suite <name> --profile <name> --seed <int64> --jsonl --out-dir .tmp/fuzz-run
```

Important invariants:

- Missing suite/profile defaults to `all smoke`.
- Missing seed uses a time-derived signed `Int64` seed; logged output always includes the resolved signed seed.
- Seeds accept decimal or `0x...` forms; `--seed` and positional seed are mutually exclusive.
- `--recipe <name>` / `--recipe=<name>` loads a checked-in `starshine.fuzz.recipe.v1` default bundle before explicit suite/profile/seed/output overrides are applied; use [`../fuzzing/recipe-schema.md`](../fuzzing/recipe-schema.md) for the standard recipe catalog and precedence ladder.
- `--seed-count <n>` performs a deterministic seed sweep from the resolved base seed through `base + n - 1` using wrapping `UInt64` arithmetic mapped back to signed `Int64` output.
- `--shard-index <i> --shard-count <n>` runs only seed ordinals where `ordinal % shard_count == shard_index`; defaults are `0/1`, and `shard_index` must be less than `shard_count`.
- `build_fuzz_shard_queue(...)` turns a `FuzzRecipe` into deterministic shard work items named `<recipe>-shard-NNN-of-MMM`. When given an output root, each work item receives a distinct `shard-NNN-of-MMM` subdirectory so parallel workers do not write the same artifact path. `build_fuzz_resume_shard_queue(...)` applies the same naming contract while skipping shards whose completed output manifests already name the required result and cases artifacts, and `merge_fuzz_shard_results(...)` merges shard result arrays in deterministic seed-index / suite / profile / shard order for stable resumed-run summaries.
- Text output lines keep the single-seed contract `suite=<name> profile=<profile> seed=<seed> attempts=<n> pass=true elapsed_ms=<ms>`. Sweep/sharded runs append `seed_index`, `seed_count`, `shard_index`, and `shard_count` fields. When a total-run budget wrapper marks a case over budget, the same result line reports `pass=false`, `total_run_budget_ms=<n>`, and `run_budget_classification=run-budget-timeout`; this is distinct from per-case timeout/resource classifications.
- JSONL output emits one JSON object per suite result, including sweep/shard metadata. Suites with first-class ledgers also include a `details` object: `validate-valid` reports validated count, generator config label, feature counters, and configured feature floors; `binary-roundtrip` reports arbitrary value roundtrips, GenValid module roundtrips, decoded GenValid validation counts, byte-fuzz case/decode/validation/stable-reencode counters, boundary corpus roundtrips, and exact arbitrary instruction/section/immediate roundtrip counters; `wat-roundtrip` reports successful/stable roundtrips plus module print, parse, roundtrip-print, unstable-text, script-render, and no-module-command counts; `wast-validate-roundtrip` reports WAST AST print, parse, lower, and validation counts plus failure categories; `gen-valid-wat-validate-roundtrip` reports GenValid generated, printed, parsed, lowered, validated, and failure-category counts for the lib-module-to-WAT lane; `valid-multi-module-linking` reports generated scripts, parsed scripts, single-module validation counts, and historical `link_passed` / `link_failed` / `link_skipped` counters that currently classify static WAST harness pass/fail/skip rather than host-linker results; `text-differential` reports local parse/print/reparse-lower counts, local lowered-byte mismatches, unavailable external text-adapter skip counts, and aggregate unavailable classifications; invalid AST/binary/text/spec-seed suites report per-strategy or per-seed counters with stable ids and expected-rejection counts; `validate-invalid-text-dynamic` additionally reports per-strategy variant ids and source feature facts such as `source:gen-valid-wat` and dynamic mutation facts such as `mutation:unknown-import`; invalid AST/binary details also include selected seed profiles and per-profile attempt counts. `validate-invalid-spec-seed` also includes a `dynamic` details object with scanned/attempted/matched counts and matched feature-family names for CI/stress dynamic spec sampling.
- `--report-json <path>` writes a single summary object with schema `starshine.fuzz.summary.v1`, `suite`, `profile`, `base_seed`, sweep/shard configuration, aggregate `run_count`, and the per-suite `runs` array. The `summary` object records aggregate counters (`total_attempts`, `total_elapsed_ms`), reserved maps for machine-readable `failure_classes` and `strategy_outcomes`, and `artifact_counts` for run records, ledgers, replay manifests, generated inputs, and failures. Total-run budget exhaustion is reported under `failure_classes.run-budget-timeout` and per-run `run_budget_classification`, not as a per-case timeout, crash, validation failure, or tool failure. The same `details` objects used by JSONL are embedded per run. The path must be explicit.
- `--out-dir <dir>` is the ordinary-run artifact directory. It is opt-in; when omitted, no standard run directory is created. When present, the runner creates the root directory plus `ledgers/` and `replay/`, then writes `result.json` with the same `starshine.fuzz.summary.v1` summary schema as `--report-json`, `cases.jsonl` with one JSONL suite-result record per case/run, `ledgers/<suite>-ledger.json` with schema `starshine.fuzz-suite-ledger.v1`, `replay/<suite>-replay.json` with schema `starshine.fuzz-replay-manifest.v1`, and `manifest.json` using schema `starshine.fuzz-output.v1`. For the representative `validate-valid` suite, the same output directory also writes `summary.json` with the compact `starshine.fuzz-summary-report.v1` coverage-delta shape: required module/attempt counters, smoke-profile required import/ref-type/v128 feature counters, optional import/ref-type/v128 counters for other profiles, status/failure/timing/artifact groups, and the base seed as a `0x...` string. The top-level manifest lists those files and declares reserved `inputs/` / `failures/` artifact directories alongside the persisted ledger and replay directories; suites only populate generated-input or failure subartifacts when their specific runner path captures those bytes.
- `--replay-corpus <replay-manifest.json>` replays every command in a persisted `starshine.fuzz-replay-manifest.v1` file in manifest order. Each command runs as a single deterministic suite/profile/seed case (`seed-count=1`, shard `0/1`) and prints the normal text result line, so promoted or quarantined cases can be replayed without checking in a large generated corpus.

Preserve this result contract when adding suites so CI logs, repro reports, and long-running compare tasks can remain machine-readable.

## Artifact Commands

### Coverage-forced valid batches

`--emit-gen-valid-batch` emits deterministic validated `.wasm` files named `gen-valid-000001.wasm`, `gen-valid-000002.wasm`, and so on:

```text
moon run src/fuzz -- --emit-gen-valid-batch --count <n> --seed <uint64> --out-dir <dir> \
  [--gen-valid-profile <profile>] [--require-feature <label[:min]>] \
  [--exclude-feature <label>] [--max-attempts <n>] [--manifest <path>] \
  [--metamorphic-transform <id> ...]
bun fuzz run --emit-gen-valid-batch --count <n> --seed <uint64> --out-dir <dir> \
  [--gen-valid-profile <profile>] [--require-feature <label[:min]>] \
  [--exclude-feature <label>] [--max-attempts <n>] [--manifest <path>] \
  [--metamorphic-transform <id> ...]
```

The default batch config is [`GenValidConfig::binaryen_oracle_coverage_forced_default()`](../../../src/fuzz/main.mbt), now also named by the `binaryen-oracle-portable` / `pass-fuzz-stress` GenValid profiles, not the default natural generator. This makes the emitted corpus useful for Binaryen-oracle pass comparison while keeping imports, memories, tables, globals, tags, elems, datas, SIMD, ref-types, and similar features constrained to the current portable comparison subset. A sibling `binaryen-oracle-relaxed-simd` profile keeps those nonportable surfaces disabled but turns `v128`, relaxed SIMD, and typed body generation on for tool-compatible relaxed-SIMD batch emission. The batch writer creates `--out-dir` before writing artifacts.

`--gen-valid-profile` selects any named GenValid profile, `--require-feature` keeps only selected modules that advance the requested feature floor, `--exclude-feature` skips candidates that contain the named feature key, and `--max-attempts` bounds the candidate stream. `--metamorphic-transform <id>` may repeat; selected modules are transformed round-robin by the requested valid metamorphic transform ids before encoding, and unknown ids reject the batch instead of silently falling back. `--manifest <path>` is opt-in and writes a JSON manifest with the generator name, seed, requested profile, required/excluded feature filters, requested `metamorphic_transform_ids`, aggregate feature stats, and one record per emitted `.wasm` file including file name, seed, index, config label, attempt count, validation status, applied `transform_id`, and feature facts. Feature labels use the stable coverage-ledger strings accepted by [`validate_valid_feature_floor_by_label(...)`](../../../src/validate/validate.mbt), such as `v128` or `mems:2`.

Callers that need generation diagnostics can use [`gen_valid_module_result(...)`](../../../src/validate/gen_valid.mbt) instead of the compatibility `Module`-only wrapper. The result-bearing API reports the stable config label, retry attempt count, feature facts for successful modules, and the last validation message/candidate on failure. The fuzz package also exposes [`emit_gen_valid_batch_artifacts_with_manifest(...)`](../../../src/fuzz/main.mbt), which preserves the existing `.wasm` artifact names while returning an in-memory manifest with file name, seed, index, config label, attempts, validation status, and feature facts for each generated input. The compare-pass `gen-valid` path now asks the batch emitter to write `inputs/gen-valid/manifest.json` next to the saved inputs so downstream triage can inspect generated-input facts without regenerating the batch.

For local coverage-guided selection, [`emit_gen_valid_batch_artifacts_until_features(...)`](../../../src/fuzz/main.mbt) generates a bounded candidate stream from an explicit `GenValidConfig`, keeps only modules that contribute to required feature floors and do not hit excluded feature keys, and returns the selected artifacts, manifest entries, aggregate `GenValidFeatureStats`, floor failures, attempt count, and skipped-candidate count. Use [`validate_valid_feature_floor_by_label(...)`](../../../src/validate/validate.mbt) and [`validate_valid_feature_actual_count_by_label(...)`](../../../src/validate/validate.mbt) when a caller needs stable string labels instead of constructing ledger enum values directly.

### Golden seed catalog schema

The maintained golden-seed catalog schema is now named `starshine.fuzz.golden-seed-catalog.v1` and is exposed by [`golden_seed_catalog_schema_json()`](../../../src/fuzz/main.mbt). Each entry records a stable `id`, `suite`, `profile`, unsigned root `seed`, `expected_counters`, and `covered_surfaces`; `artifacts` and `notes` are optional maintenance fields. Expected counters are named nonnegative integers with either `exact` or `minimum` semantics so smoke seeds can pin stable invariants while allowing broader feature counters to grow. [`GoldenSeedCatalogEntry`](../../../src/fuzz/main.mbt) and [`format_golden_seed_catalog_entry_json(...)`](../../../src/fuzz/main.mbt) provide the checked formatter used by tests.

[`golden_seed_smoke_suite_catalog()`](../../../src/fuzz/main.mbt) is the checked-in deterministic smoke-suite catalog for `[FUZ]1058B`. It currently names seven major surfaces: coverage-forced GenValid valid generation, invalid AST repro metadata, invalid binary repro metadata, invalid text repro metadata, pass-fuzz/Binaryen-oracle metadata, reducer/minimization replay, and WAST text roundtripping. Each entry records its stable suite/profile/seed tuple, expected counter floors, covered-surface labels, expected logical artifacts, and a short maintenance note so future runner or recipe work can replay the same smoke surfaces without inferring seeds from historical logs.

Use [`fuzzing/golden-seed-catalog.md`](../fuzzing/golden-seed-catalog.md) as the maintenance checklist when a catalog entry changes. In short: update the MoonBit source catalog, synchronize the checked-in JSON document, adjust the human-readable entry list and smoke assertions when needed, and run the focused golden-seed smoke before broader Moon validation. Do not rotate catalog seeds for transient local failures, one-off stress finds, or minimized bug repros that belong in a corpus or focused regression test.

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
- `--suite`, `--profile`, `--seed`, `--seed-count`, `--shard-index`, `--shard-count`, `--report-json`, ordinary-run `--out-dir`, `--output`, `--jsonl`, `--help`, `--list-suites`, `--list-profiles`, and `--emit-gen-valid-batch` forwarding, including batch `--gen-valid-profile`, `--require-feature`, `--exclude-feature`, `--max-attempts`, `--manifest`, and repeated `--metamorphic-transform` options.

`bun fuzz compare-pass ...` is a sibling entrypoint, not a `src/fuzz` suite. It delegates to [`scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts), which may call `src/fuzz --emit-gen-valid-batch` internally for generated inputs before invoking Starshine, `wasm-tools`, and Binaryen. For pass signoff lanes, build `src/cmd` once and include `--jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` explicitly. The compare-pass task uses `.tmp/pass-fuzz-cache` by default to reuse deterministic `wasm-smith` inputs and Binaryen oracle outputs/failures; use `--cache-dir <dir>` to isolate/share that cache or `--no-cache` only for cache debugging.

Use compare-pass for optimizer parity signoff or failure-replay workflows, not broad fuzz-suite coverage. Compare-pass runs now also write `summary.json` in the compact `starshine.fuzz-summary-report.v1` shape so `bun fuzz coverage-delta` can compare requested/compared cases, generator mix, GenValid transforms, input effect facts, statuses, failures, and failure artifacts across pass-fuzz runs; detailed cache hit/miss counters live in `result.json.cache`. The detailed command, generator, normalization, failure-class, replay, persistent-cache, `summary.json`, and explicit `--jobs auto` / `--starshine-bin` contract now lives in [`pass-fuzz-compare.md`](pass-fuzz-compare.md); keep this page focused on the ordinary `src/fuzz` runner and wrapper split.

`bun fuzz coverage-delta [--optional] <before-report.json> <after-report.json>` compares numeric counters under a persisted summary report's `summary` object. Counter paths containing a component that starts with `required` are treated as required coverage: decreases are printed and make the command exit nonzero. Optional counters are tolerated by default so new or removed optional surfaces do not break CI noise floors; pass `--optional` / `--include-optional` to print optional changes as well. Artifact counts, failure classes, pass statuses, timings, and their compact-schema `artifacts` / `failures` / `statuses` equivalents are always shown when changed so run-shape drift remains visible even when the changed counter is not a required coverage floor.

A minimal coverage-delta-compatible fuzz summary report can be kept small in docs or tests. The reusable schema helper in [`fuzz-summary-counters.ts`](../../../scripts/lib/fuzz-summary-counters.ts) normalizes this `starshine.fuzz-summary-report.v1` shape, preserves suite/profile/seed identity, filters each counter group to finite numbers, and roundtrips through deterministic JSON formatting:

```json
{
  "schema": "starshine.fuzz-summary-report.v1",
  "suite": "validate-invalid-ast",
  "profile": "smoke",
  "seed": "0x1048a",
  "summary": {
    "features": {
      "required_gc": 3,
      "optional_strings": 1
    },
    "opcodes": {
      "required_ref_func": 2
    },
    "strategies": {
      "required_invalid_ast": 4
    },
    "artifacts": {
      "repro": 1
    },
    "failures": {
      "validation": 0
    },
    "statuses": {
      "validate-invalid-ast": 1
    },
    "timings": {
      "wall_ms": 25
    }
  }
}
```

In that example, decreasing `summary.features.required_gc`, `summary.opcodes.required_ref_func`, or `summary.strategies.required_invalid_ast` is a required-counter regression and fails the command. The `validate-valid` smoke `summary.json` uses the same policy for the first stable GenValid coverage floors (`required_modules`, `required_imports`, `required_ref_types`, `required_v128`, and `required_validate_valid`). Decreasing `summary.features.optional_strings` is hidden and tolerated by default, then printed without failing when `--optional` is supplied. Non-coverage run-shape counters such as artifacts, failures, statuses, and timings are reported when they drift so reviewers can distinguish coverage loss from ordinary run-shape changes.

## Maintenance Guidance

- Add or extend a named `src/fuzz` suite for new broad randomized work; keep `moon test` deterministic and fast.
- Update [`src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt) whenever the suite inventory, command parser, result format, or artifact command contract changes.
- Keep [`scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts) aligned with wrapper forwarding behavior for `bun fuzz run` and `bun fuzz compare-pass`.
- Keep [`scripts/test/fuzz-coverage-delta.ts`](../../../scripts/test/fuzz-coverage-delta.ts) aligned with required-vs-optional counter policy for `bun fuzz coverage-delta`.
- If a suite emits persisted failures, include enough metadata to replay from `suite`, `profile`, `seed`, and attempt/strategy identity.
- Serialize Moon commands in automation because `_build/.moon-lock` is shared.
- When widening validator invalid lanes, update [`validate/fuzz-hardening.md`](../validate/fuzz-hardening.md) for strategy/repro summary, [`validate/diagnostics-and-invalid-repro.md`](../validate/diagnostics-and-invalid-repro.md) for stage/family/artifact semantics, and this page only for runner command shape.

## Sources

- Historical extraction note: [`../raw/research/0003-2026-03-12-fuzz-migration.md`](../raw/research/0003-2026-03-12-fuzz-migration.md)
- MoonBit runner and command tests: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt), [`../../../src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt)
- Invalid repro dispatcher: [`../../../src/fuzz/invalid_repro.mbt`](../../../src/fuzz/invalid_repro.mbt)
- Bun wrapper, summary counters, and pass compare task: [`../../../scripts/lib/fuzz-task.ts`](../../../scripts/lib/fuzz-task.ts), [`../../../scripts/lib/fuzz-summary-counters.ts`](../../../scripts/lib/fuzz-summary-counters.ts), [`../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../scripts/lib/pass-fuzz-compare-task.ts)
- Wrapper command and summary tests: [`../../../scripts/test/task-family-commands.ts`](../../../scripts/test/task-family-commands.ts), [`../../../scripts/lib/fuzz-summary-counters.test.ts`](../../../scripts/lib/fuzz-summary-counters.test.ts), [`../../../scripts/test/pass-fuzz-compare-command.ts`](../../../scripts/test/pass-fuzz-compare-command.ts)
