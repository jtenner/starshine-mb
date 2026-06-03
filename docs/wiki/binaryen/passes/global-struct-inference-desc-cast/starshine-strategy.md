---
kind: concept
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md
  - ../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md
  - ../../../raw/binaryen/2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
  - ../../../raw/research/0488-2026-05-05-global-struct-inference-desc-cast-current-main-recheck.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/global_struct_inference.mbt
  - ../../../../../src/passes/global_struct_inference_test.mbt
  - ../../../../../src/cmd/fuzz_harness_wbtest.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./descriptor-singleton-gate-and-dedicated-tests.md
  - ./wat-shapes.md
  - ../global-struct-inference/starshine-hot-ir-strategy.md
  - ../global-struct-inference/index.md
---

# Starshine `global-struct-inference-desc-cast` status and port strategy

This page describes the **current local Starshine status** for the local pass name `global-struct-inference-desc-cast`, which corresponds to upstream Binaryen's public `gsi-desc-cast` sibling.

## Current local status

Starshine does **not** implement this pass today.

The local status is:

- registry name: `global-struct-inference-desc-cast`
- upstream public name: `gsi-desc-cast`
- registry category: `BoundaryOnly`
- active presets: omitted
- pass-manager dispatch: absent
- owner file: absent
- active backlog slice: absent
- direct behavior tests: only request-rejection / failure-report plumbing, not transform behavior

A 2026-05-05 current-main recheck did not change the local status; the page's exact code map still points at the same boundary-only request guard, active plain-GSI sibling, and opcode/validator prerequisites.

The most important beginner-safe statement is:

- Starshine has an active plain [`global-struct-inference`](../global-struct-inference/index.md) module pass, but it is **not** the descriptor-cast sibling.

## Exact local code map

Use this map to follow the current implementation boundary in-tree.

### Registry and request behavior

