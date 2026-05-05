---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-constant-field-propagation-current-main-recheck.md
  - ../../../raw/research/0474-2026-05-05-constant-field-propagation-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md
  - ../../../raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../constant-field-null-test-folding/index.md
  - ../constant-field-null-test-folding/starshine-strategy.md
  - ../global-type-optimization/index.md
  - ../global-struct-inference/index.md
  - ../type-refining/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./copies-subtypes-ref-tests-and-atomics.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../constant-field-null-test-folding/index.md
  - ../constant-field-null-test-folding/starshine-strategy.md
  - ../global-type-optimization/index.md
  - ../global-struct-inference/index.md
  - ../type-refining/index.md
---

# Starshine Strategy For `constant-field-propagation`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-05-05-constant-field-propagation-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-constant-field-propagation-current-main-recheck.md) and the older 2026-04-24 manifest in [`../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md`](../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main infrastructure gaps a future parity port must resolve.
The companion implementation-readiness bridge lives in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## The honest current status

`constant-field-propagation` is still **unimplemented** in Starshine.
There is no `src/passes/constant_field_propagation.mbt`, `src/passes/constant-field-propagation.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- preserve the local pass spelling `constant-field-propagation` in the registry as a known boundary-only name,
- preserve the sibling local spelling `constant-field-null-test-folding` for upstream `cfp-reftest`,
- reject active requests honestly instead of silently no-oping,
- keep the upstream closed-world GC/type/struct-field contract visible in the wiki,
- keep its absence from the canonical open-world no-DWARF path explicit,
- keep the missing dedicated backlog slice explicit,
- document why a future port is module/type-graph work rather than a small HOT peephole.

So this is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
    - `pass_registry_boundary_only_names()` includes both `"constant-field-propagation"` and `"constant-field-null-test-folding"`.
- registry entry construction for boundary-only names
  - [`src/passes/optimize.mbt#L266-L268`](../../../../../src/passes/optimize.mbt#L266-L268)
    - each boundary-only name becomes a boundary-only registry entry through `pass_registry_entry_boundary_only(...)`.
