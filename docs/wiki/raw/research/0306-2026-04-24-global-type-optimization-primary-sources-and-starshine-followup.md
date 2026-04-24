# 0306 - `global-type-optimization` primary sources and Starshine follow-up

Date: 2026-04-24

## Question

The `global-type-optimization` dossier had a useful Binaryen overview, implementation/test map, hard-boundary page, and WAT-shape catalog, but it still relied directly on older online links plus research note `0153` for provenance and had no dedicated Starshine status/port-strategy page.
This follow-up asks:

- can the dossier be anchored to an immutable raw primary-source manifest?
- what is the exact current Starshine status for the local `global-type-optimization` registry spelling?
- which local code surfaces should future implementers read first?

## Sources checked

Local required context:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/raw/research/`
- existing `docs/wiki/binaryen/passes/global-type-optimization/` pages
- `src/passes/optimize.mbt`
- `src/passes/registry_test.mbt`
- `src/lib/types.mbt`
- `src/wast/parser.mbt`
- `src/wast/lower_to_lib.mbt`
- `src/validate/typecheck.mbt`
- `src/binary/decode.mbt`
- `src/binary/encode.mbt`
- `agent-todo.md`

Primary online source capture:

- `docs/wiki/raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md`

Older research absorbed rather than replaced:

- `docs/wiki/raw/research/0153-2026-04-21-global-type-optimization-binaryen-research.md`

## Why this pass was chosen

`global-type-optimization` was a good target for this run because:

- it is a real local pass spelling in `src/passes/optimize.mbt`, but only as `BoundaryOnly`
- it is a closed-world GC/type-cluster pass, not part of the already-covered open-world no-DWARF queue
- the existing dossier already taught the Binaryen strategy but lacked a raw primary-source manifest
- the existing folder lacked a dedicated Starshine follow-along page, which made the local status harder to discover than neighboring closed-world type passes
- the pass is easy to mis-port as “remove unread fields,” while the true contract also requires subtype-layout repair, JS descriptor keepalive, trap preservation, instruction-before-type ordering, and whole-module type remapping

## Durable source-backed Binaryen conclusions

- Upstream Binaryen registers the public name `gto`; this repo documents and tracks the longer local name `global-type-optimization`.
- Binaryen `version_129` gates the pass on GC support and `--closed-world`.
- The pass scans field traffic in functions and module code, but its optimization decisions are driven by runtime set/get/RMW/cmpxchg evidence plus JS exposure, not by constructor traffic alone.
- The core positive rewrites are private struct field immutability and private struct field removal/reordering.
- Public heap types are frozen; private descendants may still optimize child-only suffix fields when the public prefix remains compatible.
- JS-visible descriptor prototype fields can count as live even without ordinary wasm reads.
- Removed writes must still preserve value effects and null-trap order.
- Removed trapping module-initializer operands must still run, which Binaryen preserves with fresh `gto-removed-*` globals.
- `updateInstructions(...)` must run before `updateTypes(...)` because old field layouts are needed to rewrite field immediates and constructor operands.
- `GlobalTypeRewriter` performs the broad heap-type remap, but `GlobalTypeOptimization.cpp` owns the field permutation and field-name repair.

## Starshine status conclusions

Current Starshine has no `global-type-optimization` implementation.
There is no `src/passes/global_type_optimization.mbt` owner file today.

The implemented local status is:

- `src/passes/optimize.mbt` keeps `global-type-optimization` in `pass_registry_boundary_only_names()`
- the registry creates a boundary-only entry for the pass
- active requests fail with the boundary-only hot-pipeline diagnostic
- the built-in `optimize` and `shrink` presets do not include the pass
- `src/passes/registry_test.mbt` keeps preset expansions limited to active `HotPass` / `ModulePass` entries
- `agent-todo.md` currently has no dedicated `global-type-optimization` backlog slice

The future-port landing zone is module/type-graph work, not a HOT peephole, because the pass would have to rewrite type declarations, struct instructions, module-code initializers, and every remaining type use coherently.

## Local code surfaces future implementers should read first

- `src/passes/optimize.mbt`
  - registry category, preset exclusion, and active boundary-only rejection
- `src/passes/registry_test.mbt`
  - active-preset honesty guard
- `src/lib/types.mbt`
  - `FieldType`, `Mut`, `TypeIdx`, `TypeMetadata`, `SubType`, `RecType`, `DefType`, and `Instruction::StructNew*` / `StructGet*` / `StructSet` surfaces
- `src/wast/parser.mbt`
  - struct type declarations and currently parsed struct instruction surface
- `src/wast/lower_to_lib.mbt`
  - struct type and struct instruction lowering surface
- `src/validate/typecheck.mbt`
  - struct field mutability, packedness, defaultability, descriptor, and `struct.set` validation rules
- `src/binary/decode.mbt` / `src/binary/encode.mbt`
  - binary GC opcode decode/encode support for struct operations
- neighboring closed-world type dossiers
  - `remove-unused-types`, `type-refining`, `signature-pruning`, `signature-refining`, `constant-field-propagation`, `abstract-type-refining`, `unsubtyping`, and `type-merging`

## Local caveats recorded

- The local library and binary layers have `StructSet`, and validation typechecks it, but this run did not find WAT `struct.set` keyword/parser/lowerer support. Early text-fixture work for a future port may need to fill that gap or use library/binary fixtures first.
- The local instruction enum has memory atomic operations, but the currently visible struct operation surface does not expose Binaryen-style struct atomic RMW/cmpxchg instruction variants. A faithful `gto` port must either add those surfaces first or document a smaller initial scope.
- The repo currently has no closed-world option surface for scheduling this pass. Future work must decide whether open-world explicit requests reject, no-op, or require a new closed-world configuration.
- No dedicated backlog slice exists today, so this follow-up should not pretend implementation is already planned.

## Files updated by this follow-up

- Added `docs/wiki/raw/binaryen/2026-04-24-global-type-optimization-primary-sources.md`
- Added `docs/wiki/binaryen/passes/global-type-optimization/starshine-strategy.md`
- Refreshed `docs/wiki/binaryen/passes/global-type-optimization/index.md`
- Refreshed `docs/wiki/binaryen/passes/global-type-optimization/binaryen-strategy.md`
- Refreshed `docs/wiki/binaryen/passes/global-type-optimization/implementation-structure-and-tests.md`
- Refreshed `docs/wiki/binaryen/passes/global-type-optimization/field-removal-subtyping-js-interop-and-traps.md`
- Refreshed `docs/wiki/binaryen/passes/global-type-optimization/wat-shapes.md`
- Updated `docs/wiki/binaryen/passes/index.md`
- Updated `docs/wiki/binaryen/passes/tracker.md`
- Updated `docs/wiki/index.md`
- Updated `docs/wiki/log.md`
- Updated `CHANGELOG.md`

## Open follow-up questions

- Should Starshine add an explicit closed-world option before any more closed-world GC/type pass moves out of `BoundaryOnly`?
- Should `global-type-optimization`, `type-refining`, `constant-field-propagation`, `remove-unused-types`, `unsubtyping`, and `type-merging` share one closed-world type-graph rewrite framework?
- Should WAT `struct.set` support be added before implementation planning so shape fixtures can be written as text?
- How should Starshine model or intentionally exclude struct atomic RMW/cmpxchg surfaces relative to the Binaryen `gto-removals-rmw.wast` contract?

## Bottom line

`global-type-optimization` now has a complete provenance and Starshine-status bridge.
The durable local fact is that Starshine recognizes the pass name only as boundary-only today; a future implementation must be a closed-world module/type-graph transform that preserves Binaryen's private-struct field immutability/removal, subtype-layout repair, JS descriptor keepalive, trap preservation, instruction-before-type ordering, and module-wide type remapping contracts.
