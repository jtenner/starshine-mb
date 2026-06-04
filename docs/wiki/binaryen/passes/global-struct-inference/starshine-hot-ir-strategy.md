---
kind: concept
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/binaryen/2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md
  - ../../../raw/research/0506-2026-05-06-global-struct-inference-current-main-recheck.md
  - ../../../raw/research/0344-2026-04-25-global-struct-inference-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md
  - ../../../raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md
  - ../../../raw/research/0068-2026-03-25-global-struct-inference.md
  - ../../../../../src/passes/global_struct_inference.mbt
  - ../../../../../src/passes/global_struct_inference_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-analysis-and-unnesting.md
  - ./starshine-strategy.md
  - ./wat-shapes.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine `global-struct-inference` module-pass strategy

This page describes the **current local MoonBit implementation detail**, not the full upstream Binaryen `GlobalStructInference.cpp` contract or the separate higher-level Starshine strategy page. For the side-by-side owner-file, helper, test, and line-number map, see [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md); for the current local status and port map, see [`./starshine-strategy.md`](./starshine-strategy.md).

## Current local surface

Starshine exposes `global-struct-inference` as an active module pass with:

- descriptor name: `global-struct-inference`
- summary text: `Fold immutable struct field reads from direct immutable global instances when their values are globally fixed.`
- preset placement in the early module cluster after `global-refining`
- module-pass dispatch through `pass_manager.mbt`; the `options.closed_world` flag is still accepted by the entrypoint, but the direct-global fast path no longer requires it

The most important immediate local rule is:

- **the pass is an open-world direct-global rewriting subset plus narrow closed-world local/param rewrites for one exact or subtype-propagated candidate, one materializable value, or two materializable values with one singleton group, not a full closed-world origin-analysis port**

`global_struct_inference_run_module_pass(...)` now scans immutable defined globals and rewrites direct `global.get` + `struct.get*` pairs even when `closed_world` is false. That matches Binaryen's direct immutable-global fast path. In closed-world mode it builds a `typeGlobals`-shaped fact table for safe candidate globals, poisoned allocation types, subtype poison propagation, and upward candidate propagation, then consumes exact or subtype-propagated local/param reads for one-global origin rewrites when the candidate global's declared reference heap type validates as a subtype of the read type, and exact or subtype-propagated local/param reads when the safe candidates have one materializable equal field value or exactly two materializable values with one singleton candidate group.

## Current local code map

The easiest way to follow the in-tree implementation is this file map:

- `src/passes/global_struct_inference.mbt:2`
  - summary string used by the registry and preset docs
- `src/passes/global_struct_inference.mbt:20-460`
  - `GsiClosedWorldFacts`, allocation scanners, equality-comparable global declaration filter, subtype propagation helpers, exact direct candidate extraction, exact direct single-candidate extraction, and `gsi_build_closed_world_facts(...)`
- `src/passes/global_struct_inference.mbt:577-1146`
  - guarded small-module arithmetic/bitwise/shift-rotate/unary-numeric/float-sqrt un-nesting request collection, fresh-global synthesis, initializer repair, dynamic packed signed/unsigned repair for fresh-global payloads, and forced reorder-globals repair
- `src/passes/global_struct_inference.mbt:1149-1232`
  - `gsi_candidate_field_values(...)` and `gsi_candidate_global_values(...)`: harvest immutable field payloads from trusted global initializers, with descriptor-constructor field operands read before the descriptor operand, and accept only top-level `struct.new`, `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc` globals
- `src/passes/global_struct_inference.mbt:1235-2118`
  - exact and subtype-propagated local/param origin helpers, one-value local fold helpers, two-value singleton-group select helpers, candidate-created-type subtype checks, and `gsi_folded_global_field_expr(...)` / `gsi_folded_candidate_global_field_expr(...)`: map trusted globals plus one `struct.get*` into replacement expressions, including packed-field repair
