---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0132-2026-04-20-precompute-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./propagation-partial-precompute-and-gc-identity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `precompute` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `precompute` pass family.

## Read this page with one mental model

Binaryen is usually trying to do one of four things:

1. execute an expression at compile time and replace it with the result
2. preserve the writes that mattered while erasing now-unneeded computation around them
3. push parent computation into `select` arms when that yields simpler constant arms
4. stop when heap identity, traps, synchronization, or emitability make replacement unsafe

The fourth point matters most.

This pass is full of shapes that look constant but are deliberately preserved because:

- the result cannot be emitted as a legal constant
- the expression writes to locals, globals, arrays, or the heap
- control flow would be reordered incorrectly
- atomic ordering would be lost
- the path is only speculative and must not pollute the main heap cache

## Quick glossary

- **concrete value**: a `Flow` result with known literal values
- **emitability**: whether Binaryen can spell that concrete result back into IR
- **fallthrough value**: the value that escapes through wrappers like tees or similar shells
- **identity**: whether two refs are the same allocation, not just equal-looking contents
- **partial precompute**: pushing parent computation into `select` arms separately

## Shape family 1: exact scalar arithmetic

Before:

```wat
(i32.add
  (i32.const 4)
  (i32.const 5))
```

After:

```wat
(i32.const 9)
```

This is the obvious family.

Related positive families:

- integer comparisons
- simple unary folds
- deterministic SIMD shapes such as ordinary `f32x4.max`
- tuple extraction on constant tuple makers

Important warning:

- this is the smallest and least interesting part of the pass.

## Shape family 2: immutable global reads

Before:

```wat
(i32.add
  (i32.const 1)
  (global.get $g))
```

where `$g` is an immutable defined global with constant init.

After:

```wat
(i32.const 2)
```

Important negative family:

```wat
(global.get $g_mut)
```

from a mutable global is not directly folded that way.

And an interesting mixed family remains partly unfolded:

```wat
(i32.sub
  (i32.add (i32.const 1) (global.get $g_mut))
  (i32.add (i32.const 1) (global.get $g_imm)))
```

Binaryen can simplify the immutable side while preserving the mutable one.

## Shape family 3: constant `if` / block flow

Before:

```wat
(if (result i32)
  (i32.const 1)
  (then (i32.const 2))
  (else (i32.const 3)))
```

After:

```wat
(i32.const 2)
```

This family is broader than literal `if`.

Binaryen can also precompute enclosing flow shells like:

- blocks whose only real fallthrough is a known branch value
- loops inside blocks when the overall result is a statically known branch to the outer block

But there is an important limit.

## Negative family: direct loop roots are not generic targets

The walker skips `loop` nodes as direct rewrite roots.

So the important mental model is:

- loops may still simplify when an enclosing `block` becomes precomputable
- but Binaryen does not treat every loop as a first-class standalone constant-fold target

## Shape family 4: tee-preserving constant results

Before:

```wat
(i32.add
  (local.tee $temp
    (i32.const 10))
  (local.get $temp))
```

After:

```wat
(block (result i32)
  (drop
    (local.tee $temp
      (i32.const 10)))
  (i32.const 20))
```

Why the block/drop remains:

- the arithmetic result is known
- but the `local.tee` write still matters and must survive

This is one of the best examples of what the pass really does.

It is not just folding values.
It is folding values **while keeping necessary writes alive**.

## Shape family 5: multiple kept writes

Before:

```wat
(i32.add
  (local.tee $temp (i32.const 10))
  (local.tee $temp (i32.const 20)))
```

After, conceptually:

```wat
(block (result i32)
  (drop (local.tee $temp (i32.const 10)))
  (drop (local.tee $temp (i32.const 20)))
  (i32.const 30))
```

Important lesson:

- Binaryen will preserve **all** needed writes it can identify, not just one lucky child.

## Shape family 6: side-effectful children can block whole-control rewrites

Before:

```wat
(if (result i32)
  (i32.const 1)
  (then
    (block (result i32)
      (global.set $g (i32.const 20))
      (i32.const 2)))
  (else
    (i32.const 3)))
```

Potential naive result:

```wat
(i32.const 2)
```

Actual Binaryen behavior:

- preserve the `if`

Why:

- the pass can see the result value
- but preserving conditionally executed writes through a control structure is more subtle than its simple child-retention model handles here

So this is a **bailout**, not a missed obvious fold.

## Shape family 7: ordering-sensitive `br` / `select` families stay preserved

Before, conceptually:

```wat
(block $out (result i32)
  (select
    (block (result i32) (local.set $x ...) (i32.const 20))
    (block (result i32) (br $out (i32.const 10)) (i32.const 20))
    (block (result i32) (global.set $g ...) (i32.const 40))))
```

A naive transformation might try to turn the whole thing into the known `br $out (i32.const 10)`.

Binaryen refuses.

Why:

- removing the middle arm and appending a final `br` would reorder the `global.set` after control transfer
- the pass does not try to solve that ordering problem here

This is a great negative example for beginners:

- “I know the result” is still not enough when execution order would change.

