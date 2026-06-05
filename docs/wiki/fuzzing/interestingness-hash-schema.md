---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../raw/fuzzing/2026-06-05-interestingness-hash-schema-source-refresh.md
  - ../../../src/fuzz/main.mbt
  - ../../../src/fuzz/main_wbtest.mbt
related:
  - ../tooling/fuzz-corpus-policy.md
  - reduction-backends.md
  - ../tooling/pass-fuzz-compare.md
  - recipe-schema.md
  - golden-seed-catalog.md
  - ../tooling/fuzz-runner.md
---

# Fuzz Interestingness Hash Schema

## Overview

Use this page when a fuzz failure, reduced artifact, promoted corpus case, or replay-all entry needs a stable identity that is more precise than “case N from a run directory.” Starshine uses `starshine.fuzz-interestingness.v1` as the durable vocabulary for those identities.

For beginners: a fuzz run may produce many modules that fail for the same reason. Some are byte-identical, some reduce to the same tiny repro, some have the same WebAssembly feature mix, and some only look the same after normalization. The interestingness schema keeps those questions separate so corpus tooling can group related cases without deleting the original evidence.

The current source bridge is [`../raw/fuzzing/2026-06-05-interestingness-hash-schema-source-refresh.md`](../raw/fuzzing/2026-06-05-interestingness-hash-schema-source-refresh.md). It rechecked the current Starshine helpers/tests and RFC 9923 for the local FNV-1a digest vocabulary. The executable contract lives in [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt); focused coverage lives in [`src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt).

## Digest Contract

All v1 layers use Starshine's local `fnv1a64-hex` string format:

```text
fnv1a64-<16 lowercase hex digits>
```

[`fuzz_corpus_hash_bytes(...)`](../../../src/fuzz/main.mbt) starts from the 64-bit FNV offset basis, XORs each input byte into the hash, then multiplies by the 64-bit FNV prime with unsigned wraparound. That is FNV-1a order. The RFC source confirms FNV is a **non-cryptographic** hash family, so Starshine treats these values as deterministic correlation keys, not as integrity, authenticity, or security proofs.

Practical consequences:

- keep original artifact paths and replay predicates beside every hash;
- do not delete evidence merely because one hash layer collides or matches;
- add stronger hashes as extra metadata if a future storage layer needs collision resistance, but do not silently change the v1 layer meanings.

## Hash Layers

`fuzz_interestingness_hash_schema()` returns the ordered six-layer schema:

| Layer | Meaning | Typical producer or consumer |
| --- | --- | --- |
| `raw` | Original specimen bytes before decoding, normalization, or reduction. | Corpus entry `raw_artifact_hash`; dedup dry-run always keeps raw groups. |
| `decoded-shape` | Decoded module/script shape: section and instruction families without preserving incidental payload bytes. | Future per-suite shape normalizers; currently schema vocabulary rather than a destructive dedup signal. |
| `feature-fact` | Sorted feature facts such as GC, exception handling, memory64, SIMD, string, imports, exports, and proposal markers. | `build_fuzz_corpus_hash_metadata(...)` sorts facts before hashing them. |
| `normalized` | Canonical normalized comparison text or bytes after accepted representation-only cleanup. | Compare-pass and future corpus correlation. `normalized_shape_hash` is the current corpus-entry field name for this report-only role. |
| `predicate` | Oracle outcome, interestingness predicate, failure class, pass name, diagnostic family, or relevant tool verdicts. | Distinguishes two byte-similar cases that are interesting for different reasons. |
| `reduced-artifact` | Minimized or otherwise reduced artifact that still satisfies the predicate. | Reducers and corpus-entry `reduced_artifact_hash`; duplicate reduced hashes are compression candidates only. |

The order is part of the schema contract because `FuzzInterestingnessCaseKey` stores exactly these six fields: `raw_hash`, `decoded_shape_hash`, `feature_fact_hash`, `normalized_hash`, `predicate_hash`, and `reduced_artifact_hash`.

## Corpus Metadata Bridge

`[FUZ]1050A` added the first bridge from the six-layer vocabulary into promoted/quarantined corpus entries. `FuzzCorpusHashMetadata` stores:

- `raw_artifact_hash`
- `reduced_artifact_hash`
- `predicate_hash`
- `feature_fact_hash`
- `interestingness_label`

`build_fuzz_corpus_hash_metadata(...)` derives those fields from raw bytes, optional reduced bytes, a predicate string, sorted feature facts, and a human-readable label. If no reduced artifact exists, the reduced-artifact hash falls back to the raw artifact bytes so unreduced cases still have a complete metadata shape.

`FuzzCorpusPromotionMetadata` embeds the hash metadata and also stores `normalized_shape_hash`. The JSON schema helper `fuzz_corpus_promotion_metadata_schema_json()` marks the following hash/label fields as required in `starshine.fuzz-corpus-entry.v1` entries:

```text
raw_artifact_hash
reduced_artifact_hash
normalized_shape_hash
predicate_hash
feature_fact_hash
interestingness_label
```

Use [`../tooling/fuzz-corpus-policy.md`](../tooling/fuzz-corpus-policy.md) for the full promoted/quarantined state machine and required non-hash fields.

## Grouping, Dedup, And Dry-Run Rules

`[FUZ]1050B` added reversible case-index helpers. `build_fuzz_corpus_case_index(...)` groups corpus entries by three reportable hash kinds today:

| Index row | Source field | Artifact path stored | Meaning |
| --- | --- | --- | --- |
| `raw` | `raw_artifact_hash` | original input path | Same original bytes or text. |
| `reduced` | `reduced_artifact_hash` | first artifact path when available | Same reduced repro bytes/text. |
| `normalized-shape` | `normalized_shape_hash` | original input path | Same canonical/correlation shape; report-only. |

`[FUZ]1050C` and `[FUZ]1050D1` keep dedup intentionally non-destructive:

- raw groups are always `keep`, even when duplicate, because raw artifacts are original evidence and may be the only artifact for unreduced failures;
- duplicate reduced groups are `compress` candidates, but the helper only reports that candidate and never deletes or rewrites files;
- duplicate normalized-shape groups are `duplicate` reports, not deletion or compression instructions;
- unique groups are `keep`.

This dry-run rule is the safety invariant for future corpus storage work: grouping can help humans understand repeated failures, but replay evidence remains reviewable and reversible.

## Example Metadata Flow

A compare-pass mismatch that reduces successfully usually has these layers:

```text
raw_artifact_hash        = hash(input.wasm)
reduced_artifact_hash    = hash(reduced-input.wasm)
normalized_shape_hash    = hash(canonical normalized WAT or chosen report shape)
predicate_hash           = hash("pass=local-cse status=mismatch class=unknown/risky")
feature_fact_hash        = hash(sorted feature facts such as ["gc", "memory64"])
interestingness_label    = "semantic-mismatch" | "tool-failure" | "rare-feature" | ...
```

The label is intentionally human-readable. It helps scan a manifest, but the predicate hash and replay command are the durable machine-checkable evidence.

## Maintenance Checklist

When changing interestingness or corpus hash behavior:

1. Update the public data shapes and helpers in [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt).
2. Add or update whitebox coverage in [`src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt) for schema order, JSON required fields, feature-fact sorting, case-index rows, and dry-run decisions.
3. Keep [`../tooling/fuzz-corpus-policy.md`](../tooling/fuzz-corpus-policy.md), [`reduction-backends.md`](reduction-backends.md), and [`../tooling/pass-fuzz-compare.md`](../tooling/pass-fuzz-compare.md) aligned when reducers, compare predicates, or corpus states change.
4. Update this page, [`../index.md`](../index.md), and [`../log.md`](../log.md) for durable schema changes.
5. Do not change the meaning or order of `starshine.fuzz-interestingness.v1` layers silently. If compatibility breaks, name a new schema id and document the migration.