- active request guard for boundary-only passes
  - [`src/passes/optimize.mbt#L446-L463`](../../../../../src/passes/optimize.mbt#L446-L463)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
- active preset absence
  - [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263)
    - the built-in `optimize` and `shrink` presets expand only the currently implemented module/HOT sequence and do not include either CFP-family boundary-only name.
  - [`src/passes/registry_test.mbt#L121-L158`](../../../../../src/passes/registry_test.mbt#L121-L158)
    - the preset test asserts every expanded preset name is `HotPass` or `ModulePass`, which keeps boundary-only names out of the active default path.
- GC/type-section representation a future port would have to inspect
  - [`src/lib/types.mbt#L31-L57`](../../../../../src/lib/types.mbt#L31-L57)
    - `AbsHeapType`, `HeapType`, `RefType`, and `ValType` encode the reference-type surface the pass must reason about.
  - [`src/lib/types.mbt#L136-L159`](../../../../../src/lib/types.mbt#L136-L159)
    - `TypeMetadata`, `SubType`, `RecType`, and `DefType` encode the struct, subtype, rec-group, descriptor, and exact-def-type surfaces.
- struct/descriptor instruction representation a future port would have to scan and rewrite
  - [`src/lib/types.mbt#L733-L761`](../../../../../src/lib/types.mbt#L733-L761)
    - `StructNew`, `StructNewDefault`, `StructNewDesc`, `StructNewDefaultDesc`, `StructGet`, `StructGetS`, `StructGetU`, `StructSet`, `RefGetDesc`, `RefTest`, and descriptor-cast instructions are represented as library instructions.
  - [`src/wast/parser.mbt#L410-L437`](../../../../../src/wast/parser.mbt#L410-L437)
    - WAT parser instruction variants already distinguish struct creation, field reads, descriptor reads, and descriptor tests.
  - [`src/wast/lower_to_lib.mbt#L2418-L2453`](../../../../../src/wast/lower_to_lib.mbt#L2418-L2453)
    - WAT lowering resolves type immediates for struct allocation, `struct.get` / `struct.get_s` / `struct.get_u`, and `ref.get_desc` into `@lib.Instruction` values.
  - [`src/binary/encode.mbt#L2629-L2659`](../../../../../src/binary/encode.mbt#L2629-L2659)
    - binary encoding already has GC struct-field opcode emission for the field-read family.
- validator surfaces a future port must preserve after read rewrites
  - [`src/validate/env.mbt#L150-L181`](../../../../../src/validate/env.mbt#L150-L181)
    - validation resolves heap types, subtypes, and type indices through the module type environment.
  - [`src/validate/env.mbt#L246-L272`](../../../../../src/validate/env.mbt#L246-L272)
    - `with_rectype(...)` and `append_rectype_types(...)` encode how rec groups populate validation type environments.
  - [`src/validate/env.mbt#L395-L435`](../../../../../src/validate/env.mbt#L395-L435)
    - descriptor-target and descriptor-result helpers encode the `ref.get_desc` result-type invariant surface.
  - [`src/validate/typecheck.mbt#L1868-L1930`](../../../../../src/validate/typecheck.mbt#L1868-L1930)
    - `ref.get_desc`, `ref.test`, `ref.cast`, and descriptor test/cast validation preserve exactness, nullability, and descriptor compatibility.
  - [`src/validate/typecheck.mbt#L2115-L2178`](../../../../../src/validate/typecheck.mbt#L2115-L2178)
    - `struct.get`, `struct.get_s`, `struct.get_u`, and `struct.set` validation already distinguishes packed-field reads and mutable-field writes.
  - [`src/validate/typecheck.mbt#L3277-L3290`](../../../../../src/validate/typecheck.mbt#L3277-L3290)
    - the instruction dispatcher wires the GC struct/descriptor opcodes to those validators.
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place CFP in the active open-world route.
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `constant-field-propagation`, `cfp`, `constant-field-null-test-folding`, or `cfp-reftest` slice.

That map is the durable local status today: the pass family is known, intentionally unavailable, boundary-only, not in the open-world path, not assigned to an active implementation slice, and not backed by an owner file.

## Why this is not a HOT peephole

Binaryen's `cfp` strategy is a module-wide closed-world analysis over struct field facts.
The pass needs to see all relevant constructors, defaults, `struct.set`s, copied `struct.get`s, descriptor reads, atomics/RMW unknowns, and subtype relationships before it can decide whether one field read is replaceable.

A faithful Starshine port would need to reason over:

- the full module type graph,
- GC feature and closed-world gates,
- all struct heap types and their fields,
- exact versus inexact reference views,
- constructor defaults and literal / immutable-global writes,
- field-to-field copy edges and fixed-point solving,
- subtype-down written-value propagation and supertype-up readable-value propagation,
- packed-field sign/zero-extension repair,
- null-trap preservation around read replacements,
- descriptor reads and exact descriptor result types,
- ordered-atomic successful-read bailouts,
- known-trap conversion to `drop(ref); unreachable`,
- final validation / refinalization after replacements.

Those requirements cross package boundaries that current HOT expression passes do not own.
The right future landing shape is a module pass plus shared closed-world GC/type/field-analysis infrastructure, not a local match like `struct.get(struct.new(...))`.

## What Starshine currently does for the pass names

### 1. The names are tracked, not forgotten

`src/passes/optimize.mbt` keeps both `constant-field-propagation` and `constant-field-null-test-folding` in `pass_registry_boundary_only_names()`.
That means:

- the local descriptive spellings remain discoverable,
- neighboring closed-world GC/type dossiers can point at one consistent local status,
- future port work has to intentionally move the pass names into implemented categories.

### 2. The active pipeline rejects them honestly

When a user requests either boundary-only pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a boundary-only error.
That behavior matters because:

- explicit pass requests do not silently pretend to solve whole-module struct-field facts,
- the registry category remains executable documentation,
- future implementation work will have to change the category and diagnostics intentionally.

### 3. The active presets exclude them

The Starshine `optimize` and `shrink` presets expand only implemented module/HOT passes today.
The registry test asserts that preset expansions stay on active pass names.
That matches the current local strategy: CFP-family passes have no open-world no-DWARF preset role in this repo today.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- require GC support and closed-world mode before rewriting,
- keep open-world behavior explicit and non-silent,
- keep parent `constant-field-propagation` / upstream `cfp` separate from sibling `constant-field-null-test-folding` / upstream `cfp-reftest`,
- collect write/default/copy/RMW evidence for struct fields across the module,
- use a tiny literal-or-immutable-global value lattice for plain CFP,
- keep exact and inexact reference facts separate,
- propagate written values down to subtypes and readable values back up to supertypes,
- solve copy edges to a fixed point,
- rewrite only reads after the analysis stabilizes,
- preserve null traps by dropping or non-null-checking the receiver before yielding a replacement,
- repair packed-field reads with the right sign/zero-extension semantics,
- preserve descriptor-result type validity for `ref.get_desc`,
- bail out on successful ordered atomic reads while still allowing known-trapping reads to become unreachable,
- validate after every rewritten function/module.

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./copies-subtypes-ref-tests-and-atomics.md`](./copies-subtypes-ref-tests-and-atomics.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`../constant-field-null-test-folding/index.md`](../constant-field-null-test-folding/index.md)

## Nearby boundaries to keep distinct

### `constant-field-null-test-folding`

See [`../constant-field-null-test-folding/index.md`](../constant-field-null-test-folding/index.md) and the sibling-specific local status page [`../constant-field-null-test-folding/starshine-strategy.md`](../constant-field-null-test-folding/starshine-strategy.md).

The local sibling name corresponds to upstream `cfp-reftest`.
It reuses the CFP engine but adds one narrow two-bucket `select(ref.test(...))` read replacement family.
Do not teach it as a generic null-test folder.

### `global-type-optimization`

See [`../global-type-optimization/index.md`](../global-type-optimization/index.md).

`global-type-optimization` can remove or freeze fields and thereby make later CFP stronger.
CFP itself does not delete fields or change declared struct field mutability.

### `type-refining`

See [`../type-refining/index.md`](../type-refining/index.md).

`type-refining` changes declared field and function types.
CFP changes read expressions when values are provably constant/global.
Do not teach CFP as field-type narrowing.

### `global-struct-inference`

See [`../global-struct-inference/index.md`](../global-struct-inference/index.md).

`global-struct-inference` reasons about global-originated struct values and can un-nest fields into globals.
CFP reasons about type-level field values and rewrites reads.
They are neighboring closed-world GC/type passes, but their proof surfaces differ.

## Validation plan for the eventual port

A future implementation should validate in layers:

1. registry behavior
   - keep boundary-only rejection until the transform exists,
   - when the pass lands, update registry category, tests, tracker, and docs in the same change.
2. feature and world gates
   - no-GC modules are unchanged,
   - open-world requests are rejected or not scheduled,
   - closed-world test fixtures enable the rewrite explicitly.
3. core read-replacement families
   - never-created reads become `drop(ref); unreachable`,
   - default-created fields fold to zero with null-trap preservation,
   - single literal fields fold to constants,
   - immutable-global fields fold to `global.get`,
   - mutable-global sources remain unknown.
4. type graph and exactness
   - inexact supertype reads account for subtypes,
   - exact subtype reads can still optimize when the subtype view is stable,
   - child-field validity repairs avoid invalid replacement types.
5. hard boundary families
   - copy chains require fixed-point propagation,
   - packed reads preserve masking/sign-extension,
   - ordered atomic successful reads are kept,
   - known-trapping reads can still become explicit unreachable.
6. sibling variant coverage
   - `constant-field-null-test-folding` / `cfp-reftest` stays unavailable until ordinary CFP exists,
   - then add the exact-two-bucket `ref.test` split only as a second mode.
7. parity coverage
   - compare targeted fixtures against Binaryen `wasm-opt --closed-world --cfp` first,
   - compare `--cfp-reftest` only after the parent pass is green,
   - only then include the family in combined closed-world GC/type clusters.

## Current uncertainty and recommendation

The main local uncertainty is where shared closed-world struct-field/type-analysis infrastructure should live.
A one-off CFP implementation would duplicate machinery that nearby passes also need:

- [`global-type-optimization`](../global-type-optimization/index.md) needs whole-module private-struct field-use facts.
- [`type-refining`](../type-refining/index.md) needs closed-world field LUB and instruction repair.
- [`global-struct-inference`](../global-struct-inference/index.md) needs closed-world struct-origin and field-read reasoning.
- [`constant-field-null-test-folding`](../constant-field-null-test-folding/index.md) must be layered on ordinary CFP's facts.

Until a backlog slice decides that architecture, keep `constant-field-propagation` documented as boundary-only and unimplemented.
