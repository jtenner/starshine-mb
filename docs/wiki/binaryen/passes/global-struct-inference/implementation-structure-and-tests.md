---
kind: concept
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md
  - ../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md
  - ../../../raw/research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md
  - ../../../../../src/passes/global_struct_inference.mbt
  - ../../../../../src/passes/global_struct_inference_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./closed-world-analysis-and-unnesting.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
---

# `global-struct-inference` implementation structure and tests

## Purpose

This page maps the source-backed implementation and proof surface for `global-struct-inference`.

Read it as a follow-along guide:

- first for Binaryen's official owner file and lit contract
- then for Starshine's current smaller MoonBit implementation and its separate strategy page
- then for the gaps a parity-focused expansion must close

## Binaryen owner-file map

Primary source: [`../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md`](../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md), which points to the official `version_129` and current-main source URLs. Use [`../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md`](../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md) as the freshness bridge above it.

### `src/passes/GlobalStructInference.cpp`

This is the owner file for both public upstream siblings:

- `gsi`
- `gsi-desc-cast`

The important source regions are:

- file-level comment
  - states the high-level idea: infer reads from structs created in globals, including open-world direct immutable-global opportunities and stronger closed-world reasoning.
- `GlobalStructInference(bool optimizeToDescCasts)`
  - one pass class; a constructor flag enables the descriptor-cast sibling.
- `requiresNonNullableLocalFixups()`
  - returns false; this pass repairs changed expression types through explicit refinalization.
- `run(Module*)`
  - hard GC gate.
  - conditionally runs closed-world analysis.
  - always runs the optimizer afterward, which is why plain `gsi` is not closed-world-only.
- `analyzeClosedWorld(Module*)`
  - builds the `typeGlobals` map.
  - scans function-local `struct.new` allocations as poison sources.
  - scans globals for top-level immutable `struct.new` candidate origins and nested poison sources.
  - propagates poisoning and candidate names through the subtype graph.
- nested `FunctionOptimizer`
  - visits `StructGet`, `RefGetDesc`, and sibling-only `RefCast`.
  - owns the direct-global fast path, the closed-world candidate path, the value-grouping/select logic, un-nesting requests, and function refinalization.
- `readFromStructNew(...)`
  - reads a field or descriptor value from a candidate global initializer and delegates constant classification to `PossibleConstantValues`.
- `getReadValue(...)`
  - materializes replacement values, preserves null traps, handles packed-field repair, and records non-constant un-nesting work.
- public factories
  - `createGlobalStructInferencePass()` constructs the plain pass.
  - `createGlobalStructInferenceDescCastPass()` constructs the descriptor-cast sibling.

### Registration and scheduler files

- `src/passes/pass.cpp`
  - registers both `gsi` and `gsi-desc-cast`.
  - places plain `gsi` in the global-prepass cluster after earlier global cleanup/refinement work.
- `src/passes/passes.h`
  - declares both pass factories.

### Helper surfaces Binaryen relies on

- `src/ir/possible-constant.h`
  - makes literals and immutable `global.get`s materializable values.
  - does not make arbitrary expression trees semantically equivalent.
- `src/ir/subtypes.h`
  - supports upward poison propagation and upward candidate-global propagation.
- `src/ir/bits.h`
  - rebuilds packed-field signed/unsigned behavior.
- `src/ir/module-utils.h`
  - provides the parallel function analysis used for `struct.new` poison discovery.
- `src/ir/names.h`
  - supplies fresh valid global names during un-nesting.
- `src/passes/ReorderGlobals.cpp`
  - owns the nested `reorder-globals-always` repair that makes fresh un-nested globals appear before use.

## Binaryen test surface

### Dedicated lit oracle: `test/lit/passes/gsi.wast`

The shipped plain-GSI lit file is broad. Treat it as part of the pass contract, not as a tiny smoke test.

It covers:

- immutable-field positives and mutable-field negatives
- direct immutable-global reads
- one candidate global reference rewrites
- many globals collapsing to one unique value
- two unique values with one singleton group emitting `select(ref.eq(...))`
- more-than-two-unique-value bailouts
- two-equal-pair bailouts where one comparison is not enough
- function-local allocation poisoning
- nested global-initializer allocation poisoning
- child-to-parent candidate propagation
- child-to-parent poison propagation
- immutable `global.get` operands as materializable field values
- non-constant operand un-nesting into fresh globals
- packed-field signed/unsigned repair
- atomic gets on immutable fields
- `eqref` versus `anyref` declaration boundaries
- bottom/no-crash cases
- null-result refinement and refinalization

### Sibling context

Plain `gsi` already visits `ref.get_desc`, but the descriptor-cast rewrite is the separate public sibling `gsi-desc-cast`.

For that sibling's source and test map, use:

- [`../global-struct-inference-desc-cast/index.md`](../global-struct-inference-desc-cast/index.md)
- [`../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md)

## Starshine implementation map

Current local implementation is intentionally smaller than Binaryen's full `gsi` contract. The 2026-06-03 O4z audit upgraded it from closed-world-only to Binaryen-style open-world direct-global folding; follow-up closed-world facts slices added an analysis-only candidate/poison table with subtype poison and candidate propagation, without enabling local/param rewrites yet.

### `src/passes/optimize.mbt`

- `src/passes/optimize.mbt:279-280`
  - active module-pass registry entry for `global-struct-inference`.
- `src/passes/optimize.mbt:310`
  - local `optimize` preset placement after `global-refining`.
- `src/passes/optimize.mbt:326`
  - local `shrink` preset placement with the same early module cluster.
- `src/passes/optimize.mbt:131`
  - keeps `global-struct-inference-desc-cast` boundary-only, which is the sibling pass, not the active plain local pass.

### `src/passes/pass_manager.mbt`

- `src/passes/pass_manager.mbt:12308-12309`
  - dispatches the active module pass through `global_struct_inference_run_module_pass(mod_, options.closed_world)`.

This line shows the dispatcher still passes `closed_world`. The current direct-global subset no longer gates open-world folds on that flag; when the flag is true, Starshine now builds conservative closed-world candidate/poison facts before running the same direct rewrite layer.

### `src/passes/global_struct_inference.mbt`

- `src/passes/global_struct_inference.mbt:2`
  - summary string: folds immutable struct field reads from direct immutable global instances.
- `src/passes/global_struct_inference.mbt:20-270`
  - `GsiClosedWorldFacts`, struct-allocation scanners, equality-comparable global declaration filter, subtype propagation helpers, and `gsi_build_closed_world_facts(...)` for analysis-only closed-world candidate and poison facts.
- `src/passes/global_struct_inference.mbt:275-440`
  - default-value materialization, simple one-instruction result typing, accepted field-value materialization, candidate field-value harvesting from trusted global initializers, and accepted top-level global initializer constructors.
- `src/passes/global_struct_inference.mbt:443-560`
  - packed signed and unsigned value repair, then maps one trusted global plus one `struct.get*` to a replacement expression.
- `src/passes/global_struct_inference.mbt:563-670`
  - recursive body rewrite; only immediate `global.get` + `struct.get`, `struct.get_s`, or `struct.get_u` pairs are replaced.
- `src/passes/global_struct_inference.mbt:672-748`
  - cheap pre-scan to skip functions with no possible direct pair rewrite.
- `src/passes/global_struct_inference.mbt:750-854`
  - public pass entrypoint; builds closed-world facts when requested, runs the direct-global candidate table, rewrites changed functions, and returns the original module when no change is found.

## Starshine test surface

### `src/passes/global_struct_inference_test.mbt`

Current focused public-pipeline tests prove the local rewrite subset:

- open-world direct immutable-global field folding, including an exported immutable global positive
- nullable direct-global trap preservation with `ref.as_non_null` and `drop`
- packed i8/i16 signed and unsigned direct-read repair
- `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc` field extraction, including nullable-ref defaults
- mutable-field, mutable-global, and imported-global negatives
- non-global ref producers remaining unchanged even in closed world

### `src/passes/global_struct_inference_wbtest.mbt`

Current focused white-box tests prove the new closed-world fact builder:

- immutable top-level `struct.new*` globals become candidate origins by created struct type
- mutable globals and too-broad/`anyref` declared globals are excluded
- function-local `struct.new*` allocations poison the allocated type and clear its candidates
- nested non-top-level global-initializer `struct.new*` allocations poison only the nested allocated type
- poisoned child types poison parents, including modules with no global section
- child candidate globals propagate upward to parent types in deterministic global-index order

These tests now cover the direct-global O4z audit surfaces and the subtype-aware closed-world candidate-map foundation, but they are still far narrower than Binaryen `gsi.wast` because local/param rewrites, selects, and un-nesting remain absent.

## Current local-vs-Binaryen matrix

| Surface | Binaryen `version_129` | Starshine today |
| --- | --- | --- |
| GC gate | yes | implicit via supported syntax and pass inputs; no full Binaryen feature gate mirror |
| Open-world direct-global read | yes | yes for immediate `global.get` + `struct.get*` |
| Closed-world candidate map by heap type | yes | analysis-only direct-type plus subtype-propagated candidates and poison facts; not consumed by rewrites |
| Direct immutable-global fold | yes | yes, immediate-pair-only |
| Local/param/supertype-origin rewrite | yes | no |
| Function-local and nested-global poisoning | yes | yes, with poison propagated upward to parent types in the analysis-only facts |
| Subtype poisoning and propagation | yes | yes in analysis-only facts; not yet consumed by rewrites |
| One-value direct replacement | yes | only exact direct-global field value |
| Two-value `select(ref.eq(...))` | yes | no |
| Immutable `global.get` as materializable value | yes | yes for direct field payloads, but without global candidate grouping |
| Non-constant un-nesting | yes | no |
| Packed-field repair | yes | yes for `i32.const` direct payloads |
| Atomic gets | yes | no dedicated local surface |
| `ref.get_desc` | yes | no; descriptor constructors are covered only for ordinary field reads |
| `gsi-desc-cast` | sibling pass | boundary-only sibling name, no implementation |
| Refinalization | explicit Binaryen `ReFinalize` | represented differently; no equivalent full typed-AST repair layer in this pass |

## Beginner-to-advanced reading order

1. [`./index.md`](./index.md) for the pass purpose and local-vs-upstream headline.
2. [`./wat-shapes.md`](./wat-shapes.md) for before/after shapes and bailouts.
3. [`./binaryen-strategy.md`](./binaryen-strategy.md) for the official algorithm.
4. This page for owner files, helpers, and tests.
5. [`./starshine-strategy.md`](./starshine-strategy.md) for the current local status and port map.
6. [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md) for current local code.
7. [`./parity.md`](./parity.md) before making parity claims.

## Practical maintenance rule

When future work touches this pass, update this page if any of these change:

- local line-number code map
- active registry/preset/dispatcher status
- local test coverage
- whether Starshine still exits in open world
- whether Starshine consumes the analysis-only candidate map or gains any of Binaryen's subtype, select, un-nesting, atomic, descriptor, or refinalization surfaces

Do not describe saved-artifact parity as full pass parity unless the missing official shape families are also implemented or explicitly proven irrelevant for the chosen artifact.
