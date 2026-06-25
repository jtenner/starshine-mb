---
kind: research
status: active
created: 2026-06-25
sources:
  - ./0847-2026-06-20-heap-store-optimization-o4z-slot-evidence.md
  - ./0777-2026-06-20-heap-store-optimization-hso-b-direct-baseline.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../../agent-todo.md
---

# `heap-store-optimization` direct and O4z slot refresh

## Question

Refresh HSO-B evidence with the explicit native Starshine binary after the generated old-field coverage work through `1070`, and recheck the current generated `-O4z` HSO slot/neighborhood replay against local Binaryen `version_130`.

## Answer

The refreshed direct 10000-case lane is normalized-green, and the generated O4z slot replay still shows exact equality at both current HSO predecessor artifacts with Starshine raw-fast-skip.

This advances HSO-B but does **not** close the HSO audit. The slot replay is still no-candidate generated-artifact regression evidence, not proof that all source-backed HSO directional movement and barrier families are implemented. HSO-D/E/F/G/H/I/J remain open in `agent-todo.md`.

## Environment

- Local Binaryen oracle: `wasm-opt version 130 (version_130)`.
- `wasm-tools`: `wasm-tools 1.251.0 (a1a178a02 2026-05-28)`.
- Starshine binary rebuilt with:

```sh
moon build --target-dir target --target native --release src/cmd
```

The explicit `--target-dir target` form was used so `target/native/release/build/cmd/cmd.exe` is refreshed in this workspace.

## Direct compare refresh

Command:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-direct-refresh-20260625-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

| Metric | Count |
|---|---:|
| Requested | 10000 |
| Compared | 10000 |
| Normalized matches | 10000 |
| Cleanup-normalized matches | 0 |
| Raw mismatches | 0 |
| Validation failures | 0 |
| Property failures | 0 |
| Generator failures | 0 |
| Command failures | 0 |
| Binaryen cache | 10000 hits / 0 misses |

Agent classification: no HSO behavior mismatch was observed in this direct lane. This is compare evidence only and does not supersede the source-backed open-family checklist.

## O4z slot replay

Input generation and predecessor materialization reused the `0847` command shape against the current `_build/wasm/debug/build/cmd/cmd.wasm` generated artifact. The current Binaryen O4z debug path still contains the two top-level HSO slots represented by these predecessor artifacts:

- slot 17 predecessor after the early `optimize-instructions` slot;
- slot 45 predecessor after the late `optimize-instructions` slot.

Both predecessor artifacts validated with `wasm-tools validate --features all`.

### Slot 17

Command:

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-o4z-slot-evidence-20260625/prefix16-before-hso.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-o4z-slot-evidence-20260625/slot17-hso-compare \
  --heap-store-optimization
```

Result:

| Metric | Result |
|---|---:|
| Canonical wasm equal | yes |
| Normalized WAT equal | yes |
| Starshine raw skip | yes |
| Starshine pass ms | 0.000 |
| Binaryen pass ms | 54.731 |
| Starshine whole-command ms | 486.032 |
| Binaryen whole-command ms | 602.449 |
| Starshine size | 4101103 |
| Binaryen size | 4101103 |

### Slot 45

Command:

```sh
bun scripts/self-optimize-compare.ts \
  .tmp/hso-o4z-slot-evidence-20260625/prefix44-before-hso.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/hso-o4z-slot-evidence-20260625/slot45-hso-compare \
  --heap-store-optimization
```

Result:

| Metric | Result |
|---|---:|
| Canonical wasm equal | yes |
| Normalized WAT equal | yes |
| Starshine raw skip | yes |
| Starshine pass ms | 0.000 |
| Binaryen pass ms | 38.498 |
| Starshine whole-command ms | 406.489 |
| Binaryen whole-command ms | 346.955 |
| Starshine size | 2394856 |
| Binaryen size | 2394856 |

Agent classification: both generated O4z HSO slots remain no-candidate raw-fast-skip matches. Slot 45 still shows Starshine whole-command overhead despite `0.000ms` HSO pass time; that belongs to the broader wall-time budget unless a future HSO-candidate artifact shows pass-local HSO cost.

## Follow-up

- Keep HSO-B open until final closeout includes the required full direct/signoff lanes and source-backed family checklist review.
- Keep HSO-I open: this note refreshes no-candidate slot performance only and does not improve or accept the allocation-heavy candidate slowdown from `0870`.
