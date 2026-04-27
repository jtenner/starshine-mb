# `type-refining` port-readiness bridge

_Date:_ 2026-04-27  
_Status:_ absorbed into living wiki pages; keep as numbered research provenance

## Question

The `type-refining` dossier already had overview, Binaryen strategy, implementation/test map, focused fixup notes, shape catalog, raw tagged-source manifest, and Starshine status coverage.
The remaining wiki-health gap was the newer standard implementation-readiness bridge: a page that turns the upstream contract into a safe local first-slice plan, validation ladder, and explicit code-map checkpoints.

## Sources reviewed

Primary captured source manifests:

- [`../binaryen/2026-04-24-type-refining-primary-sources.md`](../binaryen/2026-04-24-type-refining-primary-sources.md)
- [`../binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md`](../binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md)

Living pages re-read:

- [`../../binaryen/passes/type-refining/index.md`](../../binaryen/passes/type-refining/index.md)
- [`../../binaryen/passes/type-refining/binaryen-strategy.md`](../../binaryen/passes/type-refining/binaryen-strategy.md)
- [`../../binaryen/passes/type-refining/implementation-structure-and-tests.md`](../../binaryen/passes/type-refining/implementation-structure-and-tests.md)
- [`../../binaryen/passes/type-refining/normal-vs-gufa-and-fixups.md`](../../binaryen/passes/type-refining/normal-vs-gufa-and-fixups.md)
- [`../../binaryen/passes/type-refining/wat-shapes.md`](../../binaryen/passes/type-refining/wat-shapes.md)
- [`../../binaryen/passes/type-refining/starshine-strategy.md`](../../binaryen/passes/type-refining/starshine-strategy.md)
- [`../../binaryen/passes/type-refining/starshine-port-readiness-and-validation.md`](../../binaryen/passes/type-refining/starshine-port-readiness-and-validation.md)

Local code surfaces reviewed:

- [`../../../../src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt)
- [`../../../../src/passes/registry_test.mbt`](../../../../src/passes/registry_test.mbt)
- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt)
- [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt)
- [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt)
- [`../../../../src/validate/env.mbt`](../../../../src/validate/env.mbt)
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
- [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt)
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt)
- [`../../../../agent-todo.md`](../../../../agent-todo.md)

Primary online sources rechecked:

- Binaryen current-main `TypeRefining.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeRefining.cpp>
- Binaryen current-main `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen current-main `type-refining*.wast` lit files listed in [`../binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md`](../binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md)

## Findings

### Source contract remains a closed-world type-declaration rewrite

The 2026-04-27 current-main recheck did not change the teaching model captured on 2026-04-24.
`type-refining` is still a closed-world, GC-only private struct-field type refiner. It gathers write/default/copy evidence, preserves public type boundaries, repairs invalidated reads before declaration rewriting, rewrites private struct declarations, then refinalizes and repairs writes.

The important negative remains: arrays are still outside this pass. Future local work should not overgeneralize from Starshine's existing array representation or from neighboring GC passes.

### Port readiness needs an analyzer-first slice

A faithful Starshine port is too broad for a first mutating patch.
The bridge page now recommends a first no-rewrite analyzer that can classify private struct fields, collect direct constructor/set evidence, and explain bailouts for public types, arrays, open-world mode, missing WAT fixture support, hierarchy conflicts, GUFA-only wins, and write-repair hazards.

That analyzer-first slice gives future developers validation fixtures and diagnostics before any type-section mutation exists.

### First mutating slice should stay deliberately narrow

The recommended first mutating slice is:

- GC-enabled closed-world modules only
- private non-exported struct types only
- direct `struct.new` / `struct.set` evidence only
- no arrays
- no GUFA / `ContentOracle` dependency
- no global-initializer write repair
- hierarchy checks before rewriting
- explicit read retagging or `drop + unreachable` repair
- final validation after type-section and instruction updates

This preserves the beginner-to-advanced mapping from transformed shapes to Binaryen strategy while avoiding a false claim of parity with the full upstream pass.

### Local code status remains boundary-only

The current exact local code map still shows:

- `src/passes/optimize.mbt` lists `type-refining` in boundary-only names.
- Active requests fail with the boundary-only error.
- Presets omit the pass.
- No owner file exists.
- `type-refining-gufa` is documented but not separately registered.
- Local type, parser/lowerer, validation, and binary surfaces are prerequisites rather than an implementation.

## Living-page changes made

- Added [`../../binaryen/passes/type-refining/starshine-port-readiness-and-validation.md`](../../binaryen/passes/type-refining/starshine-port-readiness-and-validation.md).
- Added [`../binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md`](../binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md).
- Refreshed the `type-refining` overview and Starshine status page to link the port-readiness bridge.
- Updated the top-level wiki index, pass index, tracker, and log so `type-refining` is tracked as deep rather than merely dossier-covered.

## Open questions

- What will Starshine's explicit closed-world option be for type-section passes?
- Should `type-refining-gufa` be added as its own boundary-only name now, or wait until GUFA infrastructure exists?
- Should Starshine implement WAT `struct.set` parsing/lowering before the analyzer slice, or start with library/binary fixtures?
- Which shared module/type-graph rewrite engine should own public/private type reachability, subtype legality, declaration rewriting, and post-rewrite validation across `type-refining`, `remove-unused-types`, `type-merging`, `unsubtyping`, `signature-pruning`, and `signature-refining`?

## Bottom line

The dossier is now complete for implementation planning: readers can start at the overview, inspect transformed shapes, follow Binaryen's strategy and tests, see the exact current Starshine boundary-only code map, and use the new port-readiness bridge as a safe first-slice and validation ladder without mistaking it for an active implementation.