- `src/passes/global_struct_inference.mbt:2121-2345`
  - `gsi_rewrite_instrs(...)`: recurse through bodies and rewrite immediate `global.get` + `struct.get*` instruction pairs, closed-world exact and subtype-propagated single-candidate `local.get` + `struct.get*` origin pairs, closed-world exact/subtype-propagated one-value local folds, and closed-world exact/subtype-propagated two-value singleton-group selects
- `src/passes/global_struct_inference.mbt:2348-2562`
  - `gsi_instrs_may_rewrite(...)`: cheap pre-scan used to skip unchanged functions
- `src/passes/global_struct_inference.mbt:2565-2726`
  - `global_struct_inference_run_module_pass(...)`: builds closed-world exact single-candidate and propagated candidate facts when requested, then runs the direct-global candidate table build, per-function rewrite loop, and final `with_code_sec(...)` replacement
- `src/passes/global_struct_inference_test.mbt:28-1062`
  - focused positive/negative local coverage for the direct-global subset, guarded arithmetic/bitwise/shift-rotate/unary-numeric/float-sqrt un-nesting, exact single-candidate local/param origin subset, exact/subtype-propagated one-value local/param fold subset, and exact/subtype-propagated two-value singleton-group select subset
- `src/passes/global_struct_inference_wbtest.mbt:1-240`
  - analysis-only closed-world fact coverage for candidate inclusion/exclusion, poisoning, subtype poison propagation including no-global-section poison propagation, upward candidate propagation, and deterministic candidate ordering
- `src/passes/pass_manager.mbt:12308-12309`
  - active module-pass dispatch site
- `src/passes/optimize.mbt:279-280`
  - pass registry entry and summary wiring
- `src/passes/optimize.mbt:310`
  - `optimize` preset cluster placement after `global-refining`
- `src/passes/optimize.mbt:326`
  - `shrink` preset cluster placement after `global-refining`

## How the local pass works today

## 1. Candidate discovery is still rewrite-limited, but closed-world facts now exist

The local rewrite implementation still starts from the narrow direct-global table. In closed-world mode, the fact table records candidate global origins by struct type, poisoned allocation types, and subtype-propagated poison/candidate facts. Exact-direct candidate tables feed the exact single-candidate origin rewrite, subtype-propagated candidate tables feed parent/supertype single-candidate origin rewrites only when the candidate global's declared reference heap type is validation-safe for the read type, and the one-value/two-value paths consume the propagated safe candidate list after verifying each candidate-created type is a subtype of the read type before materializing a field value.

The direct rewrite scans defined globals and records candidate field values only when all of these are true:

- the global is defined, not imported
- the global is immutable
- the initializer ends in one of the accepted top-level struct constructors
- the initializer arity matches the declared field layout closely enough for local extraction

That logic lives in:

- `gsi_candidate_field_values(...)`
- `gsi_candidate_global_values(...)`
- the candidate-global collection loop inside `global_struct_inference_run_module_pass(...)`

This means the local pass trusts only a very small origin family:

- top-level immutable globals whose values are visibly constructed in their own initializer expression

The closed-world fact table now reasons about direct top-level candidates, function-local allocation poisoning, nested-global allocation poisoning, mutable-global exclusion, too-broad/`anyref` global declaration exclusion, poisoned-child-to-parent propagation, and child-candidate-to-parent propagation. It now reasons about locals and params as exact or subtype-propagated single-candidate rewrite origins, exact or subtype-propagated one-value folds, and exact or subtype-propagated two-value singleton-group selects. It still limits un-nesting to small modules and selected pure arithmetic/bitwise/shift-rotate/unary-numeric/float-sqrt scalar field operands.

## 2. Value materialization is intentionally small and syntax-driven

The local pass can materialize only a compact replacement vocabulary.
The helper surface accepts:

- numeric constants
- `v128.const`
- `ref.null`
- `ref.func`
- immutable `global.get`
- `string.const`
- default values for defaultable field types

Packed fields are handled specially:

