---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./variant-surface.md
  - ../flatten/index.md
  - ../local-cse/index.md
---

# `simplify-locals-notee-nostructure` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen’s `simplify-locals-notee-nostructure` pass.

## Read this page with one mental model

Binaryen is trying to remove the **easy temp-local traffic** that `flatten` and other earlier rewrites create,

- without inventing tees
- without inventing new block / `if` / loop result values
- but still with ordinary direct one-use sinking and late cleanup enabled

That is why many examples below are about:

- single-use direct sinks
- preserved multi-use locals
- preserved structured carrier shapes
- dead-overwrite cleanup
- late equivalent-`get` canonicalization
- explicit bailout families

## Quick glossary

- **sink**: replace a later `local.get` with the value from an earlier `local.set`
- **origin set**: the old `local.set` site that becomes `nop`
- **multi-use local**: a local whose value is read more than once in the current counting pass
- **structure rewrite**: turning arm-local / block-local sets into a new control-flow result value
- **equivalent get**: a `local.get` that can be redirected to another local known to carry the same value

## Shape 1: a multi-use local stays as explicit local traffic

Before:

```wat
(local.set $x
  (i32.const 1))
(if
  (local.get $x)
  (then (nop)))
(if
  (local.get $x)
  (then (nop)))
```

After `simplify-locals-notee-nostructure`:

```wat
(local.set $x
  (i32.const 1))
(if
  (local.get $x)
  (then (nop)))
(if
  (local.get $x)
  (then (nop)))
```

Why it stays the same:

- the local has multiple uses
- this variant does not create a `local.tee`
- so the set never becomes sinkable for the multi-use path

This is the most visible direct test-backed shape in the pass.

## Shape 2: a single-use local can still sink into an existing consumer

Conceptual before:

```wat
(local.set $tmp
  (i32.add
    (local.get $a)
    (i32.const 1)))
(drop
  (local.get $tmp))
```

Conceptual after:

```wat
(nop)
(drop
  (i32.add
    (local.get $a)
    (i32.const 1)))
```

Why it rewrites:

- the local has one real use
- teeing is not needed
- the consumer already exists
- no new structure had to be invented

Important note:

- this is a source-backed inference from the shared `SimplifyLocals.cpp` engine and the sibling simplify-locals tests
- the dedicated `notee-nostructure` golden focuses on the multi-use contrast, not every one-use sink family

## Shape 3: existing value-producing children can still sink directly

The sibling simplify-locals tests show ordinary one-use sink families like:

```wat
(local.set $y
  (if (result i32)
    (i32.const 2)
    (then (i32.const 3))
    (else (i32.const 4))))
(drop
  (local.get $y))
```

For this variant, the shared source implies the same direct sink path is still available because:

- `allowNesting = true`
- the sink is one-use
- no tee or new structure is required

So the important mental model is:

- “no structure” blocks *creating new result structure*
- it does **not** block sinking into an existing result-producing child

## Shape 4: structured local-carrier families are preserved

Before:

```wat
(if (i32.const 6)
  (then
    (local.set $a (i32.const 7)))
  (else
    (local.set $a (i32.const 8))))
(drop (local.get $a))
```

After `simplify-locals-notee-nostructure` the important part stays structured:

```wat
(if
  (i32.const 6)
  (then
    (local.set $a
      (i32.const 7)))
  (else
    (local.set $a
      (i32.const 8))))
(drop
  (local.get $a))
```

Why it stays that way:

- converting it into one outer `drop(if (result i32) ...)` requires a structure rewrite
- `allowStructure = false`

So the pass deliberately leaves that cleanup for later phases.

## Shape 5: block / branch carrier locals are also preserved

Before:

```wat
(block $val
  (if (i32.const 10)
    (then
      (block
        (local.set $b (i32.const 11))
        (br $val))))
  (local.set $b (i32.const 12)))
(drop (local.get $b))
```

After `simplify-locals-notee-nostructure` the important part stays the same shape.

Why it stays that way:

- turning this into a block return value would use `optimizeBlockReturn(...)`
- that helper is disabled in this variant

## Shape 6: overwritten pending sets become dead

Conceptual before:

```wat
(local.set $x
  (call $compute_a))
(local.set $x
  (call $compute_b))
(drop
  (local.get $x))
```

