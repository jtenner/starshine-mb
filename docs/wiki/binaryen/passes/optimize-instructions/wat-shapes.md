---
kind: concept
status: supported
last_reviewed: 2026-06-19
sources:
  - ../../../raw/binaryen/2026-05-05-optimize-instructions-current-main-recheck.md
  - ../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ./starshine-strategy.md
  - ../../../wast/code-metadata-and-function-annotations.md
  - ../../no-dwarf-default-optimize-path.md
---

# `optimize-instructions` WAT shapes

This page is the beginner-friendly shape catalog for Binaryen's `optimize-instructions` pass. The 2026-06-19 `version_130` matrix now maps these shapes to active Starshine O4z slices; the examples remain explanatory, while implementation ownership lives in [`../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md`](../../../raw/binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md).

## Read this page with one mental model

Binaryen is usually trying to do one of four things:

1. rewrite an instruction into a more canonical spelling
2. remove work that is provably redundant
3. expose a simpler instruction family for later passes
4. preserve the same effects and type facts while changing the surface shape

The last point matters most.

This pass is full of local rewrites that are only legal because Binaryen checked:

- effect order
- trap behavior
- bit-width facts
- type compatibility
- feature availability

## Quick glossary

- **canonical form**: the spelling Binaryen prefers before doing more matching
- **fallthrough value**: the expression value that actually emerges after wrappers like tees or blocks
- **bit-width fact**: `Bits::getMaxBits(...)` or related proof about how many bits a value can really use
- **TNH / IIT**: `trapsNeverHappen` / `ignoreImplicitTraps`
- **dropped-children append**: rebuild side-effectful children, then append a new result

## Shape family 1: compare-to-zero canonicalization

Before:

```wat
(i32.eq
  (local.get $x)
  (i32.const 0))
```

After:

```wat
(i32.eqz
  (local.get $x))
```

Related families:

- signed compare to `-1` or `1` becomes a compare to `0`
- unsigned compare to `1` may become `eq` / `ne` against `0`
- some compare-to-near-min or near-max cases become exact compare-to-min/max

Why Binaryen likes this:

- the zero form is simpler
- later boolean and ternary helpers understand `eqz` very well

Same-local integer compares also collapse when both operands are the same `local.get`:

```wat
(i32.eq (local.get $x) (local.get $x)) ;; -> i32.const 1
(i64.lt_s (local.get $y) (local.get $y)) ;; -> i32.const 0
```

Starshine now covers this direct local subset for integer `eq`/`ne` and signed/unsigned `lt`/`le`/`gt`/`ge`; it does not claim a broader expression-identity proof for effectful or trapping operands.

A first `maxBits`-style unsigned subset folds when an `and` mask bounds the left operand below the compared constant. Starshine now preserves effectful i32 and i64 masked operands by dropping the evaluated masked value before the folded constant. First recursive-width facts also handle direct i32/i64 unsigned-right-shift results with constant shift amounts `1..31` / `1..63`, including direct child `and`/`shr_u` facts such as `(x & 1023) >>> 4`. Starshine also covers the first direct i32 sign-extension equality range facts for `i32.extend8_s` / `i32.extend16_s` compared with constants outside the signed lane range.

```wat
(i32.eq (i32.and (local.get $x) (i32.const 255)) (i32.const 256)) ;; -> i32.const 0
(i32.lt_u (i32.and (local.get $x) (i32.const 255)) (i32.const 256)) ;; -> i32.const 1
(i32.ge_u (i32.and (local.get $x) (i32.const 255)) (i32.const -1)) ;; -> i32.const 0
(i64.eq (i64.and (local.get $y) (i64.const 255)) (i64.const 256)) ;; -> i32.const 0
(i32.lt_u (i32.shr_u (local.get $x) (i32.const 8)) (i32.const 16777216)) ;; -> i32.const 1
(i64.lt_u (i64.shr_u (local.get $y) (i64.const 8)) (i64.const 72057594037927936)) ;; -> i32.const 1
(i32.eq (i32.shr_u (i32.and (local.get $x) (i32.const 1023)) (i32.const 4)) (i32.const 64)) ;; -> i32.const 0
(i64.eq (i64.shr_u (i64.and (local.get $y) (i64.const 1023)) (i64.const 4)) (i64.const 64)) ;; -> i32.const 0
```

