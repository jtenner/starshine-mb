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
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
---

# GC, casts, `call_ref`, and trap-sensitive rewrites in `optimize-instructions`

This page exists because the easiest wrong reading of Binaryen `optimize-instructions` is:

- “it mostly rewrites arithmetic”

The source and tests say otherwise.

A very large part of `OptimizeInstructions.cpp` is about reference-typed and GC-specific operations, especially when traps and type information interact.

## Read this page with one mental model

Binaryen is asking three related questions:

1. does this instruction already trap on null, so an earlier non-null check is redundant?
2. if I remove or weaken a cast, do I lose useful type information or reorder a trap incorrectly?
3. can I replace a reference-typed indirect shape with a more direct one without breaking effects or types?

If you keep those three questions in mind, the reference / GC half of the file becomes much easier to understand.

## The three helper pillars

## 1. `skipNonNullCast(...)`

This helper tries to remove `ref.as_non_null` when a later operation already traps on null anyway.

The important beginner caveat is:

- Binaryen still checks sibling ordering.

Example danger shape from the source comments:

```wat
(struct.set
  (ref.as_non_null X)
  (call $foo))
```

If `X` is null, the original code traps **before** `$foo`.

If Binaryen removed the `ref.as_non_null` carelessly, the later `struct.set` would still trap, but only **after** `$foo` executed.

So `skipNonNullCast(...)` does not just delete checks.

It uses effect reasoning to see whether moving the null trap later would cross invalidating work.

That is why it uses:

- sibling-order inspection
- `EffectAnalyzer`
- `ShallowEffectAnalyzer`
- special relaxation in `trapsNeverHappen` mode

## 2. `skipCast(...)`

This helper is broader than `skipNonNullCast(...)`:

- it can skip `ref.as_*` and `ref.cast`
- but only in traps-never-happen mode
- and only if the remaining type still satisfies an optional required supertype

The important thing to preserve is that this helper is **intentionally conservative**.

It is not “drop casts whenever TNH is enabled.”

Binaryen's own source comments explain why:

- removing a cast can throw away useful exactness or subtype information
- later passes may benefit from that information even if the cast is dynamically redundant

So a future port must treat cast removal as a type-information question, not just a trap question.

## 3. `trapOnNull(...)`

This helper is where Binaryen exploits the fact that a later operation already traps on null.

The helper can sometimes simplify the input reference itself.

Examples from the implementation story:

- if an `if` produces `null` on one arm and a usable value on the other, TNH mode can drop the null-producing arm if a null would only lead to a trap later
- similarly for some `select` shapes
- if the fallthrough value is definitely null, the parent can often be replaced by `unreachable` plus any preserved side-effect children
- nullable casts feeding a null-trapping operation can sometimes be tightened to non-nullable casts

This is one of the easiest parts of the pass to misunderstand.

Binaryen is not saying:

- “null doesn't matter anymore”

It is saying:

- “this null would only trigger a trap we are already accounting for, so we can simplify around that fact while preserving effect order”

## Compile-time cast reasoning: `GCTypeUtils::evaluateCastCheck(...)`

The core engine for `ref.cast` and `ref.test` simplification is `GCTypeUtils::evaluateCastCheck(...)`.

That helper classifies a cast or test outcome into cases like:

- `Unknown`
- `Success`
- `SuccessOnlyIfNonNull`
- `SuccessOnlyIfNull`
- `Failure`
- `Unreachable`

That classification then drives several families.

## `ref.cast`

Binaryen can:

- tighten the cast type first
- turn impossible casts into `unreachable`
- turn definitely successful casts into the propagated underlying value
- sometimes replace a cast with a tee-based reconstruction if the best refined fallthrough value is not the immediate child
- materialize a null result directly if success means “only if null” and TNH mode allows it

But there are important limits.

### Descriptor casts are stricter

If a cast has a descriptor operand, Binaryen cannot freely optimize based only on heap-type relations.

Why:

- the descriptor values must also match

The source explicitly says that Binaryen only optimizes some descriptor-cast cases eagerly when:

- traps-never-happen mode is on, or
- it can prove the value is null so the descriptor comparison never matters

That is an important future-port rule.

Descriptor casts are not just normal casts with one more child.

### Exactness matters

Even when the heap type relation looks redundant, Binaryen may keep a cast because it still conveys exactness.

This is a strong beginner warning:

- a “dynamically redundant” cast can still be **statically useful**

