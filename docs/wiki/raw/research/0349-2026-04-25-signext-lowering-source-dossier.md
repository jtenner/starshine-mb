---
kind: research
status: absorbed
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-signext-lowering-primary-sources.md
  - ../../binaryen/passes/signext-lowering/index.md
  - ../../binaryen/passes/signext-lowering/binaryen-strategy.md
  - ../../binaryen/passes/signext-lowering/wat-shapes.md
  - ../../binaryen/passes/signext-lowering/starshine-strategy.md
---

# `signext-lowering` Source Dossier

## Question

The pass tracker no longer had an obvious `none` queue, so this run looked for a newly justified upstream-only Binaryen transformation that is not already covered by the Starshine pass wiki. `signext-lowering` qualified because:

- Binaryen exposes it as a real public pass with a compact owner file and dedicated lit test.
- Starshine already parses, validates, encodes, HOT-lifts, and optimizes around sign-extension opcodes.
- Existing `pick-load-signs` and `optimize-instructions` pages mention sign-extension, but no page explained the separate feature-lowering pass that removes sign-extension opcodes entirely.

## Findings

- Binaryen `version_129` `src/passes/SignExtLowering.cpp` is a tiny function-parallel `PostWalker` over unary nodes.
- It rewrites exactly five opcodes:
  - `i32.extend8_s`
  - `i32.extend16_s`
  - `i64.extend8_s`
  - `i64.extend16_s`
  - `i64.extend32_s`
- Each rewrite is a same-width left shift followed by arithmetic right shift. The shift counts are `24`, `16`, `56`, `48`, and `32`, respectively.
- The pass also removes Binaryen's `FeatureSet::SignExt` bit from the module. That makes it feature lowering, not just a peephole canonicalization.
- The dedicated `signext-lowering.wast` lit test covers all five output families. It does not prove neighboring sign-extension optimizations, which remain owned by other passes.
- A focused current-main check on 2026-04-25 found no teaching-relevant drift from the reviewed `version_129` implementation or dedicated test.

## Local Starshine status

- `src/passes/optimize.mbt` does not register `signext-lowering` as active, boundary-only, removed, or preset.
- `src/passes/pass_manager.mbt` has no dispatcher case or owner path for this pass.
- `src/wast/types.mbt`, `src/wast/keywords.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/lib/types.mbt`, `src/binary/encode.mbt`, `src/validate/typecheck.mbt`, `src/ir/hot_lift.mbt`, and `src/passes/pick_load_signs.mbt` are prerequisite surfaces, not an implementation.
- `src/lib/show.mbt` currently prints sign-extension mnemonics without underscores (`i32.extend8s` etc.); this dossier records that as a WAT hygiene caveat around future testing, not as part of the Binaryen pass contract.

## Durable wiki changes

Created a new living dossier under `docs/wiki/binaryen/passes/signext-lowering/`:

- `index.md` - pass overview, invariants, validation guidance, and source map.
- `binaryen-strategy.md` - upstream strategy and proof surface.
- `wat-shapes.md` - concrete before/after shape catalog for all five opcodes plus non-goals.
- `starshine-strategy.md` - current unknown-pass status, exact code-location map, and future port plan.

Also updated:

- `docs/wiki/raw/binaryen/2026-04-25-signext-lowering-primary-sources.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`

## Uncertainty

- This note does not establish the historical introduction release for `signext-lowering`.
- Starshine does not currently have Binaryen's exact `FeatureSet::SignExt` module-state model. A future port must decide whether to remove a `target_features` custom section, add an explicit feature model, or document that local lowering only changes instruction shape.