For i32 and i64, effectful direct masked operands are preserved with an explicit drop before the folded `i32.const`; for example, `((call $effect) & 255) == 256` becomes `drop(i32.and(call $effect, 255)); i32.const 0`, and the i64 spelling uses `i64.and` under the same drop. Effectful direct i32/i64 `shr_u` bounded operands likewise become `drop(i32.shr_u(...)); i32.const result` or `drop(i64.shr_u(...)); i32.const result`, including a direct nested mask child under the dropped shift. The remaining boundaries are dynamic/zero shift amounts, signed range proofs, local-scanner facts, select/phi/load/extension width facts, and broader recursive `maxBits` expressions unless covered by later slices.

## Shape family 2: negative-add and subtraction spelling

Before:

```wat
(i32.add
  (local.get $x)
  (i32.const -5))
```

Canonical after:

```wat
(i32.sub
  (local.get $x)
  (i32.const 5))
```

But there is an important counter-shape.

For some signed-LEB-friendly powers of two, Binaryen may prefer the negative spelling instead of the positive one because the encoded constant is smaller.

So the real rule is:

- canonicalization is partly algebraic
- and partly encoding-aware

## Shape family 2a: direct same-local integer binary operands

Before:

```wat
(i32.sub (local.get $x) (local.get $x))
(i64.xor (local.get $y) (local.get $y))
(i32.and (local.get $x) (local.get $x))
```

After:

```wat
i32.const 0
i64.const 0
local.get $x
```

Starshine covers this only for direct identical `local.get` operands: `sub` and `xor` fold to zero, while `and` and `or` fold to the local value for i32 and i64. Broader expression identity is not claimed.

## Shape family 2b: commutative operand canonicalization

Before:

```wat
(i32.add
  (i32.const 7)
  (local.get $x))
```

After when reordering is safe:

```wat
(i32.add
  (local.get $x)
  (i32.const 7))
```

What to remember:

- Starshine's HOT canonicalizer now reorders ranked value nodes for commutative
  binary instructions (`add`, `mul`, `and`, `or`, `xor`, and related
  commutative comparisons) only after `optimize_instructions_subtrees_can_swap`
  proves the two operand subtrees can exchange positions safely
- calls (`call`, `call_indirect`, and value-producing `call_ref`) rank before
  locals/constants to match Binaryen's call-first commutative spelling, so
  `local.get + call` and `const * call` become `call + local.get` and
  `call * const` when the proof allows the swap
- constants move behind local gets, higher-numbered local gets sort after
  lower-numbered local gets, and nested expression nodes move behind simpler
  local/global/load/constant forms when the effect proof allows it
- unsafe reorder cases still stay in source order, including same-local
  `local.tee`/`local.get` conflicts, memory write/read conflicts such as
  `load + call`, may-trap past side-effect hazards such as `local.tee + call`,
  and control-flow operands
- this is HOT canonicalizer behavior, but the public/raw pipeline now admits
  the narrow stack-style form `pure local.get/const; no-param direct call;
  commutative integer binop`, so simple `local.get + call` functions reach HOT
  and get the same call-first spelling. It also admits flat tiny `memory.copy`
  sequences whose address operands may independently be local/constant/global
  operands, no-param direct-call operands, or direct calls with pure
  local/constant/global arguments, plus flat byte `memory.fill` sequences with
  local/constant/global, no-param-call, or pure-argument direct-call
  destination/value operands; mixed
  flat tiny-copy/byte-fill functions are covered by the same raw gate; broader
  stack-carried call/effect shapes still remain behind
  `stack-carried-effect-optimize-instructions-noop` until a localizing/HOT
  lowering slice proves them safe.

