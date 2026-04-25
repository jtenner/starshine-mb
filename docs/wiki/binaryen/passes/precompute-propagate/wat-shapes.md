---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md
  - ../../../raw/research/0375-2026-04-25-precompute-propagate-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md
  - ../../../raw/research/0296-2026-04-24-precompute-propagate-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0167-2026-04-21-precompute-propagate-binaryen-research.md
  - ../../../raw/research/0198-2026-04-21-precompute-propagate-worklist-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-worklist-fallthrough-and-merge-boundaries.md
  - ./starshine-strategy.md
  - ../precompute/index.md
---

# `precompute-propagate` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `precompute-propagate` pass. The source provenance for the dedicated upstream tests is captured in [`../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md`](../../../raw/binaryen/2026-04-24-precompute-propagate-primary-sources.md), with a 2026-04-25 current-main no-drift/code-map refresh in [`../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md`](../../../raw/binaryen/2026-04-25-precompute-propagate-current-main-and-code-map.md).

## Read this page with one mental model

Binaryen is not asking only:

- “is this subtree a constant right now?”

For this pass it is asking a slightly bigger question:

- “if I learn more concrete values through locals, will the ordinary precompute evaluator now be able to replace this expression honestly?”

So the visible rewrites still come from the shared `precompute` family.
The chosen pass matters because it can make more expressions reach that point.

## Important note about the examples

The `after` snippets are **conceptual**.
Real Binaryen output may keep wrapper blocks, `drop`s, or exact constant spellings that differ from the tiny examples.
What matters here is the rewrite family and the reason it becomes legal.

## Quick glossary

- **first walk**: the normal `precompute` bottom-up evaluation pass
- **propagated fact**: a concrete value known for some `local.get`
- **second walk**: the rerun after propagation succeeded
- **child retention**: keeping local/global-writing children alive even when the outer expression becomes constant
- **emitability**: whether Binaryen can print the computed value back as valid IR

## Shape 1: a local-carried constant unlocks a later arithmetic fold

Before:

```wat
(local.set $x
  (i32.const 7))
(drop
  (i32.add
    (local.get $x)
    (i32.const 1)))
```

After, conceptually:

```wat
(local.set $x
  (i32.const 7))
(drop
  (i32.const 8))
```

Why it matters:

- the visible rewrite is ordinary precompute-style constant folding
- the chosen variant matters because the rerun can know more about `local.get $x`

## Shape 2: propagated facts help the partial-`select` algorithm

Before:

```wat
(local.set $x (i32.const 10))
(drop
  (i32.add
    (select
      (local.get $x)
      (i32.const 3)
      (local.get $cond))
    (i32.const 1)))
```

After, conceptually:

```wat
(local.set $x (i32.const 10))
(drop
  (select
    (i32.const 11)
    (i32.const 4)
    (local.get $cond)))
```

Why it rewrites:

- Binaryen can sometimes push the parent work into both `select` arms
- the propagated local fact can make one or both arms simpler on the rerun

## Shape 3: the outer expression becomes constant, but child writes still stay

Before:

```wat
(drop
  (block (result i32)
    (local.set $x (i32.const 4))
    (i32.const 9)))
```

After, conceptually:

```wat
(drop
  (block
    (local.set $x (i32.const 4))
    (i32.const 9)))
```

Why this page keeps the example:

- `precompute-propagate` shares this rule with plain `precompute`
- beginners often expect the whole block to collapse away once the result is known
- the pass still has to preserve child writes

## Shape 4: propagation is useful even when the visible rewrite is still small

Before:

```wat
(local.set $x (i32.const 0))
(drop
  (select
    (local.get $x)
    (i32.const 1)
    (local.get $cond)))
```

After, conceptually:

```wat
(local.set $x (i32.const 0))
(drop
  (select
    (i32.const 0)
    (i32.const 1)
    (local.get $cond)))
```

Why it matters:

- the chosen pass can still be valuable even when it does not collapse the whole expression to one constant
- exposing concrete arms can help later passes too

## Shape 5: emitability can still block a rewrite

Conceptual family:

```wat
;; evaluator knows more about the result
;; but cannot re-emit it as a legal constant expression here
```

After:

```wat
;; unchanged
```

Why it matters:

- knowing a value semantically is not enough
- the pass only rewrites when the value can be emitted honestly
- propagation does not bypass that rule

## Shape 6: GC identity still blocks over-eager folding

Conceptual family:

```wat
(local.set $x (some-heap-allocation ...))
(drop
  (ref.eq
    (local.get $x)
    (local.get $x)))
```

Possible outcome:

```wat
;; sometimes simplifiable, sometimes not, depending on what the evaluator can prove
;; without confusing identical contents for identical allocation identity
```

Why it matters:

- the chosen pass inherits the shared GC-identity contract
- propagation through locals does not permit structural-equality cheating

## Shape 7: unsupported local facts do not magically become constants

Before:

```wat
(local.set $x
  (call $impure))
(drop
  (i32.add
    (local.get $x)
    (i32.const 1)))
```

After:

```wat
;; usually unchanged
```

Why it bails out:

- the propagate phase is conservative
- it is not a generic arbitrary-value propagation engine

## Shape 8: bounded loops stay bounded

Before:

```wat
(loop $L
  ...)
```

After:

```wat
;; unchanged unless the ordinary evaluator can already prove the loop result under its limits
```

Why it matters:

- the propagate variant still shares the family's bounded loop/depth contract
- it is not a license for open-ended symbolic execution

## Shape 9: this pass is the one that shows up after optimizing boundary rewrites

Conceptual scheduler shape:

```text
precompute-propagate -> default function optimization pipeline
```

Why it matters:

- when `dae-optimizing` or `inlining-optimizing` creates fresh constant/local-carrier opportunities, this is one of the first cleanup passes Binaryen runs on the changed functions
- that is why the pass deserves its own dossier even though it shares code with plain `precompute`

## Positive families to remember

- local-carried constants that unlock ordinary arithmetic or boolean folding
- propagated facts that make partial `select` precompute succeed
- second-pass simplifications that plain `precompute` would leave behind in the same slot

## Negative families to remember

- non-emitable values
- child-write-preservation cases where the writes must stay
- unsupported local facts
- bounded loop/depth cases
- GC-identity-sensitive heap shapes
- any documentation that silently claims no-DWARF top-level `-O` / `-Os` uses this variant

## Starshine status note

Current Starshine does not implement these `precompute-propagate` shapes under the sibling name. Plain [`../precompute/index.md`](../precompute/index.md) implements a narrower scalar/control HOT subset, while [`./starshine-strategy.md`](./starshine-strategy.md) records the missing get/set propagation and nested-rerun scheduler work.

## Best beginner summary

If plain `precompute` means:

- “evaluate this expression now if it is safe and emitable”

then `precompute-propagate` means:

- “do that, then learn a few more concrete local facts, and try the same honest evaluation pass once more.”
