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

- **the pass is an open-world direct-global rewriting subset plus a narrow exact single-candidate closed-world local/param origin rewrite, not a full closed-world origin-analysis port**

`global_struct_inference_run_module_pass(...)` now scans immutable defined globals and rewrites direct `global.get` + `struct.get*` pairs even when `closed_world` is false. That matches Binaryen's direct immutable-global fast path. In closed-world mode it builds a `typeGlobals`-shaped fact table for safe candidate globals, poisoned allocation types, subtype poison propagation, and upward candidate propagation, then consumes only the exact-type single-candidate subset where no subtype-propagated candidate ambiguity exists.

## Current local code map

The easiest way to follow the in-tree implementation is this file map:

- `src/passes/global_struct_inference.mbt:2`
  - summary string used by the registry and preset docs
- `src/passes/global_struct_inference.mbt:20-339`
  - `GsiClosedWorldFacts`, allocation scanners, equality-comparable global declaration filter, subtype propagation helpers, exact direct single-candidate extraction, and `gsi_build_closed_world_facts(...)`
- `src/passes/global_struct_inference.mbt:340-571`
  - `gsi_candidate_field_values(...)` and `gsi_candidate_global_values(...)`: harvest immutable field payloads from trusted global initializers, with descriptor-constructor field operands read before the descriptor operand, and accept only top-level `struct.new`, `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc` globals
- `src/passes/global_struct_inference.mbt:626-784`
  - exact local/param origin helpers plus `gsi_folded_global_field_expr(...)`: map one trusted global plus one `struct.get*` into a replacement expression, including packed-field repair
- `src/passes/global_struct_inference.mbt:786-919`
  - `gsi_rewrite_instrs(...)`: recurse through bodies and rewrite immediate `global.get` + `struct.get*` instruction pairs plus closed-world exact single-candidate `local.get` + `struct.get*` pairs
- `src/passes/global_struct_inference.mbt:921-1017`
  - `gsi_instrs_may_rewrite(...)`: cheap pre-scan used to skip unchanged functions
- `src/passes/global_struct_inference.mbt:1020-1127`
  - `global_struct_inference_run_module_pass(...)`: builds closed-world exact single-candidate facts when requested, then runs the direct-global candidate table build, per-function rewrite loop, and final `with_code_sec(...)` replacement
- `src/passes/global_struct_inference_test.mbt:28-358`
  - focused positive/negative local coverage for the direct-global subset and exact single-candidate local/param origin subset
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

The local rewrite implementation still starts from the narrow direct-global table. In closed-world mode, the fact table records candidate global origins by struct type, poisoned allocation types, and subtype-propagated poison/candidate facts; a separate exact-direct single-candidate table consumes only slots where the propagated fact list still contains exactly that one direct candidate.

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

The closed-world fact table now reasons about direct top-level candidates, function-local allocation poisoning, nested-global allocation poisoning, mutable-global exclusion, too-broad/`anyref` global declaration exclusion, poisoned-child-to-parent propagation, and child-candidate-to-parent propagation. It now reasons about locals and params only as exact-type single-candidate rewrite origins. It still does **not** yet reason about:

- parent/supertype candidate sets as rewrite origins
- multi-candidate value grouping
- nested-global candidate propagation beyond top-level origin propagation

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

- only `i32.const` payloads are packed locally
- `gsi_pack_signed(...)`, `gsi_pack_unsigned(...)`, and `gsi_packed_expr(...)` rebuild the signed or unsigned packed read result

This is narrower than upstream Binaryen's `PossibleConstantValues` plus un-nesting path, but it is enough for the current direct-global subset.

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

`gsi_rewrite_instrs(...)` recursively descends into:

- `block`
- `loop`
- `if`
- `try_table`

but at each level it still rewrites only those immediate adjacent pairs.

So the pass can optimize through nested control bodies, but it does **not** optimize arbitrary operand producers. The exact local/param case emits a result-typed block that evaluates and drops the original local, using `ref.as_non_null` when needed, then yields the one safe global candidate. It will not rewrite cases where the reference comes from:

- a multi-candidate local/param type
- a poisoned type
- a parent-typed candidate set with propagated subtype candidates
- a `select`
- a more distant expression tree

That is the core reason the local implementation should be taught as a narrow direct-global folder, not as the full upstream origin-analysis pass.

## 4. Null-trap preservation is explicit in the emitted instruction stream

When the local pass folds a nullable global-backed read, it preserves the original null trap by emitting:

- the original `global.get`
- `ref.as_non_null` when the global reference type is nullable
- `drop`
- the folded replacement value

That is why the focused positive test checks for both:

- disappearance of `struct.get`
- continued presence of `global.get` and `drop`

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

- using closed-world `typeGlobals`-style facts beyond exact single-candidate local/param reads
- consuming subtype-propagated facts for supertype-origin rewrites
- one-vs-two-unique-value grouping and `select(ref.eq(...))` synthesis
- fresh-global un-nesting of non-constant operands
- `ref.get_desc` handling
- sibling `gsi-desc-cast` rewrites
- explicit refinalization machinery after type refinement
- atomic-get-specific teaching surfaces

Those are real capability gaps, not just documentation wording differences.

## Biggest local-vs-upstream difference

The most important durable correction is:

- upstream Binaryen `gsi` is a layered open-world-plus-closed-world origin optimizer
- local Starshine `global-struct-inference` is currently an **open-world direct-global fold** plus a subtype-aware closed-world fact table and narrow exact single-candidate local/param origin rewrite

That narrower local strategy is still useful, and it is already green on the saved generated-artifact slot documented in `parity.md`.
But it should not be described as if it were the whole official Binaryen pass.

## Current local tests and what they prove

The focused tests in `src/passes/global_struct_inference_test.mbt` currently prove these local contracts:

- the pass folds immutable direct-global `struct.get*` in open world
- nullable direct-global reads preserve the null trap
- packed i8/i16 signed and unsigned direct reads are repaired
- default, descriptor, and default-descriptor constructors expose foldable fields
- mutable fields, mutable globals, and imported globals stay unchanged
- non-global reference producers stay unchanged even in closed world

That is a good local floor.
It is much smaller than the official Binaryen `gsi.wast` proof surface, which is why the local parity page keeps the missing multi-candidate local/param, supertype, select, un-nesting, atomic, and descriptor families explicit.

The 2026-06-03 O4z audit changed the local status by enabling the direct-global fast path in open world and adding packed/default/descriptor-constructor coverage. The page remains anchored to the 2026-05-06 current-main bridge and raw Binaryen manifest for the upstream contract.

## Practical maintenance rule

Treat the current Starshine implementation as:

- a real in-tree module pass
- a deliberately narrow subset of upstream `gsi`
- a direct-global folder whose correctness depends on immutable trusted global initializers plus explicit null-trap preservation
- a conservative closed-world fact builder whose first rewrite consumer is limited to exact single-candidate local/param origins

Future work on this pass should answer one question explicitly:

- are we preserving the current local direct-global subset,
- or are we expanding toward full Binaryen origin reasoning?

For `global-struct-inference`, those are very different amounts of work.
