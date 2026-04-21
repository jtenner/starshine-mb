---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0139-2026-04-20-global-refining-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./parity.md
---

# `global-refining`: exports, public types, and retagging

This page covers the hardest part of Binaryen `global-refining` to explain correctly.

The LUB algorithm itself is tiny.
The subtle part is:

- which globals are even legal to refine,
- what counts as a safe refined type at module boundaries,
- and why declaration changes force a `global.get` repair pass afterward.

## The easiest misconception

It is tempting to think:

- if closed world gives Binaryen more knowledge, then closed world should obviously let `global-refining` optimize more exported globals

That is **not** what the official `version_129` code does.

The current Binaryen rule is more conservative:

- **closed world:** skip all exported globals
- **open world:** skip exported mutable globals, but allow some immutable exported refinements

That asymmetry is deliberate and source-backed.

## The real boundary matrix

## Case 1: imported globals

Imported globals are never refined.

Why:

- this pass only reasons from the current module's initializer and writes
- imported globals are part of an external contract, not something the pass owns

## Case 2: private defined globals

Private defined globals are the main positive case.

If the initializer and all observed writes fit a narrower type, Binaryen may rewrite the declaration freely.

This is where the pass gets most of its value.

## Case 3: exported mutable globals in open world

Binaryen refuses to refine these.

Why:

- another module might import that same global using the original type
- mutable globals behave like mutable shared storage across the module boundary
- narrowing the type locally could make a previously legal external store invalid

That is why open-world mutable exports are inserted into `unoptimizable` immediately.

## Case 4: exported immutable globals in open world

This is the non-obvious positive case.

Binaryen can still refine these.

But only if the new type is a valid **public type**.

So the rule is not:

- immutable export => always safe to narrow

The real rule is:

- immutable export => safe to narrow only when the narrowed type is still valid to expose publicly

## Case 5: exported globals in closed world

The current official implementation skips all of them.

Why the code comment says that happens:

- refining from a public type to a private type could create a validation problem

Why this is surprising:

- many developers expect closed world to enable more optimization
- but the implementation here does not currently attempt the more precise "closed world but still public" distinction

The file even leaves a TODO saying Binaryen could refine closed-world exports to still-public types in the future.
Today, it does not.

## What counts as a public type here?

`PublicTypeValidator` gives the key rule.

Important beginner-friendly summary:

- basic public types are okay
- tuples are checked recursively
- exact reference types are **not** public when custom descriptors are off

That means:

### Public positive example

This kind of open-world immutable export may refine:

```wat
(global $imm-exp (ref null func) (ref.null nofunc))
(export "imm-exp" (global $imm-exp))
```

After `global-refining`, Binaryen can print it as:

```wat
(global $imm-exp nullfuncref (ref.null nofunc))
```

because `nullfuncref` is still a public type.

### Public negative example

This kind of exact refined type is not public in the same way:

```wat
(ref null (exact $foo_t))
```

So an exported immutable global is not allowed to refine to that kind of exact private heap type in open world.

## Why exactness is the tricky part

Exactness is a good example of the difference between:

- what the module internally knows
- and what the outside world is allowed to see as a stable boundary type

Inside the module, `global-refining` is perfectly happy to infer:

- `(ref (exact $foo_t))`
- `(ref null (exact $foo_t))`

for private globals.

At a public boundary, that same exactness may be invalid.

So future parity work must not confuse:

- "this is the best internal LUB result"
- with
- "this is a legal exported type"

## Why declaration changes force retagging

Binaryen's AST caches expression result types.
So after changing:

- `global $a : oldType`

to

- `global $a : newType`

any later expression like:

```wat
(global.get $a)
```

must also report `newType`, not `oldType`.

If Binaryen skipped that retagging step, later validation or later passes could see stale types.

## The module-initializer case most people miss

The dedicated lit file includes this important shape:

```wat
(global $a (ref $super) (ref.func $func))
(global $b (ref $super) (global.get $a))
```

After refining `$a`, Binaryen still expects `$b`'s initializer to remain valid.

That is why the pass does not only walk functions afterward.
It also calls:

- `runOnModuleCode(...)`

so `global.get` users in global initializers and other module code are repaired too.

## Why `global.set` values usually do not need bespoke rewriting

A common question is:

- if the global declaration gets narrower, shouldn't every `global.set` value expression be rewritten too?

The key answer is:

- the new type was chosen as a least upper bound of the initializer and every observed write value type
- so every observed written value is already a subtype of the new declaration type

That means there is no special setter-rewrite algorithm in `GlobalRefining.cpp`.

## The subtle null-printing story

The official lit file shows some null expressions printed more narrowly after refinement.
For example, after a global narrows to `eqref`, some `ref.null i31` or `ref.null $array` spellings are printed as `ref.null none`.

Important honesty note:

- `GlobalRefining.cpp` explicitly updates `global.get` cached types
- it does **not** explicitly walk `global.set` values and mutate `ref.null` nodes in a dedicated rewrite step

So the safest interpretation is:

- that narrower null printing is likely downstream type/refinalization or printer normalization behavior
- not a bespoke `global.set`-child rewrite algorithm in the pass itself

That is an inference from the source plus the lit output, not a direct prose statement from the file.

## Why this distinction matters for Starshine

The current MoonBit pass differs from Binaryen in a few relevant ways:

- it skips all exported globals instead of modeling the full boundary matrix
- it does not use a public-type validator on this path
- it does not need Binaryen-style AST retagging because the local representation does not cache expression types the same way

That means a future parity port must decide carefully:

- whether the local representation truly avoids the need for any equivalent of `GetUpdater`
- or whether future typed caches in boundary IR / HOT IR will need their own retagging repair step

## Beginner-friendly rule of thumb

When documenting or implementing `global-refining`, keep this short rule in mind:

- the *LUB* part is small
- the *boundary legality* part is subtle
- and the *retagging/refinalize* part is mandatory if your IR caches expression result types
