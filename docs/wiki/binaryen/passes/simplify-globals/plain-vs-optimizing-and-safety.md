---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md
  - ../../../raw/binaryen/2026-05-05-simplify-globals-current-main-recheck.md
  - ../../../raw/research/0461-2026-05-05-simplify-globals-current-main-recheck.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-globals-optimizing/index.md
---

# `simplify-globals`: plain vs optimizing, and the real safety story

This page focuses on the parts of Binaryen `simplify-globals` that are easiest to blur together:

- plain pass versus optimizing variant
- startup-time propagation versus runtime propagation
- effect summaries versus actual owned syntax
- dead global writes versus dropped side effects

The 2026-05-05 current-main recheck kept this split intact on the reviewed surfaces, so the safety story below still matches current Binaryen behavior.

## The biggest beginner warning

If you summarize the pass as:

- “replace constant `global.get`s”

you will miss most of the implementation.

A better mental model is:

- prove which globals still matter as state,
- erase fake state while preserving operand evaluation,
- and substitute only the values Binaryen can still justify safely in the current context.

## 1. Plain `simplify-globals` and `simplify-globals-optimizing` are not the same public contract

The upstream file is mostly shared, but the public behavior is not identical.

| Variant | Global rewrite engine | Nested default function rerun |
| --- | --- | --- |
| `simplify-globals` | yes | no |
| `simplify-globals-optimizing` | yes | yes |

So plain `simplify-globals` should be taught as:

- do the global analysis and rewrites,
- repair types when necessary,
- and stop.

That means plain-pass output can still visibly contain local debris such as:

- `drop(i32.const ...)`
- dead branches after a condition became constant
- dead locals after a global value became literal

The optimizing variant is the one that immediately reruns Binaryen's default function cleanup to cash in on those new opportunities.

## 2. Startup-time propagation and runtime propagation are different algorithms

This is the most important safety split.

## Startup-time propagation

When Binaryen rewrites:

- later global initializers
- element-segment offsets
- data-segment offsets

it is still reasoning in module-instantiation order.

So this is a valid positive shape:

```wat
(global $a (mut i32) (i32.const 42))
(global $b i32 (global.get $a))
```

Even though `$a` is mutable at runtime, it is still definitely `42` while later globals are being initialized.

## Runtime propagation

Inside function bodies, Binaryen is much stricter.

It starts from:

- globally constant globals
- plus current values established by constant `global.set`s along a simple linear trace

So this is positive only while no barrier appears:

```wat
(global.set $g (i32.const 10))
(drop (global.get $g))
```

The pass does **not** claim that `$g` is globally constant forever.
It only knows what is true on the current cheap trace.

## 3. Calls and nonlinear control are the main runtime barriers

The runtime current-value map is cleared when the walker sees:

- a call
- nonlinear control
- a relevant write

So this family is intentionally preserved:

```wat
(global.set $g (i32.const 10))
(call $maybe_changes_globals)
(drop (global.get $g))
```

Even if the call often does not change `$g`, Binaryen refuses to keep the old current-value fact across that boundary.

## 4. `connectAdjacentBlocks = true` is helpful, but not magical

Binaryen does allow some cheap adjacency-based domination-like wins.
That is why some “set here, read in the immediately following dominated block” shapes optimize.

But the pass still does **not** become a full dominator analysis.

The reviewed dominance test keeps that boundary explicit:

- some adjacent dominated positives work
- broader `else` or call-separated cases still do not

A future port should preserve the narrow cheap model, not silently widen it.

## 5. `read-only-to-write` is about fake state, not just repeated names

A good beginner summary is:

- a global qualifies only when Binaryen can prove the program reads it solely to decide whether to write that same global, and nothing else important depends on that read.

Positive example:

```wat
(if
  (global.get $once)
  (then
    (global.set $once (i32.const 1))
  )
)
```

But the real rule is stricter than “condition reads `$once`, body writes `$once`.”

## 6. The body must effectively be “just write this global”

Binaryen checks the body with `EffectAnalyzer` and requires:

- exactly one written global effect
- no remaining effects after removing that write from the effect set

So these are negative families:

- extra call in the body
- memory write in the body
- another global write in the body
- throw or other side effect in the body

A wrapper `block` or `nop` can still be fine if it does not add real effects.

## 7. Actual AST `global.get` / `global.set` nodes matter more than summary facts

This is one of the easiest source-level details to miss.

Binaryen does use computed effects elsewhere, but for `read-only-to-write` it still wants:

- an actual `global.get` node in the condition
- an actual `global.set` node in the body

So this family stays negative even if a helper call is known to read or write the same global indirectly:

```wat
(if
  (call $reads_g_somehow)
  (then
    (call $writes_g_somehow)
  )
)
```

The pass does not claim ownership of that pattern.

## 8. Side effects in the condition are not automatically fatal

The real question is whether the **global’s value** can decide some dangerous side effect.

If the condition contains side effects but the global's value only flows safely to the final boolean result, Binaryen may still accept the pattern.

If the global's value controls whether an effectful call happens, Binaryen rejects it.

So the source distinguishes between:

- side effects being present nearby
- side effects actually depending on the global read

That is why the reviewed `simplify-globals-read_only_to_write.wast` file is so large and important.

## 9. The pass also knows one narrow whole-function early-return shape

Binaryen recognizes a specific family like:

```wat
(block
  (if (global.get $once)
    (then (return))
  )
  (global.set $once (i32.const 1))
)
```

But this is not a general CFG proof.
It is an exact narrow body-shape matcher.

Good beginner rule:

- if the body grows extra siblings or a different control shape, assume the optimization stops.

## 10. Dead global writes become `drop(value)`, not deletion of the subtree

This is another place where a naive summary goes wrong.

When Binaryen proves the state change is unnecessary, it still preserves evaluation of the value being written.
So:

```wat
global.set $g (call $expensive)
```

can become conceptually:

```wat
drop (call $expensive)
```

That preserves side effects while removing the global state change.

## 11. Single-use folding is startup-only on purpose

The pass can copy a one-time initializer into another later global initializer.
It does **not** use the same rule to copy that initializer into arbitrary runtime code.

That is why “single use” here should be taught as:

- one-time startup use

not:

- any one-time-looking use anywhere in the module

## 12. Copy-chain cleanup prefers earlier immutable ancestors, but only with exact type compatibility

If immutable globals form a chain, Binaryen can sometimes rewrite uses to the earliest compatible ancestor.

But the compatibility gate in `version_129` is strict:

- if the ancestor type does not exactly fit the use type, the rewrite stops

So GC/reference cases often bail out even when a human might imagine a more aggressive refinement.

## 13. Type repair is part of the real pass contract

Some substitutions become more refined than the original `global.get` expression.
When that happens, Binaryen runs `ReFinalize()` on the affected function.

So the pass is not only:

- scan globals
- swap expressions

It is also:

- repair surrounding inferred types afterward when needed

## 14. Why the plain pass deserves its own dossier anyway

The existing `simplify-globals-optimizing` dossier already documents most of the shared engine.
But the plain variant still deserves its own home because it teaches a different beginner lesson:

- what the global algorithm itself owns,
- before the optimizing wrapper immediately hides the leftovers with another pass batch.

That split matters for:

- scheduler modeling
- port planning
- debugging visible pass output
- understanding which simplifications belong to the global pass itself and which belong to later cleanup

## Durable mental model for future Starshine work

If you want one short porting rule, use this:

- plain `simplify-globals` is a whole-module global-state simplifier with two different propagation modes and a narrow self-guard proof,
- while the optimizing suffix is that same engine plus immediate local cleanup.

That is the real public-contract split to preserve.
