---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0505-2026-05-06-remove-unused-brs-current-main-recheck.md
  - ../../../raw/research/0146-2026-04-20-remove-unused-brs-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedBrs.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-desc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-exact.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-exact-only.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs-intrinsics.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints-unconditionalize.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_branch-hints-shrink.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_enable-multivalue.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_levels.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_shrink-level=1.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-brs_trap.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ../remove-unused-names/index.md
  - ../merge-blocks/index.md
---

# `remove-unused-brs` WAT and IR shape catalog

This page is the beginner-friendly answer to three questions:

1. what shapes does Binaryen actually rewrite here?
2. what shapes does it intentionally leave alone?
3. what nearby-pass interactions are easiest to miss?

## Reading rule

- The examples below are schematic WAT, not byte-for-byte copies of the lit files.
- They summarize the durable shape families the official `remove-unused-brs*` tests and `RemoveUnusedBrs.cpp` prove.
- “After” means “after RUB's own rewrite,” not necessarily “after the entire surrounding cleanup cluster.”

## Positive shape 1: plain tail `br` to the current block disappears

### Before

```wat
(block $out
  ...
  (br $out)
)
```

### After

```wat
(block $out
  ...
)
```

### Why

The branch already flows to the surrounding continuation.
RUB's main flow-tracking phase records that and removes it.

## Positive shape 2: tail `br` with a carried value becomes just the value

### Before

```wat
(block $out (result i32)
  ...
  (br $out
    (i32.const 7))
)
```

### After

```wat
(block $out (result i32)
  ...
  (i32.const 7)
)
```

### Why

The control transfer is redundant, but the value is still needed.
RUB removes only the jump wrapper.

## Positive shape 3: tail `return` becomes fallthrough

### Before

```wat
(func (result i32)
  ...
  (return
    (i32.const 9)))
```

### After

```wat
(func (result i32)
  ...
  (i32.const 9))
```

### Why

At function tail, `return` is the same continuation the function body already has.

## Positive shape 4: one-arm `if` with a break becomes `br_if`

### Before

```wat
(block $out
  (if
    (local.get $cond)
    (then
      (br $out))))
```

### After

```wat
(block $out
  (br_if $out
    (local.get $cond)))
```

### Why

This is one of RUB's canonical early rewrites.
It is guarded by reorder and effect rules when a branch value is involved.

## Positive shape 5: nested one-arm conditions can fold together

### Before

```wat
(if
  (local.get $a)
  (then
    (if
      (local.get $b)
      (then
        (br $out)))))
```

### After, conceptually

```wat
(br_if $out
  (select
    (local.get $b)
    (local.get $a)
    (i32.const 0)))
```

### Why

RUB can combine the conditions when it is legal to execute the inner condition unconditionally.

### Easy-to-miss boundary

This is blocked by:

- side effects in the inner condition
- too-costly unconditional execution
- `never-unconditionalize`

## Positive shape 6: a final loop-top branch can be pushed behind a condition

### Before

```wat
(loop $loop
  (block $exit
    (br_if $exit
      (local.get $done))
    ...
    (br $loop)))
```

### After, conceptually

```wat
(loop $loop
  (block $exit
    (if
      (local.get $done)
      (then
        (br $exit))
      (else
        ...
        (br $loop))))))
```

### Why

This is the kind of shape `optimizeLoop(...)` prepares so later flow cleanup can delete the now-redundant exit branch more easily.

## Positive shape 7: dense adjacent `br_if eq const` ladders become `br_table`

### Before

```wat
(block $a
  (block $b
    (block $c
      (br_if $a (i32.eq (local.get $x) (i32.const 0)))
      (br_if $b (i32.eq (local.get $x) (i32.const 1)))
      (br_if $c (i32.eq (local.get $x) (i32.const 2))))))
```

### After, conceptually

```wat
(block $tablify|0
  (br_table $a $b $c $tablify|0
    (local.get $x)))
```

### Why

RUB's late `tablify(...)` recognizes a dense run of equality-tested `br_if` on the same effect-safe input value.

### Easy-to-miss boundary

This does **not** fire for arbitrary branch ladders.
It requires:

