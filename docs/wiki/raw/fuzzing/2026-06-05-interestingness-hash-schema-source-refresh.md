# Fuzz Interestingness Hash Schema Source Refresh

- Capture date: 2026-06-05
- Source family: Starshine fuzz corpus/reduction metadata plus current FNV reference material

## External primary / high-quality sources checked

- RFC 9923, `The FNV Non-Cryptographic Hash Algorithm`: <https://datatracker.ietf.org/doc/html/rfc9923>. This is the current reference for FNV-1a as a non-cryptographic byte-at-a-time hash. It defines the FNV-1a order as XOR with the next octet before multiplying by the FNV prime modulo the selected power-of-two width, and records that the offset basis and prime depend on hash size.
- RFC Editor info page for RFC 9923: <https://www.rfc-editor.org/info/rfc9923>. This was used only to confirm the RFC identity and publication metadata; the algorithm details above come from the datatracker HTML.

## Local repository sources checked

- [`../../../../src/fuzz/main.mbt`](../../../../src/fuzz/main.mbt) owns `FuzzInterestingnessHashLayer`, `FuzzInterestingnessHashSchema`, `FuzzInterestingnessCaseKey`, `FuzzCorpusHashMetadata`, `FuzzCorpusPromotionMetadata`, `fuzz_corpus_hash_bytes(...)`, `build_fuzz_corpus_hash_metadata(...)`, `fuzz_interestingness_hash_schema()`, corpus-entry JSON formatting/parsing, case-index construction, and the dry-run dedup classifier.
- [`../../../../src/fuzz/main_wbtest.mbt`](../../../../src/fuzz/main_wbtest.mbt) locks the ordered six-layer schema, deterministic FNV-prefixed hash metadata, feature-fact sort stability, corpus-entry required fields, raw/reduced/normalized-shape index rows, and dry-run decisions that keep raw artifacts while only reporting duplicate or compress candidates.
- [`../../fuzzing/interestingness-hash-schema.md`](../../fuzzing/interestingness-hash-schema.md) was the living page refreshed by this source bridge.
- [`../../tooling/fuzz-corpus-policy.md`](../../tooling/fuzz-corpus-policy.md) is the policy page that consumes the schema fields for promoted/quarantined corpus entries.
- [`../../fuzzing/reduction-backends.md`](../../fuzzing/reduction-backends.md) is the reducer contract whose outputs can populate reduced-artifact hashes.
- [`../../tooling/pass-fuzz-compare.md`](../../tooling/pass-fuzz-compare.md) is the compare lane that supplies mismatch predicates, failure classes, normalized shapes, and reduced inputs.

## Durable takeaways

- Starshine intentionally uses a local `fnv1a64-*` digest string for corpus metadata. This is a deterministic identity/correlation key, not a cryptographic integrity or authenticity proof.
- The implementation matches the RFC 9923 FNV-1a update order for bytes: start from the 64-bit offset basis, XOR the next byte, then multiply by the 64-bit FNV prime with normal unsigned wraparound. Starshine formats the result as `fnv1a64-` plus sixteen lowercase hex digits.
- `starshine.fuzz-interestingness.v1` remains a six-layer vocabulary: raw, decoded-shape, feature-fact, normalized, predicate, and reduced-artifact.
- `FuzzCorpusHashMetadata` is the compact bridge into `starshine.fuzz-corpus-entry.v1`: raw artifact hash, reduced artifact hash, predicate hash, feature-fact hash, and an initial human-readable interestingness label. `normalized_shape_hash` lives on `FuzzCorpusPromotionMetadata`, not in the smaller hash-metadata helper.
- `build_fuzz_corpus_hash_metadata(...)` sorts feature facts before hashing them. This means equivalent feature sets with different generator enumeration order produce the same `feature_fact_hash`.
- `build_fuzz_corpus_case_index(...)` currently emits `raw`, `reduced`, and `normalized-shape` rows. The dry-run dedup classifier always keeps raw groups, reports duplicate non-raw groups, and marks duplicate reduced groups as future compression candidates only. No helper deletes or rewrites artifacts.

## Uncertainties and boundaries

- The page should not promise collision resistance. FNV-1a is fast and deterministic but non-cryptographic; consumers must retain original/reduced artifact paths and replay predicates so a rare collision remains diagnosable.
- The `decoded-shape` and full `normalized` layers are schema vocabulary today. The current code has corpus-entry fields and a report-only `normalized_shape_hash`, but it does not yet define per-suite decoded-shape normalizers or a destructive dedup action.
- Future tooling may add stronger hashes beside the existing fields, but changing the meaning or ordering of `starshine.fuzz-interestingness.v1` layers would be a compatibility-affecting schema change requiring docs, tests, index, and log updates.
