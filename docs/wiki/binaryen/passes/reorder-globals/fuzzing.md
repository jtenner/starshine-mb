---
kind: workflow
status: strong
last_reviewed: 2026-09-22
sources:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_reorder_globals.mbt
  - ../../../../../src/validate/gen_valid_reorder_globals_wbtest.mbt
  - ../../../../../src/passes/reorder_globals_wbtest.mbt
  - ../../../../../src/passes_perf_long/reorder_globals_perf_test.mbt
  - ../../../../../src/fuzz/main.mbt
  - ../../../../../src/fuzz/main_wbtest.mbt

---

# `reorder-globals` fuzzing profile

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

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

The aggregate aliases are `reorder-globals`, `reorder-globals-closeout`, and `reorder-globals-all-profiles`. Manifest metadata records the selected leaf plus a pass-owned family label. `src/validate/gen_valid_reorder_globals_wbtest.mbt` validates every seeded subfamily, and `src/fuzz/main_wbtest.mbt` requires all seven leaves and all 20 labels to appear in a bounded aggregate manifest.

Focused white-box coverage in `src/passes/reorder_globals_wbtest.mbt` separately proves the zero/raw/summed/exponential search vectors, the exact `0.095` exponential factor, true ULEB-cost selection, and first-candidate tie stability.

## Oracle and source anchors

The 2026-07-29 closeout used:

- native Starshine: `_build/native/release/build/cmd/cmd.exe`
- native SHA-256: `d09b0100360cb83d87545fb1ca92e98f01780882d1649acf2aa96293d364aadc`
- explicit official oracle: `.tmp/binaryen-version-131-bin/bin/wasm-opt`
- oracle text: `wasm-opt version 131 (version_131)`
- oracle SHA-256: `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`
- source checkout: tag `version_131`, commit `1f903c14babf829745b421b92ff0f286e93e4209`
- `ReorderGlobals.cpp` SHA-256: `4b15caef4d7436e67efd1da90d1a53201e2acf029a686349f1dfd360d1a10194`
- `reorder-globals.wast` SHA-256: `11703272b84aface8143a98544b9877be72062e5028cac79417f859445dc7c7d`
- `reorder-globals-real.wast` SHA-256: `52d0cfb47d008487f52fe1630eeb3e4484780dfc3a850948f92913d6ec63a70b`
- default persistent cache: `.tmp/pass-fuzz-cache`
- `--jobs auto`, which resolved to 16 workers

The source audit found a real shape-parity gap: Binaryen's `module->globals` order includes imported globals, so a hot imported global can move within the import prefix. The 2026-07-29 implementation copied that behavior and produced the historical exact results below.

The 2026-09-22 host-observability correction supersedes imported-global shape parity. Starshine now keeps the import section in declaration order because reordering imports changes the order in which hosts can resolve side-effecting getters. Traffic and dependencies still use the complete absolute global index space, eligible defined globals still reorder, and every moved defined-global index is remapped. The historical imported-global exactness and performance output hashes below remain provenance for the earlier behavior; they are not current signoff for the corrected import-order contract.

## Full four-lane matrix

| Lane | Seed | Out dir | Requested / compared | Direct normalized | Cleanup-normalized | Raw mismatches | Failures | Cache |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| regular GenValid | `0x5eed` | `.tmp/pass-fuzz-reorder-globals-perf-heap-regular-100000-20260729` | `100000 / 100000` | `100000` | `0` | `0` | validation/property/generator/command `0` | Binaryen `100000/0`; failures `0/0` |
| dedicated `reorder-globals-all` | `0x5eed` | `.tmp/pass-fuzz-reorder-globals-perf-heap-dedicated-10000-20260729` | `10000 / 10000` | `10000` | `0` | `0` | validation/property/generator/command `0` | Binaryen `10000/0`; failures `0/0` |
| random all-profiles | `0x5555` | `.tmp/pass-fuzz-reorder-globals-perf-heap-random-all-10000-20260729` | `10000 / 10000` | `9375` | `0` | `625` | validation/property/generator/command `0` | Binaryen `10000/0`; failures `0/0` |
| explicit wasm-smith, required unnormalized run | `0x5eed` | `.tmp/pass-fuzz-reorder-globals-perf-heap-wasm-smith-10000-20260729` | `10000 / 9956` | `9955` | `0` | `1` | 44 Binaryen/tool failures: rec-group-zero `39`, invalid-tag-index `1`, table-index-out-of-range `1`, bad-section-size `3`; zero Starshine failures | wasm-smith `10000/0`; Binaryen `9956/0`; failures `44/0` |
| wasm-smith classification confirmation with `unreachable-control-debris` | `0x5eed` | `.tmp/pass-fuzz-reorder-globals-perf-heap-wasm-smith-10000-unreachable-normalized-20260729` | `10000 / 9956` | `9955` | `1` | `0` | same 44 Binaryen/tool failures | wasm-smith `10000/0`; Binaryen `9956/0`; failures `44/0` |

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

