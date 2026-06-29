# remove-unused-brs raw-gate/performance refresh

Date: 2026-06-29

Slice: `[O4Z-AUDIT-RUB-Q]` recursive complete-family audit.

## Scope

This slice records the raw-gate/performance accountability evidence requested after the accepted-boundary consolidation in notes `1382`-`1384`. No `remove-unused-brs` transform behavior changed.

The direct `pass-fuzz-compare` harness still does not report pass-local timings, so this slice used the existing `self-optimize-compare` timing lane on the checked-in reduced O4z startup repro. This is a bounded artifact timing probe, not a broad representative performance benchmark.

## Command and result

- `bun scripts/self-optimize-compare.ts tests/repros/o4z-debug-startup-map-init-repro.wasm --out-dir .tmp/self-opt-rub-q-raw-gate-timing-o4z-startup --starshine-bin target/native/release/build/cmd/cmd.exe --timing-only --remove-unused-brs`
  - Passed.
  - Artifact path: `.tmp/self-opt-rub-q-raw-gate-timing-o4z-startup`.
  - Effective input: `tests/repros/o4z-debug-startup-map-init-repro.wasm`.
  - Starshine raw wasm and canonicalized wasm size: `192892` bytes.
  - Binaryen raw/reference wasm size: `192892` bytes.
  - Canonical wasm equal: no; timing-only mode did not print normalized WAT or canonical function diffs.
  - Starshine whole-command runtime: `8.013 ms`.
  - Binaryen whole-command runtime: `8.997 ms`.
  - Starshine whole-command at least as fast: yes.
  - Starshine pass runtime: `0.684 ms`.
  - Binaryen pass runtime: `0.909 ms`.
  - Starshine pass at least as fast: yes.
  - Starshine raw runtime: `0.000 ms`.
  - Starshine other traced runtime: `4.272 ms`.
  - Starshine untraced/runtime overhead: `3.057 ms`.
  - `starshinePassSkippedRaw=true`, so this fixture exercises the current raw skip/no-op gate rather than a heavy HOT mutation family.

## Agent classification

This bounded timing lane satisfies the immediate raw-gate accountability request for a current artifact-backed repro: RUB skips raw work on the fixture and is faster than Binaryen pass-local under the harness (`0.684 ms` vs `0.909 ms`).

It does not replace the older large self-opt trace history in the RUB dossier, and it is not a full performance characterization. If a larger self-optimized debug artifact returns to this checkout, rerun a direct timing lane on that artifact and compare against the historical April RUB traces.
