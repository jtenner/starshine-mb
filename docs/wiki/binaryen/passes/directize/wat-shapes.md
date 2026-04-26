---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md
  - ../../../raw/research/0380-2026-04-26-directize-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-directize-current-main-recheck.md
  - ../../../raw/research/0350-2026-04-25-directize-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-directize-primary-sources.md
  - ../../../raw/research/0126-2026-04-20-directize-binaryen-research.md
  - ../../../raw/research/0265-2026-04-22-directize-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./table-info-and-immutability.md
  - ./starshine-port-readiness-and-validation.md
---

# `directize` WAT shapes

The reviewed official Binaryen `version_129` release page observed on 2026-04-22 showed publish date **2026-04-01**.
A focused 2026-04-25 current-`main` source bridge now confirms no teaching-relevant shape drift in `Directize.cpp`, `call-utils.h`, `table-utils.{h,cpp}`, or the dedicated `directize*` lit files.
The 2026-04-26 Starshine port-readiness bridge maps these shapes into the local validation ladder in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

This page is the beginner-friendly shape catalog for Binaryen’s `directize` pass.

## Read this page with one mental model

Binaryen is trying to answer:

- “what does this table index definitely mean?”

Only after it has a good answer does it rewrite the call.

That means the interesting outputs are not just:

- direct call

They are:

- direct call
- `unreachable`
- or unchanged indirect call

## Quick glossary

- **known target**: Binaryen knows the constant index names one exact function of a compatible type
- **known trap**: Binaryen knows the indirect call must fail
- **unknown target**: Binaryen still cannot prove what the call does
- **immutable mode**: `--pass-arg=directize-initial-contents-immutable`
- **known prefix**: the flattened table entries Binaryen could materialize safely from constant-offset function segments

## Shape 1: simple constant index to direct call

Before:

```wat
(module
  (type $ii (func (param i32 i32)))
  (table 5 5 funcref)
  (elem (i32.const 1) $foo)
  (func $foo (param i32 i32)
    unreachable)
  (func (param $x i32) (param $y i32)
    (call_indirect (type $ii)
      (local.get $x)
      (local.get $y)
      (i32.const 1))))
```

After, conceptually:

```wat
(func (param $x i32) (param $y i32)
  (call $foo
    (local.get $x)
    (local.get $y)))
```

Why it rewrites:

- the table is flat enough to inspect
- slot `1` is known to hold `$foo`
- `$foo` has a compatible type

## Shape 2: `return_call_indirect` becomes `return_call`

Before:

```wat
(return_call_indirect (type $ii)
  (local.get $x)
  (local.get $y)
  (i32.const 1))
```

After:

```wat
(return_call $foo
  (local.get $x)
  (local.get $y))
```

Why it rewrites:

- Binaryen keeps the original tail-call intent via the `isReturn` bit
- the pass is not limited to non-tail indirect calls

## Shape 3: known bad constant target becomes `unreachable`

Before:

```wat
(call_indirect (type $ii)
  (local.get $x)
  (local.tee $y
    (local.get $y))
  (i32.const 5))
```

After, conceptually:

```wat
(drop
  (local.tee $y
    (local.get $y)))
(unreachable)
```

Why it rewrites:

- Binaryen can prove the target is invalid
- but it still preserves argument side effects before trapping

This is one of the most important beginner shapes in the pass.

## Shape 4: wrong-type target also becomes `unreachable`

Before:

```wat
(module
  (type $ii (func (param i32 i32)))
  (table 5 5 funcref)
  (elem (i32.const 1) $foo)
  (func $foo (param i32)
    unreachable)
  (func (param $x i32) (param $y i32)
    (call_indirect (type $ii)
      (local.get $x)
      (local.get $y)
      (i32.const 1))))
```

After, conceptually:

```wat
(func (param $x i32) (param $y i32)
  unreachable)
```

Why:

- the slot is known
- but the known callee type is not a subtype of the required indirect-call type
- so this is a known trap, not a known direct call

## Shape 5: unknown nonconstant index stays indirect

Before:

```wat
(call_indirect (type $ii)
  (local.get $x)
  (local.get $y)
  (local.get $z))
```

After stays the same.

Why it does **not** rewrite:

- `directize` in `version_129` does not do broad value analysis here
- ordinary nonconstant index expressions are just `Unknown`

## Shape 6: `select` between two known constants becomes an `if`

Before:

```wat
(call_indirect (type $ii)
  (local.get $x)
  (local.get $y)
  (select
    (i32.const 1)
    (i32.const 2)
    (local.get $z)))
```

After, conceptually:

```wat
(block
  (local.set $tmp0 (local.get $x))
  (local.set $tmp1 (local.get $y))
  (if
    (local.get $z)
    (then
      (call $foo1
        (local.get $tmp0)
        (local.get $tmp1)))
    (else
      (call $foo2
        (local.get $tmp0)
        (local.get $tmp1)))))
```

Why it rewrites:

- both select arms are understood
- Binaryen stores the operands once in locals
- then emits an `if`, not two duplicated operand trees

## Shape 7: `select` with a trap arm becomes `if` with `unreachable`

Before:

```wat
(call_indirect (type $ii)
  (local.get $x)
  (local.get $y)
  (select
    (i32.const 99999)
    (i32.const 2)
    (local.get $z)))
```

After, conceptually:

```wat
(block
  (local.set $tmp0 (local.get $x))
  (local.set $tmp1 (local.get $y))
  (if
    (local.get $z)
    (then
      unreachable)
    (else
      (call $foo2
        (local.get $tmp0)
        (local.get $tmp1)))))
```

Why it rewrites:

- one arm is a known trap
- the other arm is a known direct target
- Binaryen is willing to encode both outcomes explicitly

## Shape 8: `select` with an unknown arm stays indirect

Before:

```wat
(call_indirect (type $ii)
  (local.get $x)
  (local.get $y)
  (select
    (local.get $z)
    (i32.const 2)
    (local.get $z)))
```

After stays the same.

Why it does **not** rewrite:

- one arm is still `Unknown`
- current Binaryen does not lower “one known arm, one unknown arm” into a partial directized form here

## Shape 9: unreachable select condition or operand disables the optimization

Before:

```wat
(call_indirect (type $ii)
  (local.get $x)
  (local.get $y)
  (select
    (i32.const 1)
    (i32.const 2)
    unreachable))
```

After stays the same.

Why:

- `call-utils.h` deliberately gives up if the select type is already unreachable or if an operand is unreachable
- Binaryen leaves these for other cleanup passes instead of forcing a directize rewrite

## Shape 10: imported table is unchanged in ordinary mode

Before:

```wat
(module
  (type $ii (func (param i32 i32)))
  (import "env" "table" (table $table 5 5 funcref))
  (elem (i32.const 1) $foo)
  (func $foo (param i32 i32)
    unreachable)
  (func (param $x i32) (param $y i32)
    (call_indirect (type $ii)
      (local.get $x)
      (local.get $y)
      (i32.const 1))))
```

After in ordinary mode stays indirect.

Why:

- imported tables are treated as modifiable
- without the immutable-mode promise, Binaryen does not trust the observed initial entry enough

## Shape 11: same imported table can directize in immutable mode

Using the same module with `--pass-arg=directize-initial-contents-immutable`, Binaryen can rewrite the same call to:

```wat
(call $foo ...)
```

Why:

- immutable mode says the initial known entries are not overwritten
- Binaryen can then trust slot `1`

This is the single most important positive shape for the pass arg.

## Shape 12: hole inside the known prefix becomes `unreachable`

Conceptually, if the known flattened prefix looks like:

```text
index: 0 1 2 3
value: - A - B
```

then a call through constant index `0` or `2` can become:

```wat
unreachable
```

Why:

- those are known null slots inside the known prefix
- Binaryen treats them as definite traps

## Shape 13: beyond-known-prefix constant can still stay indirect

Using the same conceptual table as above, a later constant index like `4` may stay as:

```wat
(call_indirect ... (i32.const 4))
```

Why:

- `4` is beyond the known flattened prefix
- on a mutable/imported table, later growth might make that slot valid
- so the answer is `Unknown`, not `Trap`

This is one of the easiest directize corner cases to get wrong.

## Shape 14: `table.set` / `fill` / `init` block ordinary mode

Before:

```wat
(func $fill
  (table.fill $table
    (i32.const 0)
    (ref.func $funcB)
    (i32.const 1)))

(func $call
  (drop
    (call_indirect (type $i32)
      (i32.const 0))))
```

After in ordinary mode stays indirect.

Why:

- Binaryen sees runtime mutation potential
- so it refuses to trust entry `0` in normal mode

In immutable mode, the same call may still directize if the initial slot is known and the mutation promise says those initial contents are not overwritten.

## Shape 15: nonconstant segment offset disables table flattening

Before:

```wat
(global $g (import "env" "g") i32)
(table 5 5 funcref)
(elem (global.get $g) $foo)
```

A constant `call_indirect` elsewhere against that table can stay unchanged.

Why:

- the table is no longer flat in the cheap way `directize` wants
- the pass does not try a stronger proof

## Shape 16: weird element layout can cause conservative no-op

Examples like these stay indirect:

```wat
(table 10 10 funcref)
(elem (i32.const -1) $0)
(call_indirect (type $v)
  (i32.const -1))
```

or:

```wat
(table 10 10 funcref)
(elem (i32.const 9) $0 $0)
(call_indirect (type $v)
  (i32.const 9))
```

Why:

- flat-table construction rejects the suspicious layout
- Binaryen prefers a conservative no-op over inventing a stronger entry-level answer

## Shape 17: wasm64 indices are handled at full width

Before:

```wat
(table i64 5 5 funcref)
(elem (i64.const 1) $foo)
(call_indirect (type $ii)
  (local.get $x)
  (local.get $y)
  (i64.const 4294967297))
```

After becomes:

```wat
unreachable
```

not:

```wat
(call $foo ...)
```

Why:

- Binaryen reads the full unsigned value
- it does not accidentally truncate to 32 bits and think the target is `1`

## Shape 18: GC subtype-compatible target directizes

Before:

```wat
(rec
  (type $super (sub (func)))
  (type $sub (sub final $super (func))))
(table 93 funcref)
(elem (i32.const 0) $target)
(func $caller
  (call_indirect (type $super)
    (i32.const 0)))
(func $target (type $sub))
```

After:

```wat
(func $caller
  (call $target))
```

Why:

- the target type is a subtype of the required indirect-call type
- exact-name equality is not required

## Shape 19: reversed GC subtype direction traps

Before:

```wat
(call_indirect (type $sub)
  (i32.const 0))
```

when the known target has type `$super`.

After:

```wat
unreachable
```

Why:

- this is not subtype-compatible in the needed direction
- Binaryen treats it as a known trap, not a known call

## Shape 20: directization can refine the visible result type

A GC test also shows a call site that originally uses a supertype result can directize to a callee with a more refined subtype result.

The key lesson is not the exact WAT text.
The key lesson is:

- the directized call may change surrounding IR typing expectations
- which is why `ReFinalize()` is part of the real pass contract

## What this pass deliberately does not do

- It does not optimize `call_ref` in `version_129`.
- It does not solve arbitrary symbolic or arithmetic target expressions.
- It does not duplicate operand trees freely; it stores them in locals for the supported `select` case.
- It does not assume imported/exported tables are safe by default.
- It does not treat every suspicious table-layout case as a proved trap.
- It does not widen one-known-one-unknown `select` cases into a partial rewrite.

The 2026-04-25 current-main recheck and the 2026-04-26 port-readiness bridge did not change those non-goals. If you see those behaviors, you are probably looking at a different Binaryen helper or at a later upstream evolution, not this exact `version_129` pass.

## Sources

- [`../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md)
- [`../../../raw/research/0380-2026-04-26-directize-port-readiness.md`](../../../raw/research/0380-2026-04-26-directize-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-directize-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-directize-current-main-recheck.md)
- [`../../../raw/research/0350-2026-04-25-directize-current-main-recheck.md`](../../../raw/research/0350-2026-04-25-directize-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-directize-primary-sources.md`](../../../raw/binaryen/2026-04-22-directize-primary-sources.md)
- [`../../../raw/research/0126-2026-04-20-directize-binaryen-research.md`](../../../raw/research/0126-2026-04-20-directize-binaryen-research.md)
- [`../../../raw/research/0265-2026-04-22-directize-primary-sources-and-starshine-followup.md`](../../../raw/research/0265-2026-04-22-directize-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast>