## Shape family 3: eliminate `0 - x` wrappers inside adds

Before:

```wat
(i32.add
  (i32.sub
    (i32.const 0)
    (local.get $x))
  (local.get $y))
```

After when reordering is safe:

```wat
(i32.sub
  (local.get $y)
  (local.get $x))
```

What to remember:

- this leading form `(0 - x) + y -> y - x` actually reorders the two value
  computations (`x` and `y` swap positions), so it is gated on a sound
  operand-reorder proof, not on operand purity
- the trailing form `y + (0 - x) -> y - x` keeps both computations in order and
  needs no reorder check
- the reorder is allowed only when the two operand subtrees can swap without
  changing observable behavior. Starshine implements this as
  `optimize_instructions_subtrees_can_swap`, mirroring Binaryen's reorder rule:
  - no read-after-write / write-after-read / write-after-write conflict on
    locals, globals, memory, or tables (read × read is fine, which is why
    `local.get × local.get`, `load × load`, and `local.get × call` reorder)
  - no may-trap-or-throw operand reordered past a side effect (which is why
    `(0 - load) + local.tee` and `(0 - memory.grow) + load` stay put)
  - control-flow operands never swap, because their region bodies are outside
    the aggregated effect masks
- a `call` is modeled as may-trap and opaque global/memory/table state, but it
  never reads or writes the caller's locals; therefore a caller-local-only read
  like `local.get` can swap past a `call`:
  `(0 - call) + local.get -> local.get - call`

## Shape family 3b: eliminate double `0 - x` wrappers inside a mul

Before:

```wat
(i32.mul
  (i32.sub (i32.const 0) (local.get $x))
  (i32.sub (i32.const 0) (local.get $y)))
```

After:

```wat
(i32.mul (local.get $x) (local.get $y))
```

What to remember:

- this is `-x * -y -> x * y` for both `i32` and `i64`, implemented as
  `optimize_instructions_try_rewrite_mul_negation`
- unlike the leading add form above, the mul negation is stripped in place on
  both factors, so it does **not** reorder the operands and needs no
  `subtrees_can_swap` proof
- because there is no reorder, the rewrite applies even when a factor carries
  effects, as long as both factors are negated the same way:
  `(0 - call) * (0 - y) -> call * y`

## Shape family 4: shift-mask cleanup

Before:

```wat
(i32.shl
  (local.get $x)
  (i32.and
    (local.get $y)
    (i32.const 31)))
```

After:

```wat
(i32.shl
  (local.get $x)
  (local.get $y))
```

And if the mask proves the effective shift is always zero:

```wat
(i32.shl
  (local.get $x)
  (i32.and
    (local.get $y)
    (i32.const 32)))
```

may simplify to just:

```wat
(local.get $x)
```

but only if removing the right side would not erase needed side effects.

## Shape family 5: power-of-two multiply / divide / remainder

Before:

```wat
(i32.mul
  (local.get $x)
  (i32.const 8))
```

After:

```wat
(i32.shl
  (local.get $x)
  (i32.const 3))
```

Other related families:

- `u32(x) % 8 -> x & 7`
- `u32(x) / 8 -> x >> 3`
- power-of-two float divide may become multiply by the inverse power-of-two

These are classic peepholes, but here they live inside a much broader pass.

## Shape family 6: sign-extension idioms

Before:

```wat
(i32.shr_s
  (i32.shl
    (local.get $x)
    (i32.const 24))
  (i32.const 24))
```

After when the sign-extension opcode is available:

```wat
(i32.extend8_s
  (local.get $x))
```

And if the child is already known to be sign-extended enough, Binaryen may remove a later sign-extension wrapper entirely.

This family is one of the best examples of why the local pre-scan matters.

Sometimes the proof does not come from the syntax at the read site.

