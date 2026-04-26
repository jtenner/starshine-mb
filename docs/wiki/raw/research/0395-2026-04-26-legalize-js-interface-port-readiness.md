---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md
  - ../binaryen/2026-04-24-legalize-js-interface-primary-sources.md
  - ../../binaryen/passes/legalize-js-interface/index.md
  - ../../binaryen/passes/legalize-js-interface/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/legalize-js-interface/starshine-strategy.md
  - ../../binaryen/passes/legalize-and-prune-js-interface/index.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast.mbt
  - ../../../../src/binary/decode.mbt
---

# `legalize-js-interface` port-readiness follow-up

## Question

The existing `legalize-js-interface` folder already taught Binaryen's wrapper-based JS ABI legalization, but it still forced future Starshine implementers to infer the first safe local slice, the function-index remap hazards, and the validation order from several pages.

This note asks: what should a future Starshine port implement first, and what local code surfaces must be read before editing?

## Findings

- Upstream Binaryen current `main` still matches the already captured `version_129` teaching contract in the areas checked: same owner file, same public pass-family split, same `i64` import/export wrapper strategy, same temp-ret helper policy, and same dedicated lit lanes.
- Starshine still treats `legalize-js-interface` as unknown, not boundary-only or removed. The decisive local code is `src/passes/optimize.mbt#L127-L151` for the boundary-only / removed lists and `src/passes/optimize.mbt#L462-L470` for the unknown-versus-explicit-rejection behavior.
- The first useful local slice is not a HOT peephole. It is a module pass that proves Starshine can add wrapper function types, wrapper definitions/imports, export retargets, direct-call retargets, and `ref.func` retargets without corrupting function-index spaces.
- The safest implementation order is export-stub-only first, then import-wrapper creation plus call repair, then `ref.func` repair, then original-import deletion, then optional temp-ret helper reuse and `export-originals`.
- Prune mode should stay separate. It uses the same family but adds removal/stubbing of still-JS-illegal SIMD, multivalue-result, EH, and stack-switching surfaces. Folding that work into the first plain-pass slice would make failures harder to diagnose.

## Code locations that future work should read first

- `src/passes/optimize.mbt#L127-L151`: current registry lists omit both `legalize-js-interface` and `legalize-and-prune-js-interface`.
- `src/passes/optimize.mbt#L462-L470`: unknown pass requests fail before the boundary-only / removed rejection paths.
- `src/lib/types.mbt#L171-L214`: `ExternType`, `ExternIdx`, `Import`, `Export`, and `ElemKind` model the boundary and `ref.func`-adjacent module shapes.
- `src/lib/types.mbt#L301-L350`: `Module` owns the type/import/function/export/code sections that wrapper generation must update atomically.
- `src/lib/types.mbt#L3979-L3981`: `Instruction::ref_func` is the local instruction constructor for function references that Binaryen repairs for legalized imports.
- `src/wast/keywords.mbt#L98`, `src/wast/module_wast.mbt#L416`, and `src/wast/lower_to_lib.mbt#L172-L176`: WAT parse/print/lower surfaces for `ref.func`.
- `src/wast/lower_to_lib.mbt#L3373-L3438`: element-segment lowering paths that distinguish function-index items from typed expression items; a wrapper pass must not assume all `ref.func` uses only appear in ordinary function bodies.
- `src/binary/decode.mbt#L2773-L2774` and `src/binary/tests.mbt#L820-L821`: binary `ref.func` support and a small roundtrip proof surface.

## Recommended first-slice validation ladder

1. Registry honesty test: document whether the names remain unknown or become boundary-only before implementation.
2. Export-stub tests: one `i64` param, one `i64` result, and one combined param/result case.
3. Import-wrapper tests: direct `call` repair and deletion-last behavior.
4. Function-reference tests: `ref.func` in a function body and in an element/module-code surface that Starshine can represent.
5. Helper-policy tests: default `env.setTempRet0` / `env.getTempRet0` imports before exported-helper reuse.
6. Binaryen fixture comparison: replay the official all-features, exported-helpers, and export-originals fixtures before broad fuzzing.
7. Only after the plain pass is green, add prune-sibling tests from `legalize-and-prune-js-interface.wast`.

## Open questions

- Should Starshine first register these names as boundary-only to improve CLI honesty, or keep them unknown until real wrapper generation lands?
- Should wrapper generation live in a generic module-rewrite helper shared with `i64-to-i32-lowering`, `signature-pruning`, and future function-remap passes, or in a dedicated pass owner first?
- Which module-code surfaces are in scope for the first `ref.func` repair slice beyond ordinary function bodies and element-segment expressions?

## Durable update made

Added `docs/wiki/binaryen/passes/legalize-js-interface/starshine-port-readiness-and-validation.md` and refreshed the pass landing/status/index/tracker/log references so the first-slice and validation story is no longer scattered across the older overview, Binaryen strategy, and Starshine status pages.
