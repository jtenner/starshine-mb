---
kind: research
status: absorbed
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-signext-lowering-implementation-test-map-source-correction.md
  - ../binaryen/2026-04-25-signext-lowering-primary-sources.md
  - ../../binaryen/passes/signext-lowering/index.md
  - ../../binaryen/passes/signext-lowering/implementation-structure-and-tests.md
  - ../../binaryen/passes/signext-lowering/binaryen-strategy.md
  - ../../binaryen/passes/signext-lowering/wat-shapes.md
  - ../../binaryen/passes/signext-lowering/starshine-strategy.md
---

# `signext-lowering` Implementation/Test Map Follow-up

## Question

The existing `signext-lowering` dossier had overview, Binaryen strategy, WAT-shape, and Starshine status pages, but it lacked the now-standard implementation/test-map page used by neighboring pass dossiers. While filling that gap, this run also checked whether the earlier wording overstated what the dedicated Binaryen lit file proves about feature metadata.

## Findings

- Binaryen `version_129` and current `main` still teach the same small pass: `SignExtLowering.cpp` rewrites exactly the five sign-extension unary opcodes to same-width shift pairs and then disables `FeatureSet::SignExt`.
- `pass.cpp` and `passes.h` only provide public registration/factory plumbing; there is no hidden helper engine, CFG analysis, use-def analysis, effect analysis, or profitability rule behind the pass.
- `test/lit/passes/signext-lowering.wast` directly proves all five opcode-to-shift-pair output shapes.
- The feature-clearing side effect is source-proven in the owner file, but this run did not find a direct target-feature custom-section assertion in the dedicated lit fixture. The living pages now state that distinction explicitly instead of implying the lit file independently proves feature annotation removal.

## Local Starshine status checked

- `src/passes/optimize.mbt` still has no active, boundary-only, removed, module, or preset `signext-lowering` entry.
- `src/passes/pass_manager.mbt` still has no dispatcher case.
- Existing sign-extension instruction support remains prerequisite-only: WAT opcode cases, keyword mapping, parser test, WAT-to-lib lowering, lib instruction constructors, binary opcodes, typechecker cases/tests, HOT unary lifting, and `pick-load-signs` consumer recognition.
- The known `src/lib/show.mbt` underscore caveat remains relevant for future roundtrip tests.

## Durable wiki changes

Added:

- `docs/wiki/raw/binaryen/2026-04-25-signext-lowering-implementation-test-map-source-correction.md`
- `docs/wiki/binaryen/passes/signext-lowering/implementation-structure-and-tests.md`

Refreshed:

- `docs/wiki/binaryen/passes/signext-lowering/index.md`
- `docs/wiki/binaryen/passes/signext-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signext-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/signext-lowering/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`

## Uncertainty

The historical introduction release for `signext-lowering` remains outside this follow-up. The actionable local uncertainty is still Starshine's lack of a Binaryen-identical target-feature model: a future implementation must decide whether to rewrite target-feature custom sections, add feature state, or intentionally document instruction-only lowering.
