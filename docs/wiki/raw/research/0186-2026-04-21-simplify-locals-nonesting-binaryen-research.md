# 0186 - Binaryen `simplify-locals-nonesting` research

## Supersession note

Superseded on 2026-04-25 for raw-source provenance and Starshine local-status mapping by:

- [`../binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md`](../binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md)
- [`0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md`](0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md)

This note remains useful for the first-pass mechanics reading and the original rationale for creating the folder.

## Scope and intent

- Continue the recursive Binaryen pass wiki-ing campaign after the upstream-only `untee` dossier.
- Pick exactly one still-underdocumented Binaryen pass and give it a dedicated living dossier.
- Create a canonical home for the upstream public pass `simplify-locals-nonesting`, which is still only described indirectly inside neighboring `simplify-locals*` folders.

## Why this pass was eligible

The campaign prompt required re-checking the tracker before choosing a pass.
At the start of this thread:

- the original no-DWARF / saved `-O4z` parity queues were already dossier-covered
- the first widened upstream-only tracker wave was already dossier-covered
- `docs/wiki/binaryen/passes/tracker.md` explicitly said there was no obvious remaining still-`none` queue-expansion target
- the local registry in `src/passes/optimize.mbt` still exposed several real upstream public variants or sibling/test-oriented pass names without dedicated landing folders

I picked `simplify-locals-nonesting` for four source-backed reasons:

1. `src/passes/optimize.mbt` still tracks the local alias `simplify-locals-no-nesting`, so this is not invented scope.
2. Official Binaryen `version_129` registers `simplify-locals-nonesting` as a real public pass name in `src/passes/pass.cpp`.
3. Official Binaryen exposes a dedicated constructor `createSimplifyLocalsNoNestingPass()` in `passes.h` / `SimplifyLocals.cpp`, so this is a real public variant, not a prose-only nickname.
4. The existing `simplify-locals`, `simplify-locals-notee`, `simplify-locals-nostructure`, `simplify-locals-notee-nostructure`, `flatten`, and `dataflow-optimization` dossiers all mention this variant, which proves it matters, but there was still no dedicated folder to serve as the canonical home for its exact contract.

## Agent-todo status

`agent-todo.md` currently has **no dedicated `simplify-locals-nonesting` or `simplify-locals-no-nesting` slice**.
That absence is explicit and should stay explicit in the living docs.

## Primary upstream sources reviewed

### Official Binaryen `version_129` sources

- `src/passes/SimplifyLocals.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `test/passes/simplify-locals-nonesting.wast`
- `test/passes/simplify-locals-nonesting.txt`
- `test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast`
- `test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
- `test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`

### Neighboring local living docs re-read to avoid duplication

- `docs/wiki/binaryen/passes/simplify-locals/index.md`
- `docs/wiki/binaryen/passes/simplify-locals/variant-matrix-and-scheduler.md`
- `docs/wiki/binaryen/passes/simplify-locals/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee/variant-boundaries-and-registry-aliases.md`
- `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/variant-surface.md`
- `docs/wiki/binaryen/passes/flatten/index.md`
- `docs/wiki/binaryen/passes/dataflow-optimization/index.md`

## Exact public identity

Official `version_129` source defines the full family as:

- `SimplifyLocals<allowTee, allowStructure, allowNesting>`

The public nonesting pass is:

- `createSimplifyLocalsNoNestingPass()`
- `return new SimplifyLocals<false, false, false>();`

That means `simplify-locals-nonesting` is the only public family variant that disables **all three** of:

- tee creation
- structure creation
- nesting creation

This is the most important durable correction in the whole dossier.
The pass is not just “no tee and no structure.”
It is a stronger flatness-preserving variant.

## Official registration and naming

`pass.cpp` registers:

- `simplify-locals-nonesting`
- description: `miscellaneous locals-related optimizations (no nesting at all; preserves flatness)`

That description matters.
It is the official public wording that makes the flatness promise explicit.

The local Starshine registry still uses the alias:

- `simplify-locals-no-nesting`

So the new living docs must preserve both names:

- upstream public Binaryen name: `simplify-locals-nonesting`
- local registry alias: `simplify-locals-no-nesting`

## Main implementation structure

`SimplifyLocals.cpp` uses the same core engine as the larger family.
The pass is still a real locals optimizer, not a test stub.
Its structure is:

1. count `local.get` uses with `LocalGetCounter`
2. run a first cycle that only considers one-use sinks
3. run additional cycles when earlier motion unlocks later motion
4. perform the same late `EquivalentOptimizer` pass over equivalent copy chains
5. run `UnneededSetRemover`
6. `ReFinalize` if a rewrite sharpened types
7. rely on the pass runner's usual nondefaultable-local fixups afterward

So the pass is not “just skip a few flags.”
It is the same multi-phase engine, with one stricter movement contract.

## What the `allowNesting = false` switch actually changes

The important implementation detail lives in `optimizeLocalGet(...)`.
When nesting is disabled:

- a direct `local.get` replacement is still allowed if the stored value is itself just another `local.get` copy
- a direct sink of a non-`local.get` value is rejected unless the parent is another `local.set`
- if the stored value is a copy and the use is multi-use, the pass cannot make a tee, so it falls back to retargeting the read to the original index instead of nesting the copied value