It comes from what earlier `local.set`s taught the pass about that local.

## Shape family 7: boolean-context cleanup

Before:

```wat
(if
  (i32.eqz
    (i32.eqz
      (local.get $x)))
  (then ...)
)
```

After:

```wat
(if
  (local.get $x)
  (then ...)
)
```

Other families in boolean context:

- `x != 0` may become `x`
- invertible comparisons may flip under `eqz`
- `% power-of-two` tests may become masked tests
- sign-extended boolean producers may become cheaper zero-extended forms

## Shape family 8: `if` condition inversion by removing `eqz`

Before:

```wat
(if
  (i32.eqz (local.get $cond))
  (then A)
  (else B)
)
```

After:

```wat
(if
  (local.get $cond)
  (then B)
  (else A)
)
```

Important hidden rule:

- Binaryen also flips branch-hint metadata here via `BranchHints::flip(...)`

So this is not just a structural swap.

It is also a metadata repair step.

## Shape family 9: identical-arm `if` folding

Before:

```wat
(if (result i32)
  (local.get $cond)
  (then
    (i32.add (local.get $x) (i32.const 1)))
  (else
    (i32.add (local.get $x) (i32.const 1)))
)
```

Possible after:

```wat
(i32.add (local.get $x) (i32.const 1))
```

or, if the condition still has side effects:

```wat
(block (result i32)
  (drop (local.get $cond))
  (i32.add (local.get $x) (i32.const 1))
)
```

Important negative shape:

- Binaryen avoids folding into an expression that would incorrectly change a concrete expression into an unreachable one without the right wrapper typing.

## Shape family 10: `select` between boolean-shaped values

Before:

```wat
(select (result i32)
  (i32.const 1)
  (local.get $y)
  (local.get $x))
```

Possible after:

```wat
(i32.or
  (local.get $y)
  (local.get $x))
```

And similarly:

- `x ? y : 0 -> x & y`
- `cond ? 1 : 0 -> booleanized cond`
- some `x ? x : 0` families collapse to `x`

This is one of the clearest signs that the pass is not just arithmetic cleanup.

## Shape family 11: hoist duplicated one-child wrappers out of `if` / `select`

Before, conceptually:

```wat
(select
  (i32.eqz X)
  (i32.eqz Y)
  Z)
```

After:

```wat
(i32.eqz
  (select
    X
    Y
    Z))
```

But only if the pass can prove all of these are safe:

- the shell is shallow-equal on both arms
- the shell has one child
- child types remain compatible
- for `select`, side effects do not make the hoist invalid
- select-arm emission remains valid after the change

This is a common misunderstanding boundary.

The pass is *willing* to hoist duplicated shells, but it is much pickier than “same outer opcode, therefore hoist.”

## Shape family 12: offset folding on loads and stores

Before:

```wat
(i64.load offset=4
  (i64.const 6))
```

After when the address space and overflow rules allow it:

```wat
(i64.load
  (i64.const 10))
```

Important caveat:

- Binaryen does this only when folding the offset into the pointer cannot overflow the effective address representation.
- memory32 and memory64 have different safe ranges here.
- Starshine's public/raw pipeline now admits the exact load/call escape `i32.const; nonzero-offset scalar load; drop; call`, so the direct HOT offset fold also runs when a direct call follows the dropped load. Nonconstant-pointer load/drop/call shapes such as `local.get; i32.load offset=4; drop; call` are source-backed keep-spelling boundaries, and broader mixed load/call functions remain behind `load-call-optimize-instructions-noop`.

## Shape family 13: narrow-store cleanup

Before:

```wat
(i32.store8
  (local.get $p)
  (i32.and
    (local.get $x)
    (i32.const 255)))
```

After:

```wat
(i32.store8
  (local.get $p)
  (local.get $x))
```

Why it folds:

- the narrow store already keeps only the low byte
- the explicit mask is redundant

Related store families:

- truncate stored constants to the store width
- widen direct one-use `i32.wrap_i64` values under `i32.store8` / `i32.store16` / `i32.store` to matching `i64.store8` / `i64.store16` / `i64.store32`, preserving source store memargs
- keep local-carried/shared `i32.wrap_i64` values before narrow i32 stores for the probed `local.tee` shape, matching Binaryen `version_130`
- classify sign-extension-before-store spellings carefully; Binaryen `version_130` keeps the probed explicit sign-extension opcodes before narrow stores, so Starshine treats those as parity boundaries today
- rewrite reinterpret-store pairs into stores of the original representation type when possible, preserving the source store memargs
- keep the probed local-carried/shared reinterpret-store forms where `local.tee(f32.reinterpret_i32(...))` or `local.set`/`local.get` feeds `f32.store`
- rewrite full-width load plus reinterpret-result pairs into loads of the final result type when the load is one-use
- rewrite one-use i32 loads under `i64.extend_i32_u` / `i64.extend_i32_s` into matching i64 loads when the intermediate i32 load semantics are preserved
- keep the probed local-carried/shared load-result forms where `local.tee(i32.load)` feeds reinterpret or `i64.extend_i32_*`

Starshine now covers the direct one-use `i32.wrap_i64` store-widening, direct reinterpret-store, one-use reinterpret-load, and one-use i64 extend-load subsets observed in Binaryen `version_130`. Replacement stores and loads preserve the source memarg offset and alignment. Local-carried/shared wrap-store, load-result, and reinterpret-store spellings are now explicit keep-spelling boundaries rather than hidden one-use parity claims:

```wat
(i32.store8 offset=4 (local.get $p) (i32.wrap_i64 (local.get $x))) ;; -> i64.store8 offset=4
(i32.store8 (local.get $p) (local.tee $tmp (i32.wrap_i64 (local.get $x)))) ;; kept
(f32.store (local.get $p) (f32.reinterpret_i32 (local.get $x))) ;; -> i32.store
(f32.store (local.get $p) (local.tee $tmp (f32.reinterpret_i32 (local.get $x)))) ;; kept
(f64.store (local.get $p) (f64.reinterpret_i64 (local.get $y))) ;; -> i64.store
(i32.store (local.get $p) (i32.reinterpret_f32 (local.get $f))) ;; -> f32.store
(i64.store (local.get $p) (i64.reinterpret_f64 (local.get $g))) ;; -> f64.store
(f32.reinterpret_i32 (i32.load (local.get $p))) ;; -> f32.load
(f64.reinterpret_i64 (i64.load (local.get $p))) ;; -> f64.load
(i32.reinterpret_f32 (f32.load (local.get $p))) ;; -> i32.load
(i64.reinterpret_f64 (f64.load (local.get $p))) ;; -> i64.load
(i64.extend_i32_u (i32.load (local.get $p))) ;; -> i64.load32_u
(i64.extend_i32_s (i32.load8_u (local.get $p))) ;; -> i64.load8_u
(i64.extend_i32_s (i32.load16_s (local.get $p))) ;; -> i64.load16_s
```

## Shape family 14: tiny `memory.copy` and `memory.fill`

Before:

```wat
(memory.copy
  (local.get $dst)
  (local.get $src)
  (i32.const 4))
```

Possible after:

```wat
(i32.store
  (local.get $dst)
  (i32.load (local.get $src)))
```

For size `16`, Binaryen and Starshine use the same one-load/one-store shape with SIMD:

```wat
(v128.store
  (local.get $dst)
  (v128.load (local.get $src)))
```

And under IIT / TNH:

```wat
(memory.copy
  X
  X
  size)
```

may become a block of drops.

Likewise:

```wat
(memory.fill
  (local.get $dst)
  (i32.const 0)
  (i32.const 4))
```

