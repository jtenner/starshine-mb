---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-dealign-primary-sources.md
  - ../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./align-one-rewrite-surface-and-alignment-lowering-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../alignment-lowering/index.md
supersedes:
  - ../../../raw/research/0221-2026-04-21-dealign-binaryen-research.md
---

# Binaryen `dealign` strategy

Use this page with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-dealign-primary-sources.md`](../../../raw/binaryen/2026-04-24-dealign-primary-sources.md).

## What the pass really is

Binaryen `dealign` is a tiny function-walking pass that sets selected memory-access alignment fields to `1`.

It does **not**:

- split loads or stores into smaller accesses
- rewrite address arithmetic
- legalize weak alignment with helper locals
- optimize for throughput
- rewrite every memory instruction family

The right mental model is: **alignment-metadata pessimization / normalization**.

## Public surface

`pass.cpp` registers the public pass name:

- `dealign`

with a short description saying it forces loads and stores to `align=1`.
That description is directionally right, but the exact implementation surface must be read from `DeAlign.cpp`.

## Correct implementation shape

The reviewed `version_129` implementation is:

- `struct DeAlign : public WalkerPass<PostWalker<DeAlign>>`
- `isFunctionParallel()` returns `true`
- there is no custom module iteration loop in the source file
- there is no explicit `module->memory.exists()` bailout in the source file

This corrects the older 2026-04-21 local dossier text, which described a manual module pass wrapper and no-memory bailout that are not present in reviewed `DeAlign.cpp`.

## Exact visitor surface

Reviewed `DeAlign.cpp` defines three visitor methods:

- `visitLoad(Load* curr)`
- `visitStore(Store* curr)`
- `visitSIMDLoad(SIMDLoad* curr)`

Each one assigns the node alignment field to `1`.

Important correction: the reviewed file does **not** define `visitSIMDStore`.
If future Binaryen versions add one, update this page and cite the changed source explicitly.

## Exact rewrite rule

The implementation rule is direct assignment:

```text
curr->align = 1
```

That means the previous local shorthand “if `align > 1`, set it to `1`” is only a semantic description, not the source shape.
Already-`align=1` nodes remain unchanged in output because assignment to the same value is idempotent.

## What changes

Only the alignment immediate changes.

## What does not change

The pass preserves:

- opcode kind
- width
- scalar load signedness
- offset
- pointer child
- stored value child
- result type
- control flow
- the memory access's ordinary trap behavior

There are no helper locals, no address recomputation, and no multi-access expansion.

## Positive rewrite surface

Source-backed positive families are:

- scalar loads
- scalar stores
- SIMD loads

The dedicated lit file directly proves scalar `i32.load` and `i32.store` cases. The `SIMDLoad` family is source-confirmed from `DeAlign.cpp`, but not visibly isolated by the reviewed `dealign.wast` file.

## Negative surface

The reviewed pass does not directly visit:

- `SIMDStore`
- atomics
- bulk-memory operations
- `memory.copy`, `memory.fill`, `memory.init`, or `data.drop`
- tables
- GC instructions
- control nodes
- address expressions outside the access node

That negative list matters because the public name is broad enough to invite over-teaching.

## Relation to `alignment-lowering`

`dealign` and `alignment-lowering` are conceptual siblings, not two halves of one transform.

### `dealign`

- weakens alignment metadata to `1`
- keeps one access as one access
- never adds locals or bit assembly
- covers scalar `Load` / `Store` plus `SIMDLoad` in reviewed source

### `alignment-lowering`

- starts from weakly aligned scalar accesses
- emits smaller aligned scalar accesses to preserve semantics
- may add locals, shifts, ors, reinterprets, and explicit unreachable repairs
- does not share `dealign`'s simple metadata-only implementation shape

A future Starshine port should keep those jobs separate.

## Test-backed visible behavior

The dedicated `dealign.wast` file is intentionally small. It proves:

- default `i32.load` / `i32.store` accesses print with `align=1` after the pass
- explicit `align=2` `i32.load` / `i32.store` accesses become `align=1`
- explicit `align=1` accesses remain `align=1`
- offsets and children are not rewritten by the pass

It does not visibly prove broad scalar type coverage or SIMD coverage. Those broader statements should stay source-confirmed, not lit-overstated.

## Freshness note

A narrow 2026-04-26 current-`main` recheck on `DeAlign.cpp`, `pass.cpp`, and `dealign.wast` did not surface teaching-relevant drift from the tagged `version_129` behavior summarized here. That recheck is captured in [`../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md).

## What a faithful port must preserve

A future Starshine port should preserve:

- public pass identity if the local registry decides to track it: `dealign`
- exact visited surface unless intentionally widened: `Load`, `Store`, `SIMDLoad`
- direct alignment-field rewrite to `1`
- preserved offsets, widths, signedness, child expressions, and control flow
- no chunk-splitting or helper locals
- explicit distinction from `alignment-lowering`
- tests that do not overstate the upstream lit proof surface

## Shortest correct summary

Binaryen `dealign` is a public function-parallel walker that sets `Load`, `Store`, and `SIMDLoad` alignment fields to `1`; it does not split memory accesses or otherwise rewrite their semantics.

## Sources

- [`../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dealign-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-dealign-primary-sources.md`](../../../raw/binaryen/2026-04-24-dealign-primary-sources.md)
- [`../../../raw/research/0389-2026-04-26-dealign-port-readiness.md`](../../../raw/research/0389-2026-04-26-dealign-port-readiness.md)
- [`../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md`](../../../raw/research/0317-2026-04-24-dealign-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeAlign.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dealign.wast>