- eq/eqz shape
- unique constants
- dense-enough range
- no branch values
- a safe shared condition input

## Positive shape 8: block-tail `if br else br` becomes `br_if` plus fallthrough

### Before

```wat
(block $out
  ...
  (if
    (local.get $cond)
    (then
      (br $out))
    (else
      (call $side))))
```

### After, conceptually

```wat
(block $out
  ...
  (br_if $out
    (local.get $cond))
  (call $side))
```

### Why

This is part of RUB's late final optimizer, not just the early one-arm cleanup.

## Positive shape 9: a self-targeted dropped `br_if` can lose a redundant value

### Before

```wat
(block $block (result i32)
  ...
  (drop
    (br_if $block
      (local.get $v)
      (local.get $cond)))
  (local.get $v))
```

### After, conceptually

```wat
(block $block (result i32)
  ...
  (drop
    (local.get $cond))
  (local.get $v))
```

### Why

If the `br_if` targets the current block and the value after it is the same value, RUB can drop the carried value when effect invalidation does not spoil it.

## Positive shape 10: `local.set (if ...)` with a branch arm becomes `br_if` plus later set

### Before

```wat
(local.set $x
  (if (result i32)
    (local.get $cond)
    (then
      (br $out))
    (else
      (i32.const 7))))
```

### After, conceptually

```wat
(br_if $out
  (local.get $cond))
(local.set $x
  (i32.const 7))
```

### Why

This is RUB's late `optimizeSetIfWithBrArm(...)` family.
The branch arm becomes control flow again and the non-branch arm becomes the later set value.

## Positive shape 11: `local.set (if ...)` with a copy arm can lose the copy arm

### Before

```wat
(local.set $x
  (if (result i32)
    (local.get $cond)
    (then
      (call $make))
    (else
      (local.get $x))))
```

### After, conceptually

```wat
(if
  (local.get $cond)
  (then
    (local.set $x
      (call $make))))
```

### Why

If one arm is just `local.get` of the same target local, RUB can remove that copy arm and keep only the real producing arm.

## Positive shape 12: pure two-arm `if` becomes `select`

### Before

```wat
(if (result i32)
  (local.get $cond)
  (then
    (i32.const 1))
  (else
    (i32.const 0)))
```

### After

```wat
(select
  (i32.const 1)
  (i32.const 0)
  (local.get $cond))
```

### Why

This is RUB's `selectify(...)` family.
It runs only when both arms are safe to execute unconditionally and the cost model allows it.

## Positive shape 13: caught `throw` can become `br`

### Before

```wat
(block $catch
  (try_table (catch_all $catch)
    (throw $e)))
```

### After, conceptually

```wat
(block $catch
  (try_table (catch_all $catch)
    (nop)))
```

or, before later cleanup removes it:

```wat
(block $catch
  (try_table (catch_all $catch)
    (br $catch)))
```

### Why

If the `throw` is definitely caught by an enclosing `try_table` catch destination and no `exnref` catch is involved, RUB treats it as control-flow-only branching.

## Positive shape 14: `br_on_null` / `br_on_non_null` can collapse from known ref type

### Before

```wat
(br_on_null $label
  (ref.null any))
```

### After

```wat
(br $label)
```

and

### Before

```wat
(br_on_non_null $label
  (local.get $nnref))
```

### After

```wat
(br $label
  (local.get $nnref))
```

### Why

The GC subpass uses fallthrough-type information to decide whether the null test is already known.

## Positive shape 15: `br_on_cast*` can simplify to `br`, fallthrough value, `br_on_non_null`, or `unreachable`

### Before

```wat
(br_on_cast $label anyref (ref $sub)
  (local.get $ref))
```

### Possible after shapes

```wat
(br $label
  (local.get $ref))
```

```wat
(local.get $ref)
```

```wat
(block (result nullref)
  (br_on_non_null $label ...)
  (ref.null none))
```

```wat
(unreachable)
```

### Why

The GC subpass reasons about known cast outcomes and about whether it must insert or preserve casts to keep the surrounding type story valid.

## Negative shape 1: multivalue selects do not appear in the early `if -> br_if` family