may become a single `store` of a repeated-byte constant pattern. Starshine also lowers direct `local.get` fill values for sizes `2`/`4`/`8` by building the repeated-byte pattern from the low byte. For constant size `16` fills, Starshine now matches Binaryen's one-store SIMD shape with a repeated-byte `v128.const` plus `v128.store`. For size `1`, flat local or no-param-call values also lower directly to `i32.store8`. Non-local wider fill values such as direct calls or computed `i32.add` values for sizes `2`/`4`/`8` are now explicit keep-spelling boundaries matching Binaryen `version_130`, not missing materialization.

Effectful flat copy operands and byte-fill values are also covered for narrow no-param-call and pure-argument direct-call shapes:

```wat
(memory.copy
  (call $dst)
  (call $src)
  (i32.const 8))
```

becomes `i64.store(i64.load(call $src))` for size `8`, or the corresponding `v128.store(v128.load(...))` for size `16`, with the destination call emitted before the nested source load, matching Binaryen's observed evaluation order. The tiny-copy raw-gate escape also covers pure-argument direct-call address forms, `global.get` operands used directly or as call arguments, source-backed mixed combinations, and mixed straight-line functions that contain both tiny copy and byte fill:

```wat
(memory.copy
  (call $dst (local.get $d))
  (call $src (local.get $s))
  (i32.const 8))

(memory.copy
  (call $dst (local.get $d))
  (call $src0)
  (i32.const 1))

(memory.copy
  (call $dst2 (local.get $d) (local.get $v))
  (call $src2 (local.get $s) (local.get $d))
  (i32.const 1))
(memory.fill
  (call $dst2 (local.get $d) (local.get $v))
  (call $value2 (local.get $d) (local.get $v))
  (i32.const 1))

(memory.copy
  (call $dst (global.get $d))
  (call $src (global.get $s))
  (i32.const 1))
```

Similarly, `local.get $dst; call $value; i32.const 1; memory.fill`, `global.get` byte-fill operands, and pure-argument byte-fill operands become `i32.store8`:

```wat
(memory.fill
  (call $dst (local.get $d))
  (call $value (local.get $v))
  (i32.const 1))

(memory.fill
  (global.get $d)
  (call $value (global.get $v))
  (i32.const 1))
```

Important negative shape:

- zero-size or same-src/dst cases are not blindly dropped in default mode; trap assumptions matter.
- non-flat, non-pure call arguments, nonconstant-size, wider call-backed fill, and broader control/effect copy forms still need separate localization proof.

## Shape family 15: `call_ref` with known target

Before:

```wat
(call_ref $sig
  (local.get $x)
  (ref.func $f))
```

After:

```wat
(call $f
  (local.get $x))
```

Other positive families:

- `call_ref(table.get ...) -> call_indirect`, including the covered call-indexed table case where the index-producing direct call is preserved as the indirect-call table index
- if the target's fallthrough is a `ref.func`, directize while preserving target-side effects and operand order; Starshine covers zero-argument forms and single-result argument localization through temp locals before dropping the target
- select-of-known-direct-targets can become an `if` over direct calls or return-calls

Important negative shapes:

- if the target type would no longer match the call's expected heap type, Binaryen must not directize
- if the target or operand ordering would be wrong, Binaryen uses locals / block wrappers instead of a naive replacement
- Starshine currently keeps multi-result argument select-of-`ref.func` `call_ref` and `return_call_ref` unchanged even though Binaryen localizes the probed `call $pair` through a tuple scratch and scalar locals before direct call or tail-call `if` arms; this remains an explicit OI-H tuple-scratch localization boundary

## Shape family 16: null-trapping GC operations remove earlier non-null checks

Before:

```wat
(struct.get $S 0
  (ref.as_non_null
    (local.get $r)))
```

Possible after:

```wat
(struct.get $S 0
  (local.get $r))
```

But only if moving or deleting the earlier null trap does not cross invalidating side effects.

So the real positive shape is not:

- “struct.get always deletes ref.as_non_null”

It is:

- “struct.get may absorb an earlier non-null check when trap ordering stays honest.”

