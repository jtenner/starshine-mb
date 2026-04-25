---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md
  - ../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals/variant-matrix-and-scheduler.md
  - ../simplify-locals-notee/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nostructure/index.md
  - ../flatten/index.md
---

# `simplify-locals-nonesting`: flatness and variant boundaries

## Why this page exists

The easiest mistake with this pass is to stop reading too early.
People see:

- no tee
- no structure

and conclude that they already understand it.

But the real defining feature is the third flag:

- no nesting

This page is the durable answer to:

- what “preserves flatness” really means
- how this differs from nearby locals variants
- why this still does useful work without collapsing into `flatten`

## The family in one table

| Public pass | Template identity | Tee allowed? | Structure allowed? | New nesting allowed? |
| --- | --- | --- | --- | --- |
| `simplify-locals` | `SimplifyLocals<true, true, true>` | yes | yes | yes |
| `simplify-locals-notee` | `SimplifyLocals<false, true, true>` | no | yes | yes |
| `simplify-locals-nostructure` | `SimplifyLocals<true, false, true>` | yes | no | yes |
| `simplify-locals-notee-nostructure` | `SimplifyLocals<false, false, true>` | no | no | yes |
| `simplify-locals-nonesting` | `SimplifyLocals<false, false, false>` | no | no | no |

That last row is the whole story.
The pass is stricter than every sibling.

## What “preserves flatness” means in practice

Binaryen does **not** mean:

- never change locals at all

Binaryen does mean:

- do not replace a `local.get` with a value expression in a way that pushes a new nested expression under a consumer, unless the rewrite is only copy traffic and stays flat

So the pass still allows some cleanup, but it rejects the classic locals-sinking pattern where a computed value gets pushed deeper into its use site.

## Positive example: flat copy retargeting still allowed

Input:

```wat
(local.set $b
  (local.get $a))
(local.set $c
  (local.get $b))
```

A nonesting-style improvement can still happen here because the pass can retarget `local.get $b` back to `local.get $a` without creating a new nested real value expression.

That is still flat.

## Negative example: sink into `drop` is disallowed

Input:

```wat
(local.set $tmp
  (i32.add
    (local.get $x)
    (i32.const 1)))
(drop
  (local.get $tmp))
```

A more aggressive variant might rewrite this as:

```wat
(drop
  (i32.add
    (local.get $x)
    (i32.const 1)))
```

`simplify-locals-nonesting` does not, because that would create new nesting under `drop`.

## Why parent `local.set` is special

The source code explicitly treats one parent shape as safe under `allowNesting = false`:

- parent is another `local.set`

That is because sinking into the **value position of another set** does not create a new arbitrary consumer nesting shape in the same sense as sinking into `drop`, `if`, arithmetic, call operands, and so on.

That is a subtle but important boundary.
The pass is flat-preserving, not frozen.

## Why this is not the same as `simplify-locals-notee-nostructure`

This is the most important sibling contrast.

`-notee-nostructure` is:

- `SimplifyLocals<false, false, true>`

That means:

- no tee
- no structure
- but **nesting still allowed**

So it may still perform direct single-use sink rewrites into existing consumers.
That is exactly what `-nonesting` refuses.

## Why this is not the same as `simplify-locals-notee`

`-notee` is:

- `SimplifyLocals<false, true, true>`

It still allows:

- structure formation
- ordinary nesting

So `-notee` is only about forbidding tee creation.
It is much broader than `-nonesting`.

## Why this is not the same as `simplify-locals-nostructure`

`-nostructure` is:

- `SimplifyLocals<true, false, true>`

That means it still allows:

- tee creation
- ordinary nesting

So `-nostructure` is only about delaying block/if/loop result formation.
It is not a flatness-preserving variant.

## Why this is not the same as `flatten`

`flatten` and `simplify-locals-nonesting` are neighbors, but they do different jobs.

### `flatten`

- rewrites general tree-shaped IR into Flat IR
- introduces many local carriers and preludes
- owns the hard control/value flattening contract

### `simplify-locals-nonesting`

- starts from already flatter IR
- removes some of the redundant local traffic
- promises not to reintroduce nesting while doing so

So the relation is:

- `flatten` creates a flatter world
- `simplify-locals-nonesting` does a conservative cleanup without breaking that world too much

## Why the pass still matters after `flatten`

The combo lit tests prove the answer:

- `flatten -> simplify-locals-nonesting -> dfo`
- `flatten -> simplify-locals-nonesting -> souperify`

Those downstream passes benefit when some redundant locals are cleaned up first.
But they also benefit when the function stays flatter than the ordinary locals variants would leave it.

That is why this variant exists as a public pass instead of being folded into one of the other reduced variants.

## Easy misunderstandings to avoid

### Mistake 1: “No nesting” means no useful work

Wrong.
Copy retargeting, equivalent-local cleanup, and dead-set cleanup still remain active.

### Mistake 2: “No tee + no structure” already implies no nesting

Wrong.
That describes `-notee-nostructure`, not `-nonesting`.

### Mistake 3: “Preserves flatness” means the pass is identical to `flatten`

Wrong.
`flatten` creates Flat IR; this pass only refuses to add new nesting while doing local cleanup.

### Mistake 4: the pass must be scheduler-dead because it is so specific

Wrong.
Official combo tests use it in real flatten-neighbor pipelines.

## Practical future-port rules

A future Starshine port should preserve these teaching-important boundaries:

- separate `simplify-locals-nonesting` from `simplify-locals-notee-nostructure`
- separate it from `flatten`
- keep the parent-`local.set` exception explicit
- keep copy retargeting and late cleanup active even though nesting is disabled
- preserve the official upstream/local naming split in docs and registry handling

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nonesting-primary-sources.md)
- [`../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md`](../../../raw/research/0331-2026-04-25-simplify-locals-nonesting-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md`](../../../raw/research/0186-2026-04-21-simplify-locals-nonesting-binaryen-research.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