- [`src/passes/optimize.mbt:129`](../../../../../src/passes/optimize.mbt#L129)
  - `pass_registry_boundary_only_names()` includes `global-struct-inference-desc-cast`.
- [`src/passes/optimize.mbt:463`](../../../../../src/passes/optimize.mbt#L463)
  - `run_hot_pipeline_expand_passes(...)` rejects boundary-only entries with the not-implemented-in-hot-pipeline message.
- [`src/cmd/fuzz_harness_wbtest.mbt:206`](../../../../../src/cmd/fuzz_harness_wbtest.mbt#L206)
  - the fuzz harness uses `global-struct-inference-desc-cast` as a generic boundary-only optimize-failure probe and asserts that the failure report keeps the requested pass name.

### Active plain-GSI sibling, not this pass

- [`src/passes/optimize.mbt:242`](../../../../../src/passes/optimize.mbt#L242)
  - active module-pass registry entry for plain `global-struct-inference`.
- [`src/passes/optimize.mbt:250`](../../../../../src/passes/optimize.mbt#L250)
  - public preset expansion includes plain `global-struct-inference`, not `global-struct-inference-desc-cast`.
- [`src/passes/pass_manager.mbt:12308`](../../../../../src/passes/pass_manager.mbt#L12308)
  - module-pass dispatcher routes only the active plain `global-struct-inference` case into `global_struct_inference_run_module_pass(...)`.
- [`src/passes/global_struct_inference.mbt:497`](../../../../../src/passes/global_struct_inference.mbt#L497)
  - local plain-GSI entrypoint. It runs the current open-world direct-global struct-field fold and does not implement descriptor-cast rewrites.
- [`src/passes/global_struct_inference.mbt:152`](../../../../../src/passes/global_struct_inference.mbt#L152)
  - local candidate discovery accepts only visible top-level struct constructors in immutable global initializers.
- [`src/passes/global_struct_inference.mbt:310`](../../../../../src/passes/global_struct_inference.mbt#L310)
  - local rewrite surface rewrites immediate `global.get` + `struct.get*` pairs. It does not synthesize `ref.cast_desc_eq`.
- [`src/passes/global_struct_inference_test.mbt:28`](../../../../../src/passes/global_struct_inference_test.mbt#L28)
  - focused local tests cover open-world direct-global field folding, packed/default/descriptor-constructor fields, unsafe-global negatives, and non-global producer bailouts.

### Enabling instruction infrastructure already present

These files mean Starshine can parse, represent, validate, and encode descriptor-equality casts. They do **not** mean the pass exists.

- [`src/lib/types.mbt:762`](../../../../../src/lib/types.mbt#L762)
  - IR instruction variant `RefCastDescEq(Bool, HeapType)`.
- [`src/lib/types.mbt:4187`](../../../../../src/lib/types.mbt#L4187)
  - constructor helper for descriptor-equality casts.
- [`src/wast/keywords.mbt:125`](../../../../../src/wast/keywords.mbt#L125)
  - WAT keywords `ref.cast_desc_eq` and `ref.cast_desc_eq_null`.
- [`src/wast/lower_to_lib.mbt:2461`](../../../../../src/wast/lower_to_lib.mbt#L2461)
  - WAT lowering resolves the type index and emits `Instruction::ref_cast_desc_eq(...)`.
- [`src/validate/typecheck.mbt:3267`](../../../../../src/validate/typecheck.mbt#L3267)
  - validator dispatches `RefCastDescEq` to its stack-effect/type rule.
- [`src/validate/typecheck.mbt:6613`](../../../../../src/validate/typecheck.mbt#L6613)
  - focused validator test covers the `RefCastDescEq` stack effect.
- [`src/binary/encode.mbt:2942`](../../../../../src/binary/encode.mbt#L2942)
  - binary encoder emits the non-nullable descriptor-equality cast opcode.
- [`src/binary/encode.mbt:2951`](../../../../../src/binary/encode.mbt#L2951)
  - binary encoder emits the nullable descriptor-equality cast opcode.
- [`src/binary/decode.mbt:3197`](../../../../../src/binary/decode.mbt#L3197)
  - binary decoder reads the same opcode pair back into `ref_cast_desc_eq(...)` instructions.

## Current local behavior in one example

If a user asks Starshine to run the pass explicitly, the request is rejected before any transform runs:

```text
pass flag global-struct-inference-desc-cast is boundary-only and is not implemented in the hot pipeline
```

That behavior is intentional today. It is more honest than silently treating the pass as plain `global-struct-inference`, because Binaryen's sibling has a real extra `ref.cast` -> `ref.cast_desc_eq` rewrite family.

## What Starshine's active `global-struct-inference` does instead

The active plain pass is documented in [`../global-struct-inference/starshine-hot-ir-strategy.md`](../global-struct-inference/starshine-hot-ir-strategy.md).

It currently:

1. requires `closed_world=true`
2. scans immutable defined globals with top-level struct constructors
3. records immutable field payloads for those globals
4. rewrites direct `global.get` + `struct.get*` pairs
5. preserves nullable-global null traps by emitting `global.get`, optional `ref.as_non_null`, `drop`, then the folded value

It currently does **not** build Binaryen's `typeGlobals` heap-type-to-global map and does **not** inspect `ref.cast`.

## Gap from Binaryen `gsi-desc-cast`

A faithful local port needs more than a small peephole on top of today's direct-global folder.

It would need these missing layers:

- shared GSI-family mode flag or sibling dispatcher entry
- closed-world `typeGlobals` map keyed by heap/descriptor type, not just by concrete global index
- descriptor-type discovery for cast targets
- strict-subtype table for exact-vs-nonexact legality
- exactly-one-global check for the target descriptor heap type
- `ref.cast_desc_eq` synthesis at the original target type
- continued support for the plain-GSI direct-global field-read subset
- a clear policy for inherited descriptor un-nesting and nested `reorder-globals-always` repair
- parity tests based on Binaryen's `gsi-to-desc-cast.wast`

## Suggested future port shape

A future implementation should probably treat this as **GSI-family module work**, not as a HOT peephole.

A safe staged plan would be:

1. Keep the existing direct-global `global_struct_inference.mbt` tests green.
2. Add an explicit registry classification change only when a real transform exists.
3. Build a small closed-world descriptor-global table for descriptor heap types.
4. Add a subtype-query helper capable of answering the exact-or-no-strict-subtypes gate.
5. Implement one direct `ref.cast` -> `ref.cast_desc_eq` rewrite family.
6. Add tests mirroring the Binaryen positive and bailout shapes:
   - singleton descriptor global positive
   - non-exact target with strict subtypes bailout
   - exact target positive
   - zero descriptor globals bailout
   - multiple descriptor globals bailout
   - target without descriptor bailout
   - nullable target positive
   - unreachable cast preservation
7. Only then consider sharing more of Binaryen's broader GSI `typeGlobals` / descriptor un-nesting machinery.

## Non-goals for the current wiki status

Do not describe current Starshine as doing any of these:

- running `gsi-desc-cast`
- emitting `ref.cast_desc_eq` as an optimization
- building Binaryen's full `typeGlobals` map
- proving strict-subtype legality for cast targets
- placing the sibling in the active `optimize` or `shrink` preset
- having a hidden owner file for the sibling

Those would overstate the current code.

## Validation guidance

Today, validation for this page is documentation and request-behavior validation, not pass parity:

- Registry status: inspect `src/passes/optimize.mbt` and `src/passes/registry_test.mbt`.
- Request rejection: inspect `run_hot_pipeline_expand_passes(...)` and the fuzz-harness boundary-only test.
- Plain-GSI sibling behavior: inspect `src/passes/global_struct_inference.mbt` and `src/passes/global_struct_inference_test.mbt`.
- Prerequisite opcode support: inspect `src/lib/types.mbt`, `src/wast/lower_to_lib.mbt`, `src/validate/typecheck.mbt`, `src/binary/encode.mbt`, and `src/binary/decode.mbt`.

A future implementation should add pass-specific tests before changing this page from boundary-only status.

## Sources

- [`../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md)
- [`../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md`](../../../raw/research/0326-2026-04-24-global-struct-inference-desc-cast-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/global_struct_inference.mbt`](../../../../../src/passes/global_struct_inference.mbt)
- [`../../../../../src/passes/global_struct_inference_test.mbt`](../../../../../src/passes/global_struct_inference_test.mbt)
- [`../../../../../src/cmd/fuzz_harness_wbtest.mbt`](../../../../../src/cmd/fuzz_harness_wbtest.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
