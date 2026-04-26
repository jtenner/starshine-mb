---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md
  - ../../../raw/research/0379-2026-04-26-alignment-lowering-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md
  - ../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AlignmentLowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/AlignmentLowering.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen strategy for `alignment-lowering`

## What the pass really is

Upstream Binaryen publishes this pass as `alignment-lowering`.
The public registration description is: lower unaligned loads and stores to smaller aligned ones.

That description is accurate, but still slightly too vague for teaching.
On 2026-04-23 the reviewed official Binaryen `version_129` release page showed publish date **2026-04-01**. A focused 2026-04-26 current-main / port-readiness recheck is captured in [`../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md); it found no teaching-relevant drift from the source-backed contract described here.

The reviewed implementation is a **small local AST legalization pass** that:

- visits only ordinary `Load` and `Store` nodes
- ignores already-natural alignment
- rewrites weaker-than-natural scalar accesses into smaller aligned scalar accesses
- preserves evaluation order with fresh locals
- reconstructs or splits the original scalar value using integer bit operations and reinterprets

So the best mental model is:

- **misaligned scalar access legalization by chunking**
- not generic memory optimization

## Scheduler placement

`src/passes/pass.cpp` registers `alignment-lowering` as a normal public pass.

The local repo makes two scheduler facts explicit:

- it remains boundary-only in `src/passes/optimize.mbt`
- it is absent from `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`

So the scheduler truth is:

- real public pass: yes
- default no-DWARF `-O` / `-Os` pass: no
- current local active optimizer pass: no
- good tracker-expansion dossier target: yes

## Implementation shape

The reviewed upstream implementation is unusually compact.
Nearly everything important lives in `src/passes/AlignmentLowering.cpp`.

The pass class is:

- `AlignmentLowering : WalkerPass<PostWalker<AlignmentLowering>>`

Important consequences:

- it is a normal Binaryen AST walker
- it works post-order
- it does not advertise function-parallel behavior in the reviewed source
- it does not rely on liveness, dominance, CFG, branch, call-graph, or alias analyses

This makes the pass a good beginner contrast with larger Binaryen passes:

- safety here comes from exact local rewrite construction
- not from a broad proof engine

## Core implementation phases

## Phase 1: quickly reject natural-alignment cases

The helpers and visitors all treat these as immediate no-ops:

- `align == 0`
- `align == bytes`

The reviewed code comments treat all later code as assuming the remaining operation is genuinely unaligned.

So the first invariant is simple:

- if the access is already naturally aligned, leave it untouched

## Phase 2: normalize the core problem around i32 helpers

The pass's main engineering choice is to centralize chunking around 32-bit integer logic.

### Load side

- `i32` narrow/full-width cases are handled directly in `lowerLoadI32`
- `f32` becomes `i32` plus `reinterpret`
- narrow `i64` loads lower through `i32` and then extend
- full 64-bit `i64` / `f64` loads are assembled from two 32-bit halves

### Store side

- `i32` narrow/full-width cases are handled directly in `lowerStoreI32`
- `f32` becomes `i32.reinterpret_f32` then uses the same path
- narrow `i64` stores wrap to `i32`
- full 64-bit `i64` / `f64` stores split into low/high 32-bit halves

That is the real implementation structure.
A future port should not start with separate bespoke algorithms for every scalar type.

## Phase 3: preserve single evaluation with fresh locals

This is the most important correctness step in the whole pass.

### Loads

The pass spills the pointer into a fresh local before issuing multiple smaller loads.

### Stores

The pass spills:

- the pointer
- and the stored value

before issuing multiple smaller stores.

Why this matters:

- a pointer expression may have effects
- a value expression may have effects
- re-running either child would change semantics

So the contract is not just “emit smaller aligned accesses.”
It is:

- **emit smaller aligned accesses after first preserving single child evaluation**

## Phase 4: lower 16-bit and 32-bit loads

## 16-bit load into `i32`

For `bytes == 2`, the pass emits two byte loads:

- low byte at `offset`
- high byte at `offset + 1`

It then combines them with:

- one shift by `8`
- one `or`

If the original load was signed, it restores signed meaning with `Bits::makeSignExt(..., 2, ...)`.

## 32-bit load into `i32`

For `bytes == 4`, the rewrite depends on the weaker alignment.

### `align == 1`

Emit four `load8_u`s combined by shifts `8`, `16`, `24` and nested `or`s.

### `align == 2`

Emit two `load16_u`s, with the high half shifted by `16`.

That gives two important beginner lessons:

- the pass uses the strongest aligned chunk size still legal under the given alignment
- it does not always split all the way to bytes

## Phase 5: lower 16-bit and 32-bit stores

## 16-bit store from `i32`

Emit two `store8`s:

- low byte: original value
- high byte: `value >> 8`

## 32-bit store from `i32`

### `align == 1`

Emit four `store8`s using right shifts `8`, `16`, and `24`.

### `align == 2`

Emit two `store16`s, with the second storing `value >> 16`.

Again the pass uses the largest chunk size allowed by the weaker alignment.

## Phase 6: handle floats through integer bit reinterpretation

The float paths are narrow but easy to forget.

### `f32`

- loads: set the load type to `i32`, lower via `lowerLoadI32`, then wrap in `f32.reinterpret_i32`
- stores: reinterpret the value with `i32.reinterpret_f32`, then lower as an `i32` store

### `f64`

- loads: assemble an `i64`, then wrap in `f64.reinterpret_i64`
- stores: reinterpret the input as `i64`, then split/store its halves

The pass is therefore bit-preserving, not numerically transforming.

## Phase 7: handle 64-bit values as two 32-bit halves

For full-width `i64` and `f64`, Binaryen does not build eight one-byte operations directly.
Instead it lowers through two 32-bit pieces.

### Load path

- save pointer once
- lower low 32 bits from `offset`
- lower high 32 bits from `offset + 4`
- extend both to `i64`
- shift the high half left by `32`
- `or` the halves together

### Store path

- save pointer once
- save 64-bit value once
- extract low half with `wrap_i64`
- extract high half with `shr_u 32` then `wrap_i64`
- lower each half through `lowerStoreI32`

The reviewed source contains a useful subtlety here:

- after adding `4` to the offset, the same weak alignment remains valid
- because the pass only expects weak alignments `1`, `2`, or `4` for these split cases

## Phase 8: preserve operand semantics for unreachable nodes

This is one of the most easy-to-miss parts.

### Unreachable load

If the load's type is already `unreachable`, Binaryen replaces the whole node with the pointer expression.

Meaning:

- remove the memory operation itself
- keep the pointer child in place as the semantic carrier

### Unreachable store

If the store's type is `unreachable`, Binaryen replaces it with a block dropping:

- the pointer
- the value

Meaning:

- remove the memory operation itself
- still preserve operand evaluation in a none-typed wrapper

A future port that simply deletes these nodes would silently diverge.

## Exact rewrite scope

## Positive families

Reviewed source positively rewrites only:

- scalar `Load`
- scalar `Store`

And within those, only when alignment is weaker than natural alignment.

## Negative families

Reviewed source does not handle:

- atomics
- SIMD memory ops or lane ops
- bulk-memory instructions
- table instructions
- GC instructions
- address arithmetic outside the current load/store subtree

This is not speculation.
It follows directly from the file's visitor surface.

## Bailout / unreachable families

The pass leaves alone:

- natural-alignment cases
- effectively 1-byte cases where the requested alignment is already enough

The helper code treats as impossible/internal-error:

- unsupported access widths in the specialized i32 helper logic
- unsupported non-natural weak alignments for those helpers

## Helper dependencies

## `Builder`

Used heavily for all new AST construction:

- locals
- loads/stores
- shifts and ors
- wraps and extends
- reinterpret nodes
- blocks and sequences

## `Bits::makeSignExt`

This is the exact helper restoring signed 16-bit meaning after byte-based lowering.
That makes it part of the true contract, not just implementation detail.

## memory `addressType`

The pass queries the memory's `addressType` when creating pointer temporaries.

Inference from source:

- pointer temps should naturally track memory32 vs memory64 width

I am labeling that explicitly as an inference because the reviewed lit file did not give a dedicated memory64 proof section.

## No heavy post-repair machinery

The reviewed implementation does not invoke special refinalization or structural-fixup helpers.
That fits the pass's narrow scope:

- it preserves scalar result types directly
- and only introduces small local/block wrappers

## Current-main drift check

I compared:

- `version_129` `src/passes/AlignmentLowering.cpp`
- current upstream `main` `src/passes/AlignmentLowering.cpp`

The files are identical in the review run for this dossier.

That does not prove the entire surrounding test surface is frozen, but it does mean the reviewed implementation summary still matches current upstream on the implementation file itself.

## Pass interactions

This pass has fewer neighboring interactions than most optimization passes.
The important ones are mostly conceptual:

- later cleanup passes may simplify the extra locals or shift/or trees it introduces
- but `alignment-lowering` itself does not depend on those later passes to be semantically correct
- the opposite-direction helper pass `dealign` exists nearby in the public pass list, which helps explain that `alignment-lowering` is about legality and representation, not generic optimization

## What a future Starshine port must preserve

A faithful port should preserve all of these source-backed properties:

- narrow scope: ordinary scalar loads/stores only unless explicitly extended
- natural-alignment no-op behavior
- pointer/value single-evaluation via fresh temporaries
- exact signed-load repair behavior
- exact float reinterpret staging
- exact 64-bit split/rebuild strategy through 32-bit halves
- unreachable-load and unreachable-store operand-preservation rules
- address-type-aware pointer locals

## Easy-to-miss teaching summary

If someone remembers only one sentence, it should be this:

> Binaryen `alignment-lowering` is a small local scalar-access legalization pass whose real correctness hinges on chunk selection and single-evaluation preservation, not on fancy global analysis.

## Sources

- [`../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-alignment-lowering-current-main-port-readiness.md)
- [`../../../raw/research/0379-2026-04-26-alignment-lowering-port-readiness.md`](../../../raw/research/0379-2026-04-26-alignment-lowering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md`](../../../raw/binaryen/2026-04-23-alignment-lowering-primary-sources.md)
- [`../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md`](../../../raw/research/0171-2026-04-21-alignment-lowering-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AlignmentLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AlignmentLowering.cpp>