For the recorded 2026-07-29 implementation, every pass-owned family was an exact Binaryen-v131 normalized match. The current stable-import contract intentionally changes the imported-global family and requires fresh evidence before any new whole-pass exact-parity claim.

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

The 2026-07-29 performance follow-up removes the quadratic ready-candidate scan. Dependency-constrained candidates now use a max heap, the zero-count topological order is reused for both dependent-count accumulations, and dependency-free modules compare only the original order with one sorted greedy order because summed and exponential counts equal the true counts when there are no edges.

Nine interleaved native-release command runs use two 2,000-global / 20,000-use fixtures:

| Fixture | Starshine median | Binaryen-v131 median | Ratio | Output |
| --- | ---: | ---: | ---: | --- |
| 2,000 immutable imported globals, final import hot | `0.742 ms` | `1.68593 ms` | `0.440x` | byte-identical, SHA-256 `a3efed97a79dcce8004edd91f32828b1bcd5ee9b92f6237fbba1eba9e7d65b9f` |
| 2,000-global initializer chain, final definition hot | `0.762 ms` | `1.49234 ms` | `0.511x` | byte-identical, SHA-256 `431a18bdb671ccf81c65acefc27499ce2712f63b5e6ed749d7c287ce61d1d1eb` |

The import-heavy Starshine median fell from `70.079 ms` to `0.742 ms`, a `98.94%` reduction, and is about `2.27x` faster than Binaryen on that fixture. The dependency-heavy heap path is about `1.96x` faster than Binaryen. Both outputs validate externally.

`src/passes_perf_long/reorder_globals_perf_test.mbt` keeps an opt-in native-release guard for both families. Its nine-sample in-process medians were `1,174 us` imported and `1,083 us` dependency-heavy, with a `20 ms` ceiling that would reject the former quadratic implementation while remaining tolerant of ordinary host variance.

Reopen performance work if either retained fixture exceeds `2x` Binaryen pass-local time, the skipped native-release lane exceeds `20 ms`, output equality or validity changes, or a new dependency topology exposes heap-ordering overhead not represented by these two extremes.

## Closeout verdict and reopening criteria

The recorded Binaryen-v131 behavior-parity matrix is historical after the 2026-09-22 imported-global safety correction. Reopen non-import families if:

- Binaryen changes the public threshold, candidate family, exponential factor, true-cost model, or tie policy;
- imported declaration order changes, or eligible defined globals stop reordering after the fixed import prefix;
- any dedicated family stops generating its intended opportunity or boundary;
- a pass-owned family develops a non-exact normalized result;
- protected-body, typed-catch, catch-all, delegate, or `try_table` traffic/remapping regresses;
- table/global initializers, element offsets/items, data offsets, exports, structured names, or stale raw names regress;
- Starshine produces any validation, generator, property, or command failure;
- a residual contains a real reorder opportunity and cannot be classified from inspected source, input/output, size, and validity evidence;
- either retained large-global fixture exceeds `2x` Binaryen pass-local time or the skipped native-release guard exceeds `20 ms`.

### September 15 portable runtime renewal

The eleven function-reference import cases now complete and match across the
original, fresh Starshine and a separately encoded portable v132 oracle copy.
All oracle re-disassemblies are identical; original compact-import bytes remain
preserved. These cases have no exports/invocations and observe construction,
instantiation and 129 imported globals. Raw compact-import size policy and name
metadata remain distinct from this observation closure.
[Provenance and limits](../../../ir2/architecture-rules.md#reorder-globals-compatible-encoding-runtime-renewal).
