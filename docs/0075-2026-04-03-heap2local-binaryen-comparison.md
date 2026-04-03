# Heap2Local Binaryen Comparison

## Scope

- Record how `Heap2Local` works in `wasm-opt version 125`.
- Separate Binaryen's transformed shapes from its explicit bailout shapes.
- Turn that matrix into a primary red-phase test target for Starshine's `heap2local` worktree.

## Oracle

- Source: `version_125/src/passes/Heap2Local.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_125/src/passes/Heap2Local.cpp>
- Lit coverage: `version_125/test/lit/passes/heap2local.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_125/test/lit/passes/heap2local.wast>

## Candidate Filter

- Binaryen considers `StructNew` allocations, including default and descriptor-bearing variants, so long as the allocation is not already `unreachable`.
- Binaryen also considers `ArrayNew` and `ArrayNewFixed`, but only when the size is constant and `< 20`.
- The allocation payload must be representable in locals.
  - Structs require every field type to satisfy `TypeUpdating::canHandleAsLocal(...)`.
  - Arrays require the element type to satisfy the same localability check.

## Escape And Exclusivity Model

- Binaryen proves two things before rewriting:
  1. the allocation does not escape the current function
  2. every reachable use is exclusive to that allocation
- Escape analysis follows flows through parents, branches, and locals.
- Parent-child interactions are partitioned into:
  - `Escapes`
  - `FullyConsumes`
  - `Flows`
  - `Mixes`
  - `None`
- Important consequences from the source:
  - no parent means escape to the caller
  - `local.get` and `local.set` themselves do not escape
  - `drop`, `struct.get*`, `ref.is_null`, `ref.eq`, `ref.test`, and `ref.get_desc` fully consume the allocation safely
  - `ref.as_non_null` is a safe flow-through
  - `block` and `loop` can safely flow the allocation onward
  - `if` is not treated as a simple flow carrier and therefore becomes a mixing barrier
  - constant-index `array.get` and `array.set` are analyzable
  - nonconstant array indexes are immediate bailouts
- Exclusivity is checked with `LazyLocalGraph`.
  - every `local.get` influenced by one of the allocation's writer sets must read only from that writer set family
  - param/local mixed provenance like `to-param-loop` is therefore rejected

## Struct Shapes Binaryen Transforms

- Direct exclusive struct locals:
  - `local.set` from `struct.new`
  - `local.set` from `struct.new_default`
  - `local.tee` feeding direct later users
- Packed field traffic:
  - `struct.get_s`
  - `struct.get_u`
- Direct field mutation and readback:
  - `struct.set`
- Local copy chains that stay exclusive:
  - copy to another local
  - one-armed conditional copies
  - multiple non-overlapping owner locals
- Flow-through control shapes:
  - block result flow
  - loop result flow
  - branch-to-block flow when the branch is the only sent value and the block has no fallthrough value
- Ref operations on the optimized allocation:
  - `ref.as_non_null` is removed
  - `ref.eq` folds to `0` or `1`
  - `ref.is_null` folds to `0`
  - `ref.test` folds to `0` or `1`
  - `ref.cast` either disappears or becomes `unreachable`
- Descriptor-bearing struct shapes:
  - `struct.new_desc`
  - `struct.new_default_desc`
  - `ref.get_desc`
  - descriptor-sensitive `ref.cast_desc_eq*`
- Validation-preserving fixups:
  - Binaryen replaces now-dead `local.get`s of removed non-nullable locals with `ref.null`
  - flowing reference types may be widened to nullable
  - the pass may refinalize after cast and type-flow rewrites
- EH fixups:
  - after any successful rewrite in a function containing `pop`, Binaryen runs `handleBlockNestedPops`

## Struct Shapes Binaryen Leaves Unchanged

- Any escape to calls, returns, or function results
- Any non-exclusive local provenance
  - `select` between allocations
  - a local that can also hold another ref value
  - loop-carried param/local mixed ownership
- Unsupported control/value mixing
  - `if`-mediated value mixing
  - branch targets with other outgoing values
- Unreachable allocations that DCE should already erase

## Array Shapes Binaryen Transforms

- `array.new_default` with constant size `< 20`
- `array.new` with constant size `< 20`
- `array.new_fixed`
- Constant-index `array.get`
- Constant-index `array.set`
- Packed array element traffic
  - `array.get_s`
  - `array.get_u`
- Array `ref.test`
- Array `ref.cast`
  - success keeps the refined flow
  - failure becomes `unreachable`
- Implementation detail:
  - Binaryen first lowers eligible arrays to synthetic structs, then runs the same struct-to-locals rewrite

## Array Shapes Binaryen Leaves Unchanged

- Nonconstant array size
- Constant size `>= 20`
- Nonconstant `array.get` index
- Nonconstant `array.set` index
- Array casts that still let the array escape
  - returning the cast result as `(ref array)`
- Atomic array accesses
  - explicitly TODO in Binaryen's source

## Pipeline And Iteration Limits

- Binaryen runs arrays first, then structs.
- The pass is intentionally single-iteration per invocation.
- Nested or newly exposed allocations depend on later cleanup such as `vacuum` before another `heap2local` run can do more work.

## Primary Red-Phase Suite

The primary suite for this worktree should lock these Binaryen-aligned expectations:

- Transform shapes to encode now:
  - direct exclusive struct baseline
  - local-copy struct ownership
  - tee flow
  - block value flow
  - `ref.as_non_null`
  - `ref.eq`
  - successful `ref.cast`
  - descriptor-bearing `struct.new_default_desc` plus `ref.get_desc`
  - `array.new_default`
  - `array.new`
  - `array.new_fixed`
  - array `ref.test`
- Bailout shapes to encode now:
  - escape via call
  - non-exclusive local merge
  - nonconstant array size
  - loop param/local mixed provenance
- Binaryen-documented shapes to keep in the research doc but leave out of the first Starshine suite:
  - shared-struct atomic get/set
  - `struct.rmw` / `struct.cmpxchg`
  - array atomic access TODOs
  - `pop` fixup coverage
  - descriptor-sensitive `ref.cast_desc_eq*`

## Starshine Gap Summary

- The current Starshine slice only handles:
  - one writer local
  - `struct.new` and `struct.new_default`
  - later direct `struct.get*` and `struct.set` users on the same type
- The current slice does not yet cover:
  - ownership flowing through locals, blocks, loops, or tees
  - direct allocation users without an owner local
  - ref operation folding
  - descriptor-bearing structs
  - array-to-struct lowering
  - Binaryen's non-nullable local and refinalization fixups

## Validation Plan

- Keep the primary suite in `src/passes` as a red contract against Binaryen behavior.
- Use `moon test src/passes` to confirm the suite is red for the intended missing surface.
- As implementation lands, move each case from red to green without weakening the bailout assertions.
