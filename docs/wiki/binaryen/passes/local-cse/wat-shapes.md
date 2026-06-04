---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md
  - ../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md
  - ../../../raw/research/0453-2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/research/0495-2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-04-25-local-cse-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../../raw/research/0119-2026-04-20-local-cse-binaryen-research.md
  - ../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./basic-block-windows-and-barriers.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
---

# `local-cse` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen’s `local-cse` pass.
It was rechecked against the 2026-04-22 raw primary-source capture at [`../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md), which records the reviewed official Binaryen `version_129` release-page date (**2026-04-01**), the 2026-05-05 current-main recheck at [`../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md), and the 2026-06-04 `version_130` / current-main audit refresh at [`../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md`](../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md). Those source checks found no teaching-relevant Binaryen drift, but the 2026-06-04 Starshine audit at [`../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md`](../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md) found one local missed Binaryen-positive shape: before-`if` into `then` reuse.

## Read this page with one mental model

Binaryen is not asking:

- “are these expressions vaguely similar?”

It is asking:

- “is this **entire** tree repeated in the current reuse window, and is it still safe and profitable to replace the later copy with a `local.get`?”

## Important note about the examples

The `after` snippets below are often **conceptual**.

In real Binaryen output, the temp-local index numbers may vary because:

- new locals are appended to the function’s locals list
- the pass may reuse one original for multiple later copies
- some roots are skipped entirely by profitability rules even if they look reusable

So read the shapes as “what family rewrites or stays put,” not “the exact printed temp local number in every run.”

## Quick glossary

- **original**: the first repeated tree that Binaryen keeps and stores with `local.tee`
- **repeat**: a later equal tree that Binaryen wants to replace with `local.get`
- **window**: the current linear execution region where reuse is allowed to connect
- **barrier**: something that makes an original unsafe or unprofitable to reuse later

## Shape 1: same-block arithmetic repeats are the core positive

Before:

```wat
(drop
  (i32.add (i32.const 1) (i32.const 2))
)
(drop
  (i32.add (i32.const 1) (i32.const 2))
)
```

After, conceptually:

```wat
(drop
  (local.tee $tmp
    (i32.add (i32.const 1) (i32.const 2))
  )
)
(drop
  (local.get $tmp)
)
```

Why it rewrites:

- the entire tree repeats
- both copies are in the same reuse window
- the root is big enough to be worth a temp local
- nothing in between invalidates it

This is the basic `local-cse` story.

## Shape 2: three repeats still use one original

Before:

```wat
(drop (i32.add (local.get $x) (local.get $y)))
(drop (i32.add (local.get $x) (local.get $y)))
(drop (i32.add (local.get $x) (local.get $y)))
```

After, conceptually:

```wat
(drop
  (local.tee $tmp
    (i32.add (local.get $x) (local.get $y))
  )
)
(drop (local.get $tmp))
(drop (local.get $tmp))
```

Why it rewrites:

- both later copies point back to the first original
- the pass does not chain second -> third; it reuses the first for both

## Shape 3: a larger parent repeat wins over a repeated child

Before:

```wat
(drop
  (i32.eqz
    (i32.add (local.get $x) (local.get $y))
  )
)
(drop
  (i32.eqz
    (i32.add (local.get $x) (local.get $y))
  )
)
```

Typical after, conceptually:

```wat
(drop
  (local.tee $tmp
    (i32.eqz
      (i32.add (local.get $x) (local.get $y))
    )
  )
)
(drop (local.get $tmp))
```

Why this shape matters:

- once the whole parent repeats, Binaryen cancels child-level requests inside it
- the goal becomes “reuse the bigger whole tree,” not “introduce temp locals for every repeated child too”

This is one of the least obvious rules in the pass.

## Shape 4: a repeated child can still optimize if the parent does not subsume it

Before, conceptually:

```wat
(drop
  (i32.add
    (i32.const 1)
    (i32.add (i32.const 2) (i32.const 3))
  )
)
(drop
  (i32.add (i32.const 2) (i32.const 3))
)
```

After, conceptually:

```wat
(drop
  (i32.add
    (i32.const 1)
    (local.tee $tmp
      (i32.add (i32.const 2) (i32.const 3))
    )
  )
)
(drop (local.get $tmp))
```

Why it rewrites:

- the smaller child tree repeats
- the bigger parent did not repeat in the right way to cancel that request

This is the lesson from the `recursive*` and `self` families.

## Shape 5: after an `if`, the old window is gone

Before:

```wat
(drop (i32.add (i32.const 1) (i32.const 2)))
(if (i32.const 0) (then (nop)))
(drop (i32.add (i32.const 1) (i32.const 2)))
```

After stays the same in the important part:

```wat
(drop (i32.add (i32.const 1) (i32.const 2)))
(if (i32.const 0) (then (nop)))
(drop (i32.add (i32.const 1) (i32.const 2)))
```

Why Binaryen keeps both:

- code after the `if` is not in the same reuse window as code before the `if`

This is the simplest “the pass is local, not whole-region” negative case.

## Shape 6: before-`if` into the `then` arm is a real positive

