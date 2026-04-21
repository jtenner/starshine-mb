---
kind: concept
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/ir/hot_lower_test.mbt
  - ../../../raw/research/0095-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-stack-underflow.md
  - ../../../raw/research/0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md
  - ../../../raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md
  - ../../../raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md
  - ../../../raw/research/0109-2026-04-18-generated-o4z-optimize-instructions-slot44-retired-by-replay-verification.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ./wat-shapes.md
---

# Current Starshine `optimize-instructions` strategy

This page is the local “what is actually implemented today?” companion to the upstream Binaryen strategy page.

## Short version

Current Starshine `src/passes/optimize_instructions.mbt` is **much narrower** than Binaryen `version_129` `OptimizeInstructions.cpp`.

The in-tree implementation is mostly a HOT-IR peephole and canonicalization pass focused on:

- exact integer constant folding
- `eqz` / compare-to-zero rewrites
- commutative operand canonicalization
- add/sub/mul/shift rewrites
- some nested boolean-`if` normalization
- a few artifact-driven control / branch cleanups

That is real work and is already useful, but it is not yet the same pass surface as upstream Binaryen.

## What Starshine already models reasonably well

By source inspection, the current implementation already covers several important upstream-adjacent themes.

## 1. Exact integer and compare peepholes

The local file has dedicated helpers for:

- exact constant folding of binary ops
- `eqz` folding
- compare-to-zero rewrites
- relational operand canonicalization
- relational-constant normalization

This is the part of the current implementation that most closely matches the popular mental model of the upstream pass.

## 2. Commutative canonicalization

The local file has explicit machinery for:

- putting constants on the preferred side
- ordering `local.get` operands
- sorting otherwise-commutative node kinds conservatively
- guarding reordering through use-def and loop-input checks

That matches the general *strategy* of upstream Binaryen:

- canonicalize first so later peepholes have fewer spellings to handle

## 3. Add / sub / mul / shift rewrites

The in-tree HOT pass includes helpers for:

- add/sub normalization
- multiply-by-power-of-two to shift rewrites
- shift normalization
- compare-to-zero reductions

So Starshine already covers a meaningful subset of the classic arithmetic rewrite surface.

## 4. Boolean and nested-`if` cleanup

The local file goes fairly deep on HOT-IR boolean / control patterns.

Examples include helpers to:

- optimize if conditions
- wrap boolean `if` values in `eqz`
- invert nested `if` conditions
- recursively negate nested boolean `if` conditions
- collapse duplicate then-branch `if`s
- collapse dead region suffixes after escaping control

This is an area where current Starshine is actually *more explicit* than the upstream `visitIf()` surface, because it encodes several artifact-driven structural safeguards directly in HOT IR.

## 5. Artifact-backed dead-suffix and branch cleanup guards

The current local pass includes logic for:

- preserving zero sentinels in dropped value carriers
- keeping fallback branches alive in mixed-label or nested-return shapes
- avoiding unsafe dead-suffix collapse in several carrier / label-sensitive cases

Those are not a direct copy of Binaryen `OptimizeInstructions.cpp`.

They are local HOT-IR and writeback survival work driven by the repo's artifact replay history.

That distinction matters.

Some of the current code is protecting:

- Starshine's HOT lowering and final writeback boundaries

more than it is proving:

- full upstream peephole parity.

## What upstream Binaryen does that Starshine still lacks

This is the bigger story.

## 1. No broad AST reference / GC optimization surface yet

The local file does not implement the upstream visitor families for things like:

- `ref.eq`
- `ref.cast`
- `ref.test`
- `ref.is_null`
- `ref.as_non_null` interaction cleanup
- `ref.get_desc`
- descriptor-aware casts
- exactness-aware cast tightening

So the upstream cast / trap-on-null / descriptor story is still largely missing locally.

## 2. No `call_ref` directization surface

The local HOT implementation does not currently model the upstream `visitCallRef(...)` story:

- `ref.func` target -> direct call
- `table.get` target -> `call_indirect`
- fallthrough-known direct target with operand-order-preserving locals
- select-of-known-direct-targets -> `if` over direct calls / return-calls

That is a large upstream feature gap.

## 3. No bulk-memory lowering surface

The local pass does not currently cover upstream families like:

- tiny constant-size `memory.copy` to load/store
- tiny `memory.fill` to store/store pair / SIMD store
- IIT/TNH zero-size drop cleanup for bulk memory

## 4. No GC constructor / field / atomics surface

The local pass does not yet model upstream visitors such as:

- `StructNew`
- `StructGet`
- `StructSet`
- `StructRMW`
- `StructCmpxchg`
- `ArrayNew`
- `ArrayNewFixed`
- `ArrayGet`
- `ArraySet`
- `ArrayLen`
- `ArrayCopy`
- `ArrayRMW`
- `ArrayCmpxchg`

So important upstream behaviors are still absent locally, including:

- `struct.new_default` / `array.new_default` style cleanup
- unshared GC memory-order relaxation
- unshared GC RMW / cmpxchg lowering

