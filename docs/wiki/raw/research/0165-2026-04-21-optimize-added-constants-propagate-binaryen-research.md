# 0165 - Binaryen `optimize-added-constants-propagate` research

## Status

- Date: 2026-04-21
- Type: Upstream-pass research / wiki-ing dossier seed
- Pass chosen: `optimize-added-constants-propagate`
- Local registry status: `removed`
- Campaign status reason: explicit tracker expansion after the original no-DWARF queue, the saved generated-`-O4z` queue, and the first upstream-only expansion queue were already dossier-covered

## Why this pass was the next eligible target

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `src/passes/optimize.mbt`

That check showed:

1. the original parity queue is already dossier-covered,
2. the first obvious upstream-only expansion queue is already dossier-covered too,
3. `optimize-added-constants-propagate` is still a real local removed-name registry entry in both `src/passes/optimize.mbt` and `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`,
4. there was still **no dedicated living wiki folder** for it, and
5. it sits right next to an important beginner-facing misunderstanding: the existing `optimize-added-constants` notes had blurred this family into arithmetic-tree reassociation, but the actual `version_129` source is about **memory address to load/store offset rewriting**, with the `propagate` sibling adding local-pair propagation.

So this is a justified second-wave tracker expansion and also a source-backed correction pass over a misleading neighboring explanation.

## `agent-todo.md` status

`agent-todo.md` has **no dedicated slice** for `optimize-added-constants-propagate`.

That matters because this dossier is documentation and tracker work, not the closeout of an already-open execution slice.

## Main beginner summary

Binaryen's `optimize-added-constants-propagate` is **not** generic constant folding and **not** arithmetic reassociation.

Its real job is:

- find loads and stores whose pointer is `base + small_constant`,
- move that constant into the memory operation's built-in `offset`,
- and in the `propagate` variant, keep doing that even when the `base + constant` shape sits behind a local `set/get` pair.

So the right beginner mental model is:

- **memory-address canonicalization for loads/stores**,
- not algebra over arbitrary integer expressions.

## Source inventory

### Local repo sources that justify tracking it

- `src/passes/optimize.mbt`
  - the pass is still a known removed-name registry entry
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
  - the pass is still listed in the repo's removed-until-ported batch map
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - current canonical no-DWARF `-O` / `-Os` does **not** include this pass because the repo's default artifact story is not using `--low-memory-unused`
- `agent-todo.md`
  - confirms there is no dedicated implementation slice today

### Official Binaryen `version_129` sources reviewed

- `src/passes/OptimizeAddedConstants.cpp`
- `src/passes/pass.cpp`
- `src/pass.h`
- `test/passes/optimize-added-constants-propagate_low-memory-unused.wast`
- `test/passes/optimize-added-constants-propagate_low-memory-unused.txt`
- `test/passes/optimize-added-constants_low-memory-unused.wast`
- `test/passes/optimize-added-constants_low-memory-unused.txt`
- `test/lit/passes/optimize-added-constants-memory64.wast`
- `test/lit/passes/optimize-added-constants-nomemory.wast`
- `README.md`

## What Binaryen source files matter most

### 1. `OptimizeAddedConstants.cpp`

This is the real pass contract.

It directly answers:

- what the pass actually optimizes,
- why `--low-memory-unused` is mandatory,
- how plain mode differs from propagate mode,
- how existing offsets and constant pointers are normalized,
- how propagated local pairs are proven safe,
- when helper locals are inserted,
- and why cleanup reruns are needed after propagation.

### 2. `pass.cpp`

This matters because it proves:

- both public pass names exist in `version_129`,
- the public descriptions are about **load/store offsets**, not arithmetic trees,
- and the pair is registered as:
  - `optimize-added-constants`
  - `optimize-added-constants-propagate`

### 3. `pass.h`

This matters because it defines `PassOptions::LowMemoryBound = 1024`, which explains the main threshold visible in the official tests:

- offsets below `1024` are candidates,
- `1024` and above are intentionally left alone.

