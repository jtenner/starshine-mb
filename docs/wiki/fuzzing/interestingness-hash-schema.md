# Fuzz Interestingness Hash Schema

Starshine fuzz corpus and reduction tooling uses `starshine.fuzz-interestingness.v1` as the stable schema id for multi-layer interestingness keys. The runtime definition lives in [`src/fuzz/main.mbt`](../../../src/fuzz/main.mbt) as `fuzz_interestingness_hash_schema` and `FuzzInterestingnessCaseKey`; focused coverage lives in [`src/fuzz/main_wbtest.mbt`](../../../src/fuzz/main_wbtest.mbt).

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

Keeping fields separate makes the upcoming corpus dedup index reversible: a runner can deduplicate by one layer, by a prefix of layers, or by the full six-tuple while still pointing back to the original seed/profile and reduced artifact.

## Current Limits

This slice defines the schema and public in-package data shape only. It does not yet compute these hashes for every fuzz runner, persist a corpus index, or choose per-suite decoded-shape normalizers; those are follow-up FUZ slices.
