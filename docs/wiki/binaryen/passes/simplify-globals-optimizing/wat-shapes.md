---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ./index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/index.md
---

# `simplify-globals-optimizing` WAT and IR shape guide

This page is the beginner-friendly shape catalog for Binaryen `simplify-globals-optimizing`, anchored to the retained 2026-04-24 research inventory, direct tagged source URLs, and [research note 0376](./index.md).

The main question to keep asking is:

- “is Binaryen removing fake global state, or proving a global value in a context where that proof is still cheap and safe?”

## Quick orientation

The pass has three broad rewrite zones:

| Zone | Typical shape | Main safety idea |
| --- | --- | --- |
| Global-init folding | one global initializer used once by another global initializer | module instantiation happens once |
| Global-state cleanup | `global.set` writes whose value never matters | keep operand effects, delete fake state |
| Value propagation | later init/offsets or simple runtime traces reading known values | startup order or cheap linear-trace proof |

## Positive shapes Binaryen really rewrites

## 1. Single-use global initializer copied into one later global initializer

Before:

```wat
(global $single-use anyref
  (struct.new $A
    (ref.i31 (i32.const 42))
  )
)
(global $other anyref
  (global.get $single-use)
)
```

After conceptually:

```wat
(global $single-use anyref
  (struct.new $A
    (ref.i31 (i32.const 42))
  )
)
(global $other anyref
  (struct.new $A
    (ref.i31 (i32.const 42))
  )
)
```

Why it works:

- the source global has exactly one read
- the use is in another global initializer
- the initializer code still runs only once overall

## 2. Immutable copy chain collapsed to the earliest compatible ancestor

Before:

```wat
(import "a" "b" (global $g1 i32))
(global $g2 i32 (global.get $g1))
(global $g3 i32 (global.get $g2))
(func
  (drop (global.get $g3))
)
```

After conceptually:

```wat
(import "a" "b" (global $g1 i32))
(global $g2 i32 (global.get $g1))
(global $g3 i32 (global.get $g1))
(func
  (drop (global.get $g1))
)
```

Why it works:

- each copied global is immutable
- Binaryen can chase the chain back to the earliest immutable ancestor
- the use type still matches exactly

## 3. Later global initializer sees an earlier known constant

Before:

```wat
(global $a i32 (i32.const 42))
(global $b i32 (global.get $a))
(global $c i32
  (i32.add
    (global.get $b)
    (global.get $a)
  )
)
```

After conceptually:

```wat
(global $a i32 (i32.const 42))
(global $b i32 (i32.const 42))
(global $c i32
  (i32.add
    (i32.const 42)
    (i32.const 42)
  )
)
```

Why it works:

- Binaryen is still in startup order here
- no runtime writes have happened yet

## 4. Segment offset reads replaced during startup propagation

Before:

```wat
(global $defined i32 (i32.const 42))
(elem (global.get $defined) func $f)
(data (global.get $defined) "abc")
```

After conceptually:

```wat
(global $defined i32 (i32.const 42))
(elem (i32.const 42) func $f)
(data (i32.const 42) "abc")
```

Why it works:

- segment offsets are part of instantiation-time init logic too
- Binaryen handles nested `global.get`s there just like in later global initializers

## 5. Dead `global.set` becomes `drop(value)` when the global is never read

Before:

```wat
(global $g (mut i32) (i32.const 0))
(func
  (global.set $g
    (call $expensive)
  )
)
```

After conceptually:

```wat
(global $g i32 (i32.const 0))
(func
  (drop
    (call $expensive)
  )
)
```

Why it works:

- the stored value is never observed
- the operand may still have effects, so Binaryen keeps it as `drop(...)`
- the global itself can now become effectively immutable

## 6. Write of the initializer value becomes `drop(value)`

Before:

```wat
(global $g (mut i32) (i32.const 0))
(func
  (global.set $g (i32.const 0))
)
```

After conceptually:

```wat
(global $g i32 (i32.const 0))
(func
  (drop (i32.const 0))
)
```

Why it works:

- Binaryen proved the write does not change state relative to the initializer

## 7. `read-only-to-write` self-guard collapses away the stateful part

Before:

```wat
(global $once (mut i32) (i32.const 0))
(func
  (if
    (global.get $once)
    (then
      (global.set $once (i32.const 1))
    )
  )
)
```

After conceptually:

```wat
(global $once i32 (i32.const 0))
(func
  (if
    (i32.const 0)
    (then
      (drop (i32.const 1))
    )
  )
)
```

Why it works:

- the global read only decided whether to write that same global
- nothing else observable depended on that read

### Block-wrapped condition variation

A transparent value-producing block can provide the same self-guard condition:

```wat
(global $once (mut i32) (i32.const 0))
(func
  (if
    (block (result i32)
      (global.get $once)
    )
    (then
      (global.set $once (i32.const 1))
    )
  )
)
```

The current Starshine SGO subset treats that single yielded `global.get` as the same read-only-to-write condition when the adjacent `if` writes one constant to the same global. The same narrow family also accepts `i32.eqz` inside the block.

### No-op const/drop condition-prefix variation

A block-wrapped condition can also contain side-effect-free constant/drop pairs before the yielded self-guard read:

```wat
(global $once (mut i32) (i32.const 0))
(func
  (if
    (block (result i32)
      (drop (i32.const 2))
      (global.get $once)
    )
    (then
      (global.set $once (i32.const 1))
    )
  )
)
```

The current Starshine subset ignores only these constant/drop prefix pairs before the final block-yielded `global.get` or `global.get; i32.eqz` self-guard condition.

### Simple pure-condition variation

