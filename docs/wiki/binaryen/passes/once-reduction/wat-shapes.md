---
kind: concept
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md
  - ../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md
  - ../../../raw/research/0202-2026-04-21-once-reduction-implementation-followup.md
  - ../../../raw/research/0256-2026-04-22-once-reduction-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0701-2026-06-03-once-reduction-o4z-audit.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./dominance-propagation-and-cycle-safety.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `once-reduction` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `once-reduction` pass.

## Read this page with one mental model

Binaryen `once-reduction` is trying to prove:

- this global is really acting like a private once-bit,
- this function really is guarded by that once-bit in the exact shape the pass knows,
- this later direct call or later write is reached on a path where that bit is already definitely nonzero,
- and removing the work will not change observable side-effect order.

If that proof fails, the pass keeps the code.

## Quick glossary

- **once global / once-bit**: the integer global used only to guard a run-once function
- **once function**: a no-param/no-result function whose body starts with the recognized once pattern
- **fake once global**: an upstream-only synthetic key used for `@binaryen.idempotent` functions
- **dominated call**: a later call reached only after a previous call or write already proved the once-bit set
- **wrapper cleanup**: final pass step that strips trivial once scaffolding from very small once bodies

## Positive family 1: the classic once pattern

Before:

```wat
(global $once (mut i32) (i32.const 0))
(func $once_fn
  (if (global.get $once)
    (then (return)))
  (global.set $once (i32.const 1))
  (call $payload))
(func $run
  (call $once_fn)
  (call $once_fn))
```

After, conceptually:

```wat
(func $run
  (call $once_fn)
  (nop))
```

Why this is safe:

- the first call sets `$once`
- the second call would immediately hit the guard and do nothing
- no params or results need to be preserved

## Positive family 2: repeated calls in the same dominated region

Before:

```wat
(if (i32.const 1)
  (then
    (call $once_fn)
    (call $once_fn)
    (call $once_fn)))
```

After, conceptually:

```wat
(if (i32.const 1)
  (then
    (call $once_fn)
    (nop)
    (nop)))
```

The key point is:

- inside one dominated straight-line region, a first call can prove later identical direct calls redundant

## Positive family 3: unconditional loop-body call can prove later loop-body and post-loop calls redundant

Before:

```wat
(loop $loop
  (call $once_fn)
  (call $once_fn)
  (br_if $loop (i32.const 1)))
(call $once_fn)
(call $once_fn)
```

After, conceptually:

```wat
(loop $loop
  (call $once_fn)
  (nop)
  (br_if $loop (i32.const 1)))
(nop)
(nop)
```

Why this is a positive case:

- the loop body definitely executes that first direct call before the later same-path calls
- Binaryen can use that dominated fact

## Positive family 4: nonzero initializer is still okay

Before:

```wat
(global $once (mut i32) (i32.const 42))
(func $once_fn
  (if (global.get $once)
    (then (return)))
  (global.set $once (i32.const 1))
  (call $payload))
(func $run
  (call $once_fn)
  (call $once_fn))
```

After, conceptually:

```wat
(func $run
  (call $once_fn)
  (nop))
```

This is one of the easiest surprises in the official lit file.
The actual implementation does not require the initializer to be zero.
It only requires the later write behavior and read behavior to fit the pass's monotonic once-bit model.

## Positive family 5: nonzero later writes elsewhere are still okay

Before:

```wat
(global $once (mut i32) (i32.const 0))
(func $once_fn
  (if (global.get $once)
    (then (return)))
  (global.set $once (i32.const 42)))
(func $run
  (call $once_fn)
  (call $once_fn)
  (global.set $once (i32.const 1337)))
```

After, conceptually:

```wat
(func $run
  (call $once_fn)
  (nop)
  (nop))
```

Why this matters:

- the exact nonzero value does not matter here
- what matters is that the once-bit never goes back to zero and is not written with an unknown expression

## Positive family 6: straight-line call-chain propagation

Before:

```wat
(func $once_fn ...)
(func $D
  (call $once_fn)
  (call $once_fn))
(func $C (call $D))
(func $B (call $C))
(func $A
  (call $B)
  (call $once_fn))
```

After, conceptually:

```wat
(func $D
  (call $once_fn)
  (nop))
(func $A
  (call $B)
  (nop))
```

Why this works:

- Binaryen iterates to a fixed point over direct-call summaries
- straight-line callees can teach callers which once-bits are definitely set

