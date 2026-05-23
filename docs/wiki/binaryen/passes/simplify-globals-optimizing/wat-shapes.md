---
kind: concept
status: supported
last_reviewed: 2026-05-21
sources:
  - ../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md
  - ../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md
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

This page is the beginner-friendly shape catalog for Binaryen `simplify-globals-optimizing`, anchored to the primary-source manifests in [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md) and [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md).

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

### Recursive nested-pattern variation

Binaryen's `FlowScanner` has a specific carveout for another no-else read-only-to-write pattern nested inside the current condition. This lets the outer final read still count as safe:

```wat
(global $once (mut i32) (i32.const 0))
(func
  (if
    (block (result i32)
      (if
        (i32.eqz (global.get $once))
        (then (global.set $once (i32.const 1)))
      )
      (i32.eq (global.get $once) (i32.const 0))
    )
    (then (global.set $once (i32.const 1)))
  )
)
```

Starshine now accepts this two-layer family plus the lit-style three-layer version where the inner condition is itself a result block containing a no-else same-global self-guard and then yielding another `global.get`. It still rejects near misses where the nested `if` has an `else`, or where an extra dropped `global.get $once` makes the number of actual reads exceed the number of safe pattern reads. The public SGO wrapper may skip nested cleanup for the resulting value-block/control body and return the valid core rewrite directly.

### Nested-arm FlowScanner block-result variation

A side-effecting condition can also hide the candidate read in a nested `if (result i32)` arm, then wrap that nested condition in a transparent result block before the final self-guard branch:

```wat
(global $once (mut i32) (i32.const 0))
(func
  (if
    (block (result i32)
      (if (result i32)
        (call $cond)
        (then (i32.const 0))
        (else (global.get $once))
      )
      (i32.eqz)
    )
    (then (global.set $once (i32.const 1)))
  )
)
```

Binaryen promotes this family because the call decides which arm runs, while `$once` only flows out to the final branch condition. Starshine's current subset accepts one or more transparent block-result wrappers for supported pure post-consumers like `i32.eqz` and for the supported clean-sibling `select` value form, and it preserves the neighboring negative where the block-wrapped post-consumer is a trapping `i32.load` whose address comes from the global-derived value.

The 2026-05-21 indirect-call and call-ref follow-ups extend the independent nested-if condition family to `call_indirect` and ordinary `call_ref` when all call operands are clean; they preserve global-derived indirect-call parameter/index operands and global-derived `call_ref` parameters because the call may trap or execute different code before the final guard.

A `br_if` probe on 2026-05-21 did not become a Starshine rule: Binaryen preserved direct `global.get; br_if; global.set` and block/return variants, so branch-target control remains outside the current FlowScanner subset.

The clean `nop` follow-up accepts an independent no-op in the same local stack/value-flow scanner paths. Binaryen v129 promoted the clean `nop` neighbor while preserving a global-steered `if (then nop)` control wrapper, so Starshine keeps control-dependent `nop` wrappers conservative instead of broadening branch reasoning. The clean void-block follow-up applies the same rule recursively to `block` bodies that have void type, contain no candidate-global read, and leave the local scan stack empty; blocks with candidate-global reads remain conservative.

The clean local/global-set follow-ups extend the same stack/value-flow accounting to `local.set` and non-candidate `global.set` when the stored value is independent of the candidate global. The local/global write and later read may remain in the output, but the fake candidate-global read/write state is removed. Starshine preserves neighboring shapes where the candidate global is stored through `local.set` or another `global.set`, because that tainted storage can carry the global-derived value to later consumers.

The clean `table.set` follow-up applies the same conservative stack rule to table writes: both the table index and stored reference must be independent of the candidate global. Binaryen v129 promoted the clean exported-table write neighbor and preserved the global-derived table-index neighbor, so Starshine accepts only that exact clean-operand side-effect shape and keeps tainted `table.set` operands conservative.

The clean `table.fill`, `table.init`, and `table.copy` follow-ups apply the same three-clean-operand rule used by bulk table writes: table index/destination, fill reference or element source, copy source, and size must all be independent of the candidate global. Binaryen v129 promoted the clean exported-table fill/init/copy neighbors and preserved global-derived destination, value/source, and size neighbors, so Starshine accepts only clean `table.fill` / `table.init` / `table.copy` and keeps tainted table operands conservative. The clean `elem.drop` and `data.drop` follow-ups are narrower: they are accepted only as operandless segment side effects independent of the candidate global, while a global-steered control wrapper around either drop remains conservative.

The clean `i32.store`, `i64.store`, `i32.store8`, `i32.store16`, `i64.store8`, `i64.store16`, `i64.store32`, `f32.store`, and `f64.store` follow-ups apply the same two-clean-operand rule to a tiny scalar memory-store family: the address and stored value must both be independent of the candidate global. The clean `memory.fill`, `memory.copy`, and `memory.init` follow-ups extend that rule to three operands: fill destination/value/size, copy destination/source/size, or init destination/source/size must all be independent of the candidate global. Binaryen v129 promoted the clean exported-memory write neighbors and preserved global-derived address/value/size or destination/source/size neighbors for each probed shape, so Starshine currently accepts only clean `i32.store` / `i64.store` / `i32.store8` / `i32.store16` / `i64.store8` / `i64.store16` / `i64.store32` / `f32.store` / `f64.store` / `memory.fill` / `memory.copy` / `memory.init` and keeps tainted store, fill, copy, or init operands conservative; remaining bulk memory operations, SIMD stores, atomics, and growth operations still need separate probes.

