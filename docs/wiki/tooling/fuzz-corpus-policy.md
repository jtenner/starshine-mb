---
kind: policy
status: supported
last_reviewed: 2026-05-28
sources:
  - ./fuzz-runner.md
  - ./pass-fuzz-compare.md
  - ../validate/diagnostics-and-invalid-repro.md
  - ../../../agent-todo.md
related:
  - ./fuzz-runner.md
  - ./pass-fuzz-compare.md
  - ../validate/fuzz-hardening.md
  - ../validate/diagnostics-and-invalid-repro.md
---

# Fuzz Corpus Promotion And Quarantine Policy

## Purpose

This policy names the long-lived fuzz corpus states used by Starshine runners, compare lanes, reducers, dedup/index tooling, and replay-all tooling. It closes the `[FUZ]1042A` documentation slice; code that persists or replays corpus entries should use these names instead of inventing ad hoc directories or statuses. `[FUZ]1042B` adds the first Moon schema/format/parse helper for single-entry metadata under `starshine.fuzz-corpus-entry.v1`, and `[FUZ]1050A` extends that entry with deterministic artifact, predicate, feature-fact, and interestingness-label metadata.

The policy is intentionally metadata-first. Large generated corpora should not be committed by default. Promote small, durable repro artifacts only when they are useful for regression, oracle triage, or tool-gap tracking, and keep noisy or machine-local bulk output under `.tmp/` unless a maintainer explicitly chooses otherwise.

## Corpus States

| State | Meaning | Typical source | Replay expectation |
| --- | --- | --- | --- |
| `promoted-valid` | A valid Starshine-generated or externally generated input worth keeping as a stable positive corpus member. | `validate-valid`, `binary-roundtrip` GenValid batch, compare-pass `gen-valid`, or hand-curated `.wasm` / `.wat`. | Must decode and validate under Starshine. If tied to a pass, it should keep satisfying the recorded comparison/property expectation unless that expectation is superseded. |
| `promoted-invalid` | A malformed, invalid, or unlinkable specimen whose expected rejection is part of the durable test surface. | `validate-invalid-*` suites, `--emit-invalid-repro`, spec-seed extraction, or a reduced parser/validator issue. | Must reproduce the recorded stage and expected diagnostic family when the diagnostic is stable enough to assert. Exact wording is optional unless the entry declares an exact diagnostic contract. |
| `pass-mismatch` | A compare-pass input where Starshine and Binaryen both produced valid/canonicalizable outputs but normalized outputs differed. | `bun fuzz compare-pass` failure directories with `status=mismatch`. | Must replay with the stored pass flags and preserve the recorded classification until fixed or reclassified. Human classification is required before using it as a release blocker. |
| `tool-failure` | A specimen blocked by an external or local tool command rather than a proven Starshine semantic bug. | compare-pass `command-failure`, generator failures, external validator failures, or parser/tool gaps such as known Binaryen command-failure classes. | Replay should preserve the failing command, tool name, tool version when known, failure class, and whether Starshine produced a usable artifact. Tool failures should not silently fail release gates unless a task explicitly makes them gating. |
| `accepted-divergence` | A replayable mismatch or shape drift that maintainers accepted as safe, non-gating, or intentionally different. | pass signoff research, compare-pass mismatch triage, self-optimize artifact comparison, or docs/wiki decision. | Must cite the acceptance evidence and boundary. Reopen only if new evidence shows a semantic mismatch, validation failure, runtime issue, or changed release requirement. |
| `quarantine` | A specimen that should be kept for investigation but not trusted as a regression oracle yet. | Flaky runs, nondeterministic imports/runtime behavior, resource-limit cases, oversized reductions, unsupported proposal/tool coverage, or unclear oracle disagreements. | Replay may fail or time out. The entry must explain why it is quarantined and what evidence would promote, accept, or delete it. |

## Required Metadata

Every promoted or quarantined entry should carry these fields in a sidecar manifest, failure metadata file, replay manifest, or equivalent checked-in note:

- `schema`: stable schema id for the manifest shape.
- `id`: stable human-readable id.
- `state`: one of the states above.
- `source`: suite, command, research note, or manual source that created the specimen.
- `input`: relative path or content-addressed pointer to the replay input.
- `created_at`: date the entry was promoted or quarantined.
- `generator`: generator name/profile/seed/attempt when generated.
- `features`: known feature facts when available.
- `expectation`: expected validation result, pass comparison status, property result, or tool failure class.
- `classification`: human triage class for mismatches or divergences, when applicable.
- `replay`: exact command or replay recipe, including pass flags and feature flags.
- `artifacts`: optional related raw/canonical/text outputs, reducer outputs, or logs.
- `owner_or_task`: backlog id, pass id, or wiki page responsible for follow-up.
- `notes`: short rationale, caveats, and supersession links.
- `raw_artifact_hash`: deterministic hash for the original raw bytes or text payload before reduction.
- `reduced_artifact_hash`: deterministic hash for the reduced artifact that still preserves the predicate, or the raw-artifact hash when no reduced artifact exists.
- `predicate_hash`: deterministic hash for the replay predicate, failure class, pass/tool verdict, or other oracle condition used to decide that the case remains interesting.
- `feature_fact_hash`: deterministic hash for sorted feature facts, such as GC, exception, memory64, SIMD, imports, exports, or proposal markers.
- `interestingness_label`: compact human-readable initial label such as `semantic-mismatch`, `tool-failure`, `rare-feature`, `decode-rejected`, or `validate-rejected`.