This is the core nonesting behavior.
It does not mean “never rewrite anything.”
It means:

- preserve flatness by refusing rewrites that would push a real expression under a new consumer node
- but still allow copy-chain canonicalization that stays flat

## Positive rewrite families that still remain in scope

Even with `allowTee = false`, `allowStructure = false`, and `allowNesting = false`, Binaryen still does useful work.

### 1. Flat single-use copy sinking into another `local.set`

Allowed because it does not introduce new nesting; the destination is still a set-value position.

### 2. Copy-chain retargeting

When the sinkable set stores `local.get $a` into `$b`, later reads of `$b` can be redirected back to `$a` even when the pass cannot safely nest or tee.

### 3. Late equivalent-copy cleanup

The pass still runs the late `EquivalentOptimizer`, so equal local classes and redundant copies are still canonicalized.

### 4. Final dead-set / dead-tee cleanup

`UnneededSetRemover` still removes locals that ended up with no remaining uses.

### 5. Block-prelude cleanup after `flatten`

The combo tests show the pass is useful as a preparatory cleanup even before later `dfo`, `souperify`, or other aggressive passes run.

## Rewrite families this variant explicitly forbids

### 1. New `local.tee` creation

Because `allowTee = false`, multi-use sinks cannot become tee-based first-use rewrites.

### 2. Block / `if` / loop result synthesis

Because `allowStructure = false`, the helpers

- `optimizeLoopReturn(...)`
- `optimizeBlockReturn(...)`
- `optimizeIfElseReturn(...)`
- `optimizeIfReturn(...)`

are simply not used in this variant.

### 3. Any sink that would create new expression nesting

Because `allowNesting = false`, a shape like

- `drop (local.get $tmp)`

cannot become

- `drop (expensive-value)`

unless the rewrite is only copy retargeting and therefore remains flat.

## Dedicated test surface and what it teaches

### `test/passes/simplify-locals-nonesting.wast` + `.txt`

This dedicated pair proves the pass is a real public variant with its own visible output contract.
The named functions are small and pedagogical:

- `figure-1a`
- `figure-1b`
- `figure-3-if`

The outputs show repeated local-copy ladders being simplified while the final code stays visibly flat.
You see many `nop`s where the source locals used to be, but you do **not** see the full pass inventing new structured result carriers or tee shapes.

### `flatten_simplify-locals-nonesting_dfo_O3.wast`

This lit combo proves the variant has a real aggressive-pipeline role:

- `flatten -> simplify-locals-nonesting -> dfo -> -O3`

That is source-backed evidence that this pass is not dead API clutter.
It is a flatten-neighbor cleanup step used before another flatness-sensitive pass.

### Souperify combo tests

- `flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
- `flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`

These prove the pass is also used as a preparation step for downstream extraction/analysis pipelines where preserving flatter local structure matters.

## Nearby-pass interactions

### Distinct from `simplify-locals-notee-nostructure`

That variant is `SimplifyLocals<false, false, true>`.
It still allows ordinary nesting.
So it is stricter about tees and structure, but **looser** about flatness.
This is the easiest confusion to make.

### Distinct from `flatten`

`flatten` enforces Flat IR.
`simplify-locals-nonesting` does not recreate arbitrary Flat IR invariants; it simply refuses to add new nesting while performing limited local cleanup.
It is a neighbor, not a synonym.

### Distinct from `untee`

`untee` removes explicit `local.tee` nodes.
`simplify-locals-nonesting` is broader, but it also refuses to create new tees and preserves flatness.
The two passes teach different things.

### Distinct from full `simplify-locals`

The full variant uses the same engine, but later cycles may create tees, synthesize control-result structure, and freely sink values into nested positions.

## Important beginner-facing corrections

1. `simplify-locals-nonesting` is a **real public Binaryen pass**, not just an implementation flag.
2. It is **not** the same as `simplify-locals-notee-nostructure`.
3. It is **not** the same as `flatten`.
4. It still does real work: copy retargeting, equivalent-local cleanup, and dead-set cleanup remain active.
5. Its defining promise is exactly what `pass.cpp` says: **preserves flatness**.

## Current-main freshness check

A narrow same-day freshness check against upstream `main` found:

- `src/passes/SimplifyLocals.cpp`: only small container changes (`std::map`/`std::set` to unordered variants on the checked fields), with no checked semantic drift in the nonesting logic
- `test/passes/simplify-locals-nonesting.wast`: unchanged
- `test/passes/simplify-locals-nonesting.txt`: unchanged

Inference: `version_129` remains a trustworthy released oracle for this pass's visible contract.

## Planned living-doc outputs

Create a dedicated folder:

- `docs/wiki/binaryen/passes/simplify-locals-nonesting/`

with at least:

- landing page
- `binaryen-strategy.md`
- `implementation-structure-and-tests.md`
- `flatness-variant-boundaries.md`
- `wat-shapes.md`

## Shared docs to update

- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Sources

### Local repo

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- existing `simplify-locals*`, `flatten`, `dataflow-optimization`, and `untee` dossier pages listed above

### Official Binaryen `version_129`

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_dfo_O3.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>

### Narrow freshness check

- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nonesting.txt>
