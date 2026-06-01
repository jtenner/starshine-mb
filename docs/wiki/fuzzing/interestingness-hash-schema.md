# Fuzz Interestingness Hash Schema

Starshine fuzz corpus and reduction tooling uses `starshine.fuzz-interestingness.v1` as the stable schema id for multi-layer interestingness keys. The runtime definition lives in [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt) as `fuzz_interestingness_hash_schema`, `FuzzInterestingnessCaseKey`, `FuzzCorpusHashMetadata`, and `build_fuzz_corpus_hash_metadata`; focused coverage lives in [`src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt).

## Hash Layers

All v1 layers use `fnv1a64-hex` for the local schema contract. The digest algorithm is intentionally simple and deterministic; callers may store richer source artifacts beside the key when collision resistance matters.

| Layer | Meaning |
| --- | --- |
| `raw` | Original specimen bytes before decoding, normalization, or reduction. |
| `decoded-shape` | Decoded module/script shape: section and instruction families without preserving incidental payload bytes. |
| `feature-fact` | Sorted feature facts such as GC, exception, memory64, SIMD, string, import, export, and proposal markers. |
| `normalized` | Canonical normalized comparison text or bytes after accepted representation-only cleanup. |
| `predicate` | Oracle outcome, interestingness predicate, failure class, pass name, and relevant tool verdicts. |
| `reduced-artifact` | Minimized or otherwise reduced artifact that still satisfies the predicate. |

## Case Key

`FuzzInterestingnessCaseKey` stores the six hashes as separate fields instead of a flattened string:

- `raw_hash`
- `decoded_shape_hash`
- `feature_fact_hash`
- `normalized_hash`
- `predicate_hash`
- `reduced_artifact_hash`

Keeping fields separate makes the corpus dedup index reversible: a runner can deduplicate by one layer, by a prefix of layers, or by the full six-tuple while still pointing back to the original seed/profile and reduced artifact.

## Corpus Metadata Bridge

`[FUZ]1050A` adds the first metadata bridge for promoted/quarantined corpus entries. `FuzzCorpusHashMetadata` stores:

- `raw_artifact_hash`
- `reduced_artifact_hash`
- `normalized_shape_hash`
- `predicate_hash`
- `feature_fact_hash`
- `interestingness_label`

`build_fuzz_corpus_hash_metadata(...)` hashes raw bytes or text through the same local corpus hash, uses the reduced artifact when present, hashes the replay/failure predicate separately, and sorts feature facts before hashing so equivalent fact sets produce the same metadata. `starshine.fuzz-corpus-entry.v1` entries now persist these fields beside the existing state/source/replay metadata. `[FUZ]1050D1` adds the report-only `normalized_shape_hash` entry field for canonical/normalized shape correlation; it is not a deduplication or deletion signal.

`[FUZ]1050B` adds `FuzzCorpusCaseIndex` / `FuzzCorpusCaseIndexEntry` plus `build_fuzz_corpus_case_index(...)`, `format_fuzz_corpus_case_index_json(...)`, and `parse_fuzz_corpus_case_index_json(...)`. The index groups entries by raw and reduced artifact hashes under the compact schema id `starshine.fuzz-corpus-case-index.v1`, preserving duplicate case ids, parsed seeds, profiles, and artifact paths. `[FUZ]1050D1` adds `normalized-shape` index rows from `normalized_shape_hash` while preserving raw artifact paths and leaving all dedup/compression decisions unchanged.

`[FUZ]1050C` adds the dry-run dedup classifier on top of that index. `classify_fuzz_corpus_dedup_dry_run(...)` returns a `FuzzCorpusDedupDryRunPlan` with `keep`, `duplicate`, and `compress` decisions; `format_fuzz_corpus_dedup_dry_run_json(...)` emits the report-only schema id `starshine.fuzz-corpus-dedup-dry-run.v1`. Raw artifact groups are always classified as `keep`, including duplicate raw hashes, because raw artifacts are originals and may be the only artifact for unreduced failures. Duplicate reduced-hash groups are classified as `compress` candidates, but the helper never deletes or rewrites files.

## Current Limits

This slice defines the schema, public in-package data shape, hash metadata helper, corpus-entry persistence fields, reversible case index, and report-only dry-run dedup classifier. It does not yet choose per-suite decoded-shape normalizers or perform any destructive dedup action; later tooling must preserve the dry-run invariant that sole unreduced artifacts are never deleted.