Use relative paths rooted at the repository when possible. Do not store absolute host paths, credentials, environment-specific cache paths, or private machine details in committed metadata.

## Current Moon Metadata Helper

`src/fuzz/main.mbt` exposes `FuzzCorpusPromotionMetadata`, `format_fuzz_corpus_promotion_metadata_json(...)`, `parse_fuzz_corpus_promotion_metadata_json(...)`, and `fuzz_corpus_promotion_metadata_schema_json()` for the initial single-entry sidecar shape:

- schema id: `starshine.fuzz-corpus-entry.v1`;
- allowed `state` values: `promoted-valid`, `promoted-invalid`, `pass-mismatch`, `tool-failure`, `accepted-divergence`, and `quarantine`;
- required fields: `id`, `state`, `source`, `input`, `created_at`, `generator`, `features`, `expectation`, `classification`, `replay`, `artifacts`, `owner_or_task`, `notes`, `raw_artifact_hash`, `reduced_artifact_hash`, `predicate_hash`, `feature_fact_hash`, and `interestingness_label`.

`[FUZ]1050A` also adds `FuzzCorpusHashMetadata` and `build_fuzz_corpus_hash_metadata(...)`, which compute the four hash fields with the local `fnv1a64-*` corpus hash and sort feature facts before hashing. The helper intentionally formats and parses a compact deterministic JSON subset for metadata produced by Starshine itself. It does not execute replays.

`[FUZ]1050B` adds the reversible case-index helper for duplicate corpus cases. `build_fuzz_corpus_case_index(...)` groups `starshine.fuzz-corpus-entry.v1` entries by raw and reduced artifact hash, preserving case ids, parsed seeds, profiles, and artifact paths for each duplicate group. `format_fuzz_corpus_case_index_json(...)` and `parse_fuzz_corpus_case_index_json(...)` roundtrip the compact `starshine.fuzz-corpus-case-index.v1` schema without deleting or compressing artifacts.

`[FUZ]1042C` adds replay-command metadata helpers for a single promoted or quarantined case. `build_fuzz_corpus_replay_command_metadata(...)` derives a deterministic `starshine.fuzz-replay-command.v1` entry from corpus metadata when `generator` includes `suite=...`, `profile=...`, `seed=...`, and optional `seed_index=...` / `strategy=...` tokens. If no strategy token is present, the helper records the first artifact path, or the input path when no artifact is listed. `format_fuzz_corpus_replay_command_metadata_json(...)` and `parse_fuzz_corpus_replay_command_metadata_json(...)` roundtrip the case id, suite, profile, seed, seed index, strategy-or-artifact, expected outcome, classification, and exact replay command.

`[FUZ]1042D` adds the first replay-all manifest planner. `plan_fuzz_corpus_replay_manifest(...)` reads a compact `starshine.fuzz-corpus-replay-all-manifest.v1` JSON manifest with an `entries` array of `starshine.fuzz-corpus-entry.v1` objects, derives replay-command metadata for every plannable entry, and reports `planned_count`, `skipped_count`, and `malformed_count` without executing any replay. Parse-invalid entries are counted as malformed; parseable entries that cannot build a replay command, such as metadata missing required `suite` / `profile` / `seed` generator tokens, are counted as skipped.

## Promotion Rules

Promote a specimen when at least one condition holds:

1. it guards a fixed bug or an accepted semantic boundary;
2. it covers a rare generator, validator, binary, text, or pass shape that ordinary smoke runs may miss;
3. it is small enough to be reviewed and replayed cheaply;
4. it is needed as an input to a deterministic reducer or replay-all workflow;
5. it documents an external-tool gap that affects pass-fuzz interpretation.

Before promotion, prefer reducing the specimen and storing the smallest replayable input that preserves the predicate. If reduction is not yet available, record `reduction_status: unreduced` and explain why the unreduced artifact is still worth keeping.

## Quarantine Rules

Quarantine instead of promoting when:

- the run is flaky or depends on nondeterministic imports/runtime behavior;
- the specimen is too large or too slow for deterministic replay;
- the expected result depends on an unsupported proposal or unavailable external tool;
- the oracle disagreement is not classified yet;
- the artifact may be useful but the replay command or input provenance is incomplete.

A quarantine entry should have an explicit exit condition: promote, mark as accepted-divergence, convert to tool-failure, reduce further, or delete from active tracking.

## Replay-All Implications

Replay-all tooling should treat these states differently:

- `promoted-valid` and `promoted-invalid` are ordinary deterministic corpus lanes.
- `pass-mismatch` is a targeted compare-pass lane and needs stored pass flags.
- `tool-failure` is an observability lane; it should report class drift without automatically becoming a Starshine correctness failure.
- `accepted-divergence` is a guardrail lane; it should alert when the recorded boundary changes, not when the accepted difference persists.
- `quarantine` is non-gating by default and should be opt-in for CI.

This split keeps the active fuzz corpus useful without turning every historical tool gap or accepted representation difference into a permanent release blocker.
