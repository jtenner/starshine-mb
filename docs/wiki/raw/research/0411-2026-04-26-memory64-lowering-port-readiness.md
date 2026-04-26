---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md
  - ../binaryen/2026-04-25-memory64-lowering-static-offset-correction.md
  - ../binaryen/2026-04-25-memory64-lowering-current-main-recheck.md
  - ../binaryen/2026-04-24-memory64-lowering-primary-sources.md
  - ../../binaryen/passes/memory64-lowering/index.md
  - ../../binaryen/passes/memory64-lowering/starshine-strategy.md
related:
  - ../../binaryen/passes/memory64-lowering/starshine-port-readiness-and-validation.md
---

# `memory64-lowering` port-readiness follow-up

## Question

The existing `memory64-lowering` dossier was source-correct after the 2026-04-25 static-offset correction, but it still made a future Starshine implementer infer the safe first slice, local prerequisites, and validation order from the overview and Starshine status page.
Can we make the pass folder beginner-to-advanced usable without duplicating the existing Binaryen strategy pages?

## Findings

- `memory64-lowering` and `table64-lowering` should stay documented as one pass family because Binaryen shares the same owner-source family and the local prerequisites overlap heavily.
- The correct first Starshine slice is not a HOT peephole. It is an analyzer/no-op module pass that proves the registry status, identifies memory64/table64 declarations, active offsets, and former-i64 use sites, then refuses to mutate.
- The first mutating memory slice should rewrite memory declarations and active data offsets before function-body memory operations are enabled. Otherwise tests can accidentally validate a function-only lowering that still emits a memory64 module.
- Function-body memory lowering should start with scalar load/store and only then add size/grow, bulk memory, SIMD, and atomics. Grow is its own checkpoint because failure-sentinel repair is correctness-sensitive.
- Table64 should remain a later sibling slice because current Starshine table typechecking still hard-codes `i32` in several table operations even though `TableType` can carry `I64Limits`.
- Emscripten's `MEMORY64=2` setting is useful motivation: this is a compatibility lowering path for wasm64-internal workflows targeting wasm32 output, not an optimization pass.

## Files updated

- Added `docs/wiki/raw/binaryen/2026-04-26-memory64-lowering-port-readiness-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/memory64-lowering/starshine-port-readiness-and-validation.md`.
- Refreshed the `memory64-lowering` overview, Binaryen strategy, Starshine strategy, wiki indexes, tracker, and log so the new bridge is discoverable.

## Local code anchors

- `src/passes/optimize.mbt:127` / `:144` / `:156` - current registry arrays, where both public pass names are absent today.
- `src/lib/types.mbt:162` through `:177` - `Limits`, `MemType`, and `TableType` carriers for width-aware declarations.
- `src/lib/types.mbt:1263` and `:1366` - address-type and mixed-width helper behavior a future lowering must align with.
- `src/validate/typecheck.mbt:587`, `:602`, `:625`, and `:635` - current table operation hard-coded `i32` typing that blocks honest table64 lowering claims.
- `src/validate/typecheck.mbt:1538` through `:1577` - static memarg offset legality check, matching the Binaryen static high-offset family.
- `src/validate/typecheck.mbt:2408` through `:2480` - memory size/grow/init/copy address-width checks.

## Open risks

- Friendly diagnostics for lowered minimum limits remain an implementation-policy question; do not teach a polished Binaryen user-facing diagnostic until a source or oracle proves it.
- Table64 must not be conflated with memory64 readiness. Starshine's model has table limits, but the table instruction typechecker still needs cleanup before a faithful `table64-lowering` sibling can be accepted.