Conceptual after:

```wat
(drop
  (call $compute_a))
(nop)
(drop
  (call $compute_b))
```

What matters here:

- the first write to `$x` is overwritten before any real read
- Binaryen preserves the first value’s side effects as `drop(...)`
- then it continues with the newer write as the meaningful one

This is why the pass is more than a set/get peephole.

## Shape 7: global-effect barriers stop dangerous trap motion

A sibling simplify-locals test shows the key hazard family:

```wat
(local.set $var$0
  (i32.trunc_f64_u
    (f64.const -nan:0xfffffffffffc3)))
(f32.store align=1
  (i32.const 22)
  (f32.const 154))
(drop
  (local.get $var$0))
```

Why Binaryen keeps the important order:

- the truncation may trap
- the store mutates global state
- changing the order would change observable behavior

That barrier still applies in `notee-nostructure` because it comes from the shared `EffectAnalyzer` invalidation logic.

## Shape 8: local-only noise can still allow safe motion

The sibling tests also show the opposite pattern:

```wat
(local.set $var$0
  (i32.trunc_f64_u
    (f64.const -nan:0xfffffffffffc3)))
(local.set $other
  (i32.const 100))
(drop
  (local.get $var$0))
```

Why motion may still be allowed here:

- the extra write is only local traffic
- later cleanup may erase it anyway
- the same global-observable hazard does not exist as with memory or mutable-global writes

This is another shared-source inference that matters for a future port.

## Shape 9: `try` / `try_table` is a hard barrier for throwing values

Conceptual before:

```wat
(local.set $x
  (call $might_throw))
(try
  (do
    (drop
      (local.get $x)))
  (catch_all
    ...))
```

Why Binaryen refuses to sink `$x` into the `try` body:

- moving the call would change where its throw could be caught
- `visitPre(...)` explicitly forgets pending sinkables whose values may throw when entering `try` / `try_table`

So this is not just a generic “effectful code is scary” rule.
It is a dedicated exception-handling safety check.

## Shape 10: late equivalent-`get` canonicalization still happens

Conceptual before:

```wat
(local.set $b
  (local.get $a))
(i32.store
  (local.get $b)
  (i32.const 1))
(f32.load
  (local.get $b))
```

Conceptual later cleanup effect:

```wat
(nop)
(i32.store
  (local.get $a)
  (i32.const 1))
(f32.load
  (local.get $a))
```

What matters here:

- the late `EquivalentOptimizer` may decide one local is the better canonical representative
- it can redirect later `local.get`s to that better local
- in this variant it does **not** also delete every equivalent set immediately

This is an important “sounds smaller than it is” part of the pass.

## Shape 11: an existing dead tee can still disappear later

Conceptual before:

```wat
(drop
  (local.tee $x
    (unreachable)))
```

Conceptual late cleanup effect:

```wat
(unreachable)
```

Why this can still happen even in a “no tee” pass:

- the pass is not allowed to *create* a new tee for multi-use sinking
- but `UnneededSetRemover` can still eliminate a useless tee that is already there

So “no tee” is a creation rule, not a blanket preservation rule.

## Shape 12: do not assume the pass keeps IR perfectly flat

Conceptual before:

```wat
(local.set $tmp
  (block (result i32)
    (i32.const 5)))
(drop
  (local.get $tmp))
```

Potential direct-sink result:

```wat
(nop)
(drop
  (block (result i32)
    (i32.const 5)))
```

Why this matters:

- even though the pass runs after `flatten`, it may reintroduce nested value use sites
- the variant that forbids that is `simplify-locals-nonesting`, not this one

This is one of the easiest scheduler myths to carry forward incorrectly.

## Practical checklist of positive vs negative families

### Positive families

- single-use direct sink into an existing consumer
- dead-overwrite cleanup
- late equivalent-`get` canonicalization
- final dead / same-value set cleanup
- cleanup of useless existing tee traffic

### Negative / bailout families

- multi-use locals that would need a tee
- new `if (result ...)` creation from arm-local sets
- new block / loop result creation from carried local traffic
- throwing values crossing into `try` / `try_table`
- trap-capable values crossing global-observable effect barriers
- full-CFG-style global reasoning across arbitrary non-linear regions

## Sources

- [`../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md`](../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