- literal `i32.const` payloads are folded to repaired constants
- immutable `global.get` payloads produced by the guarded un-nesting path are repaired dynamically with `i32.extend8s` / `i32.extend16s` for signed reads and `i32.and` masks for unsigned reads, including closed-world one-value and singleton-select value grouping
- `gsi_pack_signed(...)`, `gsi_pack_unsigned(...)`, and `gsi_packed_expr(...)` rebuild the signed or unsigned packed read result

This is narrower than upstream Binaryen's `PossibleConstantValues` plus un-nesting path; the guarded un-nesting vocabulary currently includes arithmetic add/sub/mul, integer bitwise and/or/xor, integer shift/rotate, pure unary numeric operands, and float square roots.

## 3. The rewrite surface is immediate `global.get` -> `struct.get*`

The local rewrite engine looks only for adjacent producer/read pairs:

```wat
(global.get $g)
(struct.get* ...)
```

or, in closed world only:

```wat
(local.get $x)
(struct.get* ...)
```

The closed-world local/param pair either rewrites an exact or subtype-propagated reference operand to a single candidate global, consumes both instructions and returns a trap-preserving folded value when exact or subtype-propagated candidates all materialize the same field value, or consumes both instructions and returns a typed `select` guarded by `ref.eq` against the singleton candidate global when exactly two materializable values are distinguishable by one compare.

`gsi_rewrite_instrs(...)` recursively descends into:

- `block`
- `loop`
- `if`
- `try_table`

but at each level it still rewrites only those immediate adjacent pairs.

So the pass can optimize through nested control bodies, but it does **not** optimize arbitrary operand producers. The one-global local/param case emits a result-typed block that evaluates and drops the original local, using `ref.as_non_null` when needed, then yields the one safe global candidate; subtype-propagated origin rewrites additionally require the candidate global's declared heap type to be a subtype of the read type, so broad `eqref` declarations bail. The one-value local/param case emits a result-typed block that evaluates and drops the original local, then yields the shared materializable field value and consumes the following `struct.get*`. The two-value local/param case emits a result-typed block containing both materialized values, the original local reference, an optional `ref.as_non_null` for nullable locals, a singleton-candidate `global.get`, `ref.eq`, and a typed `select`. It will not rewrite cases where the reference comes from:

- a multi-candidate local/param type with more than two values or two non-singleton value groups
- a poisoned type
- a parent-typed candidate set that cannot rewrite to one validation-safe origin, fold to one value, or fold to one singleton-tested two-value select
- a `select`
- a more distant expression tree

That is the core reason the local implementation should be taught as a narrow direct-global folder, not as the full upstream origin-analysis pass.

## 4. Null-trap preservation is explicit in the emitted instruction stream

When the local pass folds a nullable global-backed or one-value local read, it preserves the original null trap by emitting:

- the original reference producer
- `ref.as_non_null` when the reference type is nullable
- `drop`
- the folded replacement value

For two-value local selects, the emitted block instead feeds the original local reference through `ref.as_non_null` on the `ref.eq` condition path before selecting between materialized values.

That is why the focused positives check for:

- disappearance of `struct.get`
- continued presence of the trap-preserving `ref.as_non_null` path

This local detail matches the spirit of upstream Binaryen's trap-preserving rewrite, even though the surrounding analysis is much smaller.

## 5. Function rewriting is cheap-scan first, then structural copy-on-change

`gsi_instrs_may_rewrite(...)` acts as a prefilter before any function body is rebuilt.
If no matching pair appears in the current instruction tree, the function is skipped.

When a rewrite does happen, the pass:

- rebuilds only that function's instruction list
- preserves the existing local declarations
- swaps the changed function into a copied `code_sec`
- returns the original module unchanged if no function actually changed

So the local strategy is intentionally simple:

- build one candidate-global table
- run one recursive pair-rewrite per function
- replace changed functions only

## What the local pass does not do

Compared with upstream Binaryen `version_129`, Starshine currently does **not** do these `gsi` behaviors here:

- using closed-world `typeGlobals`-style facts beyond exact/subtype-propagated local/param one-global origins and exact/subtype-propagated one-value or two-value singleton-group direct-candidate reads
- sibling `gsi-desc-cast` rewrites
- explicit refinalization machinery after type refinement beyond validation-preserving replacement typing
- atomic-get-specific teaching surfaces, because no local struct atomic-get opcode exists yet; a 2026-06-03 grep across `src/lib`, `src/wast`, and `src/validate` found ordinary struct gets and `RefGetDesc`, but no `StructGetAtomic` / `struct.atomic.get` surface
- unbounded large-module un-nesting; current un-nesting and `ref.get_desc` consumers are guarded to small modules

Those are real capability gaps, not just documentation wording differences.

## Biggest local-vs-upstream difference

The most important durable correction is:

- upstream Binaryen `gsi` is a layered open-world-plus-closed-world origin optimizer
- local Starshine `global-struct-inference` is currently an **open-world direct-global fold** plus a subtype-aware closed-world fact table and narrow exact/subtype-propagated local/param one-global plus exact and subtype-propagated one-value and two-value singleton-group rewrites

That narrower local strategy is still useful, and it is already green on the saved generated-artifact slot documented in `parity.md`.
But it should not be described as if it were the whole official Binaryen pass.

## Current local tests and what they prove

The focused tests in `src/passes/global_struct_inference_test.mbt` currently prove these local contracts:

- the pass folds immutable direct-global `struct.get*` in open world
- small-module non-constant un-nesting handles read-gated arithmetic, integer bitwise, integer shift/rotate, and unary numeric field operands, including direct-global and closed-world local/param packed signed/unsigned reads repaired after fresh-global splitting
- nullable direct-global reads preserve the null trap
- packed i8/i16 signed and unsigned direct reads are repaired
- default, descriptor, and default-descriptor constructors expose foldable fields
- mutable fields, mutable globals, and imported globals stay unchanged
- non-global reference producers stay unchanged even in closed world
- exact and subtype-propagated single-candidate param and body-local origins rewrite in closed world with null-trap preservation, while broad global declarations that would make the replacement invalid bail out
- exact and subtype-propagated one-value local/param reads fold in closed world, including equal literals, immutable `global.get`s, body locals, packed-field repair, child-only parent reads, and mixed parent/child candidate order
- exact and subtype-propagated two-value local/param reads synthesize typed `select(ref.eq(...))` in closed world when a singleton candidate group can distinguish the values
- open-world, more-than-two-value, two-equal-pair, non-materializable, poisoned child/exact type, mutable-field, mutable-global, and too-broad/`anyref` local-origin negatives stay unchanged

That is a good local floor.
It is much smaller than the official Binaryen `gsi.wast` proof surface, which is why the local parity page keeps the remaining unbounded un-nesting, atomic, descriptor-cast, and refinalization families explicit.

The 2026-06-03 O4z audit changed the local status by enabling the direct-global fast path in open world and adding packed/default/descriptor-constructor coverage. The follow-up GSI001-B, GSI001-C, GSI001-D, and GSI001-F slices added exact single-candidate local/param origin rewrites, exact and subtype-propagated one-value local/param folds, and exact and subtype-propagated two-value singleton-group local/param selects. GSI001-G/H added guarded un-nesting and `ref.get_desc`, GSI001-I added subtype-propagated origins, GSI001-J broadened the guarded un-nesting vocabulary to integer bitwise operands, and GSI001-K added integer shifts/rotates. The page remains anchored to the 2026-05-06 current-main bridge and raw Binaryen manifest for the upstream contract.

## Practical maintenance rule

Treat the current Starshine implementation as:

- a real in-tree module pass
- a deliberately narrow subset of upstream `gsi`
- a direct-global folder whose correctness depends on immutable trusted global initializers plus explicit null-trap preservation
- a conservative closed-world fact builder whose current rewrite consumers are limited to exact local/param one-global origins, exact/subtype-propagated one-value direct-candidate folds, and exact/subtype-propagated two-value singleton-group selects

Future work on this pass should answer one question explicitly:

- are we preserving the current local direct-global subset,
- or are we expanding toward full Binaryen origin reasoning?

For `global-struct-inference`, those are very different amounts of work.
