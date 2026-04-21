---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0175-2026-04-21-i64-to-i32-lowering-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/I64ToI32Lowering.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/abi/js.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/asmjs/shared-constants.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/iteration.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/memory-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# Flatness, helpers, and hard boundaries in `i64-to-i32-lowering`

## 1. Flatness is a real legality rule

This is the first thing a future port should remember.

The implementation begins each function with:

- `Flat::verifyFlatness(func)`

That means the pass is not written for arbitrary nested trees.
It expects a flattened form where complicated value-producing children have already been spilled into locals.

### Why that matters

The rest of the file depends on being able to:

- insert temp locals predictably
- attach hidden high-half temps to expression nodes
- rebuild blocks around already-simple children

So the right beginner summary is:

- `flatten` is not just a convenient neighbor
- it is part of the practical precondition story

## 2. The hidden high-half side channel is the core implementation trick

When the pass lowers an `i64`-typed value, it usually does **not** create a visible tuple-like node.
Instead it stores the matching high half in a temp-local map.

The important helpers are:

- `setOutParam(...)`
- `fetchOutParam(...)`
- `hasOutParam(...)`

That gives the pass a simple internal rule:

- visible AST result = low half
- hidden temp = high half

### Why this matters for ports

A naive port might try to:

- always replace one expression with a pair of explicit nodes, or
- thread synthetic structs/tuples through the tree

That is not what upstream `version_129` does.
The official pass instead uses a side channel keyed by expression identity.

## 3. Local splitting is positional, not symbolic-only

The pass does name the new high locals with `$hi`, but the more important rule is positional:

- `indexMap[oldIndex]` points to the low half
- the high half is always `mappedIndex + 1`

Many later rewrites depend on that exact arithmetic.
So a future implementation must preserve more than just naming.
It must preserve the stable adjacent-slot layout or consciously compensate everywhere.

## 4. The return path uses a global, not multivalue

This is the other big structural rule.

Binaryen lowers `i64` returns by:

- returning the low half as the visible `i32` function result
- storing the high half in `INT64_TO_32_HIGH_BITS`

That helper global is part of the ABI contract for this pass.
It is not optional sugar.

### Why beginners often miss this

The pass name sounds like a normal integer lowering pass.
But this one crosses function boundaries, so it needs a concrete result-carrier policy.
Binaryen `version_129` chooses:

- one synthetic mutable global for the high half of returned values

## 5. Some lowerings require wasm2js helper imports

### Reinterpret helpers

For reinterpret between `i64` and `f64`, the pass uses scratch-memory helpers declared in `abi/js.h`.

Visible consequences:

- the pass is not purely syntactic wasm-to-wasm rewriting
- the pass may ensure the module has a memory
- the pass may ensure wasm2js helper imports exist

### Atomic helpers

For some atomic families, the pass calls helpers like:

- `ATOMIC_RMW_I64`
- `GET_STASHED_BITS`
- `ATOMIC_WAIT_I32`

This is a major boundary.
For those shapes, Binaryen preserves semantics through helper calls rather than through plain split wasm instructions.

## 6. Single-evaluation guarantees matter all over the pass

The pass duplicates uses frequently:

- low and high loads
- low and high stores
- low and high selects
- call result handling
- pointer reuse

So it repeatedly introduces temp locals first.

The practical invariant is:

- if a child expression would otherwise be evaluated twice, upstream stores it once and reuses the temp

This is especially visible for:

- memory pointers
- `select` conditions
- returned low halves before storing the high half to the synthetic global

## 7. Important hard boundaries

These are not vague caveats.
They are explicit source-level facts.

## Imported i64 globals

Still fatal with:

- `TODO: imported i64 globals`

## `return_call` / `return_call_indirect` with i64 results

Still fatal with:

- `i64 to i32 lowering of return_call values not yet implemented`

## Atomic cmpxchg on i64

Still explicitly unsupported.

## Atomic loads/stores as direct split ops

Still asserted unsupported in the direct load/store lowering routines.
The pass instead handles only some atomic cases through helper calls.

## Several harder integer op families

These are expected to be gone already rather than lowered here:

- `mul`
- `div`
- `rem`
- rotates
- `popcnt`
- `ctz`

That means the pass has an important scheduler precondition beyond flatness:

- other transforms are expected to have removed or rewritten certain harder `i64` ops first

## 8. The unreachable fallback is narrow on purpose

`handleUnreachable(...)` is a repair helper, but it is intentionally limited.
The source comment says it is only valid for nodes whose children run unconditionally before the node.
It explicitly excludes `if`.

So the right lesson is:

- even the fallback logic is conservative and execution-order aware
- this pass does not use a broad “just blockify dead code” policy for every shape

## 9. What future Starshine work must preserve exactly

If Starshine ever ports this pass, the minimum faithful boundary set is:

1. require or synthesize a flat-input equivalent
2. keep the low-visible/high-hidden value model
3. keep adjacent low/high local slot layout or compensate everywhere
4. preserve the synthetic return-high global contract
5. preserve single-evaluation temp insertion
6. preserve helper-import lowering for scratch reinterpret and some atomic families
7. preserve explicit unsupported/bailout behavior for upstream-unsupported shapes
8. do not advertise it as a default optimize-path pass

## 10. Short warning for future readers

The easiest way to misread `i64-to-i32-lowering` is to think:

- “it just rewrites i64 ops into i32 ops”

The source says the real story is:

- flatness-sensitive
- ABI-sensitive
- helper-sensitive
- partially scheduler-dependent
- and only partly arithmetic