## Shape family 8: partial precompute through `select`

Before:

```wat
(i32.eqz
  (select
    (i32.const 42)
    (i32.const 1337)
    (local.get $param)))
```

After:

```wat
(select
  (i32.const 0)
  (i32.const 0)
  (local.get $param))
```

What happened:

- Binaryen did not precompute the whole select
- it applied the parent `i32.eqz` separately to the left and right arms

More positive families from the shipped tests:

- binary ops around a select, like `(i32.add (select ...) (i32.const 1))`
- deeper parent stacks where two or more parents together become precomputable on each arm

## Negative family: non-promising arms block partial precompute

Before:

```wat
(i32.eqz
  (select
    (local.get $param)
    (i32.const 0)
    (local.get $param)))
```

After:

- unchanged

Why:

- the left arm is not constant-expression-like enough for the partial-precompute phase

The pass does not try to be clever with every `select`.
It requires both arms to already look promising.

## Shape family 9: immutable struct-field propagation

Before:

```wat
(local.set $ref
  (struct.new $struct-imm
    (i32.const 1)))
(call $helper
  (struct.get $struct-imm 0
    (local.get $ref)))
```

After:

```wat
(local.set $ref
  (struct.new $struct-imm
    (i32.const 1)))
(call $helper
  (i32.const 1))
```

Key positive condition:

- the field is immutable
- the allocation identity is known
- the result is emitably scalar

## Negative family: mutable field blocks the same rewrite

Before:

```wat
(local.set $ref
  (struct.new $struct-mut
    (i32.const 1)))
(call $helper
  (struct.get $struct-mut 0
    (local.get $ref)))
```

After:

- the `struct.get` stays

Why:

- mutability means later writes could change the field contents

## Shape family 10: immutable array slot and `array.len`

Before:

```wat
(local.set $ref
  (array.new_fixed $array-imm 3
    (i32.const 10)
    (i32.const 20)
    (i32.const 30)))
(call $helper
  (array.get $array-imm
    (local.get $ref)
    (i32.const 2)))
(call $helper
  (array.len
    (local.get $ref)))
```

After:

```wat
(call $helper (i32.const 30))
(call $helper (i32.const 3))
```

Important contrast:

- `array.get` only folds here because the array is immutable
- `array.len` is immutable even on mutable arrays, so it has a wider positive surface

## Shape family 11: nested immutable objects

Before, conceptually:

```wat
(local.set $ref
  (struct.new $object
    (struct.new $vtable
      (ref.func $nested-creations))))
(call $helper
  (struct.get $vtable 0
    (struct.get $object 0
      (local.get $ref))))
```

After:

```wat
(call $helper
  (ref.func $nested-creations))
```

Why this matters:

- the pass can reason through multiple immutable nested allocations
- but only when the whole chain ends in an emitably constant result

## Negative family: known-but-non-emittable interior refs

There are cases where Binaryen can tell that an inner `struct.get` reaches a specific object, but still does nothing.

Why:

- the intermediate result is a non-null GC reference that Binaryen cannot re-emit as a legal constant expression

This is a classic “known value but not emitable value” boundary.

## Shape family 12: ref identity comparisons

Before:

```wat
(ref.eq
  (local.tee $tempref
    (struct.new $empty))
  (local.get $tempref))
```

After:

```wat
(block (result i32)
  (drop
    (local.tee $tempref
      (struct.new_default $empty)))
  (i32.const 1))
```

And the unequal case:

```wat
(ref.eq
  (struct.new $empty)
  (struct.new $empty))
```

can become:

```wat
(i32.const 0)
```

Important negative families:

- params with unknown aliasing stay unknown
- locals with multiple possible incoming identities stay unknown
- some “same param on both sides” shapes are deliberately left for other passes like `optimize-instructions`

## Shape family 13: loop-carried ref equality

Positive family:

```wat
(local.set $tempref (struct.new $empty))
(local.set $stashedref (local.get $tempref))
(loop $loop
  (local.set $tempresult
    (ref.eq (local.get $tempref) (local.get $stashedref)))
  (br_if $loop ...))
```

If no new allocation changes `$tempref`, the pass can fold the equality to `1`.

Negative family:

If the loop assigns a fresh `struct.new` to `$tempref` each iteration before the comparison, the equality stays unknown.

This is a good beginner example of why heap identity and flow structure matter together.

## Shape family 14: GC atomic gets respect ordering and sharing

Positive families:

```wat
(struct.get $unshared 0
  (struct.new_default $unshared))
```

and:

```wat
(struct.atomic.get acqrel $unshared 0
  (struct.new_default $unshared))
```

can both fold to `i32.const 0`.

Negative families:

```wat
(struct.atomic.get seqcst $unshared 0 ...)
```

and:

```wat
(struct.atomic.get acqrel $shared 0 ...)
```

stay preserved.

Why:

- seqcst synchronization is observable even if the loaded value is known
- acqrel on shared data may synchronize with other threads

The same rule applies to array-atomic gets.

## Shape family 15: GC RMW / cmpxchg stay preserved