### 4. The official tests

The pass's behavior is spread across two useful test families.

#### `test/passes/optimize-added-constants*low-memory-unused*`

These are the best behavioral oracles for:

- direct `load/store` pointer-plus-constant folding,
- existing-offset accumulation,
- negative-constant bailouts,
- propagate-mode local-pair rewriting,
- SSA and helper-local behavior,
- and the “extra use means do not propagate” rule.

#### `test/lit/passes/optimize-added-constants-memory64.wast`

This proves the memory64/overflow half:

- constant pointer plus offset can be normalized into one constant when no overflow occurs,
- but overflow-sensitive cases stay preserved.

#### `test/lit/passes/optimize-added-constants-nomemory.wast`

This proves the pass is a harmless no-op on modules with no memory instead of an error.

## Actual implementation structure

## Top-level shape

The implementation is a function-parallel walker over `Load` and `Store` nodes.

The real algorithm is:

1. require `--low-memory-unused`,
2. skip modules with no memories,
3. inspect each load/store pointer,
4. if the pointer is a plain constant, normalize `offset + const` into one constant when safe,
5. if the pointer is `add(base, small_const)`, move the small constant into the memory op's `offset`,
6. if `propagate` mode is enabled, also inspect a pointer local's unique defining `local.set`,
7. prove that every influenced use is still just a load/store,
8. prove SSA reuse or insert a helper local,
9. rerun because propagation can unlock more propagation,
10. remove now-unneeded sets.

That is the actual pass shape. There is no broad arithmetic simplifier here.

## The real operator surface

The pass is intentionally tiny.

It cares about:

- `Load`
- `Store`
- pointer expressions shaped like integer `add`
- constant pointers
- `local.set` / `local.get` chains in propagate mode

It does **not** care about:

- general arithmetic expressions outside memory addresses,
- integer `sub` reassociation,
- generic local constant propagation,
- CFG-wide dataflow over arbitrary values,
- or broader peephole simplification.

## The low-memory assumption is semantic, not cosmetic

The key comment in the source says this rewrite needs the assumption that low memory is unused, because:

- `x + c` can wrap,
- but a wasm memory `offset` does not wrap in the same way.

So Binaryen only allows the transform when `--low-memory-unused` is set, and then only for small offsets below `LowMemoryBound`.

This is the single most important safety rule a future Starshine port must preserve.

## The direct rewrite families

### Family 1: fold pointer add into offset

Conceptually:

```wat
(i32.load
  (i32.add (local.get $x) (i32.const 8)))
```

becomes:

```wat
(i32.load offset=8
  (local.get $x))
```

The same applies to stores, and commuted `const + base` is also handled.

### Family 2: accumulate into an existing offset

Conceptually:

```wat
(i32.store offset=2
  (i32.add (local.get $x) (i32.const 5))
  (local.get $v))
```

becomes:

```wat
(i32.store offset=7
  (local.get $x)
  (local.get $v))
```

### Family 3: normalize constant pointer + offset

Conceptually:

```wat
(i32.load offset=10 (i32.const 0))
```

becomes:

```wat
(i32.load (i32.const 10))
```

Binaryen explicitly says this is for clarity/compressibility, because a constant pointer and an offset are interchangeable when overflow is impossible.

## What plain mode does not do

Plain `optimize-added-constants` does the direct memory-address rewrite work above.

It does **not** follow through local pairs like:

```wat
(local.set $x (i32.add (local.get $y) (i32.const 1)))
(drop (i32.load (local.get $x)))
```

That extra step belongs to the `propagate` sibling.

## What propagate mode adds

Propagate mode enables a `LazyLocalGraph`, searches for specific `local.set` patterns, and tries to rewrite memory uses of the local directly.

The simplest positive case is:

```wat
(local.set $x (i32.add (local.get $y) (i32.const 1)))
(drop (i32.load (local.get $x)))
```

which becomes conceptually:

```wat
(nop)
(drop (i32.load offset=1 (local.get $y)))
```

