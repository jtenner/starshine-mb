---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md
  - ../../../raw/research/0295-2026-04-24-abstract-type-refining-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/ref_null_exact_surface_test.mbt
  - ../../../../../src/wast/exact_type_equivalence_test.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/match.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../global-struct-inference/index.md
  - ../unsubtyping/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./traps-never-happen-exact-casts-and-descriptors.md
  - ./wat-shapes.md
  - ../global-struct-inference/index.md
  - ../remove-unused-types/index.md
  - ../type-refining/index.md
  - ../unsubtyping/index.md
---

# Starshine Strategy For `abstract-type-refining`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-abstract-type-refining-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main infrastructure gaps a future parity port must resolve.

## The honest current status

`abstract-type-refining` is still **unimplemented** in Starshine.
There is no `src/passes/abstract_type_refining.mbt`, `src/passes/abstract-type-refining.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- preserve the local pass spelling `abstract-type-refining` in the registry as a known boundary-only name
- reject active requests honestly instead of silently no-oping
- keep the upstream closed-world GC/type-cluster contract visible in the wiki
- keep its absence from the canonical open-world no-DWARF path explicit
- keep the missing dedicated backlog slice explicit
- document why a future port is type-section/module-owned work, not a HOT peephole

So this is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L139`](../../../../../src/passes/optimize.mbt#L127-L139)
    - `pass_registry_boundary_only_names()` includes `"abstract-type-refining"`
- registry entry construction for boundary-only names
  - [`src/passes/optimize.mbt#L264-L268`](../../../../../src/passes/optimize.mbt#L264-L268)
    - each boundary-only name becomes a boundary-only registry entry through `pass_registry_entry_boundary_only(...)`
- active request guard for boundary-only passes
  - [`src/passes/optimize.mbt#L446-L462`](../../../../../src/passes/optimize.mbt#L446-L462)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`
- active preset absence
  - [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263)
    - the built-in `optimize` and `shrink` presets expand only the currently implemented module/HOT sequence and do not include `abstract-type-refining`
  - [`src/passes/registry_test.mbt#L129-L158`](../../../../../src/passes/registry_test.mbt#L129-L158)
    - the preset test asserts every expanded preset name is `HotPass` or `ModulePass`, which keeps boundary-only names out of the active default path
- type-section and reference-type representation a future port would have to rewrite
  - [`src/lib/types.mbt#L31-L159`](../../../../../src/lib/types.mbt#L31-L159)
    - `AbsHeapType`, `HeapType`, `RefType`, `TypeIdx`, `TypeMetadata`, `SubType`, `RecType`, and `DefType` encode the heap-type graph, exactness bit, subtype metadata, and rec-group surface
  - [`src/lib/types.mbt#L720-L764`](../../../../../src/lib/types.mbt#L720-L764)
    - `StructNew*`, `RefGetDesc`, `RefTest`, `RefCast`, descriptor casts, and branch casts are explicit instruction variants rather than pass-local syntax
- WAT parser and lowerer surfaces a future port can reuse for fixtures
  - [`src/wast/parser.mbt#L994-L1096`](../../../../../src/wast/parser.mbt#L994-L1096)
    - exact heap-type syntax such as `(exact $t)` lowers through dedicated parser helpers
  - [`src/wast/parser.mbt#L2211-L2285`](../../../../../src/wast/parser.mbt#L2211-L2285)
    - subtype wrappers plus `describes` / `descriptor` metadata are parsed into the WAST type model
  - [`src/wast/lower_to_lib.mbt#L2400-L2469`](../../../../../src/wast/lower_to_lib.mbt#L2400-L2469)
    - `struct.new_desc`, `ref.get_desc`, and descriptor cast instructions lower into `@lib.Instruction` variants
- exact-reference and descriptor validation surfaces a future port must preserve
  - [`src/wast/ref_null_exact_surface_test.mbt#L1-L88`](../../../../../src/wast/ref_null_exact_surface_test.mbt#L1-L88)
    - exact heap-type immediates and `ref.get_desc` flows have dedicated roundtrip/validation fixtures
  - [`src/wast/exact_type_equivalence_test.mbt#L1-L45`](../../../../../src/wast/exact_type_equivalence_test.mbt#L1-L45)
    - exact struct/function equivalence fixtures protect exact-type matching behavior
  - [`src/validate/env.mbt#L134-L154`](../../../../../src/validate/env.mbt#L134-L154)
    - validation resolves `TypeIdx` / `HeapType` references through the module type environment
  - [`src/validate/env.mbt#L380-L443`](../../../../../src/validate/env.mbt#L380-L443)
    - descriptor-target and descriptor-result helpers encode part of the custom-descriptor invariant surface
  - [`src/validate/match.mbt#L66-L132`](../../../../../src/validate/match.mbt#L66-L132)
    - reference-type matching handles exactness and bottom-like abstract heap types
  - [`src/validate/typecheck.mbt#L1153-L1220`](../../../../../src/validate/typecheck.mbt#L1153-L1220)
    - branch-cast typechecking validates the cast target pairs and branch payloads
  - [`src/validate/typecheck.mbt#L3261-L3276`](../../../../../src/validate/typecheck.mbt#L3261-L3276)
    - the main instruction dispatcher routes `RefGetDesc`, `RefCastDescEq`, `StructNewDesc`, and related GC instructions to validators
- binary encoder surfaces a future port must keep coherent after rewrites
  - [`src/binary/encode.mbt#L2611-L2980`](../../../../../src/binary/encode.mbt#L2611-L2980)
    - descriptor allocations, descriptor casts, and branch casts have concrete binary opcode emission paths
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `abstract-type-refining` in the active default route
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `abstract-type-refining` slice

That map is the durable local status today: the pass is known, intentionally unavailable, boundary-only, not in the open-world path, not assigned to an active implementation slice, and not backed by an owner file.

## Why this is not a HOT peephole

Binaryen's `abstract-type-refining` changes module-level heap-type uses after proving which struct types can actually be allocated.
The transformed shapes appear across:

- type declarations and type uses
- function locals and signatures
- globals and module-scope expressions
- casts, tests, branch casts, and descriptor-sensitive operations
- `struct.new_desc` and `ref.get_desc` repair forms
- rec groups that may contain unrelated continuation/function references

A faithful Starshine port would need to reason over:

- the module's full heap-type inventory
- public versus private or externally visible heap-type boundaries
- GC and closed-world gates
- `struct.new*` creation evidence across module code and all function bodies
- upward subtype relevance propagation
- `--traps-never-happen` as a semantic mode that enables only the unique-live-child refinement half
- exact casts that must stay impossible instead of becoming successful live-child casts
- descriptor operands whose null traps and side effects must survive even when the descriptor relation disappears
- whole-module type-use rewriting
- validation or refinalization after the rewrite

Those requirements cross package boundaries that current HOT expression passes do not own.
The right future landing shape is a module pass or shared closed-world type-graph rewrite engine, not a small `HotFunc` rewrite.

## What Starshine currently does for the pass name

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `abstract-type-refining` in `pass_registry_boundary_only_names()`.
That means:

- the spelling remains discoverable in local registry behavior
- neighboring GC/type docs can point at one consistent local status
- future port work has to intentionally move the pass into an implemented category

### 2. The active pipeline rejects it honestly

When a user requests a boundary-only pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a boundary-only error.
That behavior matters because:

- explicit pass requests do not silently pretend to refine type uses
- the registry category remains executable documentation
- future implementation work will have to change the category and diagnostics intentionally

### 3. The active presets exclude it

The Starshine `optimize` and `shrink` presets expand only implemented module/HOT passes today.
The registry test asserts that preset expansions stay on active pass names.
That matches the current local strategy: `abstract-type-refining` has no open-world no-DWARF preset role in this repo today.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- return without rewriting when GC is unavailable
- require an explicit closed-world mode before running the pass
- scan `struct.new`, `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc` as creation evidence; do not count plain mentions, refs, or casts as allocations
- treat public heap types conservatively as created unless Starshine has a stronger, documented closed-world visibility proof
- propagate created-subtype relevance upward through subtype edges
- map fully never-created struct families to bottom even outside TNH
- perform parent-to-unique-live-child refinement only under TNH-like semantics
- keep multiple live-child branches as bailouts
- preserve impossible exact-cast semantics by bottom/null-target rewriting instead of retargeting exact casts to live children
- preserve descriptor operand side effects and nullable-descriptor traps while removing descriptor-sensitive checks
- repair `ref.get_desc`, `br_on_cast_desc_eq*`, and `struct.new_desc` before or during type-use rewriting so validation stays sound
- rewrite type uses coherently across locals, signatures, globals, and module expressions
- preserve declared subtype-edge cleanup as a separate responsibility, matching the upstream split with `unsubtyping`
- run validation/refinalization after the rewrite

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./traps-never-happen-exact-casts-and-descriptors.md`](./traps-never-happen-exact-casts-and-descriptors.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Nearby boundaries to keep distinct

### `global-struct-inference`

See [`../global-struct-inference/index.md`](../global-struct-inference/index.md).

`global-struct-inference` reasons from global values and can expose more precise global-derived struct traffic.
`abstract-type-refining` reasons from creation evidence after that neighboring cleanup.
Do not teach ATR as global-value inference.

### `remove-unused-types`

See [`../remove-unused-types/index.md`](../remove-unused-types/index.md).

`remove-unused-types` removes unused private types and copies retained rec groups.
`abstract-type-refining` can bottomize or retarget type uses but deliberately does not own the visible type-declaration deletion story by itself.
Many Binaryen test outputs use `--abstract-type-refining --remove-unused-types`, so do not attribute all type-section shrinkage to ATR alone.

### `type-refining`

See [`../type-refining/index.md`](../type-refining/index.md).

`type-refining` tightens field/signature types from observed value traffic earlier in the closed-world cluster.
`abstract-type-refining` is later and narrower: it asks whether struct heap types are actually created and how never-created families should rewrite.

### `unsubtyping`

See [`../unsubtyping/index.md`](../unsubtyping/index.md).

`unsubtyping` prunes declared subtype and descriptor relations.
`abstract-type-refining` explicitly preserves declared supertypes while rewriting type uses and preoptimizing exact/descriptor shapes.
Do not merge those two responsibilities into one simplistic type-graph cleanup pass.

## Validation plan for the eventual port

A future implementation should validate in layers:

1. registry behavior
   - keep boundary-only rejection until the transform exists
   - when the pass lands, update registry category, preset behavior if any, tests, tracker, and docs in the same change
2. feature and world gates
   - no-GC modules are unchanged
   - open-world requests fail or no-op according to the chosen Starshine API shape
   - closed-world test fixtures enable the rewrite explicitly
3. creation-evidence analysis
   - direct `struct.new*` allocations mark types created
   - plain refs, locals, signatures, globals, casts, and tests do not falsely mark a type created
   - public/exported/externally visible heap types stay conservatively live unless a stronger local proof is added
4. bottomization positives
   - fully never-created nonnullable refs rewrite to bottom refs
   - nullable impossible refs preserve the null-only success case
   - arrays/functions remain out of scope until source-backed support is intentionally added
5. TNH-only positives and bailouts
   - abstract parent with one live child rewrites only in TNH mode
   - chains refine to the deepest unique live child
   - multiple live branches remain unchanged
6. exact and descriptor repair
   - exact impossible casts do not become live-child successes
   - nullable descriptor operands keep null-trap behavior outside TNH
   - side-effectful ref/descriptor children preserve order through localization-equivalent rewrites
   - `ref.get_desc` and `struct.new_desc` impossible cases validate after rewrite
7. full-module rewrite and validation
   - locals, function types, globals, and module expressions update coherently
   - declared subtype-edge cleanup remains delegated to a later pass
   - final validation catches any missed type-use repair

## Open local questions

- What will Starshine's closed-world option surface be for passes that upstream Binaryen hard-gates on `--closed-world`?
- Should ATR share one type-graph rewrite engine with `remove-unused-types`, `type-refining`, `minimize-rec-groups`, `type-merging`, and `unsubtyping`?
- What is the right local equivalent of Binaryen's `ChildLocalizer` and `getDroppedChildrenAndAppend(...)` for descriptor repair outside ordinary HOT expression passes?
- Should the first local port intentionally support custom descriptors from day one, or should Starshine first document a no-custom-descriptor subset and reject the rest?

Keep those questions explicit until an implementation plan answers them.

## Bottom line

Current Starshine has a safe boundary-only `abstract-type-refining` registry entry and reusable GC/type/parser/validator infrastructure, but no pass implementation.
A future port must be a closed-world module/type-graph transform with creation scanning, subtype relevance propagation, exact/descriptor repair, coherent type-use rewriting, and final validation.
