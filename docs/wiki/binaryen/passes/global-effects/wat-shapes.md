---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-global-effects-current-main-recheck.md
  - ../../../raw/research/0480-2026-05-05-global-effects-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md
  - ../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md
  - ../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./metadata-naming-and-consumers.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals/index.md
  - ../vacuum/index.md
---

# WAT and call/global shape catalog for `global-effects`

## Reading this page correctly

This pass is unusual:

- the **input WAT** and **output WAT** are often textually identical
- what changes is the **stored effect metadata** for each function
- later passes may then rewrite code differently

So every shape below should be read as:

- “what kind of function/call pattern gains precision?”
- not “what syntax is directly rewritten by this pass?”

## Shape 1: direct read-only callee

**Pattern:** one function reads a global, and another calls it.

```wat
(module
  (global $g (mut i32) (i32.const 0))

  (func $reader (result i32)
    (global.get $g))

  (func $caller (result i32)
    (call $reader)))
```

**What `generate-global-effects` learns:**

- `$reader` reads `$g`
- `$reader` does not write `$g`
- `$caller` inherits that read behavior through the call

**Why this matters later:**

A later pass can treat `call $reader` as a reader, not a writer, for the relevant global set.

## Shape 2: direct writer callee

**Pattern:** one function writes a global, and another calls it.

```wat
(module
  (global $g (mut i32) (i32.const 0))

  (func $writer
    (global.set $g (i32.const 1)))

  (func $caller
    (call $writer)))
```

**What the pass learns:**

- `$writer` writes `$g`
- `$caller` must also be treated as causing that write through the call

**Why this matters later:**

A later pass must still treat `call $writer` as a write barrier.
The point is precision, not optimism.

## Shape 3: transitive wrapper chain

**Pattern:** an outer function calls a wrapper, which calls the real reader or writer.

```wat
(module
  (global $g (mut i32) (i32.const 0))

  (func $reader (result i32)
    (global.get $g))

  (func $mid (result i32)
    (call $reader))

  (func $outer (result i32)
    (call $mid)))
```

**What the fixed point learns:**

- `$reader` reads `$g`
- `$mid` inherits that read
- `$outer` inherits it too after propagation stabilizes

**Why this matters later:**

A shallow-only analysis would stop at the direct body of each function.
The real pass deliberately pushes the facts backward through the chain.

## Shape 4: mutually recursive group

**Pattern:** functions in a recursive SCC call each other.

```wat
(module
  (global $g (mut i32) (i32.const 0))

  (func $a
    (call $b))

  (func $b
    (if (i32.const 0)
      (then (global.set $g (i32.const 1)))
      (else (call $a)))))
```

**What the pass does:**

- starts from shallow summaries
- treats recursive call chains conservatively rather than as acyclic wrapper calls
- in current `main`, expresses this through SCC component aggregation

**Why this matters later:**

The deferred fixed point is not accidental bookkeeping.
It is how Binaryen handles recursive precision honestly.

## Shape 5: indirect, imported, or opaque boundary

**Pattern:** a local function calls an import.

```wat
(module
  (import "env" "ext" (func $ext))

  (func $caller
    (call $ext)))
```

A similar boundary exists for unresolved indirect-call or `call_ref`-style targets.

**What to expect:**

- the pass cannot inspect an external or unknown body the same way it inspects a local defined function
- later precision is therefore limited around that boundary
- `version_129` records unknown effects conservatively instead of assuming purity

**Why this matters:**

A future port must stay conservative around opaque call targets.

## Shape 6: metadata-only no-op in printed WAT

**Pattern:** run `generate-global-effects` by itself on a module.

**Expected visible result:**

- often no textual WAT change at all

**Expected semantic result:**

- function metadata becomes richer
- later effect-sensitive passes may behave differently

This is the most important “shape” to remember for this pass.

## Shape 7: consumer payoff in `vacuum`

The reviewed upstream test `vacuum-global-effects.wast` demonstrates one downstream payoff shape.

Conceptually, the family looks like this:

```wat
(drop
  (call $f))
```

If generated summaries prove that `$f` is effect-free enough when unused, `vacuum` may later erase the whole thing.

So the story is:

1. `generate-global-effects` updates metadata
2. later `vacuum` sees a more precise call-effect summary
3. then the visible WAT rewrite happens

## Shape 8: consumer payoff in `simplify-locals`

The reviewed upstream test `global-effects_simplify-locals.wast` demonstrates the second major downstream family.

Conceptually, this is the case where generated summaries let a later local simplification distinguish:

- a call that only reads a global, versus
- a call that writes a global or has unknown global effects.

The visible before/after belongs to `simplify-locals`, but the enabling fact belongs to `generate-global-effects`.

## Shape 9: no direct code motion by this pass

A common beginner mistake is to expect this pass itself to move or delete expressions around calls.
It does not.

If you see:

- a `global.get` move across a call
- an unused call vanish
- a later pass becoming less conservative around call barriers

that later rewrite belongs to the consumer pass, not to `generate-global-effects` itself.

## Positive / negative / bailout summary table

| Family | Result |
| --- | --- |
| direct local reader/writer callee | positive metadata update |
| transitive wrapper chain | positive metadata update |
| recursive call group | positive after fixed point stabilizes |
| imported, indirect, or opaque target | conservative / limited precision |
| analyzer-only Starshine first slice | summary-observable only; no consumer rewrite yet |
| running the pass alone and printing WAT | often visible no-op |
| later `vacuum` after generated summaries | downstream positive rewrite |
| later `simplify-locals` after generated summaries | downstream positive motion opportunity |

## What a future Starshine port must preserve

- no direct body rewrites should be falsely attributed to this pass
- transitive and recursive call precision should come from a real fixed point, not a one-hop shortcut
- opaque/imported/indirect targets should stay conservative
- later consumer behavior should be explained as a second step, not merged into the pass itself
- a future Starshine first slice should validate summaries directly before enabling consumer rewrites; see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)

## Sources

- [`../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md)
- [`../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md`](../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md)
- [`../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md`](../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md`](../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md)
