---
kind: concept
status: supported
last_reviewed: 2026-06-01
sources:
  - ../../../raw/binaryen/2026-05-05-optimize-added-constants-current-main-recheck.md
  - ../../../raw/research/0465-2026-05-05-optimize-added-constants-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md
  - ../../../raw/research/0418-2026-04-27-optimize-added-constants-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md
  - ../../../raw/research/0300-2026-04-24-optimize-added-constants-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md
  - ../../../raw/binaryen/2026-06-01-binaryen-v130-current-trunk-release-horizon.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./low-memory-threshold-overflow-and-offset-merge-rules.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-added-constants-propagate/index.md
---

# Binaryen `optimize-added-constants` Strategy

## Upstream source rule

- Use Binaryen `version_125` as the current release baseline for new research; this page's detailed implementation notes remain anchored to the `version_129` source set and current-main recheck until a dedicated `version_125` reread says otherwise.
- The immutable release-tag source manifest for the original refresh is [`../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md`](../../../raw/binaryen/2026-04-24-optimize-added-constants-primary-sources.md).
- The 2026-04-27 current-main / local-readiness recheck is [`../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-optimize-added-constants-port-readiness-primary-sources.md).
- The core implementation is `src/passes/OptimizeAddedConstants.cpp`.
- Public registration comes from `src/passes/pass.cpp`.
- The low-memory threshold comes from `src/pass.h`.
- The most useful shipped behavior examples for the plain pass are `test/passes/optimize-added-constants_low-memory-unused.{wast,txt}` plus the shared `memory64` and `nomemory` lit tests.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeAddedConstants.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/optimize-added-constants_low-memory-unused.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-memory64.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-added-constants-nomemory.wast>

Exact upstream source anchors worth keeping in mind:

- `OptimizeAddedConstants.cpp`: file header contract; `MemoryAccessOptimizer`; `optimizeConstantPointer`; `tryToOptimizeConstant`; `tryToOptimizePropagatedAdd`; `canOptimizeConstant`; `OptimizeAddedConstants::isFunctionParallel`; `OptimizeAddedConstants::doWalkFunction`; `createOptimizeAddedConstantsPass`; `createOptimizeAddedConstantsPropagatePass`.
- `pass.cpp`: public registration strings for `optimize-added-constants` and `optimize-added-constants-propagate`.
- `pass.h`: `PassOptions::LowMemoryBound`.
- the `low-memory-unused`, `memory64`, and `nomemory` tests: the three visible safety and empty-module shapes.

Narrow freshness note: the 2026-05-05 current-main source-anchor recheck and the earlier 2026-04-27 port-readiness spot check did not surface a teaching-relevant contract drift on the owner / registration / option / test surfaces. The public Binaryen release horizon has since advanced to `version_125`, but this page still treats the reviewed `version_129` sources as the implementation baseline until a later source ingest says otherwise.

## The pass in one sentence

Binaryen `optimize-added-constants` is a function-parallel memory-address canonicalizer that pushes small added constants into load/store offsets and normalizes constant-pointer-plus-offset forms, but does **not** use the sibling pass's local-pair propagation machinery.

The 2026-05-05 source-anchor digest keeps that contract easy to trace without changing it.

## Biggest naming fact

The easiest beginner mistake is reading “added constants” as:

- generic arithmetic simplification.

That is wrong for the reviewed `version_129` source.

A better model is:

- optimize **memory addresses that contain an added constant**.

## Relationship to the propagate sibling

This is the most important conceptual fact.

- plain `optimize-added-constants` owns the direct address-to-offset rewrite
- `optimize-added-constants-propagate` owns that same direct rewrite **plus** propagation across certain local `set/get` pairs

So the plain pass is the smaller core, not a different arithmetic algorithm.

## What the reviewed implementation is really organized around

The plain pass's durable structure is:

1. require `--low-memory-unused`,
2. skip no-memory modules,
3. inspect each `Load` and `Store`,
4. if the pointer is a constant and the offset can be merged safely, normalize to one constant pointer,
5. if the pointer is `add(base, small_const)`, move that constant into the memory op's `offset`,
6. stop there.

The propagate sibling adds more steps after that, but the plain pass does not.

## Why the low-memory assumption is mandatory

The source explicitly says the optimization needs the assumption that low memory is unused, because:

- `base + c` may wrap,
- while a wasm memory offset does not model that same wraparound behavior.

So a future Starshine port must preserve both:

- the hard `--low-memory-unused` gate,
- and the `LowMemoryBound = 1024` threshold.

## Positive rewrite family 1: direct address fold

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

## Positive rewrite family 2: commuted add fold

Conceptually:

```wat
(i32.load
  (i32.add
    (i32.const 4)
    (local.get $x)))
```

becomes:

```wat
(i32.load offset=4
  (local.get $x))
```

## Positive rewrite family 3: existing offset accumulation

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

## Positive rewrite family 4: constant-pointer normalization

Conceptually:

```wat
(i32.load offset=10
  (i32.const 0))
```

becomes:

```wat
(i32.load
  (i32.const 10))
```

Binaryen explicitly says it prefers the whole address in the constant in that case for clarity and compressibility.

## Important negative families

### Large constants

The official tests deliberately show the `1023` / `1024` cutoff.

### Negative constants

Negative-constant examples are preserved.
The pass wants safe low-memory offsets, not arbitrary signed pointer arithmetic.

### No memory modules

The pass returns early and does nothing.

### Memory64 overflow cases

The memory64 lit file proves offset-plus-constant normalization only happens when unsigned overflow is impossible.

### Local-pair propagation

This is the big thing plain mode does **not** do.
If the address first flows through a local, that extra follow-through belongs to the sibling pass.

## Beginner-facing summary of helper dependencies

The plain pass is intentionally small.

It mostly relies on:

- direct AST node inspection of `Load` / `Store` / `Const` / `Binary`
- `Builder` for replacement nodes
- the low-memory option boundary

It does **not** require the extra `LazyLocalGraph` machinery to do its core job.

## Important pass interactions

## With the propagate sibling

The plain pass is the direct-address-only core. The propagate sibling should be treated as a strict extension.

## With `precompute`

`precompute` may expose direct `add(base, const)` or constant-pointer shapes that the plain pass can then fold into memory offsets.

## With later local cleanup

The plain pass creates fewer leftovers than the propagate sibling, because it does not insert helper locals or remove dead address-carrier sets.

## What a future Starshine port must preserve

[`./starshine-strategy.md`](./starshine-strategy.md) maps current Starshine status; [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) turns those requirements into an implementation and validation ladder. A correct port should preserve six boundaries:

1. the hard `--low-memory-unused` gate,
2. the `LowMemoryBound = 1024` threshold,
3. load/store-only pointer rewriting,
4. existing-offset accumulation,
5. constant-pointer normalization without overflow,
6. no local-pair propagation in the plain variant.

## Most important beginner correction

If someone says:

- “`optimize-added-constants` is Binaryen's arithmetic reassociation pass”

that is wrong for the reviewed `version_129` source.

A much better sentence is:

- “`optimize-added-constants` is the direct memory-address offset-folding half of the `OptimizeAddedConstants.cpp` pass family.”