So Binaryen distinguishes:

- removing the cast entirely
- downgrading it to a null check
- keeping it because exactness would otherwise be lost

## `ref.test`

`visitRefTest(...)` parallels the `ref.cast` reasoning, but returns an `i32` boolean.

Binaryen can simplify it to:

- `1`
- `0`
- `ref.is_null`
- `eqz(ref.is_null(...))`
- a block containing a dropped child plus `unreachable`

The exact replacement depends on the cast-check lattice result.

Again, the theme is not generic constant folding.

It is:

- exploit type facts,
- but preserve effect order and reachable/unreachable structure honestly.

## `ref.eq` and `ref.is_null`

## `visitRefEq(...)`

Important families:

- if the two heap types do not overlap and at least one side is non-nullable, equality is impossible -> `0`
- skip removable casts first when equality only depends on the value, not the type
- if one side is syntactically `ref.null`, canonicalize it to the right
- `ref.eq(x, null) -> ref.is_null(x)`
- if consecutive inputs are provably equal and foldable, return `1`

A subtle but important point is that the pass uses helper logic for:

- syntactic equality
- fallthrough equality
- effect invalidation
- idempotent-call reasoning

That is why equal-looking consecutive inputs are sometimes foldable and sometimes not.

## `visitRefIsNull(...)`

The source treats `ref.is_null` carefully because even when the result is statically known, replacing it with a constant is not always obviously smaller.

Still, Binaryen does constant replacements here because they can enable more follow-up cleanup.

This is a nice example of the pass preferring:

- a better canonicalization opportunity downstream

instead of:

- only the shortest local encoding in isolation.

## `call_ref` is a real `optimize-instructions` responsibility

This is one of the most surprising parts of `version_129` if you only read the pass name.

`visitCallRef(...)` contains several distinct rewrite families.

## Direct known target

If the target is a plain `ref.func`, Binaryen emits a direct `call`.

That is the simple case.

## `table.get` target

If the target is a `table.get`, Binaryen can rewrite:

```wat
(call_ref ... (table.get $t index))
```

into:

```wat
(call_indirect $t ... index)
```

## Fallthrough-known direct target

This is more subtle.

If the target is not syntactically a `ref.func`, but the **fallthrough** value is a `ref.func`, Binaryen can still rewrite to a direct call.

That requires care because:

- the target expression may have side effects
- operands must still execute in the original order
- the target's type must match the call's expected heap type

So the implementation may:

- emit a `drop` of the target when there are no operands, or
- interpose a temp local around the last operand so the target-side work still happens in the correct relative order before the final call

This is a good example of why `ChildLocalizer`, locals, and effect ordering matter to this pass.

## Select of known direct targets

If the target is a suitable `select` of direct function references, Binaryen uses `CallUtils::convertToDirectCalls(...)` to lower it into an `if` over direct calls (or return-calls).

That is a very different family from arithmetic peepholes, but it still lives in this pass because it is fundamentally an instruction-shape simplification.

## GC field and array operations

## Non-null check removal

For operations like:

- `struct.get`
- `struct.set`
- `array.get`
- `array.set`
- `array.len`
- `ref.get_desc`

Binaryen often begins by:

- removing or moving `ref.as_non_null` via `skipNonNullCast(...)`
- then using `trapOnNull(...)`

This means the pass frequently turns:

```wat
(struct.get
  (ref.as_non_null x))
```

into a simpler form when the later `struct.get` already provides the relevant null trap.

## Default constructor simplification

### `struct.new`

If all fields are written with their default value and the fields are defaultable, Binaryen can rewrite to `struct.new_with_default` while dropping the original child expressions appropriately.

### `array.new`

If the initial value is the default and the array element type is defaultable, Binaryen can rewrite to `array.new_default`.

### `array.new_fixed`

If all values are equal:

- and equal to the default, rewrite toward a default constructor form
- and equal to some other value, rewrite to `array.new` with a size and one repeated value when that is worthwhile

These are good examples of the pass treating constructor shapes as instruction peepholes.

## Memory ordering relaxation on unshared heaps

The pass can relax some field operations on unshared heap types.

Examples:

- `struct.get` / `struct.set` with acquire-release ordering on unshared refs can become unordered because they cannot synchronize with other threads

This is a good example of a rewrite that depends on heap-type properties, not just syntax.

## GC RMW and cmpxchg

## Shared seqcst protection