Docs-only refreshes need source/link review and `git diff`; executable schema changes should run at least `moon test src/fuzz`, with broader validation when corpus metadata touches release gates.

## Current Limits

- `decoded-shape` remains schema vocabulary until a suite-specific decoded-shape normalizer is implemented and tested.
- `normalized_shape_hash` is report-only correlation metadata; it is not a deletion signal.
- The local FNV-1a digest is deliberately non-cryptographic. Keep replay inputs, reduced artifacts, predicates, and source notes available so collisions or classification mistakes remain diagnosable.
- No current helper performs destructive corpus deduplication.

## Sources

- Current source bridge: [`../raw/fuzzing/2026-06-05-interestingness-hash-schema-source-refresh.md`](../raw/fuzzing/2026-06-05-interestingness-hash-schema-source-refresh.md)
- Runtime schema/helpers: [`../../../src/fuzz/main.mbt`](../../../src/fuzz/main.mbt)
- Whitebox tests: [`../../../src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt)
- Corpus policy: [`../tooling/fuzz-corpus-policy.md`](../tooling/fuzz-corpus-policy.md)
- Reducer contract: [`reduction-backends.md`](reduction-backends.md)
- Compare-pass predicates/artifacts: [`../tooling/pass-fuzz-compare.md`](../tooling/pass-fuzz-compare.md)
