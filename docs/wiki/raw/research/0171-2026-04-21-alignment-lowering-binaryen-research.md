# Binaryen `alignment-lowering` research

Date: 2026-04-21
Author: OpenAI Codex
Status: source-backed tracker expansion

## Scope

This note widens the Binaryen pass wiki campaign beyond the now-closed no-DWARF / saved-`-O4z` queue and the first upstream-only expansion wave.

Chosen pass: `alignment-lowering`

Why this pass is eligible:

- it is still named in the local boundary-only registry in `src/passes/optimize.mbt`
- it is also listed in the older registry map doc `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- it does **not** yet have a dedicated living pass folder in `docs/wiki/binaryen/passes/`
- Binaryen `version_129` has a real public pass registration, implementation file, and dedicated lit test
- the pass is shape-driven and easy to misunderstand from the name alone

`agent-todo.md` currently has **no dedicated `alignment-lowering` slice**.

## Source inventory reviewed

### Local repo sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

### Official Binaryen sources

- `version_129` `src/passes/pass.cpp`
- `version_129` `src/passes/AlignmentLowering.cpp`
- `version_129` `src/pass.h`
- `version_129` `src/ir/bits.h`
- `version_129` `test/lit/passes/alignment-lowering.wast`
- `version_129` `src/passes/passes.h`

### Freshness check

I also compared upstream `version_129` and current `main` for `src/passes/AlignmentLowering.cpp`.
They are **identical** today.
That means this dossier's implementation summary is not just historical to `version_129`; it also matches current upstream on the reviewed file.

## What the pass sounds like versus what it actually does

The name can mislead beginners.
It does **not** mean:

- generic memory optimization
- changing how the program computes addresses
- deleting alignment annotations for size or speed reasons
- lowering every memory-related instruction family

What it really means in reviewed Binaryen is much narrower:

- find unaligned ordinary `load` and `store` nodes
- keep already-aligned nodes unchanged
- replace the unaligned ones with a small block of smaller aligned accesses
- reconstruct or split the scalar value using shifts, ors, wraps, extends, and reinterpret casts

So the best beginner summary is:

> `alignment-lowering` is a scalar misalignment legalization pass for ordinary loads and stores.

## Scheduler and registry facts

From `src/passes/pass.cpp`:

- public upstream pass name: `alignment-lowering`
- public description: "lower unaligned loads and stores to smaller aligned ones"

From the local repo:

- current Starshine registry category: `boundary-only`
- it is not part of the current canonical no-DWARF default optimize path page
- it is not in the saved generated-artifact `-O4z` missing-pass queue either

So this is an explicit tracker expansion target, not a remaining top-priority parity-slot pass.

## Implementation structure

The entire reviewed upstream implementation lives in one small file: `src/passes/AlignmentLowering.cpp`.

The pass class is:

- `AlignmentLowering : WalkerPass<PostWalker<AlignmentLowering>>`

Important consequences:

- it is an AST walker, not a CFG/dataflow pass
- it is post-order, so children are visited before their parent node is rewritten
- it does **not** override `isFunctionParallel()`, so on reviewed sources it remains the default non-function-parallel walker pass
- it does **not** depend on heavyweight analyses like liveness, dominance, effects, or call-graph reasoning

The implementation has only four real moving parts:

1. `lowerLoadI32(Load* curr)`
2. `lowerStoreI32(Store* curr)`
3. `visitLoad(Load* curr)`
4. `visitStore(Store* curr)`

That small surface is part of the real contract: this is not a sprawling whole-module optimizer.

## Core algorithmic phases

## Phase 1: ignore naturally aligned operations

Both `lowerLoadI32` and `lowerStoreI32`, and the outer visitors too, immediately leave nodes alone when:

- `align == 0`, or
- `align == bytes`

That means Binaryen treats these as already acceptable / naturally aligned forms.

Practical beginner translation:

- if the IR does not promise a weaker alignment than the access width, this pass does nothing
- the pass only fires when the operation is explicitly less aligned than its byte width

## Phase 2: canonicalize the hard problem to i32 chunks

The reviewed implementation reduces most work to `i32` chunk logic.

For loads:

- 16-bit and 32-bit integer loads are handled directly in `lowerLoadI32`
- `f32` first becomes `i32`, then gets `reinterpret`
- narrow `i64` integer loads first lower to `i32`, then sign- or zero-extend
- full 64-bit `i64` and `f64` loads are rebuilt from two 32-bit halves

For stores:

- 16-bit and 32-bit integer stores are handled directly in `lowerStoreI32`
- `f32` is reinterpreted to `i32`, then stored through the same path
- narrow `i64` stores wrap to `i32`, then reuse the i32 path
- full 64-bit `i64` and `f64` stores split into low and high 32-bit pieces

This is the first big teaching point:

- Binaryen does **not** invent a different algorithm for each scalar type
- it normalizes most cases to integer chunk rebuild/split logic

## Phase 3: preserve evaluation order with fresh locals

The pass uses `Builder::addVar(getFunction(), ...)` to create fresh locals for:

- the pointer
- and, for stores, the stored value too

That preserves single evaluation of subexpressions.

Why this matters:

- an address expression may have effects or be expensive
- a stored value may have effects or be expensive
- splitting a store into multiple smaller stores would be wrong if the pass re-evaluated the original children each time

So Binaryen first saves the original children in locals, then emits the chunked loads/stores from those locals.

This is one of the most important future-port invariants.

## Phase 4: rebuild small loads from aligned pieces

### 16-bit into i32

An unaligned 2-byte integer load becomes:

- load byte 0 as `load8_u`
- load byte 1 as `load8_u`
- shift the second byte left by 8
- `or` them together
- if the original load was signed, apply `Bits::makeSignExt(..., 2, ...)`

### 32-bit into i32

If `bytes == 4`:

- `align == 1` becomes four `load8_u` pieces combined with shifts by `8`, `16`, and `24`
- `align == 2` becomes two `load16_u` pieces with the second shifted by `16`

Any other partial alignment is unreachable in the reviewed source.

## Phase 5: split small stores into aligned pieces

### 16-bit from i32

An unaligned 2-byte store becomes two `store8`s:

- the low byte stores the original value
- the high byte stores `value >> 8`

### 32-bit from i32

If `bytes == 4`:

- `align == 1` becomes four `store8`s using right shifts `8`, `16`, `24`
- `align == 2` becomes two `store16`s with the second storing `value >> 16`

Again, other partial alignments are unreachable in the reviewed source.

## Phase 6: handle 64-bit scalar values as two 32-bit halves

For full-width `i64` / `f64` loads:

- save the pointer once
- lower the low 32-bit half at `offset`
- lower the high 32-bit half at `offset + 4`
- extend both to `i64`
- shift the high half left by `32`
- `or` them together
- reinterpret to `f64` when needed

For full-width `i64` / `f64` stores:

- save pointer once
- save 64-bit value once
- extract low 32 bits with `wrap_i64`
- extract high 32 bits with `shr_u 32` then `wrap_i64`
- lower each 32-bit store via `lowerStoreI32`
- use `offset` and `offset + 4`

A subtle but important comment in the upstream file explains why the second half keeps the same alignment as the first half:

- these are already unaligned loads/stores
- reviewed code only expects alignments `1`, `2`, or `4`
- adding `4` preserves those alignments

## Phase 7: special-case unreachable nodes

The visitors handle unreachable loads and stores explicitly.

For loads:

- if the load node type is `unreachable`, Binaryen replaces the entire load with its pointer expression

For stores:

- if the store node type is `unreachable`, Binaryen replaces it with a block dropping both pointer and value

This is easy to miss, but it is a real contract:

- the pass still removes the misaligned memory operation itself
- while preserving evaluation of the original operands in a type-correct way

## Exact rewrite surface

## Positive shapes

The reviewed implementation directly rewrites only these node families:

- ordinary `Load`
- ordinary `Store`

Within those nodes, the positive scalar families are:

- `i32.load16_{u,s}` with weak alignment
- `i32.load` with `align=1` or `align=2`
- `i32.store16` with weak alignment
- `i32.store` with `align=1` or `align=2`
- `i64.load`, `i64.load16_{u,s}`, `i64.load32_{u,s}` with weak alignment
- `i64.store`, narrow `i64.store16`, `i64.store32` with weak alignment
- `f32.load` / `f32.store` with weak alignment
- `f64.load` / `f64.store` with weak alignment

## Negative shapes

The reviewed pass does **not** visit or rewrite:

- atomics
- SIMD loads/stores and lane ops
- `memory.copy`, `memory.fill`, `memory.init`
- table or GC instructions
- address arithmetic outside the rewritten load/store subtree
- control flow except the small wrapper blocks/sequences it introduces

This negative scope is source-backed: the file only implements `visitLoad` and `visitStore`.

## Bailout shapes

The reviewed pass deliberately leaves nodes alone when:

- alignment is already natural (`align == 0` or `align == bytes`)
- the access width is already 1 byte
- the node is outside `Load` / `Store`

And it treats as internal-invalid / unreachable:

- unsupported byte widths in the helper routines
- unsupported partial alignments for the reviewed scalar chunk logic

## Important helper dependencies

This pass is small, but a future port still must preserve several helper contracts.

### `Builder`

Used to create:

- fresh locals
- new loads/stores
- shift/or trees
- blocks and sequences
- wraps, extends, and reinterpret nodes

### `Bits::makeSignExt`

Used for signed 16-bit lowered loads.
This is how the pass restores the original signed interpretation after rebuilding the bits through unsigned byte loads.

### memory `addressType`

The pass queries `getModule()->getMemory(curr->memory)->addressType` when creating temporary pointer locals.

This strongly suggests memory-width awareness:

- on memory32 memories, the temp pointer local is `i32`
- on memory64 memories, the temp pointer local is `i64`

This is an inference from the reviewed code shape, not from a dedicated memory64 test in the reviewed lit file.

### `pass.h` walker machinery

Because the pass is just a `WalkerPass<PostWalker<...>>`, it gets AST walking and replacement behavior from the standard pass framework.
No extra pass-local fixed point or repair framework is present here.

## What is easy to misunderstand

## Misunderstanding 1: “It optimizes alignment”

Not really.
It legalizes weaker-than-natural ordinary scalar accesses by replacing them with smaller naturally aligned accesses.
That can easily make the code larger.

## Misunderstanding 2: “It handles all memory instructions”

No.
Reviewed source handles only `Load` and `Store`.
If a future Starshine port silently widens this to atomics, SIMD, or bulk-memory instructions, it would no longer match the reviewed Binaryen contract.

## Misunderstanding 3: “It can duplicate pointer/value expressions safely”

No.
The pass is careful to spill pointer and store-value expressions to fresh locals before splitting work.
That preserves single evaluation.

## Misunderstanding 4: “Unreachable loads/stores can just be deleted”

Not quite.
Binaryen preserves operand evaluation structure:

- unreachable load -> pointer expression
- unreachable store -> block dropping pointer and value

## Misunderstanding 5: “It needs complicated dataflow analyses”

No.
This pass is almost entirely local AST surgery.
Its safety comes from exact local reconstruction rules, not from global analysis.

## Important WAT shapes a future port must preserve

## 1. Byte-splitting 32-bit load

```wat
(i32.load align=1 (local.get $p))
```

becomes the moral shape

```wat
(block (result i32)
  (local.set $tmp-p (local.get $p))
  (i32.or
    (i32.or
      (i32.load8_u (local.get $tmp-p))
      (i32.shl (i32.load8_u offset=1 (local.get $tmp-p)) (i32.const 8)))
    (i32.or
      (i32.shl (i32.load8_u offset=2 (local.get $tmp-p)) (i32.const 16))
      (i32.shl (i32.load8_u offset=3 (local.get $tmp-p)) (i32.const 24)))))
