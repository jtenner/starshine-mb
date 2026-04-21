---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md
  - ../../../raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-and-startup-boundaries.md
  - ./wat-shapes.md
  - ../simplify-globals/index.md
  - ../simplify-globals-optimizing/index.md
  - ../string-gathering/index.md
---

# Binaryen `propagate-globals-globally` Strategy

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation is **inside `src/passes/SimplifyGlobals.cpp`**, not a standalone `PropagateGlobals.cpp`.
- Public registration comes from `src/passes/pass.cpp`.
- The shipped behavior example is `test/lit/passes/propagate-globals-globally.wast`.

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyGlobals.cpp>

## The pass in one sentence

Binaryen `propagate-globals-globally` is a late module pass that uses the shared `PropagateGlobals` engine in **startup-only mode**: it substitutes startup-known global expressions into other startup-safe global users and rewrites defined global initializers plus active data/elem offsets, but it stops before walking ordinary function bodies.

## The family in one table

| Public pass | Shared engine | `optimize` | Main rewrite surface |
| --- | --- | --- | --- |
| `propagate-globals-globally` | `PropagateGlobals` in `SimplifyGlobals.cpp` | `false` | Defined globals + active data/elem offsets |
| `simplify-globals` | same engine | `true` | Startup rewrites plus broader function-body global simplification |
| `simplify-globals-optimizing` | same engine plus later scheduler behavior | `true` | Same broader rewrite surface plus optimizing-family cleanup behavior |

## Biggest correction from the older folder state

The easiest mistake was thinking this pass had its own source file and therefore its own mostly separate algorithm.

The reviewed source shows something more useful:

- Binaryen built a **shared engine**
- then exposed one public startup-only mode and two broader public simplify-globals modes

So the most accurate beginner sentence is:

- `propagate-globals-globally` is the startup-only public mode of the shared `PropagateGlobals` engine

## What the reviewed implementation is organized around

The durable structure is:

1. define a small set of expressions that are safe to treat as startup/global expressions
2. track which global names map to known startup expressions
3. substitute those known expressions into later startup-safe users
4. rewrite active data/elem offsets too, not just globals
5. stop early when `optimize` is `false`

That early stop is the public-pass boundary.

## Exact startup-safe scope matters

The pass does **not** accept arbitrary IR in global-ish positions.

The reviewed `canHandleAsGlobal` helper keeps the accepted surface intentionally small and startup-shaped, including:

- `Const`
- `GlobalGet`
- unary ops over startup-safe children
- binary ops over startup-safe children
- `Select` over startup-safe children
- several `string.*` expressions used in startup contexts

That means the pass is broader than just direct alias replacement, but narrower than generic expression evaluation.

## Known-value discovery is expression-shaped, not just const-shaped

A second helper checks whether every `GlobalGet` inside one of those startup-safe expressions already points at a known constant/startup expression.

That means the pass can learn facts like:

- `$g -> (i32.const 8)`
- `$h -> (i32.add (i32.const 8) (i32.const 4))`
- `$s -> (string.concat (string.const "a") (string.const "b"))`

not only raw literal facts.

This is why the pass can simplify more than trivial global aliases.

## Rewriter shape

Binaryen then uses a tiny postwalk rewriter that replaces `global.get $x` with the stored replacement expression for `$x`.

The durable teaching point is:

- substitution comes first
- then Binaryen decides whether the rebuilt expression now counts as startup-known

That is a much better mental model than imagining ad hoc special cases for each syntax family.

## Why reverse global scan matters

The implementation scans defined globals in reverse declaration order while growing the constants map.

The safest wiki-level statement is simply the source fact:

- a future port should preserve the reverse-scan or prove an equivalent fixed point explicitly

This note intentionally avoids overclaiming a formal semantic necessity beyond what the reviewed source proves.

## Why offsets are first-class rewrite targets

The pass walks active segment offsets after scanning globals.

That means the public contract includes:

- active data offsets
- active element offsets

This is one of the most important visible behaviors to preserve in beginner docs and future ports.

## Relationship to `simplify-globals*`

## With plain `simplify-globals`

This pass shares the same engine but stops before the broader code-level work.

## With `simplify-globals-optimizing`

Same engine again, but the optimizing sibling later participates in the larger scheduling and rerun story documented in its own dossier.

## What this pass deliberately does not own

It does not own:

- ordinary function-body `global.get` propagation
- read-only-to-write cleanup
- dead `global.set` cleanup in code
- practical-immutability analysis over arbitrary code
- nested useful-pass reruns

Those belong to the broader siblings.

## Why this matters for Starshine

A correct future Starshine port should likely share helper machinery with any later `simplify-globals*` work, but it must preserve the smaller public contract for this specific pass:

- module pass
- startup-safe expression subset
- defined globals plus active offsets
- no function-body walk in this mode

## Most important beginner correction

If someone says:

- "Binaryen has a pass that globally propagates globals everywhere"

that is wrong.

A much better sentence is:

- "Binaryen has a startup-only public mode of its global-propagation engine, and broader sibling passes that continue into ordinary function bodies."

That is the main durable teaching value of this updated dossier.