Binaryen's source accepts more than adjacent `global.get`, `i32.eqz`, or compare-const conditions. Any condition expression can qualify if the actual `global.get` only flows to the final branch decision and does not steer side effects. Starshine covers a narrow source-backed pure condition subset, including arithmetic/compare operators, non-trapping unary `i32.clz` / `i32.ctz` / `i32.popcnt`, non-trapping bitwise `i32.and` / `i32.or` / `i32.xor`, non-trapping shift/rotate `i32.shl` / `i32.shr_s` / `i32.shr_u` / `i32.rotl` / `i32.rotr`, source-backed `i64.eqz` / `i64` compare operators, non-trapping i64 value operators (`i64.clz` / `i64.ctz` / `i64.popcnt`, `i64.add` / `i64.sub` / `i64.mul`, `i64.and` / `i64.or` / `i64.xor`, and `i64.shl` / `i64.shr_s` / `i64.shr_u` / `i64.rotl` / `i64.rotr`) feeding those final conditions, `f32` / `f64` equality/relational compares, non-trapping `f32` / `f64` value operators (`abs`, `neg`, `ceil`, `floor`, `trunc`, `nearest`, `sqrt`, `add`, `sub`, `mul`, `div`, `min`, `max`, and `copysign`) feeding final float compares, source-backed non-trapping numeric conversions / reinterprets / sign-extension / `trunc_sat` conversions feeding final integer or float conditions, non-trapping reference predicates `ref.is_null` / `ref.eq` feeding final conditions, and `local.get` sibling operands feeding pure final integer conditions:

```wat
(global $once (mut i32) (i32.const 0))
(func
  (if
    (i32.lt_s
      (i32.add
        (global.get $once)
        (i32.const 17)
      )
      (i32.const 20)
    )
    (then
      (global.set $once (i32.const 1))
    )
  )
)
```

The 2026-05-18 unary, bitwise, shift/rotate, i64-compare, i64-value, and float-compare slices were backed by local Binaryen probes showing `wasm-opt --simplify-globals` promotes matching `i32.clz` / `i32.ctz` / `i32.popcnt`, `i32.and` / `i32.or` / `i32.xor`, `i32.shl` / `i32.shr_s` / `i32.shr_u` / `i32.rotl` / `i32.rotr`, `i64.eqz` / `i64` compare guards, non-trapping i64 value operators feeding `i64.eqz`, and `f32` / `f64` compare guards to immutable globals while replacing the get/set uses. The 2026-07-06 float-value follow-up added local Binaryen `version_130` probes for `f32.add` / `f32.abs`, `f64.div` / `f64.sqrt`, and function-level `if return; set` tails with `f32.mul` / `f32.ceil` and `f64.min` / `f64.floor`; all promote to immutable globals, while a float `local.tee` side-effect consumer stays mutable. The later 2026-07-06 numeric-conversion follow-up added probes for `i32.wrap_i64`, `i64.extend_i32_s/u`, int-to-float converts, float promote/demote, reinterpret ops, sign-extension, and `trunc_sat` operators; those promote to immutable globals in guarded-write and if-return tails, while trapping float-to-int `trunc` and conversion results flowing into `local.tee` remain guardrails. The next 2026-07-06 reference-predicate follow-up added Binaryen `version_130` probes where `funcref` `ref.is_null` and `eqref` `ref.eq` conditions promote guarded globals to immutable in both guarded-write and function-level `if return; set` forms; a `funcref` value flowing through `local.tee` before `ref.is_null` remains mutable, matching Binaryen. The later local-get follow-up added a Binaryen `version_130` probe where `global.get $g; local.get $x; i32.add` feeds only the final guarded write, so `$g` becomes immutable while the non-trapping local read is treated as an independent pure operand. The same pure-condition subset now also applies when the condition chain is inside a transparent result block, and to both direct and block-wrapped exact whole-body `if return; set` families, where the return guard precedes the same-global constant write and trailing code still blocks the match. Keep this separate from the official safe-side-effect positive (`select` / `local.tee` / `i32.load` in `simplify-globals-read_only_to_write.wast`), because that broader family needs Binaryen-style upward value-flow reasoning. Starshine also keeps negatives where the global value flows into `local.tee` or `select`, where a trapping memory load consumes the value before the branch, and where a potentially trapping conversion is in the condition chain.

### No-op const/drop body variation

The current subset also accepts no-op constant drops before the final constant write:

```wat
(global $once (mut i32) (i32.const 0))
(func
  (if
    (global.get $once)
    (then
      (drop (i32.const 2))
      (global.set $once (i32.const 1))
    )
  )
)
```

This stays conservative: only constant/drop pairs are ignored before the final single constant `global.set`; arbitrary value producers or side effects remain outside the supported shape.

## 8. Whole-function `if return; set` family collapses the set to a drop

Before:

```wat
(global $once (mut i32) (i32.const 0))
(func $clinit
  (if
    (global.get $once)
    (then
      (return)
    )
  )
  (global.set $once (i32.const 1))
)
```

After conceptually:

```wat
(global $once i32 (i32.const 0))
(func $clinit
  (if
    (i32.const 0)
    (then
      (return)
    )
  )
  (drop (i32.const 1))
)
```

Why it works:

- Binaryen has a special narrow whole-function matcher for exactly this shape
- the same narrow family also accepts `global.get; i32.eqz`, `global.get; const; i32.eq/i32.ne`, `const; global.get; i32.eq/i32.ne`, and transparent result blocks yielding those condition forms before the `if return`, and transparent void blocks around the final constant `global.set`, including when both the condition and set are block-wrapped

## 9. Runtime code reads replaced after a known constant `global.set`

Before:

```wat
(global $g (mut i32) (i32.const 0))
(func
  (global.set $g (i32.const 10))
  (drop (global.get $g))
)
```

After conceptually:

```wat
(global $g (mut i32) (i32.const 0))
(func
  (global.set $g (i32.const 10))
  (drop (i32.const 10))
)
```

Why it works:

- Binaryen tracks a cheap current-value map along the current linear trace

## 10. Some dominated adjacent blocks are included in that same runtime proof

Before:

```wat
(global.set $g (i32.const 10))
(if
  (i32.const 0)
  (then
    (block
      (drop (global.get $g))
    )
  )
)
```

After conceptually:

```wat
(global.set $g (i32.const 10))
(if
  (i32.const 0)
  (then
    (block
      (drop (i32.const 10))
    )
  )
)
```

Why it works:

- `LinearExecutionWalker` connects some adjacent dominated blocks cheaply

## 11. GC / reference-type constant replacement can be more refined than the old `global.get`

Before:

```wat
(global $f (mut funcref) (ref.func $func))
(func
  (drop
    (ref.cast (ref null $A)
      (global.get $f)
    )
  )
)
```

After conceptually:

```wat
(global $f (mut funcref) (ref.func $func))
(func
  (drop
    (ref.cast (ref $A)
      (ref.func $func)
    )
  )
)
```

Why it works:

- replacing the global read may reveal a more precise reference type
- Binaryen refinalizes the function when replacement changes types

## Negative or bailout shapes Binaryen deliberately preserves