## Positive family 7: empty once body becomes `nop`

Before:

```wat
(func $once_fn
  (if (global.get $once)
    (then (return)))
  (global.set $once (i32.const 1)))
```

After, conceptually:

```wat
(func $once_fn
  (nop))
```

This is the simplest final body-cleanup case.
There is no payload left to protect once the guard/set scaffold becomes provably unobservable.

## Positive family 8: trivial once wrapper around another once function

Before:

```wat
(func $outer_once
  (if (global.get $outer)
    (then (return)))
  (global.set $outer (i32.const 1))
  (call $inner_once))
```

After, conceptually:

```wat
(func $outer_once
  (call $inner_once))
```

Why this is safe:

- one once guard is enough when the entire payload is just another once call

Why this is narrow:

- if any code appeared after `call $inner_once`, Binaryen would keep the outer guard

## Positive family 9: self-recursive once function

Before:

```wat
(func $once_fn
  (if (global.get $once)
    (then (return)))
  (global.set $once (i32.const 1))
  (call $once_fn))
```

After, conceptually:

```wat
(func $once_fn
  (if (global.get $once)
    (then (return)))
  (global.set $once (i32.const 1))
  (nop))
```

Why this works:

- the recursive call sees the same once-bit already set
- so the recursive call itself is redundant

## Positive family 10: defined idempotent direct-call case

Conceptually, upstream Binaryen also treats this as once-like:

```wat
(@binaryen.idempotent)
(func $idemp)
(func $run
  (call $idemp)
  (call $idemp))
```

After, conceptually:

```wat
(func $run
  (call $idemp)
  (nop))
```

Important note:

- this is part of the official Binaryen source surface
- as of the 2026-06-03 O4z audit, Starshine models this for defined no-param/no-result functions
- imported idempotent calls remain a conservative local boundary

## Positive family 11: try/catch control containers do not block the CFG proof by themselves

Conceptually, the official lit file also checks that once-facts can still be emitted in a stable reverse-postorder walk when they appear inside EH-shaped control:

```wat
(try
  (do
    (call $once_fn)
    ...)
  (catch_all
    ...))
```

Why this matters:

- `once-reduction` is not just a straight-line expression peephole
- the CFG walker still has to serialize relevant `Call` / `GlobalSet` facts through more complicated control containers without tripping its assertions
- this lit family is mainly about keeping the pass's block-order reasoning honest, not about adding special EH-only optimization powers

## Negative family 1: code before the guard

Before:

```wat
(func $once_fn
  (nop)
  (if (global.get $once)
    (then (return)))
  (global.set $once (i32.const 1)))
```

Why this blocks optimization:

- the function no longer matches the exact recognized once shape
- Binaryen intentionally does not generalize this into “close enough”

## Negative family 2: code between the guard and the set

Before:

```wat
(func $once_fn
  (if (global.get $once)
    (then (return)))
  (nop)
  (global.set $once (i32.const 1)))
```

Why this blocks optimization:

- the exact shape matcher expects the set immediately after the guard

## Negative family 3: `else` arm present

Before:

```wat
(func $once_fn
  (if (global.get $once)
    (then (return))
    (else (call $side_effect)))
  (global.set $once (i32.const 1)))
```

Why this blocks optimization:

- the recognized form is a bare early-exit guard, not a general conditional wrapper

## Negative family 4: different globals in the `get` and `set`

Before:

```wat
(func $once_fn
  (if (global.get $once1)
    (then (return)))
  (global.set $once2 (i32.const 1)))
```

Why this blocks optimization:

- the pass needs one specific bit whose meaning is “this function has already run”
- mixing two globals breaks that model

## Negative family 5: zero writes kill once-ness

Before:

```wat
(func $once_fn
  (if (global.get $once)
    (then (return)))
  (global.set $once (i32.const 0)))
```

Why this blocks optimization:

- writing zero means the bit can return to “not yet run”
- that destroys the monotonic once-bit proof

## Negative family 6: nonconstant writes also kill once-ness

Before:

```wat
(func $once_fn
  (if (global.get $once)
    (then (return)))
  (global.set $once (i32.eqz (i32.eqz (i32.const 1)))))
```

Why this blocks optimization:

- even if the expression seems to evaluate to nonzero, the pass does not symbolically prove that here
- it only accepts direct positive integer constants

## Negative family 7: extra reads of the once global

Before:

```wat
(func $run
  (call $once_fn)
  (call $once_fn)
  (drop (global.get $once)))
```

or:

```wat
(func $once_fn
  (if (global.get $once)
    (then (return)))
  (global.set $once (i32.const 1))
  (drop (global.get $once)))
```

Why this blocks optimization:

- the once-bit is no longer just a guard
- other code is observing it directly

## Negative family 8: imported or exported mutable globals

Before:

```wat
(import "env" "glob" (global $once (mut i32)))
```

or:

```wat
(global $once (mut i32) (i32.const 0))
(export "once-global" (global $once))
```

Why this blocks optimization:

- outside code may read or write the bit in ways the pass cannot see

## Negative family 9: non-integer globals

Before:

```wat
(global $once (mut f64) (f64.const 0))
```

Why this blocks optimization:

- this pass only models integer once-bits
- the official lit file keeps the repeated calls unchanged here

## Negative family 10: params or results on the once function

Before:

```wat
(func $once_fn (param i32) ...)
```

or:

```wat
(func $once_fn (result i32) ...)
```

Why this blocks optimization:

- Binaryen does not yet have the extra machinery needed to prove equal arguments or to reuse a cached result value here
- so it keeps the calls

## Negative family 11: body root is not a plain block or is too short

Before:

```wat
(func $once_fn
  (loop $loop
    (if (global.get $once)
      (then (return)))
    (global.set $once (i32.const 1))))
```

or:

```wat
(func $once_fn
  (if (global.get $once)
    (then (return))))
```

Why these block optimization:

- the shape matcher wants a normal top-level block with enough structure to prove the pattern exactly

## Negative family 12: after-merge call may stay live

Before:

```wat
(if (local.get $cond)
  (then (call $once_fn))
  (else (call $once_fn)))
(call $once_fn)
```

Why the post-`if` call can stay:

- current Binaryen does not do full all-predecessor merge intersection here
- the pass is dominance-driven and intentionally conservative at merges

## Negative family 13: conditional loop call does not prove the post-loop call

Before:

```wat
(loop $loop
  (if (local.get $cond)
    (then (call $once_fn)))
  (br_if $loop (local.get $again)))
(call $once_fn)
(call $once_fn))
```

After, conceptually:

```wat
(loop $loop
  (if (local.get $cond)
    (then (call $once_fn)))
  (br_if $loop (local.get $again)))
(call $once_fn)
(nop))
```

Why only the last call dies:

- the first post-loop call is not proven redundant
- the second post-loop call is redundant because the first post-loop call now dominates it

## Negative family 14: dangerous triple-loop ordering case

Conceptually:

```wat
(func $once   ... (call $once.1) (call $once.2) (call $import ...))
(func $once.1 ... (call $once)   (call $once.2) (call $import ...))
(func $once.2 ... (call $once)   (call $once.1) (call $import ...))
```

Why Binaryen keeps some seemingly redundant calls:

- a once-bit being set only proves that function has been entered
- it does not prove the later imported side effects in the callee's payload have already happened before now
- removing those calls could reorder observable imports

This is the most important “sounds safe but is not” family in the official file.

## Negative family 15: wrapper cleanup does not remove every guard in a cycle

Before, conceptually:

```wat
(func $A_once ... (call $B_once))
(func $B_once ... (call $A_once))
```

Why Binaryen is careful:

- if it removed both wrappers' guards, the pair could become an infinite loop
- so the final wrapper-cleanup step keeps one side guarded when needed

## What this pass does **not** mean

These are useful non-goals to keep explicit:

- generic effect-based repeated-call elimination
- full indirect-call reasoning
- general merge-point dataflow intersection
- support for argument equality or result reuse
- proof that entering a once function means all its once-callees have fully completed
- deletion of every apparently redundant once wrapper in a call cycle

## Scheduler interaction to remember

`once-reduction` is intentionally early and module-scoped.
It sits between `memory-packing` and `global-refining`, and it is not part of the late optimize-after-inlining rerun helper.

Its job is not to solve every repeated-call optimization story.
Its job is to clean up a narrow family of run-once control scaffolding early enough that later module and function passes see a smaller, simpler module.

## Freshness note

The 2026-04-22 raw primary-source capture rechecked the official `version_129` release page plus the current `main` `OnceReduction.cpp` and dedicated `once-reduction.wast` file, and did not surface a new teaching-relevant drift in the positive or bailout shape families summarized here.