```

## 2. Halfword-splitting 32-bit load

```wat
(i32.load align=2 (local.get $p))
```

becomes two `load16_u`s combined with `or` and a `16`-bit shift.

## 3. Signed narrow load repair

```wat
(i32.load16_s align=1 (local.get $p))
```

must not stop at byte-combine.
It must sign-extend the rebuilt value back to the original signed meaning.

## 4. Split store with single-evaluation temporaries

```wat
(i32.store align=1 (call $ptr) (call $val))
```

must evaluate each call once, spill them, then emit chunk stores.

## 5. Full-width 64-bit split

```wat
(i64.load align=1 (local.get $p))
```

must rebuild the result from two 32-bit halves, not from eight separate i64-level byte operations.

## 6. Reinterpret wrappers for floats

```wat
(f32.load align=1 ...)
```

lowers through integer chunk reconstruction and then `f32.reinterpret_i32`.
Similarly `f64` uses `f64.reinterpret_i64`.

## 7. Unreachable operand preservation

```wat
(i32.store align=1 (unreachable) (i32.const 8))
```

does not become nothing; it becomes a block that still drops the operands.

## Pass interactions

The reviewed sources show very little pass-to-pass coupling here.
Important interactions are mostly conceptual:

- it can be paired with `dealign`, which pushes the IR in the opposite direction by forcing alignment 1 everywhere
- later passes may optimize the extra locals or shift/or trees it creates
- but `alignment-lowering` itself does not depend on those later cleanup passes to be correct

That means a faithful port should first preserve correctness and exact evaluation order, and only later worry about recovering compactness.

## Test surface reviewed

The dedicated lit file `test/lit/passes/alignment-lowering.wast` exercises:

- natural-alignment no-ops
- byte- and halfword-split integer loads and stores
- offset-preserving variants
- signed narrow loads
- `i64` and `f64` load/store splitting
- `f32` reinterpret-based rewriting
- unreachable load/store operand handling

What I did **not** find in the reviewed lit surface:

- dedicated atomic cases
- dedicated SIMD or lane-memory cases
- an explicit memory64-named regression section

So a future port should preserve the narrow reviewed scope and may want extra local tests if the implementation is extended.

## Future Starshine port rules

A faithful Starshine port should preserve all of the following:

- only ordinary scalar `Load` / `Store` rewriting unless the scope is intentionally expanded and documented
- single evaluation of pointer and value expressions through fresh locals
- exact signedness repair for lowered signed narrow loads
- exact float reinterpret staging
- 64-bit reconstruction/splitting through two 32-bit halves
- the reviewed unreachable-load and unreachable-store operand-preservation behavior
- natural-alignment no-op behavior
- memory `addressType`-aware pointer temporaries

## Open questions

These are smaller than in some other dossiers, but still worth keeping explicit.

1. The reviewed `version_129` and current-`main` implementation file are identical, but I did not separately review whether upstream has added new surrounding lit coverage since `version_129`.
2. The code strongly implies memory64 pointer-temp correctness through `addressType`, but the reviewed lit file did not give me a dedicated memory64 proof case. That support assessment is therefore an inference from source, not from a reviewed memory64-specific test.
3. Because the pass is not in the current no-DWARF default optimize path, future prioritization should treat it as a tracker-expansion dossier, not as an immediate parity blocker.

## Bottom line

`alignment-lowering` is a small but precise Binaryen pass.
It is best understood as:

- scalar misalignment legalization
- built from local AST rewrites
- centered on chunk splitting/reconstruction
- careful about evaluation order
- narrow in scope

That narrowness is the main thing a future port must not lose.

## Sources

### Local repo

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

### Official Binaryen

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AlignmentLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/alignment-lowering.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/AlignmentLowering.cpp>
