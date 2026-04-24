---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md
  - ../../../raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./local-flow-type-floor-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../type-refining/index.md
  - ../gufa/index.md
  - ../gufa-cast-all/index.md
supersedes:
  - ../../../raw/research/0191-2026-04-21-type-generalizing-binaryen-research.md
---

# Binaryen `type-generalizing` strategy

## Upstream source rule

Use Binaryen `version_129` as the source oracle for this corrected page.
The core sources are captured in [`../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-generalizing-primary-sources.md).

Most important official files:

- `src/passes/TypeGeneralizing.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/type-generalizing.wast`
- `src/wasm/wasm-type.h` for the `Type` lattice helpers used by the pass

## The pass in one sentence

Binaryen `experimental-type-generalizing` is a small hidden/test function pass that retags defaultable expressions to a compatible local-flow type inferred from local-set/local-tee evidence, with a special drop-plus-zero rewrite when the expression being retagged is a `local.get`.

## Biggest correction

The old dossier said this pass was a closed-world `ContentOracle` consumer over GC operations.
That is stale for reviewed `version_129`.

The corrected source-backed facts are:

- `pass.cpp` registers **one** hidden/test pass name: `experimental-type-generalizing`.
- `TypeGeneralizing.cpp` exports **one** constructor: `createTypeGeneralizingPass()`.
- The owner file has no `ContentOracle`, no `struct.get` / `struct.set` visitors, no `call_ref` visitor, no `ref.cast` visitor, and no pass-specific `ReFinalize` call.
- No `experimental-type-generalizing-with-optimizing-casts` registration or dedicated lit file was found in the reviewed release.

## Scheduler and visibility fact

Binaryen wires this pass through `registerTestPass(...)`.
That makes it useful for lit coverage and experiments, but it should not be taught as a default optimizer pass or as a normal public shrink pass.

It is also outside Starshine's current no-DWARF parity path and the saved generated-artifact `-O4z` skipped-slot audit.

## High-level algorithm

The implementation is compact enough to teach as one loop:

1. Keep a map from local index to the type evidence observed for that local.
2. Walk function expressions and scan child expression structure.
3. `local.set` and `local.tee` update the local-index evidence with the type of the value being assigned.
4. For each candidate expression, ignore unreachable, concrete, and nondefaultable cases.
5. Compare the expression's current type against the collected local-flow evidence.
6. Compute a compatible type using Binaryen's subtype and least-upper-bound operations.
7. If the computed type is safe, retag the expression to that type.
8. If the expression is a `local.get`, replace it with a sequence that drops the original get and materializes a default/zero value of the target type instead of mutating the get directly.
9. Clear and rescan the local evidence as the walk crosses barriers or rewrites.

The result is a local-flow type cleanup, not a body-restructuring pass.

## What the local evidence means

The evidence map is keyed by local index because locals are the point where incompatible expression types tend to force splits or awkward typed control results.

`local.set` / `local.tee` are important because they say:

- this expression value flows into this local,
- the local-flow type only needs to satisfy the observed assignment shape,
- a more compatible type may be enough for the surrounding expression.

This is why the pass belongs near locals/type-flow teaching, not near whole-program GC oracle teaching.

## Candidate-expression gates

The pass refuses to act on several families:

- **unreachable** expressions: no useful concrete type cleanup is needed.
- **concrete** expressions: these are scan barriers in the implementation.
- **nondefaultable** expression types: the `local.get` fallback may need to create a zero/default value, so nondefaultable targets are unsafe.
- **cases where the computed type is not a subtype-compatible improvement**: the pass keeps the original expression.

These gates are correctness constraints, not incidental implementation details.

## The `local.get` special case

A normal candidate expression can be retagged by changing its `type` field.
A `local.get` is different: its result type is tied to the local declaration, so directly mutating the expression type would be inconsistent.

Binaryen handles that by replacing the expression with a sequence shaped like:

```wat
(block (result $chosen-type)
  (drop (local.get $x))
  (ref.null $chosen-type-or-other-zero))
```

The exact printed zero/default depends on the chosen type, but the invariant is stable:

- preserve evaluation of the original `local.get` through `drop`,
- then produce a default value of the retagged type.

## Inputs and outputs

Input:

- one function body
- typed Binaryen expression tree
- local assignment evidence discovered while walking the tree

Output:

- the same function shape, except some defaultable expression result types may be retagged
- `local.get` retagging requests become drop-plus-zero sequences
- no module declarations, signatures, struct fields, call targets, or casts are changed by this pass

## Correctness constraints

A faithful implementation must preserve at least these constraints:

1. Do not retag concrete or unreachable expressions.
2. Do not synthesize zero/default values for nondefaultable types.
3. Do not directly mutate `local.get` to a type inconsistent with its local declaration.
4. Use subtype and LUB reasoning, not string/name equality.
5. Reset or rescan local evidence after barriers and rewrites so stale evidence does not leak across unrelated shapes.
6. Keep the pass function-local; do not invent closed-world module assumptions for this source contract.

## Notable edge cases

- **Local-get fallback:** this is the only source-backed case where a visible expression wrapper is created.
- **Defaultability:** a type-flow cleanup can become invalid if the chosen type lacks a default value.
- **Concrete typed expressions:** they stop the broad retagging story even when a human might think a nearby local shape is compatible.
- **No GC-operation visitors:** `struct.get`, `struct.set`, `call_ref`, and `ref.cast` examples belong to other passes or future sources, not this one.

## Validation strategy

For Binaryen parity research, validate against:

- `test/lit/passes/type-generalizing.wast` for source-backed before/after shapes.
- `TypeGeneralizing.cpp` for the local evidence and candidate gate rules.
- `pass.cpp` for the hidden/test registration status.

For any future Starshine port, add local tests that cover:

- expression retagging where local-flow evidence permits it,
- `local.get` drop-plus-zero materialization,
- nondefaultable no-ops,
- concrete/unreachable barriers,
- registry rejection until the pass becomes active.

## What a future Starshine port must preserve

A faithful Starshine port should preserve at least eight things:

1. local alias versus upstream hidden/test name split
2. function-local implementation boundary
3. local-set/local-tee evidence collection
4. subtype/LUB-based compatible type selection
5. concrete/unreachable/nondefaultable bailouts
6. `local.get` drop-plus-zero replacement
7. absence from active presets until implemented honestly
8. source-correction warning against the old `ContentOracle` / cast-sibling story

## Most important beginner correction

If someone says:

- “`type-generalizing` narrows GC field accesses and `call_ref` using a closed-world oracle”

that is the stale 0191 interpretation.

A better sentence is:

- “Binaryen `experimental-type-generalizing` is a hidden/test local-flow pass that retags defaultable expressions based on local assignment type evidence.”