### Before

```wat
(if
  (local.get $cond)
  (then
    (br_if $out
      (call $multi)
      (local.get $other))))
```

### After

```wat
;; kept conservative
```

### Why

That early path explicitly avoids building multivalue select machinery there.

## Negative shape 2: effectful or reorder-unsafe values block `restructureIf`

### Before

```wat
(block $x (result i32)
  (drop
    (br_if $x
      (call $effectful)
      (local.get $cond)))
  (i32.const 7))
```

### After

```wat
;; kept conservative, or only partly simplified
```

### Why

If the branch value must always execute, or the condition cannot move safely around the value/body, RUB refuses the prettier rewrite.

## Negative shape 3: `never-unconditionalize` blocks some `select`-style rewrites

### Before

```wat
(if (result i32)
  (local.get $x)
  (then
    (i32.const 1))
  (else
    (@metadata.code.branch_hint "\01")
    (call $maybe_costly)))
```

### After with `--pass-arg=remove-unused-brs-never-unconditionalize`

```wat
;; stays as branching structure instead of becoming selectified
```

### Why

This flag exists so RUB does not start executing code that previously might not have run, especially in branch-hint fuzzing scenarios. For Starshine-local fixture planning, `@metadata.code.branch_hint` is Core/Binaryen code-metadata evidence, not current Starshine WAST expression-annotation support; route local parser/lowerer claims through [`../../../wast/code-metadata-and-function-annotations.md`](../../../wast/code-metadata-and-function-annotations.md).

## Negative shape 4: caught throws with `exnref` stay throws

### Before

```wat
(block $catch (result exnref)
  (try_table (catch_ref $e $catch)
    (throw $e)))
```

### After

```wat
;; kept as throw-based control
```

### Why

RUB only converts caught throws to branches when no `exnref` catch transport is involved.

## Negative shape 5: mixed `Try` and `TryTable` control is left alone in `visitThrow`

### Before

```wat
(try_table (catch_all $c)
  (try
    (do
      (throw $e))
    (catch_all
      ...)))
```

### After

```wat
;; kept conservative
```

### Why

The source explicitly declines to reason through mixed old/new EH handling in that optimization.

## Negative shape 6: sparse or overlapping branch ladders do not `tablify`

### Before

```wat
(br_if $a (i32.eq (local.get $x) (i32.const 0)))
(br_if $b (i32.eq (local.get $x) (i32.const 99)))
```

### After

```wat
;; stays as separate br_if chain
```

### Why

RUB only builds `br_table` when the range is dense enough and the constants do not overlap.

## Negative shape 7: version_129 jump-threading keeps a same-type guard on one-child block redirects

### Before

```wat
(block $outer (result i32)
  (block $inner (result none)
    ...))
```

### After in `version_129`

```wat
;; no redirect through this one-child shell
```

### Why

In `version_129`, `JumpThreader` keeps the parent/child type-equality guard before redirecting branches from the parent to the child.
Current `main` removed that check, so this is also a current-main drift boundary.

## Nearby-pass interactions that are easy to miss

### `remove-unused-names`

RUB often creates or exposes dead label structure that `remove-unused-names` cleans afterward.
That is why late `remove-unused-names` sits immediately after late RUB.

### `merge-blocks`

`merge-blocks` makes late RUB more effective, and a second `merge-blocks` then cleans up new blocks late RUB created.
So if a shape seems “almost mergeable,” the correct fix may belong to scheduler fidelity, not to widening RUB.

### `dead-code-elimination` and `vacuum`

RUB deliberately leaves some unreachable or dead-wrapper families to the dedicated cleanup passes.
Not every “ugly after” shape is a RUB bug.

## Practical reading rule

When you inspect a new RUB mismatch, ask these in order:

1. is the branch actually redundant fallthrough?
2. is this a loop/block preparation family?
3. is this a late `tablify` / `restructureIf` / `selectify` / `optimizeSetIf` family?
4. is this an EH or GC branch shape?
5. or is this really another pass or a local HOT/lower/writeback issue?

That reading order matches the real upstream pass much better than the short public pass name does.