For shared GC heaps with sequentially consistent RMW / cmpxchg, Binaryen deliberately refuses to optimize aggressively.

That is a real safety boundary.

## Non-mutating RMW simplification

If the update value proves the RMW does not actually change the in-memory value, Binaryen can replace the op with a plain `struct.get`-like read in some non-seqcst or unshared cases.

Examples:

- add/sub/or/xor by zero
- and by all-ones
- cmpxchg where `expected` and `replacement` are known equal

Starshine status as of 2026-06-24: this remains an explicit OI-L representation boundary. Local WAST/core support covers `struct.atomic.get*`, but not aggregate `struct.atomic.rmw.*`, `struct.atomic.rmw.cmpxchg`, array RMW, or array cmpxchg constructors. Binaryen `version_130` probes confirm the non-mutating acqrel/acqrel `struct.atomic.rmw.add 0`, `struct.atomic.rmw.and -1`, and equal expected/replacement cmpxchg shapes optimize to `struct.get`-like reads; Starshine records that as an unsupported surface, not parity.

## Unshared lowering

For unshared heaps, Binaryen can lower `struct.rmw` and `struct.cmpxchg` to explicit get / set / if / local sequences.

This intentionally increases surface code size at first, but makes the result more optimizable and is safe because no other thread can observe intermediate states in unshared memory.

This is another place where the pass is acting like a simplifier and a lowering pass at the same time.

## Trap modes: default vs IIT / TNH

A lot of this page changes meaning depending on the pass mode.

## Default mode

In default mode, Binaryen preserves trap behavior conservatively.

That means:

- no blind cast removal
- careful sibling-order checks
- descriptor casts stay stricter
- some memory.copy/fill zero-size simplifications do not fire

## `--ignore-implicit-traps` / `--traps-never-happen`

These modes unlock more aggressive simplifications, but still not unlimited ones.

Key changes include:

- some `ref.as_non_null` and `ref.cast` removal opportunities become legal
- null-producing arms feeding null-trapping operations can be deleted in more cases
- zero-size memory.copy/fill can collapse further
- static cast results that would otherwise end in a trap can become known results

But the pass still preserves useful type information where throwing it away would hurt later optimization or validity.

## What is easy to misunderstand

### 1. “TNH means we can erase all casts.”

No.

Binaryen explicitly documents why some casts still carry useful exactness or structural-type information.

### 2. “If a later instruction traps on null, moving or removing the earlier null check is always free.”

No.

Sibling ordering matters. A later trap can be wrong if effects would move across it.

### 3. “`call_ref` optimization belongs to a later whole-callgraph pass.”

Not here.

`OptimizeInstructions.cpp` itself directly owns several `call_ref` simplifications.

### 4. “GC atomics are either all optimizable or all not.”

No.

The pass distinguishes:

- shared vs unshared
- seqcst vs acqrel
- mutating vs provably non-mutating updates

## Future Starshine port rules

The 2026-06-19 `version_130` O4z matrix keeps these families open in current Starshine: `[O4Z-AUDIT-OI-H]` owns `call_ref`, `[O4Z-AUDIT-OI-I]` owns the first non-GC reference equality/null/cast/test basics, `[O4Z-AUDIT-OI-J]` owns descriptor/exactness/TNH/IIT boundaries, `[O4Z-AUDIT-OI-K]` owns non-atomic GC constructor/field/array rewrites, and `[O4Z-AUDIT-OI-L]` owns GC RMW/cmpxchg.

A future parity port needs to preserve at least these rules:

- separate `skipNonNullCast`, `skipCast`, and `trapOnNull` reasoning; they are related, but not interchangeable
- keep exactness and descriptor information honest when simplifying casts
- treat `call_ref` directization as part of this pass, not as unrelated later work
- preserve side-effect order when target-side work is kept but directized
- do not optimize seqcst shared GC RMW/cmpxchg like unshared cases
- keep the distinction between default mode and IIT/TNH mode explicit in tests and docs
- remember that some of the pass's best wins come from **using type information**, not erasing it

## Bottom line

The GC / cast / `call_ref` half of `optimize-instructions` proves that upstream Binaryen treats this pass as much more than an arithmetic peephole bag.

It is also a:

- null-trap simplifier
- cast-result refiner
- type-aware directization pass
- and conservative unshared-GC-lowering pass

That broader scope is a major part of what future Starshine parity work must preserve.
