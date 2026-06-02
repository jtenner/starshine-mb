---
kind: concept
status: supported
last_reviewed: 2026-06-01
sources:
  - ../../../raw/binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md
  - ../../../raw/research/0409-2026-04-26-type-ssa-port-readiness.md
  - ../../../raw/binaryen/2026-05-06-type-ssa-current-main-recheck.md
  - ../../../raw/research/0503-2026-05-06-type-ssa-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-01-type-ssa-current-main-recheck.md
  - ../../../raw/research/0688-2026-06-01-type-ssa-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md
  - ../../../raw/research/0386-2026-04-26-type-ssa-source-correction.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/ssa_nomerge.mbt
  - ../../../../../src/passes/global_refining.mbt
  - ../../../../../src/passes/global_struct_inference.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./created-exact-types-control-values-and-signature-rewrites.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../ssa/index.md
  - ../type-merging/index.md
  - ../type-refining/index.md
---

# Starshine Strategy For `type-ssa`

Use this page together with the corrected raw source capture in [`../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md`](../../../raw/binaryen/2026-04-26-type-ssa-source-correction-and-current-main.md), the 2026-06-01 freshness recheck in [`../../../raw/binaryen/2026-06-01-type-ssa-current-main-recheck.md`](../../../raw/binaryen/2026-06-01-type-ssa-current-main-recheck.md), and the port-readiness bridge in [`../../../raw/binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-type-ssa-port-readiness-primary-sources.md).

## Honest current status

`type-ssa` is still **unimplemented and untracked** in Starshine.

There is no `src/passes/type_ssa.mbt` owner file, and the pass name is not listed as active, boundary-only, or removed.

That status means:

- Starshine does not currently promise CLI compatibility for `--pass type-ssa`,
- there is no pass-specific request rejection path,
- there is no active preset slot,
- there is no no-DWARF parity dependency,
- `agent-todo.md` has no dedicated `type-ssa` slice.

## Exact local code map today

The fastest read-along path through the current local status is:

- registry compatibility arrays:
  - [`src/passes/optimize.mbt#L127-L155`](../../../../../src/passes/optimize.mbt#L127-L155)
  - `pass_registry_boundary_only_names()` and `pass_registry_removed_names()` do **not** include `type-ssa`
- active registry entries and presets:
  - [`src/passes/optimize.mbt#L158-L275`](../../../../../src/passes/optimize.mbt#L158-L275)
  - `pass_registry_entries()` defines active hot/module/preset entries, and no `type-ssa` entry exists
- current expansion / rejection behavior:
  - [`src/passes/optimize.mbt#L446-L472`](../../../../../src/passes/optimize.mbt#L446-L472)
  - unknown names fall outside the tracked active/boundary/removed compatibility paths
- closest SSA-adjacent implementation:
  - [`src/passes/ssa_nomerge.mbt#L2-L49`](../../../../../src/passes/ssa_nomerge.mbt#L2-L49)
- closest active type-tightening module pass:
  - [`src/passes/global_refining.mbt#L2-L367`](../../../../../src/passes/global_refining.mbt#L2-L367)
- closest active struct/value-origin module pass:
  - [`src/passes/global_struct_inference.mbt#L1-L345`](../../../../../src/passes/global_struct_inference.mbt#L1-L345)
- backlog by omission:
  - [`agent-todo.md`](../../../../../agent-todo.md)
  - no dedicated `type-ssa` slice exists today

## Current Starshine strategy

The current strategy is deliberate non-adoption plus accurate documentation.

That is especially important after the 2026-04-26 correction and the 2026-06-01 freshness recheck: a future `type-ssa` port would be module/type-section work, not a small HOT local-flow peephole.

## What a faithful future port would require

A Starshine port would need these pieces before claiming Binaryen parity:

### 1. Registry honesty

Decide whether `type-ssa` should become:

- active,
- boundary-only with a clear rejection message,
- or still upstream-only and absent.

Do not add tests that assume active behavior while the registry still treats the name as unknown.

### 2. Allocation candidate discovery

The port needs to discover:

- `struct.new`,
- `array.new`,
- `array.new_data`,
- `array.new_elem`,
- `array.new_fixed`,
- ordinary function bodies,
- globals and module-code expression surfaces,
- element segments.

This probably belongs in module-level IR/lib analysis, not only in HOT region rewriting.

### 3. Exact-observation blocker analysis

The port needs an equivalent to Binaryen's `disallowedTypes` collection:

- exact casts,
- exact tests,
- exact function result types,
- exact global types,
- exact element-segment types,
- child exactness constraints.

Without this, fresh subtype creation can change exact-type-observable behavior.

### 4. Fresh subtype and rec-group construction

The port needs to mutate the type section:

- create private subtypes of existing struct/array heap types,
- preserve sharing among repeated old types,
- build valid rec groups,
- avoid name collisions,
- keep descriptor/describee exclusions until deliberately supported.

This is the largest local infrastructure gap.

### 5. Allocation result retagging and refinalization

The visible rewrite is allocation result typing, followed by parent/module-code type repair. A faithful port needs validator-backed proof that rewritten allocation types remain subtype-safe at all uses.

## Nearby local code is not an implementation

### `ssa-nomerge`

[`src/passes/ssa_nomerge.mbt`](../../../../../src/passes/ssa_nomerge.mbt) is useful as an SSA-adjacent Starshine pass, but it rewrites locals/phis. Corrected `type-ssa` creates fresh heap types for allocations, so `ssa-nomerge` is only a conceptual neighbor.

### `global-refining`

[`src/passes/global_refining.mbt`](../../../../../src/passes/global_refining.mbt) is the closest active type-tightening module pass. It refines private global declarations from initializers and writes. Corrected `type-ssa` instead creates new private heap types for allocation sites.

### `global-struct-inference`

[`src/passes/global_struct_inference.mbt`](../../../../../src/passes/global_struct_inference.mbt) is another useful GC/type neighbor because it reasons about fixed struct origins. It still does not build fresh rec groups or rewrite allocation result heap types.

## Validation ladder for a future port

A safe port should proceed in the detailed order in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md):

1. add registry status tests first,
2. add no-rewrite analyzer classification for allocation candidates and exact-observation blockers,
3. add reduced WAT parser/lib tests for fresh subtype emission,
4. add exact-observation bailout tests,
5. add descriptor/describee and final/open-disabled type bailouts,
6. add `array.new_data`, `array.new_elem`, and all-interesting `array.new_fixed` positives,
7. compare against official `wasm-opt --type-ssa` reductions,
8. only then run broader pass-fuzz comparison.

## Current conclusion

Starshine currently has no `type-ssa` strategy beyond documenting upstream behavior accurately. If the repo adopts it later, the corrected implementation target is a module-level GC type-section transformation, not the stale created-type propagation model.
