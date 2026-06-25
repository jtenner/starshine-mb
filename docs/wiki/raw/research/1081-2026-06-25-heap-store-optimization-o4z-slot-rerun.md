---
kind: research
status: current
created: 2026-06-25
sources:
  - ./1071-2026-06-25-heap-store-optimization-direct-o4z-refresh.md
  - ./1077-2026-06-25-heap-store-optimization-no-candidate-unreachable-cleanup.md
  - ./1080-2026-06-25-heap-store-optimization-random-all-profiles-lane.md
  - ../../../../scripts/self-optimize-compare.ts
---

# HSO O4z Slot Replay After No-Candidate Cleanup

## Context

The `1071` O4z slot replay predated the later `1077` no-candidate raw cleanup fix. Final HSO closeout still needs current O4z slot/neighborhood evidence, so this slice replayed the saved generated O4z HSO predecessor artifacts after the no-candidate cleanup fix and random all-profiles lane work.

This is still no-candidate generated-artifact regression evidence, not source-family closeout. It does not close HSO-D/E/F/G/H or the allocation-heavy HSO-I performance gap.

## Inputs

Reused the current generated O4z predecessor artifacts from `1071`:

- `.tmp/hso-o4z-slot-evidence-20260625/prefix16-before-hso.wasm`
- `.tmp/hso-o4z-slot-evidence-20260625/prefix44-before-hso.wasm`

Validation:

```sh
wasm-tools validate --features all .tmp/hso-o4z-slot-evidence-20260625/prefix16-before-hso.wasm
wasm-tools validate --features all .tmp/hso-o4z-slot-evidence-20260625/prefix44-before-hso.wasm
```

Both commands succeeded.

The replay artifacts were copied under `.tmp/hso-o4z-slot-evidence-20260625-post-random/` so this note can be compared against `1071` without overwriting the older evidence.

## Slot 17 replay

Command:

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-o4z-slot-evidence-20260625-post-random/prefix16-before-hso.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-o4z-slot-evidence-20260625-post-random/slot17-hso-compare \
  --heap-store-optimization
```

Result:

| Metric | Result |
|---|---:|
| Canonical wasm equal | yes |
| Normalized WAT equal | yes |
| Starshine raw skip | yes |
| Starshine pass ms | 0.000 |
| Starshine raw ms | 0.000 |
| Binaryen pass ms | 43.439 |
| Starshine whole-command ms | 416.791 |
| Binaryen whole-command ms | 466.517 |
| Starshine at least as fast | yes |
| Starshine pass at least as fast | yes |

## Slot 45 replay

Command:

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-o4z-slot-evidence-20260625-post-random/prefix44-before-hso.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-o4z-slot-evidence-20260625-post-random/slot45-hso-compare \
  --heap-store-optimization
```

Result:

| Metric | Result |
|---|---:|
| Canonical wasm equal | yes |
| Normalized WAT equal | yes |
| Starshine raw skip | yes |
| Starshine pass ms | 0.000 |
| Starshine raw ms | 0.000 |
| Binaryen pass ms | 30.916 |
| Starshine whole-command ms | 340.410 |
| Binaryen whole-command ms | 275.187 |
| Starshine at least as fast | no |
| Starshine pass at least as fast | yes |

## Classification

Both generated O4z HSO slots remain exact/canonical and normalized-WAT matches, and Starshine still raw-fast-skips both with `0.000ms` pass-local time. The slot 45 whole-command slowdown persists outside HSO pass-local work and remains a `[WALL]001`/command-overhead concern unless a future HSO-candidate artifact shows pass-local HSO cost.

This advances HSO-B/J O4z-slot evidence after the `1077` cleanup fix. HSO-I remains open because the allocation-heavy candidate fixture in `1072` still measured Starshine HSO about `5.7x` slower than Binaryen pass-local.
