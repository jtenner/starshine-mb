---
kind: workflow
status: strong
last_reviewed: 2026-07-29
sources:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_reorder_globals.mbt
  - ../../../../../src/validate/gen_valid_reorder_globals_tests.mbt
  - ../../../../../src/fuzz/main.mbt
  - ../../../../../src/fuzz/main_wbtest.mbt
---

# `reorder-globals` fuzzing profile

## Current closeout profile

Use `--gen-valid-profile reorder-globals-all`. The weighted aggregate has seven leaves:

| Leaf | Weight | Required family coverage |
| --- | ---: | --- |
| `reorder-globals-hot-traffic` | 3 | function-body `global.get` and mutable `global.set` heat |
| `reorder-globals-dependency-search` | 3 | original-order, raw-greedy, summed-dependent, and branching-DAG candidate behavior |
| `reorder-globals-imported` | 2 | 129 imported globals, hot imported-global movement, and numeric user remapping |
| `reorder-globals-module-code` | 3 | element/data offsets, table initializer expressions, and typed element-expression items |
| `reorder-globals-legacy-eh` | 3 | protected body, typed catch, catch-all, delegate-bearing nested legacy `try`, and `try_table` protected body |
| `reorder-globals-metadata-remap` | 2 | exported-global and structured global-name remapping |
| `reorder-globals-threshold` | 1 | 127-global public no-op, 128-global equal-cost stability, and 129-global ULEB opportunity |

The aggregate aliases are `reorder-globals`, `reorder-globals-closeout`, and `reorder-globals-all-profiles`. Manifest metadata records the selected leaf plus a pass-owned family label. `src/validate/gen_valid_reorder_globals_tests.mbt` validates every seeded subfamily, and `src/fuzz/main_wbtest.mbt` requires all seven leaves and all 20 labels to appear in a bounded aggregate manifest.

Focused white-box coverage in `src/passes/reorder_globals_wbtest.mbt` separately proves the zero/raw/summed/exponential search vectors, the exact `0.095` exponential factor, true ULEB-cost selection, and first-candidate tie stability.

## Oracle and source anchors

The 2026-07-29 closeout used:

- native Starshine: `_build/native/release/build/cmd/cmd.exe`
- native SHA-256: `0d905fcc5f4cf7b03ffb1b635cdadd4627bfd7304c14bd0befd1c1334680e1a5`
- explicit official oracle: `.tmp/binaryen-version-131-bin/bin/wasm-opt`
- oracle text: `wasm-opt version 131 (version_131)`
- oracle SHA-256: `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`
- source checkout: tag `version_131`, commit `1f903c14babf829745b421b92ff0f286e93e4209`
- `ReorderGlobals.cpp` SHA-256: `4b15caef4d7436e67efd1da90d1a53201e2acf029a686349f1dfd360d1a10194`
- `reorder-globals.wast` SHA-256: `11703272b84aface8143a98544b9877be72062e5028cac79417f859445dc7c7d`
- `reorder-globals-real.wast` SHA-256: `52d0cfb47d008487f52fe1630eeb3e4484780dfc3a850948f92913d6ec63a70b`
- default persistent cache: `.tmp/pass-fuzz-cache`
- `--jobs auto`, which resolved to 16 workers

The source audit found a real parity gap: Binaryen's `module->globals` order includes imported globals, so a hot imported global can move within the import prefix. Starshine previously ordered only defined globals. The repaired implementation now uses the complete absolute global index space, keeps all imported globals before definitions, permits imported globals to reorder among themselves, rewrites the global-import subsequence without moving non-global imports, and remaps every represented numeric global-index surface.

## Full four-lane matrix

| Lane | Seed | Out dir | Requested / compared | Direct normalized | Cleanup-normalized | Raw mismatches | Failures | Cache |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| regular GenValid | `0x5eed` | `.tmp/pass-fuzz-reorder-globals-v131-closeout-regular-100000-20260729` | `100000 / 100000` | `100000` | `0` | `0` | validation/property/generator/command `0` | Binaryen `100000/0`; failures `0/0` |
| dedicated `reorder-globals-all` | `0x5eed` | `.tmp/pass-fuzz-reorder-globals-v131-closeout-dedicated-10000-20260729` | `10000 / 10000` | `10000` | `0` | `0` | validation/property/generator/command `0` | Binaryen `10000/0`; failures `0/0` |
| random all-profiles | `0x5555` | `.tmp/pass-fuzz-reorder-globals-v131-closeout-random-all-10000-20260729` | `10000 / 10000` | `9375` | `0` | `625` | validation/property/generator/command `0` | Binaryen `10000/0`; failures `0/0` |
| explicit wasm-smith, required unnormalized run | `0x5eed` | `.tmp/pass-fuzz-reorder-globals-v131-closeout-wasm-smith-10000-20260729` | `10000 / 9956` | `9955` | `0` | `1` | 44 Binaryen/tool failures: rec-group-zero `39`, invalid-tag-index `1`, table-index-out-of-range `1`, bad-section-size `3`; zero Starshine failures | wasm-smith `10000/0`; Binaryen `9956/0`; failures `44/0` |
| wasm-smith classification confirmation with `unreachable-control-debris` | `0x5eed` | `.tmp/pass-fuzz-reorder-globals-v131-closeout-wasm-smith-10000-unreachable-normalized-20260729` | `10000 / 9956` | `9955` | `1` | `0` | same 44 Binaryen/tool failures | wasm-smith `10000/0`; Binaryen `9956/0`; failures `44/0` |

