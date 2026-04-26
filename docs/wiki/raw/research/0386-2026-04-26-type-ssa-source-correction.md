# `type-ssa` source correction

_Date:_ 2026-04-26  
_Status:_ absorbed into living wiki pages

## Question

Does the existing Starshine wiki describe Binaryen `type-ssa` correctly enough for a future pass port?

## Short answer

No. The existing 2026-04-23 dossier mischaracterized the public `version_129` pass as a created-type propagation / retagging pass. A fresh official-source read shows the real `type-ssa` pass creates fresh private subtypes for selected allocation instructions and rewrites those allocation result types to exact non-null fresh types.

## Evidence

Primary-source capture: [`../binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md`](../binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md)

Important official files:

- Binaryen `version_129` `src/passes/TypeSSA.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `test/lit/passes/type-ssa.wast`
- Binaryen current `main` versions of the same surfaces

## Corrected model

The durable beginner-to-advanced model is:

1. Binaryen scans allocation sites, not arbitrary SSA-like value flows.
2. Candidate allocations are `struct.new`, `array.new`, `array.new_data`, `array.new_elem`, and `array.new_fixed`.
3. Binaryen also records exact-observation blockers in `disallowedTypes`, including exact casts/tests, exact function/global/element surfaces, and child-type constraints.
4. Candidate interestingness is shape-based: default constructors, constants/globals, more precise operand types, data/elem arrays, and all-interesting fixed arrays are positives.
5. Binaryen creates fresh private subtypes in one new rec group, preserves sharing, rewrites selected allocations to exact non-null fresh types, copies friendly names when possible, then refinalizes functions and module code.
6. `type-ssa` is still upstream-only for Starshine; the local registry does not name it, and no owner file or backlog slice exists.

## Superseded claims

The following older claims are stale for `version_129` and current main:

- the pass is centered on a `createdTypes` expression map;
- `getTargetType(...)` rejects abstract refs and turns concrete refs into exact non-null values;
- `getValue(...)` propagates facts through `block`, `if`, and `try` values;
- `local.set` / `global.set` feed later `local.get` / `global.get` retagging;
- direct call operands and returns are retagged from remembered created types.

These claims should not be reused unless a future source recheck finds an older or different branch where they are true.

## Starshine impact

The correction changes future-port prerequisites:

- A faithful Starshine port is module/type-section work, not a HOT local-flow peephole.
- It requires type-section mutation, fresh subtype/rec-group construction, type-name preservation, exact-ref allocation typing, module-code/global/element observation scans, and validator/refinalizer support.
- Existing local neighbors remain useful (`global_refining.mbt`, `global_struct_inference.mbt`, `ssa_nomerge.mbt`), but none is an implementation substrate for the corrected pass.

## Files updated

- `docs/wiki/binaryen/passes/type-ssa/index.md`
- `docs/wiki/binaryen/passes/type-ssa/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-ssa/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-ssa/created-exact-types-control-values-and-signature-rewrites.md`
- `docs/wiki/binaryen/passes/type-ssa/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-ssa/starshine-strategy.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