That is a real semantic addition beyond plain mode.

## The real propagation safety checks

The source is conservative.

A defining `local.set` is only considered propagatable when its influenced uses are all still inside `Load` or `Store` parents.

That means this sort of case stays out:

```wat
(local.set $x (i32.add (local.get $sp) (i32.const 16)))
(drop (local.get $x))
(i32.store offset=4 (local.get $x) (i32.const 1))
```

The official `multiadd-extraUse` test keeps the extra local use and therefore blocks the propagation win.

## SSA reuse vs helper-local insertion

If the nonconstant side is another local get and both locals are in SSA form, Binaryen can reuse that earlier local directly.

If not, it inserts a helper local so the earlier base is captured safely before later mutations.

That is why some propagate tests produce shapes like:

- a fresh local copy,
- a small wrapper block/sequence,
- then a load/store on the helper local with an offset.

## Iteration and cleanup

Propagate mode loops until no further propagation happens.

After each changed iteration it:

- creates helper locals when needed,
- runs `UnneededSetRemover`,
- and then tries again.

This matters because one successful propagation can make an older defining set newly removable, which can unlock another propagation later in the same function.

## Important negative and bailout shapes

### Negative constant additions

The official tests keep examples like `+ -11` and `+ -13` unfused.

The pass wants a small nonnegative offset that stays below `LowMemoryBound`; it is not an excuse to invent weird wrapped pointer math.

### Large constants

The `1023` vs `1024` tests are deliberate.

- `1023` is still allowed,
- `1024` is not.

### No memory module

The pass returns early and does nothing.

### Memory64 overflow

The memory64 lit file proves that constant-plus-offset normalization only happens when unsigned overflow is impossible.

## Scheduler meaning

This pass family is public upstream, but the repo's current no-DWARF `-O` / `-Os` page still does not include it because that documented artifact path is not using `--low-memory-unused`.

So this dossier is still an upstream-only registry expansion, not an unfinished default-preset parity page.

## Important pass interactions

### With `precompute` / `precompute-propagate`

Those passes may simplify pointer expressions into constants or adjacent adds first.

Then `optimize-added-constants*` can convert the memory-address shape into offset form.

### With local cleanup passes

Propagate mode intentionally relies on local graph information and then creates or deletes locals. That means later local cleanup passes can remove the leftovers.

### With code size

The source explicitly says propagation can make code a little less compressible in exchange for speed. That tradeoff is part of the upstream contract, not an accidental side effect.

## Easy-to-misunderstand facts

1. The pass name is misleading if read literally.
   - It does **not** optimize arbitrary added constants.
2. The `propagate` sibling is materially different.
   - It is not just a trivial alias.
3. The low-memory assumption is mandatory.
   - Without it, the rewrite is not semantics-preserving.
4. Existing offsets can move back into constants too.
   - Not every rewrite increases the explicit offset field.
5. Propagation is intentionally narrower than generic local propagation.
   - Extra uses can block it.

## What a future Starshine port must preserve

1. The hard `--low-memory-unused` gate.
2. The `LowMemoryBound = 1024` threshold from reviewed `version_129`.
3. The direct `load/store`-pointer-only scope.
4. The plain-vs-propagate distinction.
5. The SSA-or-helper-local safety split.
6. The no-memory no-op rule.
7. The memory64 overflow-preservation rule.

## Durable conclusions

- `optimize-added-constants-propagate` is a real upstream public pass and a real local removed-registry name.
- The actual `version_129` implementation is about **load/store offsets**, not arithmetic-tree reassociation.
- Propagate mode adds a real `LazyLocalGraph`-based local-pair propagation algorithm on top of the plain load/store-address rewrite.
- The hard safety core is `--low-memory-unused` plus the `LowMemoryBound` threshold.
- `agent-todo.md` currently has no dedicated slice for this pass.

## Sources

- Local repo sources:
  - `src/passes/optimize.mbt`
  - `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
- Official Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeAddedConstants.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-memory64.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-nomemory.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>
