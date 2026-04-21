# Binaryen `optimize-added-constants` low-memory / overflow safety follow-up

- Date: 2026-04-21
- Pass: `optimize-added-constants`
- Status: follow-up research filed back into the living wiki
- Motivation: the tracker had no obvious remaining `none` targets, so this thread needed a clearly justified major-gap fallback inside an already covered folder. Plain `optimize-added-constants` was still a good target because its dossier explained the high-level direct-address rewrite well, but it still lacked one compact source-confirmed page for the **exact safety matrix** that makes the pass easy to mis-port: the hard `--low-memory-unused` gate, the strict `1023`-yes / `1024`-no bound, the `curr->offset + value` low-memory check, and the separate unsigned-overflow rules for constant-pointer normalization on memory32 vs memory64.
- `agent-todo.md` check: there is **no dedicated `optimize-added-constants` slice** today.

## Sources consulted

Official Binaryen `version_129` sources:

- `src/passes/OptimizeAddedConstants.cpp`
- `src/passes/pass.cpp`
- `src/pass.h`
- `test/passes/optimize-added-constants_low-memory-unused.wast`
- `test/passes/optimize-added-constants_low-memory-unused.txt`
- `test/lit/passes/optimize-added-constants-memory64.wast`
- `test/lit/passes/optimize-added-constants-nomemory.wast`

Current-main drift check:

- `src/passes/OptimizeAddedConstants.cpp` on `main`

## What was missing from the living dossier

The existing folder already taught the big picture correctly:

- plain mode is direct load/store-address folding,
- propagate mode adds the `LazyLocalGraph` local-pair follow-through,
- this is not generic arithmetic reassociation.

But it still did **not** isolate the exact safety math into one beginner-teachable page.
That mattered because a future port could easily get the public contract subtly wrong by:

- treating `LowMemoryBound` as `<= 1024` instead of strict `< 1024`,
- checking only the added constant and forgetting the **combined** `curr->offset + value` low-memory rule,
- folding negative or wraparound constant-pointer cases that Binaryen leaves untouched,
- or assuming memory64 changes the low-memory threshold when it actually changes only the unsigned-overflow width for constant-pointer normalization.

## Source-confirmed safety rules

## 1. The pass hard-requires `--low-memory-unused`

`OptimizeAddedConstants.cpp` explicitly aborts if the pass runs without `getPassOptions().lowMemoryUnused`.
This is not merely a profitability hint.
It is part of the soundness story: the pass is allowed to reinterpret `base + c` as an explicit memory offset only when the optimizer may assume low memory is unreachable by wraparound tricks.

## 2. Plain mode is still load/store-only

The plain pass only rewrites `Load` and `Store` pointer expressions.
It does not own arbitrary arithmetic-tree canonicalization, and it does not use the sibling's local propagation path.

## 3. `LowMemoryBound` is a strict `< 1024` rule, not `<= 1024`

`src/pass.h` defines `PassOptions::LowMemoryBound = 1024`.
`canOptimizeConstant(...)` then accepts only values where:

- `value < PassOptions::LowMemoryBound`

and only if the merged total also satisfies:

- `curr->offset + value < PassOptions::LowMemoryBound`

So the public contract is:

- `1023` may fold,
- `1024` does not.

The shipped `optimize-added-constants_low-memory-unused.{wast,txt}` oracle makes that visible for both loads and stores.

## 4. The pass checks the merged offset, not just the new constant

This is the easiest rule to miss.
Even if the added constant itself is small enough, Binaryen still refuses the rewrite unless the **new total offset** stays below the low-memory bound.

That means a future port must not implement:

- “small constant => fold”

It must implement:

- “small constant **and** small merged offset => fold.”

## 5. Constant-pointer normalization is a separate path with unsigned-overflow checks

`optimizeConstantPointer()` handles the other major family:

- `(load offset=X (const BASE))`
- `<=>` `(load (const BASE+X))`

Binaryen prefers the latter when it can prove the addition does not overflow.
But the proof is width-sensitive:

- on memory64 it checks `base > max - offset` in `uint64_t`
- on memory32 it checks `uint64_t(base) + uint64_t(offset) < (1 << 32)`

So memory64 does **not** widen the low-memory threshold.
It only widens the unsigned address space used by this constant-pointer normalization proof.

## 6. Existing large offsets may remain large

The source comments make another subtle point explicit:

- `curr->offset` may already exceed the low-memory bound,
- and Binaryen still may keep that existing offset untouched,
- but it only folds in more information when the obviously-valid no-overflow case is proven.

That means “existing large offset” and “newly foldable low-memory constant” are different questions.

## 7. Negative and wraparound-looking constants stay unfused

Because `canOptimizeConstant(...)` works on the integer literal value and enforces the low-memory bound, the pass intentionally avoids the “interesting” signed and wraparound edge cases.
The shipped tests keep those cases preserved rather than normalized into offsets.

## 8. Current `main` still matches `version_129` on the reviewed implementation file

A direct file diff of `src/passes/OptimizeAddedConstants.cpp` between Binaryen `version_129` and current `main` showed no differences on the reviewed surface.
So `version_129` remains a safe oracle for this exact safety follow-up.

## Resulting wiki changes

To close this gap cleanly, I added a new living page:

- `docs/wiki/binaryen/passes/optimize-added-constants/low-memory-threshold-overflow-and-offset-merge-rules.md`

and refreshed the landing page plus shared indexes so future campaign threads can see that the remaining missing explanation was specifically the exact safety/threshold matrix, not the already-closed broader sibling-split question.

## Practical porting takeaway

If Starshine ever ports plain `optimize-added-constants`, the minimal faithful safety checklist is:

1. require `--low-memory-unused`,
2. rewrite only `Load` / `Store` pointer shapes in plain mode,
3. accept only added constants with `value < 1024`,
4. also require the merged total offset to stay `< 1024`,
5. normalize constant pointers only when unsigned addition cannot overflow,
6. use 32-bit vs 64-bit overflow proofs according to memory address width,
7. leave negative / wraparound-looking edge cases untouched.