Commands used explicit `--wasm-opt-bin .tmp/binaryen-version-131-bin/bin/wasm-opt`, `--jobs auto`, `--starshine-bin _build/native/release/build/cmd/cmd.exe`, `--max-failures 2000`, `--keep-going-after-command-failures`, and `--no-reduce-mismatches`.

## Dedicated distribution

Every leaf and label appeared in the 10,000-case aggregate:

- dependency search `1791`: original-order `462`, summed-count `438`, greedy `442`, branching DAG `449`
- hot traffic `1764`: gets `891`, sets `873`
- imported globals `1161`
- module code `1829`: element offset `458`, data offset `452`, table initializer `451`, element item `468`
- legacy EH `1711`: protected `379`, typed catch `324`, catch-all `333`, delegate `336`, `try_table` `339`
- metadata remap `1183`
- threshold `561`: 127 globals `181`, 128 globals `189`, 129 globals `191`

Agent classification: every pass-owned family is an exact Binaryen-v131 normalized match. There is no retained Starshine-only representation difference for a `reorder-globals` opportunity or boundary.

## Residual classifications

### Random-all 625-case multivalue codec family

All 625 mismatches select `remove-unused-brs-control` and contain no globals, so both reorder implementations are no-ops. The difference is the established pass-independent multivalue boundary lowering: Starshine's canonical output is exactly 8 bytes smaller in every case, for `-5000` bytes total. Agent classification: measured Starshine codec/lowering win outside `reorder-globals`; no reorder opportunity, traffic count, dependency, import, threshold, EH, module-code, or remap behavior differs.

### wasm-smith case `009332`

The input contains no globals. Binaryen emits a short unreachable tail while Starshine retains one additional `drop(unreachable)` wrapper. The existing `unreachable-control-debris` normalizer converts the sole raw mismatch into one cleanup-normalized match. Agent classification: pass-independent unreachable representation debris, not a reorder semantic or size claim.

### Binaryen/tool failures

The 44 wasm-smith failures occur before a comparable Binaryen pass result exists:

- zero-length recursion group: `39`
- invalid tag index: `1`
- table index out of range: `1`
- bad section size: `3`

Starshine has zero validation, generator, property, or command failures in every lane.

## Performance

A retained synthetic import-heavy fixture contains 2,000 immutable imported globals and 20,000 uses of the final imported global. The input is 104,933 bytes. Nine interleaved native-release runs on the final binary report:

- Starshine pass-local median: `70.079 ms`
- Binaryen-v131 pass-local median: `1.7762 ms`
- ratio: `39.45x`

The implementation is much slower than Binaryen on this deliberately large ordering workload, but remains well below the repository's `<1s` pass-local acceptance target. Both tools produce externally valid, byte-identical output with SHA-256 `a3efed97a79dcce8004edd91f32828b1bcd5ee9b92f6237fbba1eba9e7d65b9f`. Reopen performance work if a representative artifact exceeds one second, this fixture regresses materially, or the global-count scale grows enough for the current quadratic ready-candidate scan to dominate the late pipeline.

## Closeout verdict and reopening criteria

Direct Binaryen-v131 behavior parity is closed. Reopen if:

- Binaryen changes the public threshold, candidate family, exponential factor, true-cost model, or tie policy;
- imported globals no longer remain globally sortable within the import prefix, or non-global import positions move;
- any dedicated family stops generating its intended opportunity or boundary;
- a pass-owned family develops a non-exact normalized result;
- protected-body, typed-catch, catch-all, delegate, or `try_table` traffic/remapping regresses;
- table/global initializers, element offsets/items, data offsets, exports, structured names, or stale raw names regress;
- Starshine produces any validation, generator, property, or command failure;
- a residual contains a real reorder opportunity and cannot be classified from inspected source, input/output, size, and validity evidence;
- pass-local time exceeds the `<1s` target on a representative large-global workload.