Before:

```wat
(struct.atomic.rmw.xchg acqrel acqrel $struct 0
  (global.get $struct)
  (i64.const 0))
```

After:

- unchanged

Why:

- these operations both read and write heap state
- they are not safe “known-value” expressions for this pass family

## Shape family 16: array multibyte load/store stay preserved in `version_129`

Before:

```wat
(i64.load32_u (type $array)
  (local.get $x)
  (i32.const 0))
```

After:

- unchanged

The same is true for the matching multibyte store.

Important note:

- the existing landing page already records a newer-than-`version_129` upstream drift note about multibyte `array.load`
- but the `version_129` contract for this dossier is: these shapes are still preserved

## Shape family 17: memory init/copy/fill do not precompute here

Before:

```wat
(memory.copy
  (i32.const 512)
  (i32.const 0)
  (i32.const 12))
```

After:

- unchanged

Likewise for:

- `memory.init`
- `memory.fill`
- `data.drop`

So `precompute` is *not* the pass that tries to fold bulk-memory effects away in `version_129`.

## Shape family 18: tuple extraction from constant tuples

Before:

```wat
(tuple.make 2
  (tuple.extract 2 0
    (tuple.make 2
      (i32.const 42)
      (i32.const 0)))
  (tuple.extract 2 1
    (tuple.make 2
      (i64.const 0)
      (i64.const 42))))
```

After:

```wat
(tuple.make 2
  (i32.const 42)
  (i64.const 42))
```

This is a good reminder that the pass can emit multi-value constant results when each lane is emitable.

## Shape family 19: strings can precompute surprisingly far

Positive families from `precompute-strings.wast` include:

- `string.eq`
- `string.concat`
- `string.measure_wtf16`
- `stringview_wtf16.get_codeunit`
- valid-UTF16 `stringview_wtf16.slice`
- `string.new_wtf16_array` when the array allocation is the immediate child and the result can become `string.const`

Example:

```wat
(string.eq
  (string.concat (string.const "a") (string.const "b"))
  (string.const "ab"))
```

can become:

```wat
(i32.const 1)
```

## Negative string families

Important preserved cases:

- `string.encode_wtf16_array`
  - writes into the array, so it must stay
- `string.new_wtf16_array` when the array allocation is not the immediate child
  - current source says TODO rather than optimizing through the indirection
- slices that would create invalid UTF-16 constant material
  - kept as slice ops instead of `string.const`

## Shape family 20: `ref.func` and nested branch values

The `precompute-ref-func.wast` tests show that precompute can collapse nested branch/value shapes down to `ref.func` results.

Important positive family:

```wat
(block $shared (result (ref $shared-func))
  (drop
    (block $func (result (ref $func))
      (br_if $func
        (ref.func $test)
        (br $shared
          (ref.func $test-shared)))))
  (ref.func $test-shared))
```

can reduce to just:

```wat
(ref.func $test-shared)
```

Why this test exists:

- nested `br` values may use different ref heap types
- constant reuse must not accidentally mix them up

## Shape family 21: relaxed SIMD does **not** fold

Before:

```wat
(f32x4.relaxed_max
  (v128.const f32x4 1 2 3 4)
  (v128.const f32x4 5 6 7 8))
```

After:

- unchanged

Why:

- relaxed SIMD carries nondeterminism that this pass deliberately avoids precomputing away

For contrast, ordinary deterministic SIMD ops *can* fold.

## Shape family 22: stack-switching instructions stay preserved

The stack-switching test shows that shapes like these are preserved:

- `cont.new`
- `cont.bind`
- `suspend`
- `resume`
- `resume_throw`
- `switch`

Even when children look simple, this pass family is not the place where Binaryen tries to evaluate those semantics away.

## Negative / bailout families

These are just as important as the positive ones.

## Unemittable non-null GC refs

The pass may know the exact object, but if it cannot emit a constant for that object, direct replacement does not happen.

## Effectful control structures

If preserving child writes would require path-sensitive reordering inside `if` / `try` / similar control flow, the pass often bails instead of guessing.

## Ordering-sensitive branch families

If knowing the final result is not enough to preserve the original execution order of effectful children, Binaryen refuses to optimize.

## Params and ambiguous merges

Unknown params, ambiguous merges, and loop-carried uncertainty stop propagation and identity-based folds.

## Shared synchronization

Atomic seqcst and acqrel-on-shared cases stay preserved even when the data value is obvious.

## Bottom line

Binaryen `precompute` rewrites many more shapes than the name suggests.

The most important pattern families to remember are:

- exact scalar and tuple constant folds
- constant-if / branch-result cleanup
- write-preserving scalar replacements around tees and blocks
- parent-into-`select` partial precompute
- immutable global / struct / array / string positives
- GC identity-based `ref.eq` positives
- atomic-order-sensitive GC negatives
- string encode, bulk memory, relaxed SIMD, and stack-switching non-fold boundaries

And the most important negative rule is:

- a value being *known* is still not enough unless Binaryen can preserve ordering, preserve necessary writes, and re-emit the result legally.