## Shape family 17: cast and test outcomes known statically

Before:

```wat
(ref.test (ref $Child)
  (local.get $child))
```

Possible after:

```wat
(block (result i32)
  (drop (local.get $child))
  (i32.const 1))
```

Or, for impossible cases:

```wat
(block (result i32)
  (drop ...)
  (i32.const 0))
```

Or for impossible-success casts:

```wat
(unreachable)
```

This whole family is driven by compile-time cast-result classification, not by generic constant folding.

## Shape family 18: `ref.eq` canonicalization and simplification

Before:

```wat
(ref.eq
  (local.get $x)
  (ref.null eq))
```

After:

```wat
(ref.is_null
  (local.get $x))
```

And if the two heap types do not overlap and at least one side cannot be null, Binaryen can replace the equality with `0`.

This is a good example of type-structure reasoning inside the pass.

## Shape family 19: default-value GC constructors

Before:

```wat
(struct.new $S
  (i32.const 0)
  (ref.null any))
```

After when those are the default values:

```wat
(struct.new_default $S)
```

Similarly for arrays:

- repeated default values can become `array.new_default`
- repeated equal non-default values can become `array.new` with one value and a size

## Shape family 20: unshared GC RMW / cmpxchg lowering

Before, conceptually:

```wat
(struct.rmw.add $S 0
  ref
  value)
```

Possible after on unshared heaps:

```wat
(block (result i32)
  (local.set $ref ...)
  (local.set $val ...)
  (local.set $old
    (struct.get $S 0 (local.get $ref)))
  (struct.set $S 0
    (local.get $ref)
    (i32.add (local.get $old) (local.get $val)))
  (local.get $old))
```

This is an important surprise family.

The pass is not just removing instructions here.

It is also lowering some higher-level GC atomic ops into more basic forms when the memory-sharing rules make that safe.

Important negative shape:

- shared `seqcst` GC RMW / cmpxchg is deliberately *not* lowered this way.
- Starshine's current OI-L boundary is even earlier: the local text/core aggregate atomic surface supports `struct.atomic.get*` only, not `struct.atomic.rmw.*` or `struct.atomic.rmw.cmpxchg`. Binaryen `version_130` optimizes probed acqrel/acqrel non-mutating forms (`add 0`, `and -1`, and equal expected/replacement cmpxchg) to `struct.get`-like reads, but Starshine records those as unsupported representation gaps until aggregate RMW/cmpxchg constructors exist locally.

## Shape family 21: `tuple.extract(tuple.make(...))`

Before:

```wat
(tuple.extract 0
  (tuple.make
    A
    B))
```

After, conceptually:

```wat
(block (result t0)
  ;; preserve side effects of the whole tuple creation
  ;; tee the chosen lane
  chosen-lane)
```

The actual implementation uses a temp local and dropped-children rebuilding so the selected lane survives while the rest of the tuple side effects remain honest. Current Starshine coverage includes pure omitted siblings, selected lanes that may trap such as `i32.load`, the selected trapping lane after an earlier effectful sibling, the selected trapping lane plus a later effectful sibling, and single-result effectful or trapping siblings before and after the selected lane: earlier effects/trapping loads are dropped before the selected lane, later effects/trapping loads force a selected-lane `local.set`, then later effects/trapping loads are dropped before reloading the selected value. A 2026-06-25 neighbor test proves that this covered single-result effectful-sibling spelling remains explicit after `simplify-locals-nostructure`. Full `simplify-locals` and dedicated `tuple-optimization` on the public multivalue-block probe are not parity yet: Binaryen reconstructs tuple scratch plus scalar locals, while Starshine keeps the block/drop spelling and direct-HOT replay of the full-simplify shape currently hits `InvalidChildRef`. Other 2026-06-25 boundary tests lock local-carried / multi-use tuple extraction as a keep-spelling shape and multi-result non-selected siblings and multi-result selected children (including the covered selected-second lane) as tuple-scratch localization boundaries under Binaryen `version_130`; implementation of multi-result selected/sibling scratch/drop reconstruction, any future safe multi-use tuple proof, public tuple text coverage, and broader tee/drop reconstruction remain open.