## 5. No tuple extraction parity surface

The local file does not model upstream `visitTupleExtract(...)`:

- `tuple.extract(tuple.make(...))` simplification with tee / drop reconstruction

## 6. No local pre-scan equivalent for sign-extension knowledge

Upstream Binaryen runs a whole-function `LocalScanner` to infer:

- `maxBits`
- `signExtBits`

Current Starshine has a lot of direct pattern matching and some local ordering logic, but it does not currently appear to have the same function-wide local pre-scan that powers many upstream bit-width and sign-extension decisions.

That means some upstream “small” rules are actually blocked on missing helper structure here.

## 7. No deferred `ReFinalize` / EH-pop-fixup equivalent in this pass

Upstream Binaryen explicitly depends on:

- deferred `ReFinalize`
- `EHUtils::handleBlockNestedPops(...)`

The current local HOT pass has its own HOT / lower / writeback validity story, but it is not the same helper contract.

A future parity port must preserve the fact that upstream rewrites are allowed to rely on those end-of-pass repairs.

## Important current divergence: constant `if` folding

One of the most useful durable differences between the local and upstream implementations is:

- current Starshine has an explicit `optimize_instructions_try_fold_constant_if_condition(...)`
- upstream Binaryen `version_129` `visitIf()` does **not** do generic constant-if folding here

That does **not** automatically make the local rule wrong.

But it does mean:

- the local pass is not a direct copy of the upstream phase boundary
- some currently-landed local behavior belongs more naturally to `precompute` in the Binaryen mental model

That is exactly the kind of drift future docs and parity planning should keep explicit.

## Important current divergence: artifact-driven dead-region cleanup

Several local helpers are clearly tailored to artifact-backed HOT / lowering issues rather than directly to upstream source structure.

Examples include:

- duplicate-then-branch collapse helpers
- dead region suffix collapse with sentinel preservation
- nested boolean-tree inversion / wrapping logic
- fallback-branch preservation around escaping ifs and carried labels

Those local rules may still be useful or necessary.

But they should be documented as:

- current Starshine HOT-IR and writeback strategy

not automatically as:

- direct evidence of how upstream Binaryen `OptimizeInstructions.cpp` is structured.

## Ordered-artifact blocker story: now retired, but still important context

The saved generated-artifact `-O4z` audit originally found two hard failure slots for `optimize-instructions`:

- slot `16`
- slot `44`

The durable repo-local conclusion from `0095`, `0100`, `0103`, `0104`, and `0109` is:

- both slots are now retired
- the fixes were not new upstream-shape peepholes in the pass
- they were HOT-lowering / writeback safety fixes around carried-result wrappers and parent-exit payload packing

In practical terms:

- the current artifact-facing correctness risk around this pass is lower than it was on 2026-04-18
- the remaining gap is breadth and honesty of upstream parity, not a still-open hard corruption witness

## What a future honest Starshine port must preserve

A future port does **not** need to copy the 5.8k-line Binaryen file literally.

But it does need to preserve these big truths:

## 1. The pass is broader than arithmetic

Future work must treat the upstream surface as including:

- control / ternary forms
- memory and bulk memory
- `call_ref`
- GC casts and null-trap simplification
- GC field/array and unshared atomics forms
- tuple extraction

## 2. Canonicalization is part of the algorithm

The local pass already understands this in some areas.

That should remain a design principle.

## 3. Helper substrate matters

Several upstream families depend on utilities that do not yet seem to exist locally in equivalent form, including:

- whole-function bit/sign-ext local summaries
- refined fallthrough tracking for refs
- cast-check result classification
- child localization helpers for effect-preserving rewrites
- post-pass type and EH repair helpers

## 4. Phase boundaries should stay honest

If Starshine keeps constant-if folding or artifact-specific dead-suffix cleanup in `optimize-instructions`, that may still be the right local engineering choice.

But the wiki should keep saying clearly when such work is:

- an upstream parity match

versus

- a current local HOT-IR survival strategy.

## Suggested near-term documentation / implementation reading order

If someone wants to expand the local implementation honestly, the most useful order is probably:

1. keep the current HOT integer / boolean core stable
2. study the upstream helper dependencies
3. add cast / trap-on-null helper infrastructure
4. add `call_ref` support
5. add memory / bulk-memory tiny-shape rewrites
6. add GC constructor / field / atomic families
7. only then worry about finer-grained parity on the more obscure arithmetic tail rules

That order follows the biggest present structural gaps, not the biggest individual peephole counts.

## Bottom line

Current Starshine `optimize-instructions` is already a meaningful implemented pass.

But compared to Binaryen `version_129`, it is still mostly:

- integer / boolean / HOT-control canonicalization
- plus artifact-driven writeback-safety cleanup

The largest missing upstream surfaces are:

- GC casts and null-trap logic
- `call_ref`
- memory and bulk memory
- GC field/array / unshared atomics
- tuple extraction
- the helper substrate that makes those rewrites safe

That is the honest gap a future parity plan must preserve.