## 1. The single use is in function code, not another global initializer

Before:

```wat
(global $single-use anyref (struct.new $A ...))
(func
  (drop (global.get $single-use))
)
```

Preserved because:

- function code may execute more than once
- copying the initializer there could change generative identity or repetition count

## 2. The global has more than one use

Before:

```wat
(global $single-use anyref (struct.new $A ...))
(global $a anyref (global.get $single-use))
(global $b anyref (global.get $single-use))
```

Preserved because:

- the single-use fold is intentionally only for exactly one read

## 3. Imported or exported globals block destructive cleanup families

Before:

```wat
(import "env" "g" (global $g i32))
;; or
(export "g" (global $g))
```

Preserved because:

- outside observers may still depend on the boundary
- Binaryen will not erase or silently change that state story here

## 4. A call breaks runtime current-value propagation

Before:

```wat
(global.set $g (i32.const 10))
(call $maybe_sets_globals)
(drop (global.get $g))
```

Preserved because:

- calls clear the current-value map in runtime propagation

## 5. Nonlinear control breaks runtime current-value propagation

Before:

```wat
(global.set $g (i32.const 10))
(loop $L
  ...
)
(drop (global.get $g))
```

Preserved because:

- the cheap linear-trace model is intentionally invalidated by nonlinear control

## 6. `if` with `else` is not a `read-only-to-write` match

Before:

```wat
(if
  (global.get $g)
  (then
    (global.set $g (i32.const 1))
  )
  (else
    (nop)
  )
)
```

Preserved because:

- the matcher explicitly rejects `if-else`

## 7. Extra reads of the same global block `read-only-to-write`

Before:

```wat
(if
  (global.get $g)
  (then
    (global.set $g (i32.const 1))
  )
)
(drop (global.get $g))
```

Preserved because:

- the global is now read for more than “should I write `$g`?”

## 8. Condition side effects are fine only if the global’s value does not steer them dangerously

Negative example:

```wat
(if
  (if (result i32)
    (global.get $g)
    (then (call $foo))
    (else (i32.const 1))
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Preserved because:

- `$g` decides whether `foo()` runs

Positive contrast:

```wat
(if
  (if (result i32)
    (call $foo)
    (then (i32.const 1))
    (else (global.get $g))
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Optimized because:

- the side effect exists, but `$g` does not decide whether it happens

The current Starshine subset also covers source-backed result-`if` arm variants where the global is read in an arm and flows through pure operators before the outer guarded write, including pure post-result operators such as `i32.eqz` after the side-effecting result `if`, the function-level `if return; set` variant where the side-effecting result `if` value reaches only the return guard before the final same-global write, a nested result-if-arm value-flow subset, and a nested result-if-arm pure-suffix subset with no-global prefixes. It also covers the official side-effecting `select` version where independent `i32.load` / `local.tee` operands are evaluated regardless of the global-derived select condition, including the `select` result flowing through `i32.eqz` before either the guarded write or the function-level `if return; set` tail, plus source-backed select-operand variants where the global-derived `select` operand is paired with an independent zero-parameter/result call, `memory.size`, or constant-delta `memory.grow` in either direct operand order. Further source-backed block-condition subsets handle an independent zero-parameter/result call, memory op, or local write before the block yields the final guarded global read. Value flow into `local.tee`, trapping load addresses, call parameters, `memory.grow` deltas, and local writes remain negative guardrails.

Pure-arm positive now covered locally:

```wat
(if
  (if (result i32)
    (call $foo)
    (then (i32.const 1))
    (else
      (i32.add (global.get $g) (i32.const 2)))
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Binaryen reduces the global to immutable and preserves the independent `call`; Starshine now does the same for pure arm-local operators while still rejecting arm-local side effects such as `local.tee` on the global-derived value.

Pure post-result positive now covered locally:

```wat
(if
  (i32.eqz
    (if (result i32)
      (call $foo)
      (then (i32.const 1))
      (else (global.get $g))
    )
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Binaryen reduces this to immutable global state plus the preserved independent call; Starshine now matches while still rejecting the nearby `local.tee` post-result negative.

Function-level if-return positive now covered locally:

```wat
(if
  (if (result i32)
    (call $foo)
    (then (i32.const 1))
    (else (global.get $g))
  )
  (then
    (return)
  )
)
(global.set $g (i32.const 1))
```

Binaryen reduces this to immutable global state plus `drop (call $foo)` through the same `readsGlobalOnlyToWriteIt` helper used by the ordinary guarded-write path; Starshine now matches while still rejecting the nearby `local.tee` negative where the global-derived value flows into a side effect before the return guard.

Nested result-if-arm positive now covered locally:

```wat
(if
  (if (result i32)
    (call $foo)
    (then (i32.const 1))
    (else
      (if (result i32)
        (call $bar)
        (then (i32.const 2))
        (else (global.get $g)))))
  (then
    (global.set $g (i32.const 1))
  )
)
```

Binaryen reduces this to immutable global state while preserving independent calls. Starshine now matches the narrow form where an arm ends in one nested result `if` after a prefix with no global references; broader arbitrary nested `FlowScanner` shapes remain open.

Nested result-if-arm pure-suffix positive now covered locally:

```wat
(if
  (if (result i32)
    (call $foo)
    (then (i32.const 1))
    (else
      (if (result i32)
        (call $bar)
        (then (global.get $g))
        (else (i32.const 2)))
      (i32.const 4)
      (i32.add)))
  (then
    (global.set $g (i32.const 1))
  )
)
```

Binaryen reduces this to immutable global state while preserving independent effects. Starshine now matches the narrow form where the nested result `if` has a no-global prefix and the nested result flows only through pure suffix operators before the final same-global guarded write; global-dependent prefixes and side-effecting suffix consumers remain out of scope.

Select-operand independent-call positive now covered in both direct operand orders:

```wat
(if
  (select
    (call $foo)
    (global.get $g)
    (i32.const 1)
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Binaryen reduces this to immutable global state plus `drop (call $foo)`; Starshine now matches for this symmetric second-operand case while still rejecting the nearby negative where the global-derived value flows into a call parameter.

The function-level if-return variant is now covered for direct side-effecting independent-load `select` flow and for the first-operand independent-call form. For the load form, Binaryen reduces the direct `select; if return; const; global.set` variant to immutable global state plus `drop (i32.load ...)`; Starshine now matches the narrow generated independent-load/local shell while keeping trapping-address and global-derived local side-effect negatives.

Independent-call if-return form:

```wat
(select
  (global.get $g)
  (call $foo)
  (i32.const 1)
)
(if
  (then (return))
)
(global.set $g (i32.const 1))
```

Binaryen reduces this to immutable global state plus `drop (call $foo)`. Starshine now matches this narrow zero-parameter/result call shape and cleans the SGO-created shell to `call; drop`; broader arbitrary `FlowScanner` parent/child combinations remain open.

Independent-call compare operands are now covered for direct guarded writes and the function-level if-return form:

```wat
(if
  (i32.eq
    (global.get $g)
    (call $foo)
  )
  (then
    (global.set $g (i32.const 1))
  )
)

(i32.ne
  (global.get $g)
  (call $foo)
)
(if
  (then (return))
)
(global.set $g (i32.const 1))
```

Binaryen reduces these zero-parameter/result call compare shapes to immutable global state plus `drop (call $foo)`. Starshine now matches the narrow first/second compare operand orders and the if-return tail while still rejecting the negative where the guarded-global value flows into a call parameter.

Independent memory-op compare operands are covered for direct guarded writes and function-level if-return forms. The `memory.grow` delta may be a constant or `local.get` so long as the guarded global does not feed the grow:

```wat
(if
  (i32.eq
    (global.get $g)
    (memory.size)
  )
  (then
    (global.set $g (i32.const 1))
  )
)

(i32.ne
  (memory.grow (i32.const 0))
  (global.get $g)
)
(if
  (then (return))
)
(global.set $g (i32.const 1))

(func (param $n i32)
  (i32.ne
    (global.get $g)
    (memory.grow (local.get $n))
  )
  (if
    (then
      (global.set $g (i32.const 1))
    )
  )
)
```

Binaryen reduces these independent memory compare shapes to immutable global state, deleting `memory.size` shells and preserving independent `memory.grow` as `drop (memory.grow ...)`. Starshine now matches the narrow first/second compare operand orders and the if-return tail for constant-or-`local.get` grow deltas while still rejecting the negative where the guarded-global value flows into the `memory.grow` delta.

Independent table-op compare operands are covered for direct guarded writes and function-level if-return forms. The `table.grow` operands may be constants or `local.get`s so long as the guarded global does not feed the grow:

```wat
(if
  (i32.eq
    (global.get $g)
    (table.size 0)
  )
  (then
    (global.set $g (i32.const 1))
  )
)

(i32.ne
  (table.grow 0 (ref.null func) (i32.const 0))
  (global.get $g)
)
(if
  (then (return))
)
(global.set $g (i32.const 1))

(func (param $r funcref) (param $n i32)
  (i32.eq
    (global.get $g)
    (table.grow 0 (local.get $r) (local.get $n))
  )
  (if
    (then
      (global.set $g (i32.const 1))
    )
  )
)
```

Binaryen reduces these independent table compare shapes to immutable global state, deleting `table.size` shells and preserving independent `table.grow` as `drop (table.grow ...)`. Starshine now matches the narrow first/second compare operand orders and the if-return tail for constant-or-`local.get` grow operands while still rejecting the negative where the guarded-global value flows into the `table.grow` delta.

Independent table-op `select` operands are covered for direct guarded writes and function-level if-return forms. The `table.grow` operands may be constants or `local.get`s so long as the guarded global does not feed the grow:

```wat
(if
  (select
    (global.get $g)
    (table.size 0)
    (i32.const 1)
  )
  (then
    (global.set $g (i32.const 1))
  )
)

(select
  (table.grow 0 (ref.null func) (i32.const 0))
  (global.get $g)
  (i32.const 1)
)
(if
  (then (return))
)
(global.set $g (i32.const 1))

(func (param $r funcref) (param $n i32)
  (if
    (select
      (global.get $g)
      (table.grow 0 (local.get $r) (local.get $n))
      (i32.const 1)
    )
    (then
      (global.set $g (i32.const 1))
    )
  )
)
```

Binaryen reduces the `table.size` variants to immutable global state plus no remaining table query, and preserves independent `table.grow` as `drop (table.grow ...)`. Starshine now matches the narrow first/second select operand orders and the if-return tail for constant-or-`local.get` grow operands while still rejecting the negative where the guarded-global value flows into the `table.grow` delta.

Independent constant `local.tee` `select` operands are covered for direct guarded writes and function-level if-return forms when the local write is independent of the guarded global and the local is not referenced outside the generated cleanup shell:

```wat
(if
  (select
    (global.get $g)
    (local.tee $tmp (i32.const 7))
    (i32.const 1)
  )
  (then
    (global.set $g (i32.const 1))
  )
)

(select
  (local.tee $tmp (i32.const 7))
  (global.get $g)
  (i32.const 1)
)
(if
  (then (return))
)
(global.set $g (i32.const 1))
```

Binaryen reduces these to immutable global state and, in the unused-local probe, removes the local write shell. Starshine now matches the narrow first/second select operand orders and if-return tail, while still rejecting guarded-global-derived local writes and extra guarded reads after the select.

Independent constant-or-`local.get` `local.tee` compare operands are also covered for direct guarded writes and function-level if-return forms:

```wat
(if
  (i32.eq
    (global.get $g)
    (local.tee $tmp (local.get $value))
  )
  (then
    (global.set $g (i32.const 1))
  )
)

(i32.ne
  (local.tee $tmp (local.get $value))
  (global.get $g)
)
(if
  (then (return))
)
(global.set $g (i32.const 1))
```

Binaryen reduces these to immutable global state. Starshine matches the direct/reverse compare operand orders for constant and local-fed values and removes the generated unused-local compare shells only when the local is not referenced outside the matched shell; guarded-global-derived `local.tee` values remain excluded.

Independent constant-or-`local.get` `local.set` compare operands are covered when the local write is inside a block condition and the guarded value only reaches the compare:

```wat
(if
  (block (result i32)
    (local.set $tmp (local.get $value))
    (i32.eq
      (global.get $g)
      (local.get $tmp)
    )
  )
  (then
    (global.set $g (i32.const 1))
  )
)

(block (result i32)
  (local.set $tmp (local.get $value))
  (i32.ne
    (local.get $tmp)
    (global.get $g)
  )
)
(if
  (then (return))
)
(global.set $g (i32.const 1))
```

Binaryen reduces these to immutable global state, while preserving or deleting the independent local write according to later cleanup. Starshine now matches constant and local-fed direct/reverse compare operand orders and the terminal if-return tail, but still rejects the negative where `global.get $g` feeds the `local.set` value.

Independent constant `global.set` compare operands are covered when the write targets a different global inside a result block and the guarded value only reaches the compare:

```wat
(if
  (i32.eq
    (global.get $g)
    (block (result i32)
      (global.set $other (i32.const 7))
      (i32.const 0)
    )
  )
  (then
    (global.set $g (i32.const 1))
  )
)

(i32.ne
  (block (result i32)
    (global.set $other (i32.const 7))
    (i32.const 0)
  )
  (global.get $g)
)
(if
  (then (return))
)
(global.set $g (i32.const 1))
```

Binaryen reduces these to immutable `$g` while preserving the independent `$other` write. Starshine now matches the direct/reverse compare operand orders and the terminal if-return tail, but still rejects the negative where `global.get $g` feeds `global.set $other`.

Select-operand memory positives now covered locally; `memory.grow` deltas may be constants or `local.get`s independent of the guarded global:

```wat
(if
  (select
    (global.get $g)
    (memory.grow (i32.const 0))
    (i32.const 1)
  )
  (then
    (global.set $g (i32.const 1))
  )
)

(func (param $n i32)
  (if
    (select
      (global.get $g)
      (memory.grow (local.get $n))
      (i32.const 1)
    )
    (then
      (global.set $g (i32.const 1))
    )
  )
)
```

Binaryen reduces these to immutable global state plus `drop (memory.grow ...)`; Starshine now matches while still rejecting the nearby negative where the global-derived value is the `memory.grow` delta.

The symmetric memory-op operand order is also covered:

```wat
(if
  (select
    (memory.size)
    (global.get $g)
    (i32.const 1)
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Binaryen removes the `memory.size` shell entirely in this order too, and Starshine now matches; the same direct order with constant-or-`local.get` `memory.grow` deltas is preserved as `memory.grow; drop`.

The function-level if-return variants are now covered for both direct memory-op operand orders:

```wat
(select
  (global.get $g)
  (memory.grow (i32.const 0))
  (i32.const 1)
)
(if
  (then (return))
)
(global.set $g (i32.const 1))
```

Binaryen reduces `memory.size` variants to immutable global state plus no remaining memory query, and preserves independent `memory.grow` as `drop (memory.grow ...)`. Starshine now matches those four narrow first/second operand if-return shapes for constant-or-`local.get` grow deltas while still rejecting global-derived `memory.grow` deltas.

Block-prefix independent-call positive now covered locally:

```wat
(if
  (block (result i32)
    (drop (call $foo))
    (global.get $g)
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Binaryen reduces this to immutable global state plus `drop (call $foo)`. Starshine now matches the narrow `call; drop; global.get` block-condition subset for guarded-write and if-return/set forms. The same source-backed family now also covers void independent calls with no parameters and no results:

```wat
(if
  (block (result i32)
    (call $foo_void)
    (global.get $g)
  )
  (then
    (global.set $g (i32.const 1))
  )
)
```

Binaryen reduces the void-call form to immutable global state plus the preserved `call $foo_void`. Starshine rejects nearby negatives where the global-derived value flows into a call parameter before the final read.

The if-return variant now covered locally uses the same condition matcher through Binaryen's function-level `if return; set` path:

```wat
(block (result i32)
  (drop (call $foo))
  (global.get $g)
)
(if
  (then (return))
)
(global.set $g (i32.const 1))
```

Block-prefix independent memory-op positives are now covered locally for both guarded-write and if-return tails:

```wat
(if
  (block (result i32)
    (drop (memory.size))
    (global.get $g)
  )
  (then (global.set $g (i32.const 1)))
)

(block (result i32)
  (drop (memory.grow (i32.const 0)))
  (global.get $g)
)
(if (then (return)))
(global.set $g (i32.const 1))
```

Binaryen deletes the `memory.size` shell and preserves constant-delta `memory.grow` as `drop (memory.grow ...)`. Starshine now matches the narrow `memory.size; drop; global.get` and `const; memory.grow; drop; global.get` block-condition subsets, while still rejecting global-derived `memory.grow` deltas.

Block-prefix independent table-op positives are now covered locally for both guarded-write and if-return tails:

```wat
(if
  (block (result i32)
    (drop (table.size 0))
    (global.get $g)
  )
  (then (global.set $g (i32.const 1)))
)

(block (result i32)
  (drop (table.grow 0 (ref.null func) (i32.const 0)))
  (global.get $g)
)
(if (then (return)))
(global.set $g (i32.const 1))

(block (result i32)
  (table.set 0 (i32.const 0) (ref.null func))
  (global.get $g)
)
(if (then (return)))
(global.set $g (i32.const 1))

(block (result i32)
  (table.fill 0 (i32.const 0) (ref.null func) (i32.const 1))
  (global.get $g)
)
(if (then (return)))
(global.set $g (i32.const 1))

(if
  (block (result i32)
    (table.copy 0 0 (i32.const 0) (i32.const 1) (i32.const 2))
    (global.get $g)
  )
  (then (global.set $g (i32.const 1)))
)

(block (result i32)
  (table.init 0 0 (i32.const 0) (i32.const 0) (i32.const 1))
  (global.get $g)
)
(if (then (return)))
(global.set $g (i32.const 1))

(if
  (block (result i32)
    (elem.drop 0)
    (global.get $g)
  )
  (then (global.set $g (i32.const 1)))
)
```

Binaryen deletes the `table.size` shell, preserves independent constant-delta `table.grow` as `drop (table.grow ...)`, and preserves independent `table.set`, `table.fill`, `table.copy`, `table.init`, and `elem.drop` mutations when all stack arguments are constants or the operation has no stack operands. Starshine now matches the narrow `table.size; drop; global.get`, `ref.const-or-null; const; table.grow; drop; global.get`, `const dest; const ref; table.set; global.get`, `const dest; const ref; const len; table.fill; global.get`, `const dest; const src; const len; table.copy; global.get`, `const dest; const src; const len; table.init; global.get`, and `elem.drop; global.get` block-condition subsets, while still rejecting guarded-global-derived table operation arguments.

Block-prefix independent local-write positives are now covered locally for both guarded-write and if-return tails:

```wat
(if
  (block (result i32)
    (i32.const 42)
    (local.set $tmp)
    (global.get $g)
  )
  (then (global.set $g (i32.const 1)))
)

(block (result i32)
  (i32.const 42)
  (local.set $tmp)
  (global.get $g)
)
(if (then (return)))
(global.set $g (i32.const 1))
```

Binaryen reduces the guarded global to immutable state when the local write's stored value is independent of that global. Starshine now matches the narrow `const; local.set; global.get` and `const; local.tee; drop; global.get` block-condition subsets, preserves the local write as `const; local.set`, and still rejects global-derived values flowing into local writes.

Block-prefix independent global-write positives are now covered locally for both guarded-write and if-return tails when the written global is not the guarded global and the stored value is independent:

```wat
(if
  (block (result i32)
    (i32.const 7)
    (global.set $other)
    (global.get $g)
  )
  (then (global.set $g (i32.const 1)))
)

(block (result i32)
  (i32.const 7)
  (global.set $other)
  (global.get $g)
)
(if (then (return)))
(global.set $g (i32.const 1))
```

Binaryen preserves the independent `$other` write when it is observable, such as through an exported mutable global, and still reduces `$g` to immutable state. Starshine now matches the narrow constant-or-`local.get` `global.set $other` result-block subset with `$other != $g`, preserves the independent global write, and still rejects guarded-global-derived values flowing into the `$other` write.

```wat
(if
  (i32.eq
    (global.get $g)
    (block (result i32)
      (local.get $value)
      (global.set $other)
      (i32.const 0)))
  (then (return)))
(global.set $g (i32.const 1))
```

Independent memory-store compare operands are now covered when the store address and value are constants or `local.get`s and the guarded global only supplies the other compare operand:

```wat
(if
  (i32.eq
    (global.get $g)
    (block (result i32)
      (i32.const 0)
      (i32.const 7)
      (i32.store)
      (i32.const 0)))
  (then (global.set $g (i32.const 1))))

(if
  (i32.eq
    (global.get $g)
    (block (result i32)
      (local.get $addr)
      (local.get $val)
      (i32.store)
      (i32.const 0)))
  (then (return)))
(global.set $g (i32.const 1))
```

Binaryen reduces `$g` to immutable state while preserving the independent store; Starshine now matches constant and local-fed store operands, direct/reverse compare operand orders, and the function-level if-return tail. The nearby negative where `global.get $g` feeds the store address or value remains excluded, and broader non-constant side-effect operands beyond `local.get` are still unclaimed.

### Nested same-pattern carveout

Binaryen also treats a nested same-global read-only-to-write guard as safe condition work when that nested guard's only useful result is another read of the same global feeding the next guard:

```wat
(block (result i32)
  (block (result i32)
    (if (global.get $g)
      (then (global.set $g (i32.const 1)))
    )
    (global.get $g)
  )
  i32.eqz
  (if
    (then (global.set $g (i32.const 1)))
  )
  (global.get $g)
  i32.const 0
  i32.eq
)
(if
  (then (global.set $g (i32.const 1)))
)
```

Starshine now covers this official nested-thrice positive by recognizing the nested guard prefix plus final same-global read inside the block condition. This is intentionally narrow; extra unrelated reads or unsafe effects still block the `read-only-to-write` classification.

### Nested multi-global body carveout

Binaryen also allows nested read-only-to-write patterns for different globals inside the body of another guarded write, as long as the body is still only doing those fake-state guarded writes:

```wat
(global $a (mut i32) (i32.const 0))
(global $b (mut i32) (i32.const 0))
(global $c (mut i32) (i32.const 0))
(func
  (if (global.get $a)
    (then
      (block
        (global.set $a (i32.const 1))
        (if (global.get $b)
          (then
            (block
              (if (global.get $c)
                (then
                  (global.set $c (i32.const 2))))
              (global.set $b (i32.const 3)))))))))
```

Starshine now covers this official multi-global positive by flattening transparent void blocks and accepting exactly one constant write to the guarded global plus nested different-global `global.get; if { ... }` guard pairs. It deliberately does not admit arbitrary calls, memory effects, unrelated reads, non-constant writes, or same-target nested body reads.

## 9. Calls with computed effects do not count as actual `global.get` / `global.set` nodes for `read-only-to-write`

Negative example:

```wat
(if
  (block (result i32)
    (drop (call $get))
    (i32.const 1)
  )
  (then
    (global.set $g (i32.const 0))
  )
)
```

Preserved because:

- Binaryen insists on matching real AST `GlobalGet` / `GlobalSet` nodes for this family
- effect summaries are used for invalidation and safety, not as substitutes for the matcher

## 10. Exact type mismatch blocks copy-chain canonicalization

Before:

```wat
(global $a (ref $struct) (struct.new_default $struct))
(global $c (ref null $struct) (global.get $a))
(func
  (global.get $c)
)
```

Preserved because:

- Binaryen only rewrites copy chains when the ancestor type matches the current use exactly
- the source has a TODO for a more aggressive refinalizing version, but `version_129` does not do that yet

## 11. Exported generative global stays separate

Before:

```wat
(global $A (ref $struct) (struct.new_default $struct))
(global $B (ref $struct) (global.get $A))
(export "A" (global $A))
```

Preserved because:

- duplicating or collapsing a generative exported initializer can change observable identity

## 12. The whole-function `if return; set` family is very exact

Before:

```wat
(func $clinit
  (if (global.get $once)
    (then (return))
  )
  (global.set $once (i32.const 1))
  (nop)
)
```

Preserved because:

- the body now has too many elements for the exact matcher, even though Starshine now accepts the exact, `i32.eqz`, bidirectional compare-const, and block-wrapped condition, block-wrapped set, and combined block-wrapped condition+set variants when there is no trailing code

## Interaction shapes worth remembering

## 1. `drop(const)` debris is expected after simplify-globals

When the pass removes writes or collapses self-guarded state, it often leaves behind:

```wat
(drop (i32.const 1))
```

That is not a bug. It preserves operand evaluation until later cleanup removes the now-obvious dead work.

## 2. The optimizing variant exists to clean up that debris immediately

If a function changed, `simplify-globals-optimizing` reruns the default function optimization pipeline on that function.

So a positive mental model is:

- simplify-globals creates new constants and drops
- nested function cleanup cashes in on them right away

## 3. But dead globals themselves are mostly for later module cleanup

The pass often stops after making a global:

- immutable
- unread
- or otherwise pointless

The later top-level `remove-unused-module-elements` pass is what actually removes many of those now-dead globals from the module.

## Easy mental checklist for future Starshine work

For a concrete future local test ladder, pair this shape catalog with [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

When deciding whether a shape should rewrite, ask:

1. Is this still module-init time, or already runtime code?
2. If runtime, is the current execution story still cheap and linear enough?
3. If erasing a global state family, is the read really only “to decide whether to write the same global”?
4. Are there actual AST `global.get` / `global.set` nodes, not just effect summaries?
5. Would the rewrite need type repair or exact-type gating?
6. Is later cleanup expected to finish the story?

That checklist matches the actual `version_129` source much better than “constant globals good, mutable globals bad.”

## Sources

- [research note 0570](./index.md)
- [research note 0376](./index.md)
- [research note 0286](./index.md)
- [research note 0122](./index.md)

## 2026-07-06 addendum: pure-add grow select operands

Binaryen `version_130` also accepts a narrower non-constant independent grow-argument shape for read-only-to-write select operands: the `memory.grow` / `table.grow` delta may be a nontrapping `i32.add` over constants or `local.get`s when the guarded global supplies only the other `select` value / condition for the final same-global write.

Example accepted by local `wasm-opt version 130 (version_130)` and now by Starshine:

```wat
(module
  (memory 1)
  (global $guard (mut i32) (i32.const 0))
  (func (param $n i32)
    global.get $guard
    local.get $n
    i32.const 1
    i32.add
    memory.grow
    i32.const 1
    select
    if
      i32.const 1
      global.set $guard
    end))
```

After SGO, `$guard` is immutable and the independent grow remains observable as `drop (memory.grow (i32.add (local.get ...) (i32.const 1)))`. The table form is analogous with an independent `funcref` operand and the pure-add delta.

## 2026-07-07 addendum: pure-add grow compare operands

The same narrow pure-add grow-delta allowance now covers compare operands too, including function-level `if return; set` tails. Binaryen `version_130` accepts `global.get $guard` compared against an independent `memory.grow` / `table.grow` whose delta is `i32.add` over constants or `local.get`s, then removes the fake same-global guard while preserving the grow effect.

Example accepted by local `wasm-opt version 130 (version_130)` and now by Starshine:

```wat
(module
  (memory 1)
  (global $guard (mut i32) (i32.const 0))
  (func (param $n i32)
    global.get $guard
    local.get $n
    i32.const 1
    i32.add
    memory.grow
    i32.eq
    if
      i32.const 1
      global.set $guard
    end))
```

After SGO, `$guard` is immutable, the `i32.eq` / `if` guard shell is gone, and the independent grow remains as a dropped result. This still does **not** close generic `FlowScanner` parity: guarded-value-to-grow-delta flow remains excluded, and arbitrary effectful siblings / broader side-effect parents / extra guarded reads remain open unless separately source-backed and tested.

## 2026-07-07 addendum: reverse pure-add grow select operands

The pure-add grow select allowance also covers the probed reverse operand order: an independent `memory.grow` / `table.grow` with `i32.add` delta may produce the first select value, while `global.get $guard` supplies the other select value and an independent constant supplies the select condition. Binaryen `version_130` removes the fake same-global guard for both direct guarded-write and function-level `if return; set` tails while preserving the grow.

Example accepted by local `wasm-opt version 130 (version_130)` and now by Starshine:

```wat
(module
  (memory 1)
  (global $guard (mut i32) (i32.const 0))
  (func (param $n i32)
    local.get $n
    i32.const 1
    i32.add
    memory.grow
    global.get $guard
    i32.const 1
    select
    if
      i32.const 1
      global.set $guard
    end))
```

After SGO, `$guard` is immutable, the `select` / `if` guard shell is gone, and the grow remains as a dropped effect. This addendum is still limited to nontrapping `i32.add` over constants or `local.get`s; it does not permit the guarded value to feed the grow delta/ref or any arbitrary side-effect parent.

## 2026-07-07 addendum: independent call sibling through nontrapping `i32` binary operators

Binaryen `version_130` also accepts a broader parent/child `FlowScanner` shape than the grow-only follow-ups: an independent zero-parameter/one-result call may provide the other operand to a nontrapping pure `i32` binary operator while `global.get $guard` provides one operand. The call is effectful, but the guarded value does not decide whether or how the call runs; it flows only through the pure binary operator to the same-global guarded write or the function-level `if return; set` tail. Local probes accept `i32.add`, `i32.sub`, `i32.mul`, bitwise ops, shifts, and rotates; trapping div/rem probes keep the guard mutable.

Example accepted by local `wasm-opt version 130 (version_130)` and now by Starshine:

```wat
(module
  (import "env" "imp" (func $imp (result i32)))
  (global $guard (mut i32) (i32.const 0))
  (func (export "run")
    global.get $guard
    call $imp
    i32.add
    if
      i32.const 1
      global.set $guard
    end))
```

The reverse operand order and the `if { return }; const; global.set $guard` tail are accepted as well. After SGO, `$guard` is immutable and the independent call remains observable as `drop (call $imp)`. This still does **not** admit guarded-value-to-call-argument flow, arbitrary side-effect parents, trapping div/rem parents, extra guarded reads, or generic Binaryen `FlowScanner` equivalence.

## 2026-07-07 addendum: independent call nontrapping `i32` binary through `i32.eqz`

Binaryen `version_130` also accepts one deeper pure-parent step for the independent-call/nontrapping-binary sibling family: the pure `i32` binary result may flow through `i32.eqz` before the final same-global guarded write or function-level `if return; set` tail.

```wat
(module
  (import "env" "imp" (func $imp (result i32)))
  (global $guard (mut i32) (i32.const 0))
  (func (export "run")
    global.get $guard
    call $imp
    i32.mul
    i32.eqz
    if
      i32.const 1
      global.set $guard
    end))
```

After SGO, `$guard` is immutable and the independent call remains observable as `drop (call $imp)`. Starshine now matches this narrow `i32.eqz` suffix for direct and reverse nontrapping binary operands plus the if-return tail. Trapping `i32.div_s; i32.eqz` remains excluded, and this still does **not** admit guarded-value-to-call-argument flow, arbitrary pure suffix chains, arbitrary side-effect parents, extra guarded reads, or generic Binaryen `FlowScanner` equivalence.

## 2026-07-07 addendum: independent call nontrapping `i32` binary through unary suffixes

Binaryen `version_130` also accepts a single nontrapping integer-unary pure parent above the independent-call/nontrapping-binary sibling family: after the guarded global and independent zero-parameter/one-result call feed a nontrapping `i32` binary operator, the binary result may flow through `i32.clz`, `i32.ctz`, or `i32.popcnt` before the same-global guarded write or function-level `if return; set` tail.

```wat
(module
  (import "env" "imp" (func $imp (result i32)))
  (global $guard (mut i32) (i32.const 0))
  (func (export "run")
    global.get $guard
    call $imp
    i32.mul
    i32.clz
    if
      i32.const 1
      global.set $guard
    end))
```

After SGO, `$guard` is immutable and the independent call remains observable as `drop (call $imp)`. Starshine now matches this narrow unary-suffix family for direct and reverse nontrapping binary operands plus the if-return tail. Trapping `i32.div_s; i32.clz` remains excluded, and this still does **not** admit guarded-value-to-call-argument flow, const-fed comparison suffixes, arbitrary or multiple pure suffix chains, arbitrary side-effect parents, extra guarded reads, or generic Binaryen `FlowScanner` equivalence.

## 2026-07-07 addendum: independent call binary through one constant-fed equality comparison

Binaryen `version_130` accepts one further pure parent: the nontrapping `i32` binary result may be compared with one `i32.const` using `i32.eq` or `i32.ne` before the final guard tail.

```wat
(module
  (import "env" "imp" (func $imp (result i32)))
  (global $guard (mut i32) (i32.const 0))
  (func (export "run")
    global.get $guard
    call $imp
    i32.mul
    i32.const 0
    i32.eq
    if
      i32.const 1
      global.set $guard
    end))
```

The constant-first comparison order, reverse call/binary operand order, and function-level `if return; set` tail are covered too. After SGO, `$guard` is immutable and the independent call remains `call; drop`. Trapping div/rem parents, relational comparisons, multiple/arbitrary suffix chains, guarded-value-to-call-argument flow, arbitrary side-effect parents, extra guarded reads, and generic `FlowScanner` equivalence remain excluded.

## 2026-07-07 addendum: independent `i64` call binary through one boolean suffix

Binaryen `version_130` accepts the analogous typed `i64` chain:

```wat
(module
  (import "env" "imp" (func $imp (result i64)))
  (global $guard (mut i64) (i64.const 0))
  (func (export "run")
    global.get $guard
    call $imp
    i64.add
    i64.eqz
    if
      i64.const 1
      global.set $guard
    end))
```

Starshine covers direct/reverse nontrapping `i64` binary operands followed by exactly one `i64.eqz` or constant-fed `i64.eq` / `i64.ne`, including constant-first equality and function-level `if return; set`. The guard becomes immutable and the call remains `call; drop`. A trapping `i64.div_s; i64.eqz` stays mutable.

## 2026-07-07 addendum: independent float call binary through one comparison

Binaryen `version_130` also accepts IEEE float parent chains:

```wat
(module
  (import "env" "imp" (func $imp (result f32)))
  (global $guard (mut f32) (f32.const 0))
  (func (export "run")
    global.get $guard
    call $imp
    f32.add
    f32.const 0
    f32.lt
    if
      f32.const 1
      global.set $guard
    end))
```

Starshine now covers `f32` / `f64` `add`, `sub`, `mul`, `div`, `min`, `max`, and `copysign`, followed by exactly one same-typed constant-fed `eq`, `ne`, `lt`, `gt`, `le`, or `ge`. Direct/reverse binary operands, result-first/constant-first comparisons, guarded-write and if-return tails, float divide, and NaN-sensitive comparisons are included. The guard becomes immutable and the call remains `call; drop`. Guarded-value-to-call-argument flow, extra guarded reads, deeper chains, and arbitrary effectful parents remain excluded.

## 2026-07-07 addendum: reusable scalar parent chain

The independent-call shape is no longer limited to exactly one suffix. For the supported straight-line result-first grammar, Starshine follows the global-derived scalar value through repeated nontrapping unary/conversion and constant-fed binary/comparison parents until it becomes the final `i32` condition. Examples now include `i32.add; i32.clz; i32.eqz`, `i32.add; i32.const 7; i32.lt_s`, `f32.add; f32.abs; f32.const 0; f32.lt`, and `f32.add; f64.promote_f32; f64.const 0; f64.ge`. The independent call remains `call; drop` after guard removal.

A parameter-fed `i32.div_s` in that path remains a bailout because it may trap based on the guarded-derived value. Reverse unary chains before the first parent, generic structured parents, and arbitrary independent effect producers remain future FlowScanner work.

## 2026-07-07 addendum: multiple constant-first scalar parents

The supported scalar grammar also handles a contiguous stack of constant-first operands below the guarded expression. For example, Binaryen and Starshine both reduce this condition to immutable `$guard` plus `call; drop`:

```wat
(func
  i32.const 9
  i32.const 7
  global.get $guard
  call $imp
  i32.add
  i32.mul
  i32.lt_s
  if
    i32.const 1
    global.set $guard
  end)
```

The constants are consumed in stack order: `7` feeds `i32.mul`, then `9` feeds `i32.lt_s`. The reverse first-parent order (`call; global.get; i32.add`) is covered too. This does not admit non-constant prefix producers or arbitrary effectful siblings.

## 2026-07-07 addendum: reverse pre-parent independent fragments

Binaryen removes pure call-result preparation before the guarded global's first parent:

```wat
call $imp
f64.convert_i32_s
global.get $guard
f64.add
f64.const 0
f64.gt
if
  f64.const 1
  global.set $guard
end
```

After SGO, `$guard` is immutable and only `call; drop` remains. A trap-capable preparation must remain observable:

```wat
call $imp
i32.trunc_f32_s
global.get $guard
i32.add
i32.eqz
if
  i32.const 1
  global.set $guard
end
```

Both Binaryen and Starshine reduce this to immutable `$guard` plus `call; i32.trunc_f32_s; drop`. Pure same-type unary operations such as `i32.clz` are removed like the nontrapping conversion. Trapping instructions on the guarded-dependent path remain excluded.
