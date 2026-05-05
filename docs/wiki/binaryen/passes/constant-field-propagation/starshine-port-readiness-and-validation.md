---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-constant-field-propagation-current-main-recheck.md
  - ../../../raw/research/0474-2026-05-05-constant-field-propagation-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md
  - ../../../raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0158-2026-04-21-constant-field-propagation-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./copies-subtypes-ref-tests-and-atomics.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../constant-field-null-test-folding/index.md
  - ../constant-field-null-test-folding/starshine-strategy.md
  - ../global-type-optimization/index.md
  - ../global-struct-inference/index.md
  - ../type-refining/index.md
---

# Starshine port readiness and validation for `constant-field-propagation`

Use this page as the implementation bridge between Binaryen's source-backed CFP contract and Starshine's current boundary-only status.
The 2026-05-05 current-main recheck in [`../../../raw/binaryen/2026-05-05-constant-field-propagation-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-constant-field-propagation-current-main-recheck.md) repeated the same narrow source-level check and found no teaching-relevant drift.
The pass is still unimplemented locally; this page exists so a future port starts with the right module/type rewrite shape instead of a misleading HOT peephole.

## Current local decision

Keep `constant-field-propagation` boundary-only until Starshine can run a closed-world module pass that updates all of these surfaces together:

- function heap types and their nominal declarations;
- struct field reads, packed reads, and descriptor reads;
- type-view exactness and subtype relationships;
- validator and binary round-trip behavior after the read rewrite.

The current registry behavior is therefore correct:

- [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140) keeps `constant-field-propagation` and `constant-field-null-test-folding` in `pass_registry_boundary_only_names()`.
- [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263) omits them from the active `optimize` / `shrink` presets.
- [`src/passes/optimize.mbt#L446-L463`](../../../../../src/passes/optimize.mbt#L446-L463) rejects explicit boundary-only requests instead of silently no-oping.

## Why direct `struct.get` folding is not enough

The tempting first implementation is: detect `struct.new(... const ...)` or `struct.set` followed by a later read and rewrite the read.
That is not Binaryen parity.

Binaryen decides by **whole-module field facts**:

- all writes/defaults/copies for the field matter;
- exact and inexact reference views are tracked separately;
- subtype relationships change which instances count;
- copy edges need a fixed point;
- packed fields need sign/zero-extension repair;
- descriptor reads need their own result-type repair;
- ordered-atomic successful reads are a deliberate bailout;
- known-trapping reads may still become `drop(ref); unreachable`.

So the smallest honest Starshine port is still module-wide.
A local peephole is only acceptable if it is explicitly a first slice on top of the same field-fact engine, not a replacement for it.

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
    - the built-in `optimize` and `shrink` presets do not include either CFP-family name.
  - [`src/passes/registry_test.mbt#L121-L158`](../../../../../src/passes/registry_test.mbt#L121-L158)
    - the preset test asserts that every expanded preset name is active `HotPass` or `ModulePass`.
- GC/type/struct/descriptor representation a future port would have to inspect
  - [`src/lib/types.mbt#L31-L57`](../../../../../src/lib/types.mbt#L31-L57)
    - `HeapType`, `RefType`, and `ValType` encode the reference-type surface the pass must reason about.
  - [`src/lib/types.mbt#L136-L159`](../../../../../src/lib/types.mbt#L136-L159)
    - `TypeMetadata`, `SubType`, `RecType`, and `DefType` encode the struct, subtype, rec-group, descriptor, and exact-def-type surfaces.
  - [`src/lib/types.mbt#L733-L761`](../../../../../src/lib/types.mbt#L733-L761)
    - `StructNew`, `StructNewDefault`, `StructNewDesc`, `StructNewDefaultDesc`, `StructGet`, `StructGetS`, `StructGetU`, `StructSet`, `RefGetDesc`, `RefTest`, and descriptor-cast instructions are represented as library instructions.
- WAT parser / lowerer surfaces a future port can reuse for fixtures
  - [`src/wast/parser.mbt#L410-L437`](../../../../../src/wast/parser.mbt#L410-L437)
    - the parser already distinguishes struct creation, field reads, descriptor reads, and descriptor tests.
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

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- require GC support and closed-world mode before rewriting;
- keep open-world behavior explicit and non-silent;
- keep parent `constant-field-propagation` / upstream `cfp` separate from sibling `constant-field-null-test-folding` / upstream `cfp-reftest`;
- collect write/default/copy/RMW evidence for struct fields across the module;
- use a tiny literal-or-immutable-global value lattice for plain CFP;
- keep exact and inexact reference facts separate;
- propagate written values down to subtypes and readable values back up to supertypes;
- solve copy edges to a fixed point;
- rewrite only reads after the analysis stabilizes;
- preserve null traps by dropping or non-null-checking the receiver before yielding a replacement;
- repair packed-field reads with the right sign/zero-extension semantics;
- preserve descriptor-result type validity for `ref.get_desc`;
- bail out on successful ordered atomic reads while still allowing known-trapping reads to become unreachable;
- validate after every rewritten function/module.

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./copies-subtypes-ref-tests-and-atomics.md`](./copies-subtypes-ref-tests-and-atomics.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`../constant-field-null-test-folding/index.md`](../constant-field-null-test-folding/index.md)
- [`../constant-field-null-test-folding/starshine-strategy.md`](../constant-field-null-test-folding/starshine-strategy.md)

## Validation plan for the eventual port

1. Registry honesty
   - keep the current boundary-only rejection until a mutating module pass exists;
   - when the pass lands, update registry category, tests, tracker, and docs in the same change.
2. Feature and world gates
   - no-GC modules are unchanged;
   - open-world requests are rejected or not scheduled;
   - closed-world test fixtures enable the rewrite explicitly.
3. Core read-replacement families
   - never-created reads become `drop(ref); unreachable`;
   - default-created fields fold to zero with null-trap preservation;
   - single literal fields fold to constants;
   - immutable-global fields fold to `global.get`;
   - mutable-global sources remain unknown.
4. Type graph and exactness
   - inexact supertype reads account for subtypes;
   - exact subtype reads can still optimize when the subtype view is stable;
   - child-field validity repairs avoid invalid replacement types.
5. Hard boundary families
   - copy chains require fixed-point propagation;
   - packed reads preserve masking/sign-extension;
   - ordered atomic successful reads are kept;
   - known-trapping reads can still become explicit unreachable.
6. Sibling variant coverage
   - `constant-field-null-test-folding` / `cfp-reftest` stays unavailable until ordinary CFP exists;
   - then add the exact-two-bucket `ref.test` split only as a second mode.
7. Parity coverage
   - compare targeted fixtures against Binaryen `wasm-opt --closed-world --cfp` first;
   - compare `--cfp-reftest` only after the parent pass is green;
   - only then include the family in combined closed-world GC/type clusters.

## Current uncertainty and recommendation

The main local uncertainty is where shared closed-world struct-field/type-analysis infrastructure should live.
A one-off CFP implementation would duplicate machinery that nearby passes also need:

- [`global-type-optimization`](../global-type-optimization/index.md) needs whole-module private-struct field-use facts.
- [`type-refining`](../type-refining/index.md) needs closed-world field LUB and instruction repair.
- [`global-struct-inference`](../global-struct-inference/index.md) needs closed-world struct-origin and field-read reasoning.
- [`constant-field-null-test-folding`](../constant-field-null-test-folding/index.md) must be layered on ordinary CFP's facts.

Until that architecture is decided, keep `constant-field-propagation` documented as boundary-only and unimplemented.
