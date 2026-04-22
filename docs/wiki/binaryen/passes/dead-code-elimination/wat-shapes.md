---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-dead-code-elimination-primary-sources.md
  - ../../../raw/research/0203-2026-04-21-dead-code-elimination-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadCodeElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce_vacuum_remove-unused-names.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-eh-legacy.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dce-stack-switching.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./typed-control-voidification-and-eh.md
  - ../../no-dwarf-default-optimize-path.md
---

# `dead-code-elimination` WAT shapes

This page now follows the source-confirmed `version_129` implementation.
The older local shape catalog over-attributed broad dead-result simplification to DCE.
The real pass is mainly about **unreachable shapes**.

## Read this page with one mental model

Binaryen `dce` is mostly trying to answer:

- where does execution first become unreachable?
- what earlier pieces still execute before that point?
- which control nodes can no longer finish normally?

## Quick glossary

- **first unreachable child**: the first child expression whose type is `unreachable`
- **dead suffix**: siblings after that first unreachable child
- **control structure**: `block`, `if`, `loop`, `try`, `try_table`
- **type collapse to unreachable**: keeping the node, but changing its type because it cannot finish normally anymore

## Shape family 1: non-control expression with an unreachable child

Before, conceptually:

```wat
(i32.add
  EFFECT-OR-VALUE-A
  (unreachable))
```

After, conceptually:

```wat
(block
  (drop EFFECT-OR-VALUE-A)
  (unreachable))
```

Important rule:

- DCE preserves earlier children by turning them into `drop`s
- it keeps the first unreachable child
- it removes children after that point

This is the most important ordinary-expression rule in the real source.

## Shape family 2: `drop (unreachable)` becomes `unreachable`

Before:

```wat
(drop
  (unreachable))
```

After:

```wat
(unreachable)
```

Why:

- `drop` is a non-control expression
- its child is already unreachable
- there are no earlier children to preserve

## Shape family 3: block dead suffix after `br`, `return`, or `unreachable`

Before:

```wat
(block
  (call $side)
  (return)
  (call $dead))
```

After, conceptually:

```wat
(block
  (call $side)
  (return))
```

Anything after the first unreachable child is recursively removed.

## Shape family 4: block collapses to lone `unreachable`

Before:

```wat
(block
  (unreachable)
  DEAD)
```

After:

```wat
(unreachable)
```

This is the direct one-child collapse Binaryen performs after trimming the suffix.

## Shape family 5: block type changes to `unreachable`

Before, conceptually:

```wat
(block (result i32)
  ...
  (unreachable))
```

After, conceptually:

```wat
(block (result unreachable-ish)
  ...
  (unreachable))
```

In Binaryen IR terms, DCE changes the block type to `unreachable` when:

- the block had a concrete type,
- the last surviving child is unreachable,
- and no `break`s still target the block.

This is a type-collapse rule, not generic block deletion.

## Shape family 6: `if` with unreachable condition

Before:

```wat
(if
  (unreachable)
  (then THEN)
  (else ELSE))
```

After:

```wat
(unreachable)
```

More exactly, DCE replaces the `if` with the condition expression and recursively marks the arms removed.

## Shape family 7: `if` with both arms unreachable

Before, conceptually:

```wat
(if (result i32)
  COND
  (then (unreachable))
  (else (unreachable)))
```

After, conceptually:

```wat
(if (result unreachable-ish)
  COND
  (then (unreachable))
  (else (unreachable)))
```

The real source action is:

- change the `if` type to `unreachable`

It does **not** erase the `if` or broadly rewrite it to a void shell.

## Shape family 8: loop with fully unreachable body

Before:

```wat
(loop
  (unreachable))
```

After:

```wat
(unreachable)
```

This is the only loop-specific rule in the source.

## Shape family 9: `try` or `try_table` that cannot finish normally

### `try`

If the try body is unreachable and all catches are unreachable, DCE changes the try type to `unreachable`.

### `try_table`

If the body is unreachable, DCE changes the `try_table` type to `unreachable`.

The modern EH lit file proves these exact distinctions.

## Shape family 10: EH block repair after block creation

Legacy EH tests show DCE can create a new `block` while preserving an executing prefix before an unreachable child.
If the function also contains `pop`, DCE then runs nested-pop repair at function end.

So a practical shape family is:

- expression cleanup introduces a new block
- the function contains `pop`
- `EHUtils::handleBlockNestedPops(...)` must run

## Shape family 11: stack-switching handler label stays live under `drop`

The stack-switching tests prove a negative case.
A shape like:

```wat
(drop
  (block $handle_effect (result ...)
    (resume ... (on $tag $handle_effect) ...)
    (br $exit)))
```

must keep the typed handler block because the handler can branch to it.

So:

- surrounding `drop` does **not** mean the block result contract is dead.

## Negative families and non-goals

These are not the real `version_129` `dce` contract:

- effect-analyzer-based pure-vs-impure dead-result pruning
- a dedicated `drop` simplifier that keeps only side effects
- generic typed-control voidification
- flattening nested blocks as part of DCE
- refinalization at the end of the pass
- generic local-type repair

Those older claims were the big reason this follow-up was needed.

## Scheduler interaction to remember

The combo lit file with `vacuum` and `remove-unused-names` is a hint about intended division of labor.
A shape that still looks ugly after DCE alone is not automatically a DCE bug.
Sometimes DCE's real job is just:

- make the unreachable fact explicit,
- trim the dead suffix,
- leave later cleanup to neighbors.
