---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md
  - ../../../raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md
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
  - ../constant-field-propagation/starshine-strategy.md
  - ../constant-field-propagation/index.md
  - ../tracker.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md
  - ./wat-shapes.md
  - ../constant-field-propagation/starshine-strategy.md
  - ../constant-field-propagation/index.md
  - ../global-type-optimization/index.md
  - ../type-refining/index.md
  - ../global-struct-inference/index.md
---

# Starshine strategy for `constant-field-null-test-folding`

Use this page together with the sibling raw primary-source capture in [`../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md`](../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md) and the parent CFP Starshine page in [`../constant-field-propagation/starshine-strategy.md`](../constant-field-propagation/starshine-strategy.md).
The goal here is to make the local status of the **sibling** explicit so readers do not have to infer it from the parent `constant-field-propagation` dossier.

## The honest current status

`constant-field-null-test-folding` is still **unimplemented** in Starshine.
There is no `src/passes/constant_field_null_test_folding.mbt`, `src/passes/cfp_reftest.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- keep the local descriptive spelling `constant-field-null-test-folding` as a known boundary-only name,
- map that spelling to upstream Binaryen's public `cfp-reftest` contract in the wiki,
- reject active requests honestly instead of silently no-oping,
- keep the sibling unavailable until the parent ordinary CFP analysis exists,
- keep the pass out of the open-world no-DWARF presets,
- document why a future port is closed-world module/type-graph work, not a HOT peephole.

So this is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through current Starshine is:

- boundary-only pass-name tracking
  - [`src/passes/optimize.mbt#L127-L140`](../../../../../src/passes/optimize.mbt#L127-L140)
    - `pass_registry_boundary_only_names()` includes both `"constant-field-propagation"` and `"constant-field-null-test-folding"`.
