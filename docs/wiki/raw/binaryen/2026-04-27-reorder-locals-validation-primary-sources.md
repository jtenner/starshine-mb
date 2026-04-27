---
kind: raw-source
status: supported
last_reviewed: 2026-04-27
source_type: primary-source-manifest
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals.txt
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals_print_roundtrip.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/reorder-locals_print_roundtrip.txt
  - ../../binaryen/passes/reorder-locals/index.md
  - ../../binaryen/passes/reorder-locals/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/reorder_locals.mbt
  - ../../../../src/passes/reorder_locals_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/registry_test.mbt
  - ../../../../src/cmd/cmd_wbtest.mbt
---

# Reorder locals validation primary sources

## Capture purpose

This manifest records a focused 2026-04-27 recheck of official Binaryen current `main` and local Starshine code for the `reorder-locals` validation and preset-readiness story.

The existing dossier already explained the upstream sorter, name-roundtrip behavior, Starshine module implementation, and multivalue-call writer caveat. The missing teaching piece was a compact bridge that turns those facts into actionable validation rules for future preset work and neighboring-local-pass activation.

## Primary sources checked

Official Binaryen current-main primary sources:

- `src/passes/ReorderLocals.cpp`
- `src/passes/pass.cpp`
- `test/passes/reorder-locals.wast`
- `test/passes/reorder-locals.txt`
- `test/passes/reorder-locals_print_roundtrip.wast`
- `test/passes/reorder-locals_print_roundtrip.txt`

Local Starshine sources checked:

- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/reorder_locals.mbt`
- `src/passes/reorder_locals_test.mbt`
- `src/passes/optimize_test.mbt`
- `src/passes/registry_test.mbt`
- `src/cmd/cmd_wbtest.mbt`

## Source-backed findings

- Binaryen current `main` still registers `reorder-locals` as the public pass that sorts locals by access frequency.
- Binaryen current `main` still schedules `reorder-locals` three times in the default no-DWARF function-optimization pipeline: after `simplify-locals-nostructure` plus `vacuum`, after `simplify-locals` plus `vacuum`, and after the second `coalesce-locals` before a final `vacuum`.
- The current-main owner file still implements the small `ReorderLocals` walker: count `LocalGet` / `LocalSet`, stabilize parameters, sort body locals by count and first-use order, truncate at the first zero-count body local, rewrite `LocalGet` / `LocalSet` indices, and rebuild local-name maps.
- The dedicated current-main test surfaces still cover access-frequency ordering, zero-use local removal, and print/binary roundtrip of reordered local declarations and names.
- Starshine still registers and dispatches `reorder-locals` as an active module pass, not a HOT pass.
- Starshine still keeps `reorder-locals` out of the public `optimize` and `shrink` presets; `src/passes/optimize_test.mbt` asserts that policy until neighboring local passes land.
- Starshine's implementation still preserves the Binaryen-visible rules locally: params fixed, live body locals sorted by access count plus first-use order, zero-access body locals dropped, `local.get` / `local.set` / `local.tee` users remapped, grouped local runs rebuilt, local-name maps repaired, imported-function local names preserved, and stale raw name-section payloads cleared.

## Documentation action

Add `docs/wiki/binaryen/passes/reorder-locals/starshine-port-readiness-and-validation.md` as a living bridge between the existing overview, Binaryen strategy, WAT-shape catalog, Starshine module strategy, parity notes, and multivalue-call scope decision.

## Uncertainties and caveats

- This recheck focused on the pass owner, scheduler placements, dedicated test surfaces, and local implementation/validation surfaces. It was not a full diff of every Binaryen writer or stack IR helper that can affect the older multivalue-call output caveat.
- The Starshine explicit pass is active and useful today. Preset scheduling remains intentionally open because faithful no-DWARF placement depends on the missing neighboring local passes and ordered replay evidence, not because the standalone sorter is unknown.
- The current Starshine module representation has a distinct `LocalTee` instruction, while Binaryen's tee path is represented through `LocalSet`; docs should keep that representation difference visible without treating it as semantic divergence.