Before:

```wat
(drop (i32.add (i32.const 2) (i32.const 3)))
(if
  (i32.const 0)
  (then
    (drop (i32.add (i32.const 2) (i32.const 3)))
  )
  (else
    (drop (i32.add (i32.const 2) (i32.const 3)))
  )
)
```

After, conceptually:

```wat
(drop
  (local.tee $tmp
    (i32.add (i32.const 2) (i32.const 3))
  )
)
(if
  (i32.const 0)
  (then
    (drop (local.get $tmp))
  )
  (else
    (drop (i32.add (i32.const 2) (i32.const 3)))
  )
)
```

Why this split happens:

- the `then` arm is in the cheap adjacent dominated window
- the `else` arm is not

So `local-cse` is not just “same AST block only,” but it is also not arbitrary dominance-based CSE.

Starshine status note, current as of the 2026-06-04 audit: this is an upstream Binaryen positive but a local missed optimization. Current `src/passes/local_cse.mbt` visits `then` and `else` regions with fresh region states, so direct `--local-cse` leaves this repeated tree in place. Future fixes should add this positive together with after-`if` and else-arm negatives before widening the local window model.

## Shape 7: repeated loads are allowed

Before:

```wat
(drop (i32.load (i32.const 10)))
(drop (i32.load (i32.const 10)))
```

After, conceptually:

```wat
(drop
  (local.tee $tmp
    (i32.load (i32.const 10))
  )
)
(drop (local.get $tmp))
```

Why it rewrites:

- the root is large enough to matter
- loads are not rejected just because they may trap
- Binaryen keeps the first trapping behavior and replaces only later copies

This is a source-backed and test-backed rule.

## Shape 8: a store between two loads is a barrier

Before, conceptual source-derived example:

```wat
(drop (i32.load (i32.const 10)))
(i32.store (i32.const 10) (i32.const 99))
(drop (i32.load (i32.const 10)))
```

After stays the same in the important part.

Why Binaryen keeps both loads:

- the in-between store can change what the later load reads
- the checker invalidates the earlier original before the repeat arrives

Important honesty note:

- this exact family is directly source-derived from the `LocalCSE.cpp` comments and the effect checker logic
- I did not see a dedicated standalone `local-cse.wast` fixture for this exact store-between-loads case in this thread

## Shape 9: repeated ordinary call roots do not fold

Before and after stay the same:

```wat
(drop (call $f (i32.const 10)))
(drop (call $f (i32.const 10)))
```

Why Binaryen keeps both:

- ordinary calls are not safe repeated roots here
- they may have non-trap side effects
- they may also be generative or nondeterministic

The shipped `calls` test exists to make this obvious.

## Shape 10: repeated arguments inside calls can still fold

Before:

```wat
(drop
  (call $f
    (i32.add (i32.const 10) (i32.const 20))
  )
)
(drop
  (call $f
    (i32.add (i32.const 10) (i32.const 20))
  )
)
```

After, conceptually:

```wat
(drop
  (call $f
    (local.tee $tmp
      (i32.add (i32.const 10) (i32.const 20))
    )
  )
)
(drop
  (call $f
    (local.get $tmp)
  )
)
```

Why it rewrites:

- the call roots themselves are not candidates
- but the repeated arithmetic child is a valid candidate

So the pass is selective, not totally hostile to calls.

## Shape 11: a parent with nested effectful children does not fold

Before and after stay the same in the important part:

```wat
(drop
  (i32.add
    (call $f)
    (call $f)
  )
)
(drop
  (i32.add
    (call $f)
    (call $f)
  )
)
```

Why Binaryen keeps both:

- the parent root contains nested effectful / generative children
- the scanner rejects that root early as impossible

This is the `nested-calls` lesson.

## Shape 12: changing a depended-on local kills reuse

Before:

```wat
(drop (i32.add (local.get $x) (local.get $y)))
(local.set $x (i32.const 100))
(drop (i32.add (local.get $x) (local.get $y)))
```

After stays the same in the important part.

Why Binaryen keeps both adds:

- the second add no longer means the same value as the first
- the in-between `local.set $x` invalidates the old original

The shipped `basics` test covers this family directly.

## Shape 13: repeated `global.get` stays unfused mainly for profitability

Before and after stay the same:

```wat
(drop (global.get $glob))
(drop (global.get $glob))
```

Why Binaryen keeps both:

- `global.get` is tiny
- size-1 roots are intentionally skipped
- this is mostly a “not worth it” rule, not a “never safe” rule

That is an easy distinction to lose if you summarize the pass too quickly.

## Shape 14: repeated idempotent direct calls are a narrow positive exception

Before, conceptual source-derived example:

```wat
(drop (call $idempotent_f (i32.const 10)))
(drop (call $idempotent_f (i32.const 10)))
```

After, conceptually:

```wat
(drop
  (local.tee $tmp
    (call $idempotent_f (i32.const 10))
  )
)
(drop (local.get $tmp))
```

Why Binaryen can allow it:

- `LocalCSE.cpp` explicitly checks callee annotations for `idempotent`
- idempotent direct calls are treated as possible roots
- a later shallowly-equal idempotent call also does not invalidate the earlier one

Starshine status:

- local direct-pass coverage now uses `(@binaryen.idempotent)` WAT annotation lowering and proves repeated single-result direct calls to that callee are materialized and reused
- ordinary non-annotated calls and repeated `call_indirect` / `call_ref` roots now have paired direct no-reuse coverage; the `call_ref` fixture is core-built because the local WAT path is awkward for this surface

## Shape 15: repeated indirect-call roots do not fold

Before and after stay the same:

```wat
(drop (call_indirect (type $t) (local.get $x) (local.get $table_index)))
(drop (call_indirect (type $t) (local.get $x) (local.get $table_index)))
```

Why Binaryen keeps both:

- `call_indirect` is not the direct-call idempotence exception
- the root may be effectful, trap differently, or dispatch to a non-idempotent target
- replacing the second dynamic call with the first result would be arbitrary call CSE

Starshine status: direct WAT coverage proves repeated `call_indirect` roots remain separate and introduce no temp local. A paired core-built `call_ref` fixture proves reference-call roots remain separate as well.

## Shape 16: fresh GC allocation roots do not fold

Before and after stay the same, conceptually:

```wat
(drop (struct.new $T ...))
(drop (struct.new $T ...))

(drop (array.new $A (i32.const 1) (i32.const 2)))
(drop (array.new $A (i32.const 1) (i32.const 2)))
```

Why Binaryen keeps both:

- repeated fresh allocations are generative
- `properties.cpp` marks roots like `struct.new`, `struct.new_default`, and `array.new*` as generative
- reusing the first fresh result would be wrong

Starshine status: direct coverage proves `struct.new`, `struct.new_default`, and core-built `array.new` / `array.new_default` / `array.new_fixed` fixtures remain separate. The core fixtures cover array allocations without widening the local WAT parser path for ordinary `array.*` text.

## Shape 17: repeated switch / `br_table` children can fold

Before, conceptually:

```wat
(br_table $a $a
  (i32.and (local.get $x) (i32.const 3))
  (i32.and (local.get $x) (i32.const 3))
)
```

After, conceptually:

```wat
(br_table $a $a
  (local.tee $tmp
    (i32.and (local.get $x) (i32.const 3))
  )
  (local.get $tmp)
)
```

Why this matters:

- the pass must preserve the correct child ordering for `switch` / `br_table`
- the shipped `switch-children` test exists because Binaryen previously got this wrong

## Shape 18: before-`try_table` into try-body can be a connected window

Before:

```wat
(block $exit
  (drop (i32.add (local.get $x) (local.get $y)))
  (try_table (catch_all $exit)
    (drop (i32.add (local.get $x) (local.get $y)))
  )
)
```

After, conceptually:

```wat
(block $exit
  (drop (local.tee $tmp (i32.add (local.get $x) (local.get $y))))
  (try_table (catch_all $exit)
    (drop (local.get $tmp))
  )
)
```

Why this matters:

- a `try_table` body is not automatically a hard-boundary negative for this adjacent-window shape
- hard terminators inside the nested body still clear the nested reuse window
- the catch target does not turn the pass into CFG-wide CSE

Starshine status: this Binaryen-positive shape is now covered and implemented narrowly in the raw/module path, and a paired `try_table` body fixture proves an inner `unreachable` clears the borrowed outer window before later body code.

## Shape 19: flatten can turn a near-miss into a positive

Before, conceptual near-miss:

```wat
(drop
  (foo
    (bar (baz (qux)))
  )
)
(drop
  (foo
    (bar (baz (other)))
  )
)
```

Current `local-cse` alone does not extract the shared subtree.

Why scheduler placement matters:

- the pass only handles repeated whole trees
- after `flatten`, some near-miss families become repeated whole-tree local-fed shapes instead
- that is why aggressive `-O4` mode inserts `flatten -> simplify-locals-notee-nostructure -> local-cse`

## Important interaction families

## Interaction 1: `coalesce-locals` can expose clearer repeated trees

When several local names collapse or copy traffic shrinks, repeated local-fed roots can become more obviously identical.

That is why the ordinary no-DWARF slot places `local-cse` after `coalesce-locals`.

## Interaction 2: `simplify-locals` can clean up the new temp-local traffic

After `local-cse` introduces new `local.tee` / `local.get` traffic, later local cleanup passes may simplify some of that structure further.

That is why full `simplify-locals` comes immediately afterward.

## Interaction 3: optimizing reruns make this pass recur often

Because `dae-optimizing` and `inlining-optimizing` rerun the default function optimization pipeline on changed functions, `local-cse` is also a recurring nested cleanup tool, not just a one-shot top-level stage.

## One good rule of thumb

A good beginner summary is:

> `local-cse` keeps one repeated whole tree, stores it in a temp local, and reuses it later—but only within one small execution window and only when effects, determinism, and profitability all agree.

That is the real shape story Binaryen `version_129` through `version_130` implements, with no teaching-relevant current-main drift found in the 2026-06-04 source refresh.