- boundary-only registry-entry construction
  - [`src/passes/optimize.mbt#L266-L268`](../../../../../src/passes/optimize.mbt#L266-L268)
    - boundary-only names become `HotPassRegistryCategory::BoundaryOnly` entries through `pass_registry_entry_boundary_only(...)`.
- active request guard
  - [`src/passes/optimize.mbt#L446-L463`](../../../../../src/passes/optimize.mbt#L446-L463)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is boundary-only and is not implemented in the hot pipeline`.
- active preset absence
  - [`src/passes/optimize.mbt#L240-L263`](../../../../../src/passes/optimize.mbt#L240-L263)
    - the built-in `optimize` and `shrink` presets do not include either CFP-family name.
  - [`src/passes/registry_test.mbt#L121-L158`](../../../../../src/passes/registry_test.mbt#L121-L158)
    - the preset test asserts that every expanded preset name is active `HotPass` or `ModulePass`.
- no owner file today
  - `src/passes/` has no `*constant*` or `*field*` pass file matching this sibling.
- backlog absence
  - [`agent-todo.md`](../../../../../agent-todo.md) has no dedicated `constant-field-null-test-folding` or `cfp-reftest` slice.
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) does not place the sibling in the current open-world no-DWARF default route.

That map is the durable local status today: the name is preserved and rejected as boundary-only, with no implementation, no dispatcher case, no preset role, and no active backlog slice.

## What local infrastructure is relevant but not sufficient

A future port would reuse existing syntax, IR, binary, and validation surfaces, but none of these are the pass itself:

- heap/ref/type graph representation
  - [`src/lib/types.mbt#L31-L57`](../../../../../src/lib/types.mbt#L31-L57) models `HeapType`, `RefType`, and `ValType`.
  - [`src/lib/types.mbt#L136-L159`](../../../../../src/lib/types.mbt#L136-L159) models rec groups, subtypes, and def types.
- instruction representation
  - [`src/lib/types.mbt#L733-L761`](../../../../../src/lib/types.mbt#L733-L761) includes `StructGet`, `StructGetS`, `StructGetU`, `StructSet`, `RefTest`, descriptor-test/cast instructions, and neighboring GC opcodes.
- WAT and binary front/back doors
  - [`src/wast/parser.mbt#L410-L437`](../../../../../src/wast/parser.mbt#L410-L437) parses GC/descriptor instruction variants.
  - [`src/wast/lower_to_lib.mbt#L2418-L2453`](../../../../../src/wast/lower_to_lib.mbt#L2418-L2453) lowers type immediates for struct and descriptor operations.
  - [`src/binary/encode.mbt#L2629-L2659`](../../../../../src/binary/encode.mbt#L2629-L2659) emits the GC struct-field opcode family; the paired decoder preserves the input instruction surface.
- validation rules a rewrite must preserve
  - [`src/validate/env.mbt#L150-L181`](../../../../../src/validate/env.mbt#L150-L181) resolves heap types, subtypes, and type indices.
  - [`src/validate/env.mbt#L246-L272`](../../../../../src/validate/env.mbt#L246-L272) populates validation environments from rec groups.
  - [`src/validate/typecheck.mbt#L1868-L1930`](../../../../../src/validate/typecheck.mbt#L1868-L1930) validates `ref.test`, `ref.cast`, `ref.get_desc`, and descriptor compatibility.
  - [`src/validate/typecheck.mbt#L2115-L2178`](../../../../../src/validate/typecheck.mbt#L2115-L2178) validates `struct.get`, packed `struct.get_s` / `struct.get_u`, and `struct.set`.

Those surfaces prove Starshine can represent the syntax a future port needs.
They do **not** prove any current CFP field-fact analysis, subtype bucket solver, or `select(ref.test(...))` transform exists.

## Why this sibling cannot land before ordinary CFP

Binaryen's `cfp-reftest` is not an independent matcher.
The upstream raw capture shows the sibling as `ConstantFieldPropagation(true)`: the same closed-world CFP engine with one extra `ref.test` rescue mode.

A faithful Starshine port therefore needs the parent machinery first:

1. closed-world and GC gates,
2. module-wide struct-field write/default/copy scanning,
3. exact-versus-inexact reference fact handling,
4. subtype hierarchy propagation,
5. copy-edge fixed-point solving,
6. plain single-value read replacement,
7. packed-field, atomic, null-trap, and descriptor-result safety,
8. final validation/refinalization after rewrites.

Only after that exists should the sibling add:

- the exact-two-value-bucket path,
- one simple subtype classifier per side,
- `ref.as_non_null` receiver repair where needed,
- `select(payload_a, payload_b, ref.test(...))` output.

Trying to implement only the visible WAT shape as a HOT local peephole would miss the source-backed contract.

## What Starshine currently promises

For users and future implementers, the current promise is intentionally conservative:

- `constant-field-null-test-folding` is discoverable as a known pass name.
- Explicit requests fail with a boundary-only diagnostic.
- The pass is absent from `optimize` and `shrink` presets.
- The sibling's upstream identity is documented as `cfp-reftest`, not hidden behind the local alias.
- The wiki records the transformation shape and the implementation prerequisites, but Starshine does not claim to optimize it today.

## Future implementation checklist

A future Starshine port should preserve these sibling-specific requirements:

- implement or share the parent `constant-field-propagation` field-fact engine first,
- keep the sibling as a mode/variant of that engine rather than a separate syntax-only pass,
- use the upstream/local name split in registry docs and CLI diagnostics,
- require the same closed-world and GC gates as ordinary CFP,
- try ordinary one-bucket CFP replacement before the sibling rescue path,
- require exactly two surviving replacement buckets,
- require one testable subtype partition that matches the value split,
- keep payloads inside CFP's tiny replacement lattice,
- preserve null-trap behavior around nullable receivers,
- preserve packed-field and ordered-atomic boundaries inherited from CFP,
- validate the emitted `ref.test`, `ref.as_non_null`, and `select` forms under Starshine's current typechecker.

## Validation plan for the eventual port

1. Keep the current boundary-only tests green until a transform exists.
2. Add parent CFP fixtures first: default fields, literal writes, immutable global writes, copy fixed points, packed fields, atomic bailouts, and null traps.
3. Add sibling fixtures only after parent CFP is green:
   - two subtype populations with two constants,
   - one constant plus one immutable global,
   - nullable-base repair,
   - no-op `struct.set` tolerance if the parent analysis supports it,
   - three-value bailout,
   - two-value no-single-test bailout,
   - payload-outside-lattice bailout.
4. Compare targeted fixtures against `wasm-opt --cfp-reftest --closed-world`.
5. Keep the family out of open-world no-DWARF presets unless a future scheduler decision deliberately adds a closed-world GC/type route.

## Current uncertainty and recommendation

The main unresolved design question is where Starshine should put shared closed-world GC/type-analysis infrastructure.
This sibling should not own that infrastructure alone; the same field/type facts are relevant to [`constant-field-propagation`](../constant-field-propagation/index.md), [`type-refining`](../type-refining/index.md), [`global-type-optimization`](../global-type-optimization/index.md), and [`global-struct-inference`](../global-struct-inference/index.md).

Until that architecture exists, keep `constant-field-null-test-folding` boundary-only, explicitly rejected, and documented as a future closed-world module-pass variant.

## Sources

- [`../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md`](../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md)
- [`../../../raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md`](../../../raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md)
- [`../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md`](../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md)
- [`../constant-field-propagation/starshine-strategy.md`](../constant-field-propagation/starshine-strategy.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/wast/parser.mbt`](../../../../../src/wast/parser.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
