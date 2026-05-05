---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md
  - ../../../raw/research/0462-2026-05-05-type-merging-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md
  - ../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../src/wast/ref_null_exact_surface_test.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./dfa-partitions-casts-and-refinalization.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../remove-unused-types/index.md
  - ../type-refining/index.md
  - ../type-ssa/index.md
  - ../minimize-rec-groups/index.md
  - ../unsubtyping/index.md
---

# Starshine port-readiness and validation for `type-merging`

Use this page together with the current status page in [`./starshine-strategy.md`](./starshine-strategy.md), the Binaryen contract pages in [`./binaryen-strategy.md`](./binaryen-strategy.md), [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), [`./dfa-partitions-casts-and-refinalization.md`](./dfa-partitions-casts-and-refinalization.md), and [`./wat-shapes.md`](./wat-shapes.md), plus the fresh 2026-05-05 raw bridge in [`../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-type-merging-current-main-recheck.md).

This is a **future-port** page, not an implementation page.
Starshine still does not implement `type-merging`.

## Current local status

- registry category: boundary-only
- active owner file: none
- active module dispatcher branch: none
- active `agent-todo.md` slice: none
- active preset role: none

The current local behavior is honest rejection, not silent no-oping.

## Exact local code map

The fastest read-along path is:

- `src/passes/optimize.mbt:84-87`
  - `pass_registry_entry_boundary_only(...)` gives boundary-only names the legacy boundary-only summary
- `src/passes/optimize.mbt:133-136`
  - `pass_registry_boundary_only_names()` includes `type-merging`
- `src/passes/optimize.mbt:505-520`
  - `run_hot_pipeline_expand_passes(...)` rejects boundary-only requests with the boundary-only diagnostic
- `src/passes/pass_manager.mbt`
  - there is no `type-merging` dispatcher case today
- `src/lib/types.mbt:41-136`
  - `HeapType`, `RefType`, `TypeIdx`, `TypeMetadata`, `SubType`, `RecType`, and `DefType` encode the heap-type graph a future port must rewrite
- `src/wast/parser.mbt:3479-3481`
  - WAT rec groups are parsed into module fields a future port can reuse for fixtures
- `src/wast/lower_to_lib.mbt:376-428`
  - WAT type declarations and rec groups lower into the reusable type-section model
- `src/wast/module_wast_tests.mbt:377-405`
  - rec-group roundtrip coverage already exists for future fixture work
- `src/wast/ref_null_exact_surface_test.mbt:1-88`
  - exact heap-type immediates and descriptor flows already have validation fixtures
- `src/validate/env.mbt:134-154`
  - type references resolve through the module type environment
- `src/validate/env.mbt:395-443`
  - descriptor-target and descriptor-result helpers already encode part of the GC descriptor invariant surface

## What Starshine currently does for the pass name

Today the pass name is preserved only as a tracked boundary-only name.
That is the correct current behavior for an unimplemented closed-world type-graph pass.

The name is not forgotten, but it is not runnable.

## Why the future port is module-level, not HOT-level

Binaryen `type-merging` rewrites the heap-type graph and every affected type use.
That means the future Starshine shape must own:

- the whole module's private heap-type inventory
- public-vs-private visibility classification
- GC and closed-world gating
- cast / exact-cast / `ref.test` / `br_on_cast*` / `call_indirect` observability scanning
- descriptor-chain-aware merge candidates
- supertype-first target choice
- DFA-style partition refinement over child heap-type transitions
- whole-module type-use rewrite
- refinalization or validation after the rewrite

Those are module/type-graph responsibilities, not single-function HOT peepholes.

## Validation ladder for the eventual port

### 1. Registry behavior

- keep the boundary-only rejection until the real transform exists
- once implemented, move the pass out of the boundary-only category in the same change that adds the code path
- keep the CLI spelling and registry status aligned

### 2. Feature and world gates

- no-GC modules should remain unchanged
- closed-world should stay the gating precondition for the real rewrite
- if Starshine chooses a different API shape, the docs must say so explicitly instead of implying Binaryen semantics where they do not exist

### 3. Type-graph positives

Start with the source-backed families from [`./wat-shapes.md`](./wat-shapes.md):

- direct supertype merges
- multi-level chain collapse
- child convergence unlocking a parent merge
- recursive and mutually recursive families
- array and function heap types
- private subtype below a public parent

### 4. Cast and exactness blockers

Prove the negative gates before widening the rewrite:

- `ref.cast`
- exact `ref.cast`
- `ref.test`
- `br_on_cast` / `br_on_cast_fail`
- `call_indirect`
- descriptor-chain mismatches
- public-type observability boundaries

### 5. Rewrite and repair coverage

- all type uses update consistently
- expression result types remain valid after the rewrite
- descriptor chains stay coupled
- the module still validates after the pass

### 6. Binaryen oracle lanes

- compare the focused fixture set against `wasm-opt --type-merging`
- keep the comparison targeted to the pass rather than widening to unrelated type passes too early
- only then consider broader closed-world type-cluster replay

## Open design question

The unresolved local architecture question is whether the shared type-graph rewrite machinery should live in a standalone module pass, a reusable closed-world helper, or a small set of coordinated type passes that share analysis and rewrite plumbing.

A faithful port should not duplicate the same module-wide type-graph machinery across `remove-unused-types`, `type-refining`, `type-ssa`, `minimize-rec-groups`, and `unsubtyping`.

## Related pages

- Overview: [`./index.md`](./index.md)
- Binaryen strategy: [`./binaryen-strategy.md`](./binaryen-strategy.md)
- Upstream implementation map: [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- DFA / cast / refinalization guide: [`./dfa-partitions-casts-and-refinalization.md`](./dfa-partitions-casts-and-refinalization.md)
- Shape catalog: [`./wat-shapes.md`](./wat-shapes.md)
- Current Starshine status: [`./starshine-strategy.md`](./starshine-strategy.md)
- Related GC/type passes: [`../remove-unused-types/index.md`](../remove-unused-types/index.md), [`../type-refining/index.md`](../type-refining/index.md), [`../type-ssa/index.md`](../type-ssa/index.md), [`../minimize-rec-groups/index.md`](../minimize-rec-groups/index.md), [`../unsubtyping/index.md`](../unsubtyping/index.md)