The clean trapping-read follow-up extends the same stack/value-flow accounting from `i32.load` to source-backed scalar memory loads and `table.get` when their address or table index is independent of the candidate global. The load or table read remains in the output, but the fake global read/write state is removed. Starshine preserves neighboring shapes where the candidate global supplies the load address or `table.get` index, because that value may decide whether a trap occurs before the final guard.

The 2026-05-20 if-wrapper follow-up covers another adjacent FlowScanner parent-walk family: a clean value-producing `if` arm can itself contain the supported nested-if arm-flow result, then yield to a supported pure post-consumer or clean-sibling `select` before the outer same-global write guard. Starshine preserves the paired negatives where the wrapper result feeds a trapping `i32.load` or the candidate `global.get` steers the inner wrapper condition.

The reference-typed post-consumer slices admit the same nested-if arm flow when a `funcref` candidate flows through nontrapping `ref.is_null`, an `eqref` candidate flows through nontrapping ordinary `ref.test` or `ref.eq`, an `i32` candidate flows through nontrapping `ref.i31` and then `ref.eq`, fact-sensitive `ref.as_non_null`, `i31.get_s` / `i31.get_u`, or typed `select` results whose value operands are both proven `ref.i31`, or an `anyref` candidate flows through nontrapping `extern.convert_any` / `any.convert_extern` / `ref.is_null`, with transparent result-block wrappers around the supported conversion chain when covered, before the outer same-global write guard. The paired negatives keep the global mutable when the ordinary `ref.test` / reference-test boolean result feeds a post-consumer call before the final branch, preserve `ref.as_non_null`-fed `ref.test` because the operand may trap first, and preserve nullable, mixed-select, or otherwise non-`ref.i31`-proven `i31.get_s` because it can trap. The `ref.eq` / conversion fixtures use `ref.i31` initializers or non-null-to-null writes where needed so the tests prove read-only-to-write FlowScanner behavior instead of same-as-init null cleanup.

The numeric post-consumer follow-up applies the same rule to nontrapping numeric conversions and float arithmetic: int-to-float conversions, `f32.demote_f64`, `f64.promote_f32`, saturating float-to-int truncations, and `f32.div` / `f64.div` may sit between the nested-if arm result and the final branch condition. Starshine still preserves regular float-to-int truncations such as `i32.trunc_f32_s`, because they can trap before the final branch and therefore cannot be treated as removable condition-only flow.

The size-query follow-up treats `memory.size` and `table.size` as clean nullary values in the same stack/value-flow scanner, so a direct self-guard, nested-if arm result, or nested transparent block-wrapped condition may combine the candidate read with those size queries before the final branch. The paired guardrails keep `memory.grow` and `table.grow` conservative when the global-derived value determines the size-changing side effect.

The SIMD follow-ups admit a parser-backed nontrapping subset: `i32` candidates can flow through `i32x4.splat` and then `i32x4.all_true`, `i32x4.bitmask`, `i32x4.extract_lane`, a clean `i32x4.add` or `i32x4.eq` chain, or `i8x16.splat` plus `i8x16.add` / `i8x16.popcnt` / `i8x16.bitmask` / `i8x16.all_true`; `i16x8.splat` / `i16x8.abs` / `i16x8.neg` / `i16x8.eq` / `i16x8.all_true` / `i16x8.bitmask`, `i64x2.splat` / `i64x2.neg` / `i64x2.eq` / `i64x2.bitmask` / `i64x2.all_true`, `f32x4.splat` / `f32x4.abs` / `f32x4.neg` / `f32x4.sqrt` / `f32x4.div` / compare / all-true, and `f64x2.splat` / `f64x2.abs` / `f64x2.neg` / `f64x2.add` / compare / all-true chains are also covered. The 2026-05-21 lane/shift/replace slice adds nontrapping lane extracts for `i8x16`, `i16x8`, `i64x2`, `f32x4`, and `f64x2`, all six `*.replace_lane` forms, and `shl` / `shr_s` / `shr_u` for `i8x16`, `i16x8`, `i32x4`, and `i64x2`. The SIMD comparison follow-up fills in the remaining parser-backed integer and float lane comparisons for `i8x16`, `i16x8`, `i32x4`, `i64x2`, `f32x4`, and `f64x2`. The SIMD arithmetic follow-up adds basic nontrapping SIMD arithmetic/unary ops (integer lane abs/neg, saturating add/sub, sub/mul/min/max/avgr, `i64x2.add`/`sub`/`mul`, f32/f64 ceil/floor/trunc/nearest/sqrt and add/sub/mul/div/min/max/pmin/pmax). The SIMD core-bitwise follow-up adds WAT-lowered `v128.not`, `v128.any_true`, bitwise `v128.and` / `v128.andnot` / `v128.or` / `v128.xor`, `i8x16.shuffle`, `i8x16.swizzle`, and ternary `v128.bitselect` chains; focused guardrails preserve post-consumer calls and trapping-load side effects. The SIMD extension/conversion follow-up adds parser-backed nontrapping `extend_low/high`, demote/promote, saturating vector truncation, integer-to-float vector conversion, `narrow`, `extmul`, and `i32x4.dot_i16x8_s` chains. The extadd-pairwise follow-up adds WAT parsing/lowering and FlowScanner coverage for `i16x8.extadd_pairwise_i8x16_s/u` and `i32x4.extadd_pairwise_i16x8_s/u`. Starshine now has a generic block-yielded FlowScanner check for flat or nested transparent result blocks, so supported size-query and SIMD chains can be wrapped in a transparent result block before the final branch. The same supported chains can now guard exact `if return; set` bodies, including external `i32.eqz` and block-wrapped-set variants. A clean value-producing `if` inside such a block condition may also yield a supported size-query or SIMD chain from one arm when the wrapper condition is independent of the candidate global; the same subset applies to exact `if return; set` block conditions. Starshine preserves the paired negatives where the SIMD lane/shift/replace-lane/compare/arithmetic/core-bitwise/extadd-pairwise/extension/conversion result or boolean feeds a post-consumer call, where the global-derived value is a SIMD load address, where a block-yielded if-return condition feeds a trapping load, or where a clean wrapper arm feeds the candidate global to a trapping load.

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

