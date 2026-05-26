# Golden Seed Catalog

The golden seed catalog is the maintained, intentionally small set of deterministic fuzz seeds used for smoke-level self-tests and examples. Broad coverage remains the job of CI and stress fuzzing; this catalog exists to keep representative GenValid, invalid-input, pass-fuzz, reduction, and text roundtrip surfaces easy to replay and review.

## Schema

Catalog documents use schema `starshine.fuzz.golden-seed-catalog.v1` and are formatted by `format_golden_seed_catalog_json(...)` in `src/fuzz/main.mbt`.

Each entry records:

- `id` - stable unique catalog id.
- `suite` - fuzz suite or external adapter name.
- `profile` - suite profile or recipe profile.
- `seed` - unsigned 64-bit deterministic root seed.
- `expected_counters` - exact or minimum smoke counters to assert in follow-up runners.
- `covered_surfaces` - maintained feature, strategy, or tool surfaces intentionally covered by the seed.
- `artifacts` - logical output files expected from the suite or adapter.
- `notes` - human maintenance note explaining why the seed exists.

The checked-in smoke catalog lives in [`golden-seed-catalog.json`](golden-seed-catalog.json). The source of truth for the same entries is `golden_seed_smoke_suite_catalog()` so tests and docs stay aligned. The executable smoke runner is `moon run src/fuzz -- --golden-seed-smoke`; it currently locks the standard `smoke` recipe's high-level `validate-valid` counters (`attempts=128`, `validated=128`, and `coverage-forced` generator config) and fails if those drift unexpectedly.

## Current smoke entries

- `gen-valid-coverage-forced-smoke` covers the portable GenValid valid-module smoke lane.
- `invalid-ast-repro-smoke` covers invalid AST strategy metadata and validator rejection.
- `invalid-binary-repro-smoke` covers binary decode and validation-stage repro metadata.
- `invalid-text-repro-smoke` covers text parse/lower/validate diagnostics.
- `pass-fuzz-metadata-smoke` covers pass-fuzz compare metadata, Binaryen oracle comparison, and normalization outputs.
- `minimization-repro-smoke` reserves the deterministic reducer replay surface.
- `wast-roundtrip-smoke` covers non-binary WAST/text roundtrip infrastructure.

## Maintenance rules

- Keep the catalog small and intentional; do not add bulk coverage seeds here.
- Update the MoonBit catalog, the JSON document, and this page together when entries change.
- Prefer minimum counters for smoke-stable coverage unless an exact counter is deliberately part of the contract.
- Add or update `--golden-seed-smoke` assertions when counters become executable or when the stable smoke recipe intentionally changes.
