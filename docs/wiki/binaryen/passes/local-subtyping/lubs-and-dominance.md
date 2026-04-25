---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/binaryen/2026-04-22-local-subtyping-primary-sources.md
  - ../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md
  - ../../../raw/research/0261-2026-04-22-local-subtyping-source-correction-and-starshine-followup.md
  - ../../../raw/research/0116-2026-04-20-local-subtyping-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../coalesce-locals/index.md
---

# `local-subtyping`: LUBs, gets, dominance, and iteration

This page exists because `local-subtyping` is easy to misread in two opposite ways:

1. “It is a broad local-flow optimizer that infers from every use and inserts helper locals.”
2. “It is a tiny set/tee-only pass with no get or refinalization surface.”

Both are wrong for Binaryen `version_129`.

## Corrected mental model

A safe mental model is:

- scan reference-typed locals,
- remember their sets/tees and gets,
- compute a LUB from assigned value types,
- use gets to prove or reject non-nullability,
- rewrite body-local declarations,
- retag gets and tees,
- refinalize and repeat when a rewrite exposes more precise assigned-value types.

So the two key ideas are still:

- **least upper bounds** for declarations;
- **structural dominance** for non-nullability.

But now include a third idea:

- **iteration after refinalization**.

## What feeds the LUB

The LUB candidate is fed by assigned values:

- `local.set` value types;
- `local.tee` value/result types through the assignment site.

It is not fed by `local.get` consumer contexts alone.

That distinction keeps the pass conservative: a call that wants `(ref $A)` does not by itself prove an `anyref` local always contains `$A`.

## What gets are used for

The 2026-04-22 pages were too strong when they said there was no `local.get` handling.

The owner file records get sites so it can answer two questions:

1. If we make the declaration non-null, are all relevant gets dominated by non-null-producing assignments?
2. After the declaration changes, which `local.get` expression types can be retagged to the new type, and which must remain nullable?

So gets are **not** LUB evidence, but they are still part of correctness.

## Why Binaryen uses a LUB

A local declaration must have one type that covers every assigned value.

Examples:

- all assignments are `(ref null $Child)` → candidate can be `(ref null $Child)`;
- assignments are `(ref null $Left)` and `(ref null $Right)` with common parent `$Parent` → candidate is `(ref null $Parent)`;
- assignments have no useful common subtype below the old declaration → no narrowing.

That is why the pass does not pick the narrowest leaf it sees or the last assigned type.

## Why dominance matters only for non-nullability

A nullable-to-non-null change is special because a local's default value and some control paths may still permit null.

Binaryen asks `LocalStructuralDominance` for non-dominated get indices. If any get is not proven safe, the declaration falls back to the nullable version and the unsafe gets keep nullable expression types.

This is stricter than textual order. Loops, blocks, catches, and other structured control matter.

## Why repeated refinement matters

Changing one local declaration can change the inferred type of expressions that assign to another local. Binaryen therefore reruns the analysis after refinalization while changes continue.

A future Starshine implementation that does one pass over declarations may match small examples but miss repeated-refinement cases from the official lit file.

## Parameters and body locals

Parameter handling is split:

- the scanner can see params today, and the source has a TODO to ignore them;
- the declaration rewrite loop starts at the body-local base, so params are not changed.

The correct porting rule is: preserve the parameter ABI and do not rewrite params unless a deliberate future design says otherwise.

## Nondefaultable and tuple-like locals

The checked owner file does not use the old dossier's `TypeUpdating::canHandleAsLocal(...)` gate. The visible behavior is still conservative:

- relevant locals are reference-typed;
- nondefaultable candidates must be safe non-null references or become nullable;
- tuple/non-reference shapes stay out of the transformation surface.

The official tests include nondefaultable preservation so this boundary is user-visible.

## Easy-to-miss truths

If you only remember a few things from this page, remember these:

1. LUB candidates come from assignments.
2. Gets are recorded for dominance and type repair.
3. Non-null declarations require dominance over gets.
4. Parameters are not rewritten even though the scanner has a TODO about params.
5. Repeated refinement after refinalization is part of the pass.
6. The old `LocalUpdater` / copy-local story remains an overread, but the old set-only correction was also too narrow.

## Porting checklist

A future Starshine port should preserve:

- reference-local relevance filtering;
- set/tee-fed LUB computation;
- get-aware dominance and get-type repair;
- `local.tee` retagging;
- parameter-preserving rewrite scope;
- non-null fallback to nullable when dominance fails;
- repeated refinalize/reanalyze loop;
- explicit tests for repeated refinement and nondefaultable preservation.

## Sources

- [`../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- [`../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md`](../../../raw/research/0362-2026-04-25-local-subtyping-implementation-test-map-source-correction.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalSubtyping.cpp>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-subtyping.wast>