## Negative / bailout families

These are just as important as the positive shapes.

## Unreachable expressions are often left alone

The pass often checks for `type == unreachable` and bails.

Why:

- the pass relies on later refinalization
- many unreachable cleanup stories are better handled by DCE or vacuum-like cleanup

So upstream `optimize-instructions` is not trying to be the generic unreachable normalizer.

## No generic constant-if folding here

This deserves repeating.

Upstream `visitIf()` does not simply pick the taken arm when the condition is constant.

That is a useful distinction from both `precompute` and the current Starshine HOT implementation.

## No blind code motion

If a rewrite would require reordering effectful children, Binaryen checks that explicitly.

Many tempting algebraic rewrites are only legal when:

- `EffectAnalyzer::canReorder(...)` or equivalent reasoning says so

## Branch hints can block folding and reordering

The pass supports a special argument:

- `optimize-instructions-never-fold-or-reorder`

This exists so branch-hint fuzzing does not become invalid when:

- code with different hints would fold together, or
- a branch hint would move earlier than a trap and start executing in a new place

That is a very specific but very real bailout family. For Starshine's current lack of expression-level branch-hint/code-metadata support, use [`../../../wast/code-metadata-and-function-annotations.md`](../../../wast/code-metadata-and-function-annotations.md) instead of treating Binaryen branch-hint examples as local WAST parser evidence.

## Cast removal is deliberately conservative

Even in TNH mode, Binaryen does not erase casts blindly.

Important preserved families include cases where removing the cast would:

- lose exactness
- lose descriptor information
- lose useful subtype facts for later optimization

## `select` hoisting is limited

The pass refuses some duplicated-shell hoists when:

- the shell is a control-flow structure
- child types do not match tightly enough
- select-arm emission would stop being valid
- moving the shell would alter effect behavior

## Shared seqcst GC atomics are protected

This is a strong preserved boundary.

The pass intentionally avoids “obvious” rewrites that would be wrong once synchronization semantics matter.

## How this pass interacts with nearby passes

Early neighborhood:

- comes after `remove-unused-brs`
- before `heap-store-optimization`
- before `pick-load-signs`
- before `precompute` / `precompute-propagate`
- before `code-pushing` and tuple/local cleanup

Late neighborhood:

- after `merge-blocks`, `remove-unused-brs`, and late propagation
- before late `heap-store-optimization`
- before `rse`
- before final `vacuum`

That placement means the pass often sees:

- cleaner boolean/control shapes than earlier phases did
- and then produces cleaner tiny instruction spellings for even later cleanup passes

## Bottom line

Binaryen `optimize-instructions` rewrites many more shapes than its name suggests.

The most important pattern families to remember are:

- compare / zero / boolean canonicalization (`[O4Z-AUDIT-OI-D]` and `[O4Z-AUDIT-OI-F]` for the remaining local gaps)
- add/sub / shift / power-of-two cleanup (`[O4Z-AUDIT-OI-D]`)
- sign-extension and bit-width reasoning (`[O4Z-AUDIT-OI-E]`)
- `if` / `select` ternary shell simplification (`[O4Z-AUDIT-OI-F]`)
- memory and bulk-memory lowering (`[O4Z-AUDIT-OI-G]`)
- `call_ref` directization (`[O4Z-AUDIT-OI-H]`)
- GC null-check, cast, and constructor cleanup (`[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, `[O4Z-AUDIT-OI-K]`)
- unshared GC RMW / cmpxchg lowering (`[O4Z-AUDIT-OI-L]`)
- tuple extraction simplification (`[O4Z-AUDIT-OI-M]`)

And the most important negative rule is:

- none of those are “free” rewrites unless effect order, trap behavior, and type validity still work.