Binaryen's source accepts more than adjacent `global.get`, `i32.eqz`, or compare-const conditions. Any condition expression can qualify if the actual `global.get` only flows to the final branch decision and does not steer side effects. Starshine covers a narrow source-backed pure integer condition subset, including arithmetic/compare operators, non-trapping unary `i32.clz` / `i32.ctz` / `i32.popcnt`, non-trapping bitwise `i32.and` / `i32.or` / `i32.xor`, non-trapping shift/rotate `i32.shl` / `i32.shr_s` / `i32.shr_u` / `i32.rotl` / `i32.rotr`, source-backed `i64.eqz` / `i64` compare operators, non-trapping i64 value operators (`i64.clz` / `i64.ctz` / `i64.popcnt`, `i64.add` / `i64.sub` / `i64.mul`, `i64.and` / `i64.or` / `i64.xor`, and `i64.shl` / `i64.shr_s` / `i64.shr_u` / `i64.rotl` / `i64.rotr`) feeding those final conditions, and `f32` / `f64` equality/relational compares:

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

The 2026-05-18 unary, bitwise, shift/rotate, i64-compare, i64-value, and float-compare slices were backed by local Binaryen probes showing `wasm-opt --simplify-globals` promotes matching `i32.clz` / `i32.ctz` / `i32.popcnt`, `i32.and` / `i32.or` / `i32.xor`, `i32.shl` / `i32.shr_s` / `i32.shr_u` / `i32.rotl` / `i32.rotr`, `i64.eqz` / `i64` compare guards, non-trapping i64 value operators feeding `i64.eqz`, and `f32` / `f64` compare guards to immutable globals while replacing the get/set uses. The same pure-condition subset now also applies when the condition chain is inside a transparent result block, and to both direct and block-wrapped exact whole-body `if return; set` families, where the return guard precedes the same-global constant write and trailing code still blocks the match. Starshine now also accepts pure `select` self-guards where the other two select operands are constants and the global-derived value is the select condition input, first selected value input, or second selected value input. Keep that distinct from the official safe-side-effect family because broader side-effect cases need Binaryen-style upward value-flow reasoning. As of 2026-05-20, Starshine accepts a conservative side-effecting subset from the official family: independent `local.tee` and `i32.load` operands are preserved, while a single actual `global.get $g` may flow through supported non-trapping pure ops such as `i32.add` and `i32.xor`, then through `select; i32.eqz`, and finally into the outer same-global write guard. The global-derived value may be the `select` condition input, the first selected value input, or the second selected value input in the covered stack forms. Starshine also accepts lit-style nested `if (result i32)` arm-flow cases where a call with clean operands, supported pure chain, local tee, or load decides the nested arm and the candidate global appears only in a value arm, not as the nested condition; independent arm-local calls are preserved when they do not consume the global-derived value. Narrow follow-ups allow clean arm-local `local.tee` / `i32.load` effects, transparent value blocks around the arm result, post-if `select` value use with clean sibling operands, and nested-if results that pass through supported pure post-if consumers such as `i32.eqz` before the outer branch. Starshine preserves those side effects while removing the fake global state, and still keeps negatives where the global is consumed by a trapping memory load before the branch, escapes through `local.tee` / `drop`, appears multiple times in one condition, steers the nested `if`, feeds a post-if call operand, feeds a trapping post-if load after `select`, feeds a trapping load inside a transparent arm block, or reaches unsupported value-flow shapes.

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

- [`../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`](../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md)
- [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`](../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md)
