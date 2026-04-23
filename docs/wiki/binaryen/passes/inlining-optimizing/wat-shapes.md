---
kind: concept
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
  - ../../../raw/research/0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./planning-partial-inlining-and-reruns.md
  - ./starshine-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# `inlining-optimizing` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen's `inlining-optimizing` pass.

## Read this page with one mental model

Binaryen is looking for **call boundaries worth erasing**.
It is not asking only:

- “is this callee tiny?”

It is asking something closer to:

- “is this direct call boundary cheap enough to erase,
- is the callee still safe to inline,
- would the module stay well-structured afterward,
- and is the follow-up cleanup worth it?”

That is why the pass has both positive inline families and strong bailout families.

## Quick glossary

- **root**: a function Binaryen keeps alive because outside or implicit callers may still exist
- **surviving use**: a use such as export, start, or `ref.func` that still keeps the function boundary relevant
- **full inline**: replace the call with the callee body directly
- **partial inline**: split out a structured region into a helper first, then inline that helper
- **touched function**: a caller or callee body that changed and therefore gets the nested cleanup rerun

## Shape 1: tiny private direct helper fully inlines

Before:

```wat
(func $add1 (param $x i32) (result i32)
  (i32.add
    (local.get $x)
    (i32.const 1)))

(func $main (result i32)
  (call $add1
    (i32.const 41)))
```

After, conceptually:

```wat
(func $main (result i32)
  (i32.add
    (i32.const 41)
    (i32.const 1)))
```

Why it folds:

- the helper is tiny
- the call is direct
- there is no export/start/root hazard
- there is no tail-call or recursive-growth blocker

After `inlining-optimizing`, later nested cleanup may also precompute the final constant.

## Shape 2: inline succeeds, but the callee still survives

Before:

```wat
(func $helper (param i32) (result i32)
  (i32.mul
    (local.get 0)
    (i32.const 2)))

(func $a (result i32)
  (call $helper (i32.const 3)))

(func (export "keep") (param i32) (result i32)
  (call $helper (local.get 0)))
```

Conceptual after:

```wat
(func $a (result i32)
  (i32.mul
    (i32.const 3)
    (i32.const 2)))

(func $helper (param i32) (result i32)
  (i32.mul
    (local.get 0)
    (i32.const 2)))
```

Why Binaryen keeps the helper:

- one internal callsite was worth inlining
- but other surviving uses still require the helper boundary
- here the exported path keeps the function alive indirectly

This is the easiest way to remember that “inline” does not always mean “delete callee.”

## Shape 3: a one-caller helper can inline even when it is not the tiniest possible leaf

Before:

```wat
(func $one_use (param $x i32) (result i32)
  (local $tmp i32)
  (local.set $tmp
    (i32.add (local.get $x) (i32.const 5)))
  (i32.mul
    (local.get $tmp)
    (i32.const 2)))

(func $caller (result i32)
  (call $one_use (i32.const 10)))
```

Why Binaryen may still inline it:

- the helper has only one use
- the call overhead disappears entirely
- the planner's single-use heuristic is looser than the tiny-leaf rule

So a non-trivial helper can still inline when it is a one-caller wrapper.

## Shape 4: nested cleanup is part of the positive story

Before:

```wat
(func $id_plus_zero (param $x i32) (result i32)
  (i32.add
    (local.get $x)
    (i32.const 0)))

(func $use (result i32)
  (call $id_plus_zero (i32.const 7)))
```

After raw inlining, conceptually:

```wat
(i32.add
  (i32.const 7)
  (i32.const 0))
```

After the optimizing rerun, conceptually:

```wat
(i32.const 7)
```

Why this matters:

- the inline rewrite itself is only half the story
- `precompute-propagate` plus the default cleanup pipeline is how Binaryen cashes in on the new constant shape

## Shape 5: `ref.func` can keep the boundary alive even after a direct inline

Before:

```wat
(table 1 1 funcref)
(elem (i32.const 0) $helper)

(func $helper (param i32) (result i32)
  (i32.add (local.get 0) (i32.const 1)))

(func $internal (result i32)
  (call $helper (i32.const 9)))
```

Conceptual after:

```wat
(func $internal (result i32)
  (i32.add
    (i32.const 9)
    (i32.const 1)))

(func $helper (param i32) (result i32)
  (i32.add (local.get 0) (i32.const 1)))
```

Why the helper remains:

- the direct callsite was worth inlining
- but the `ref.func`-style table use still keeps the helper boundary observable

## Shape 6: generic `call_ref` selection is not the main chosen-action story in reviewed `version_129`

Before and after stay the same conceptually:

```wat
(func $use (param funcref i32) (result i32)
  (call_ref (result i32)
    (local.get 1)
    (local.get 0)))
```

Why this page teaches it as a non-goal:

- reviewed `version_129` chosen inline actions are still discovered from reachable direct `call` / `return_call` sites
- `call_ref` and `return_call_ref` still matter in copied-body repair and surrounding helper logic
- but this folder should not teach the release as if general precise `call_ref` selection were already the main planner contract

## Shape 7: imports never inline

Before and after stay the same:

```wat
(import "env" "imp" (func $imp (param i32) (result i32)))

(func $use (result i32)
  (call $imp (i32.const 1)))
```

Why Binaryen leaves it alone:

- the implementation body is outside the module
- there is nothing internal to copy into the caller

## Shape 8: self-recursive growth is a deliberate bailout

Before and after conceptually stay the same:

```wat
(func $fact (param $n i32) (result i32)
  (if (result i32)
    (i32.eqz (local.get $n))
    (then (i32.const 1))
    (else
      (i32.mul
        (local.get $n)
        (call $fact
          (i32.sub (local.get $n) (i32.const 1)))))))
```

Why Binaryen refuses the obvious bad idea:

- inlining recursive self-calls would only grow the same function again and again
- the planner has an explicit recursive-growth guard

## Shape 9: tail-call-containing callees stay conservative

Before and after conceptually stay the same:

```wat
(func $tail_wrapper (param i32) (result i32)
  (return_call $other
    (local.get 0)))
```

Why Binaryen is conservative:

- the ordinary inline-worth logic bails out on tail-call-containing functions
- tail-call shape is not treated as ordinary small-helper structure

## Shape 10: partial inlining can split a branchy region first

Conceptual before:

```wat
(func $mixed (param $cond i32) (param $x i32) (result i32)
  (if (result i32)
    (local.get $cond)
    (then
      (call $tiny_hot_path (local.get $x)))
    (else
      (i32.const 0))))
```

Conceptual middle step:

```wat
(func $mixed_split_helper (param i32 i32) (result i32)
  (if (result i32)
    (local.get 0)
    (then
      (call $tiny_hot_path (local.get 1)))
    (else
      (i32.const 0))))
```

Conceptual end state:

```wat
;; the split helper may now inline where the original whole function was too mixed
```

Why this matters:

- Binaryen sometimes improves the inline unit first
- partial inlining is a structured split strategy, not “inline half the callee body”

## Shape 11: nested cleanup can unlock late passes like code-folding and merge-blocks

Conceptual story:

1. `inlining-optimizing` erases a helper call
2. the caller now contains duplicated or constant-exposed tail structure
3. the nested rerun lets later function passes clean that up immediately

This is why the saved `-O4z` log shows repeated nested:

- `code-folding`
- `merge-blocks`
- `local-cse`
- `rse`

inside the same top-level inlining interval.

## Good questions to ask when a would-be inline does not happen

- Is the callee imported?
- Is it exported or the start function?
- Does a `ref.func` or table use still keep the boundary alive?
- Does it contain tail calls?
- Is the growth recursive or otherwise too expensive?
- Would a partial-inline split be needed first?
- Are you accidentally expecting a `call_ref` selection that this reviewed release does not actually promise?

Those questions usually explain non-inlines better than “Binaryen missed an obvious opportunity.”
