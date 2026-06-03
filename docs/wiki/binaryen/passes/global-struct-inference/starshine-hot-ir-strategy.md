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

- **the pass is an open-world direct-global subset, not a full closed-world origin-analysis port**

`global_struct_inference_run_module_pass(...)` now scans immutable defined globals and rewrites direct `global.get` + `struct.get*` pairs even when `closed_world` is false. That matches Binaryen's direct immutable-global fast path while leaving the broader `typeGlobals` analysis unimplemented.

## Current local code map

The easiest way to follow the in-tree implementation is this file map:

- `src/passes/global_struct_inference.mbt:2`
  - summary string used by the registry and preset docs
- `src/passes/global_struct_inference.mbt:110`
  - `gsi_candidate_field_values(...)`: harvest immutable field payloads from trusted `struct.new*` global initializers, with descriptor-constructor field operands read before the descriptor operand
- `src/passes/global_struct_inference.mbt:152`
  - `gsi_candidate_global_values(...)`: accept only top-level `struct.new`, `struct.new_default`, `struct.new_desc`, and `struct.new_default_desc` globals
- `src/passes/global_struct_inference.mbt:250`
  - `gsi_folded_global_field_expr(...)`: map one trusted global plus one `struct.get*` into a replacement expression, including packed-field repair
- `src/passes/global_struct_inference.mbt:310`
  - `gsi_rewrite_instrs(...)`: recurse through bodies and rewrite only immediate `global.get` + `struct.get*` instruction pairs
- `src/passes/global_struct_inference.mbt:419`
  - `gsi_instrs_may_rewrite(...)`: cheap pre-scan used to skip unchanged functions
- `src/passes/global_struct_inference.mbt:497`
  - `global_struct_inference_run_module_pass(...)`: direct-global candidate table build, per-function rewrite loop, and final `with_code_sec(...)` replacement; `closed_world` is currently accepted but ignored by this direct subset
- `src/passes/global_struct_inference_test.mbt:28-242`
  - focused positive/negative local coverage for the direct-global subset
- `src/passes/pass_manager.mbt:12308-12309`
  - active module-pass dispatch site
- `src/passes/optimize.mbt:279-280`
  - pass registry entry and summary wiring
- `src/passes/optimize.mbt:310`
  - `optimize` preset cluster placement after `global-refining`
- `src/passes/optimize.mbt:326`
  - `shrink` preset cluster placement after `global-refining`

## How the local pass works today

## 1. Candidate discovery is global-initializer-only

The local implementation does **not** build Binaryen's broader `typeGlobals` map.
Instead it scans defined globals and records candidate field values only when all of these are true:

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

It does **not** reason about:

- locals
- params
- parent-typed candidate sets
- function-local allocation poisoning
- nested-global candidate propagation

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

The local rewrite engine looks only for one direct pattern:

```wat
(global.get $g)
(struct.get* ...)
```

`gsi_rewrite_instrs(...)` recursively descends into:

- `block`
- `loop`
- `if`
- `try_table`

but at each level it still rewrites only the immediate adjacent pair above.

So the pass can optimize through nested control bodies, but it does **not** optimize arbitrary operand producers.
It will not rewrite cases where the reference comes from:

- a local
- a parameter
- a `select`
- a parent-typed candidate set
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

- closed-world `typeGlobals` analysis over heap types
- subtype poisoning and upward candidate propagation
- local/param-origin rewrites
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
- local Starshine `global-struct-inference` is currently an **open-world direct-global fold** plus tests for packed/default/descriptor constructor surfaces

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
It is much smaller than the official Binaryen `gsi.wast` proof surface, which is why the local parity page keeps the missing select/subtype/un-nesting/atomic/descriptor families explicit.

The 2026-06-03 O4z audit changed the local status by enabling the direct-global fast path in open world and adding packed/default/descriptor-constructor coverage. The page remains anchored to the 2026-05-06 current-main bridge and raw Binaryen manifest for the upstream contract.

## Practical maintenance rule

Treat the current Starshine implementation as:

- a real in-tree module pass
- a deliberately narrow subset of upstream `gsi`
- a direct-global folder whose correctness depends on immutable trusted global initializers plus explicit null-trap preservation

Future work on this pass should answer one question explicitly:

- are we preserving the current local direct-global subset,
- or are we expanding toward full Binaryen origin reasoning?

For `global-struct-inference`, those are very different amounts of work.
