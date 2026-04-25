---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-optimize-added-constants-propagate-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md
  - ../../../raw/research/0330-2026-04-25-optimize-added-constants-propagate-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-added-constants/index.md
  - ../precompute/index.md
---

# Binaryen `optimize-added-constants-propagate` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The sibling-specific raw source manifest is [`../../../raw/binaryen/2026-04-25-optimize-added-constants-propagate-primary-sources.md`](../../../raw/binaryen/2026-04-25-optimize-added-constants-propagate-primary-sources.md).
- The core implementation is `src/passes/OptimizeAddedConstants.cpp`.
- Public registration comes from `src/passes/pass.cpp`.
- The low-memory threshold comes from `src/pass.h`.
- The most useful shipped behavior examples are `test/passes/optimize-added-constants-propagate_low-memory-unused.{wast,txt}` plus the shared `memory64` and `nomemory` lit tests.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeAddedConstants.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants-propagate_low-memory-unused.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-memory64.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-nomemory.wast>

## The pass in one sentence

Binaryen `optimize-added-constants-propagate` is a function-parallel memory-address canonicalizer that pushes small added constants into load/store offsets and, in propagate mode, follows certain local `set/get` pairs to keep doing that rewrite across locals.

## The pass in one table

| Phase | What Binaryen does | Why it exists |
| --- | --- | --- |
| Gate | Require `--low-memory-unused`; skip no-memory modules | The rewrite is only sound under the low-memory assumption |
| Direct address fold | Turn `load/store(base + small_const)` into `load/store offset=... (base)` | VMs and later passes like cleaner memory ops |
| Constant-pointer normalization | Merge `offset + const` into one constant when overflow is impossible | Keeps constant addresses simpler and often more compressible |
| Propagation setup | Build `LazyLocalGraph` and find safe `local.set(add(...const...))` candidates | Only propagate when uses are narrow enough |
| Reuse or helper insertion | Reuse an SSA local or insert a helper local copy | Preserve semantics when the base could otherwise change |
| Cleanup + iterate | Remove now-unneeded sets and retry if propagation changed the function | One propagation can unlock another |

## Biggest naming fact

The easiest beginner mistake is reading “added constants” as:

- generic integer-expression optimization.

That is wrong for the reviewed `version_129` source.

A better model is:

- optimize **added constants inside memory addresses** into explicit memory offsets.

## Scheduler fact

This pass is public upstream and is separately registered from plain `optimize-added-constants`, but the repo's current no-DWARF `-O` / `-Os` page still does not include it because that documented artifact path is not using `--low-memory-unused`.

So this dossier is a deliberate upstream-only registry expansion rather than unfinished default-preset parity documentation.

## Relationship to the plain sibling

This is the most important conceptual relationship in the folder.

- plain `optimize-added-constants` rewrites direct load/store-address shapes
- `optimize-added-constants-propagate` does that **plus** local-pair propagation using `LazyLocalGraph`

So the `propagate` variant is not just a cosmetic alias. It has a real extra analysis and rewrite phase.

## What the reviewed implementation is really organized around

The durable structure is:

1. enter the shared `MemoryAccessOptimizer` owner with `propagate = true`,
2. visit each `Load` / `Store`,
3. try constant-pointer cleanup first,
4. try direct `add(base, const)` folding next,
5. in propagate mode, build/use `LazyLocalGraph` and inspect `local.get` pointers with unique defining sets,
6. prove those sets are safe to propagate,
7. either reuse an SSA local or insert a helper local,
8. clean up dead sets and iterate again

That is a narrow but real load/store-address pipeline.

## Why the pass is function-shaped instead of module-shaped

The rewrite targets are ordinary executable expressions:

- `Load`
- `Store`
- `LocalSet`
- `LocalGet`

The pass is therefore a local function-body canonicalizer, even though its low-memory assumption is module-wide.

## Positive rewrite family 1: direct address-to-offset fold

Conceptually:

```wat
(i32.load
  (i32.add
    (local.get $x)
    (i32.const 8)))
```

becomes:

