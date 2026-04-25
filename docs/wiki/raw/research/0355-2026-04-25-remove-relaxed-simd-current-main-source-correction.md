---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md
  - ../binaryen/2026-04-24-remove-relaxed-simd-primary-sources.md
  - ./0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/remove-relaxed-simd/index.md
  - ../../binaryen/passes/remove-relaxed-simd/binaryen-strategy.md
  - ../../binaryen/passes/remove-relaxed-simd/implementation-structure-and-tests.md
  - ../../binaryen/passes/remove-relaxed-simd/wat-shapes.md
  - ../../binaryen/passes/remove-relaxed-simd/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/wast/types.mbt
  - ../../../../src/wast/keywords.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/validate/typecheck.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/ir/hot_lift.mbt
  - ../../../../src/ir/hot_lower.mbt
supersedes:
  - ./0322-2026-04-24-remove-relaxed-simd-primary-sources-and-starshine-followup.md
related:
  - ../../binaryen/passes/late-pipeline-dispatch.md
  - ../../binaryen/passes/precompute/index.md
  - ../../binaryen/passes/strip-target-features/index.md
---

# `remove-relaxed-simd` current-main source correction

## Question

The 2026-04-24 `remove-relaxed-simd` dossier was complete enough to teach the pass, but it still said Binaryen skips each function when the module lacks the relaxed-SIMD feature and only refinalizes changed functions. A fresh current-main check re-read the official owner file to decide whether that feature-gate wording was source-backed and whether the open feature-metadata caveat could be narrowed.

## Sources reviewed

- Official Binaryen `version_129` and current-`main` `src/passes/RemoveRelaxedSIMD.cpp`.
- Official Binaryen `version_129` and current-`main` `src/passes/pass.cpp` and `src/passes/passes.h`.
- Official Binaryen `version_129` and current-`main` `test/lit/passes/remove-relaxed-simd.wast`.
- WebAssembly relaxed SIMD proposal overview for background on implementation-defined relaxed operations.
- Local Starshine relaxed-SIMD surfaces in `src/wast/`, `src/lib/types.mbt`, `src/validate/typecheck.mbt`, `src/binary/`, and HOT lift/lower files.

## Findings

- The core pass contract is unchanged: Binaryen still replaces matched relaxed SIMD expressions with a `block` ending in `unreachable` and still uses `ChildLocalizer` so child effects are preserved before the trap.
- The 2026-04-24 feature-gate wording was over-specific. The reviewed `RemoveRelaxedSIMD.cpp` does not contain a per-function `FeatureSet::RelaxedSIMD` guard. Its `doWalkFunction(...)` postwalks the function and then refinalizes it.
- The “changed functions” wording was also over-specific. The reviewed owner file does not maintain a `changed` flag around refinalization; it calls `ReFinalize().walkFunctionInModule(...)` after walking the function.
- The reviewed sources still do not show a feature-section cleanup step. That means future Starshine work should not promise Binaryen-like target-feature metadata deletion as part of this pass; keep that question separate from instruction replacement.
- Binaryen's source/lit names for the two relaxed dot-product operations omit the textual `relaxed_` prefix, while current Starshine WAT keyword names include it. This is a naming-surface caveat, not a semantic disagreement: both sides treat those opcodes as members of the relaxed-SIMD removal family.
- Starshine's local status remains unchanged: there is no `remove-relaxed-simd` registry entry, no dispatcher, no owner file, and no active backlog slice. Starshine can parse/lower/typecheck/encode/decode/HOT-lift relaxed SIMD instructions, but it does not remove them.

## Durable wiki updates made

- Added `docs/wiki/raw/binaryen/2026-04-25-remove-relaxed-simd-current-main-source-correction.md`.
- Refreshed the `remove-relaxed-simd` overview, Binaryen strategy, implementation/test-map, WAT-shape catalog, and Starshine status page.
- Updated the pass folder catalog, tracker, top-level wiki index, changelog, and wiki log.
- Marked the older 2026-04-24 research note as superseded for the feature-gate and changed-function wording while preserving it as the original dossier provenance.

## Current corrected teaching summary

Beginner version:

- `remove-relaxed-simd` traps at every relaxed SIMD operation instead of choosing a deterministic SIMD replacement.
- Operand effects are still preserved before the trap.
- Ordinary SIMD is not rewritten.
- The reviewed Binaryen owner file walks and refinalizes functions; do not teach a feature-gated per-function skip unless a future source adds one.

Advanced version:

- The source-backed implementation is a `WalkerPass<PostWalker<RemoveRelaxedSIMD>>` with explicit `visitUnary`, `visitBinary`, and `visitSIMDTernary` opcode lists.
- `rewrite(...)` delegates child preservation to `ChildLocalizer` and appends `makeUnreachable()`.
- `doWalkFunction(...)` calls `PostWalker::doWalkFunction(func)` followed by `ReFinalize().walkFunctionInModule(func, getModule())`.
- Registration remains public as `remove-relaxed-simd`; no feature-section mutation was observed in the reviewed pass sources.

## Follow-up questions

- If Starshine ports the pass, should it first register `remove-relaxed-simd` as a boundary-only name for clarity, or wait until the rewrite exists?
- Should a future Starshine WAT parser accept Binaryen's dot-product spellings without `relaxed_` as aliases, or keep current spelling and document the incompatibility?
- If a future source adds feature-section cleanup, should Starshine model that as part of `remove-relaxed-simd` or as an output-option pass closer to `strip-target-features`?
