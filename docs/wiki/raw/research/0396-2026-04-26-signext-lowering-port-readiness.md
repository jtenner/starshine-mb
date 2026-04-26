---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-signext-lowering-port-readiness-primary-sources.md
  - ../binaryen/2026-04-25-signext-lowering-implementation-test-map-source-correction.md
  - ../binaryen/2026-04-25-signext-lowering-primary-sources.md
  - ../../../binaryen/passes/signext-lowering/index.md
  - ../../../binaryen/passes/signext-lowering/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/lib/show.mbt
---

# `signext-lowering` port-readiness bridge

## Question

The existing `signext-lowering` folder had a source-correct Binaryen dossier, but it still made a future implementer infer the first Starshine slice, validation ladder, feature-metadata caveat, and local hygiene blockers from separate pages. This note records the focused 2026-04-26 bridge.

## Findings

- Official Binaryen `version_129` and current `main` still implement `signext-lowering` as a small function-parallel postwalk in `src/passes/SignExtLowering.cpp`.
- The pass rewrites only the five same-width sign-extension opcodes to exact `shl` + signed `shr_s` pairs: `24`, `16`, `56`, `48`, and `32`.
- Binaryen also disables `FeatureSet::SignExt`. The owner file proves that side effect; the dedicated `signext-lowering.wast` fixture proves instruction shape but should not be cited alone for feature-section removal.
- Starshine has no registry, dispatcher, or owner-file entry for `signext-lowering`; `src/passes/optimize.mbt` omits it from boundary-only and removed lists, and `src/passes/pass_manager.mbt` has no dispatcher case.
- Starshine already parses, lowers, validates, encodes, decodes, HOT-lifts, and optimizes around the five direct sign-extension opcodes. That makes an instruction-only first slice feasible.
- `src/lib/show.mbt` still prints no-underscore names such as `i32.extend8s`. Future WAT-golden tests should fix or bypass that before relying on textual output.

## Recommended future port shape

1. Add failing reduced tests for the five direct opcodes.
2. Add an effectful-child reduced test where the child appears exactly once after rewriting.
3. Add a negative `i64.extend_i32_s` / `i64.extend_i32_u` test.
4. Implement a tiny function/HOT rewrite that moves the child under `shl` and wraps with signed `shr_s`.
5. Validate after rewriting.
6. Register the pass only after the rewrite is real.
7. Mark target-feature metadata either as intentionally unchanged in the first slice or implement explicit cleanup before claiming full Binaryen parity.
8. Compare against `wasm-opt --signext-lowering` once the local pass name is public.

## Durable wiki updates

- Added `docs/wiki/raw/binaryen/2026-04-26-signext-lowering-port-readiness-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/signext-lowering/starshine-port-readiness-and-validation.md`.
- Refreshed the signext overview, Binaryen strategy, Starshine strategy, pass catalog, tracker, wiki index, and wiki log to expose the first-slice and validation bridge.

## Uncertainty

The only material parity uncertainty is feature metadata: Binaryen owns a module feature set and clears `FeatureSet::SignExt`; Starshine currently preserves opaque custom sections and does not expose an equivalent feature model in the reviewed local code. A local first slice can still be useful if it is documented as instruction-only lowering.