```wat
(i32.load offset=8
  (local.get $x))
```

This is the plain pass's core win and the propagate variant still does it too.

## Positive rewrite family 2: existing offset accumulation

Conceptually:

```wat
(i32.store offset=2
  (i32.add
    (local.get $x)
    (i32.const 5))
  (local.get $v))
```

becomes:

```wat
(i32.store offset=7
  (local.get $x)
  (local.get $v))
```

## Positive rewrite family 3: propagation across locals

Conceptually:

```wat
(local.set $x
  (i32.add
    (local.get $y)
    (i32.const 1)))
(drop
  (i32.load
    (local.get $x)))
```

can become conceptually:

```wat
(nop)
(drop
  (i32.load offset=1
    (local.get $y)))
```

That is the signature propagate-only win.

## Positive rewrite family 4: helper-local salvage when direct reuse is unsafe

When the base local is not safely reusable, Binaryen can insert a helper local that snapshots the base before later mutations.

Conceptually:

```wat
(local.set $x (i32.add (local.get $y) (i32.const 1)))
(local.set $y (i32.const -2))
(drop (i32.load (local.get $x)))
```

may become closer to:

```wat
(block
  (local.set $tmp (local.get $y))
  (nop))
(local.set $y (i32.const -2))
(drop (i32.load offset=1 (local.get $tmp)))
```

That shape is strange if you expect generic constant propagation, but it makes sense once you know the pass is preserving the old memory base.

## Negative family 1: large or out-of-policy offsets

The threshold is `LowMemoryBound = 1024` in reviewed `version_129`.

That is why the official tests deliberately show:

- `1023` folds,
- `1024` does not.

## Negative family 2: negative constants

The official tests explicitly keep negative-constant examples unfused.

The pass wants a safe low-memory offset; it is not trying to encode arbitrary signed pointer arithmetic into memory offsets.

## Negative family 3: extra local uses

If a candidate local still has other uses, Binaryen will often refuse propagation.

That prevents the pass from duplicating the address computation pointlessly.

## Negative family 4: no memory module

The pass returns early and does nothing.

This is an important public behavior because the CLI pass still exists even on modules that have nothing to optimize here.

## Negative family 5: overflow-sensitive constant-pointer normalization

The memory64 lit test proves Binaryen only merges `offset + const` into one constant when overflow cannot occur.

## Beginner-facing summary of helper dependencies

Compared with many Binaryen passes, this one has a small dependency surface.

It uses:

- `LazyLocalGraph`
- `GetParents` via an `ExpressionStackWalker`
- `UnneededSetRemover`
- `Builder`

It does **not** centrally depend on:

- branch utilities
- dominance as a separate analysis pass
- liveness as a separate analysis pass
- whole-module type rewriting
- heavy refinalization or nondefaultable-local repair

That is a clue that this is still a compact local canonicalizer, even in propagate mode.

## Important pass interactions

## With the plain sibling

The plain sibling is the smaller core.
The propagate sibling should be taught as:

- the same memory-offset rewrite,
- plus a conservative local-pair follow-through step.

## With `precompute` and `precompute-propagate`

Those passes may simplify pointer expressions first.
Then `optimize-added-constants-propagate` can canonicalize the surviving memory address into the memory op itself.

## With later local cleanup passes

Propagation can create `nop`s, dead sets, or helper locals. Later local cleanup passes can often reduce those leftovers further.

## What a future Starshine port must preserve

A correct port should preserve seven boundaries:

1. the hard `--low-memory-unused` gate,
2. the `LowMemoryBound = 1024` threshold,
3. load/store-only pointer rewriting,
4. direct-address folding even without propagation,
5. conservative propagate-only use filtering,
6. SSA reuse versus helper-local insertion,
7. no-memory and overflow no-op preservation.

## Most important beginner correction

If someone says:

- “Binaryen has a propagate pass that reassociates added constants”

that is too vague and, for this family, misleading.

A much better sentence is:

- “Binaryen has a load/store offset canonicalizer, and the propagate variant can chase that address pattern across specific local pairs.”

That is the main durable teaching value of this dossier.
