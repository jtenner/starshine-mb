---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-avoid-reinterprets-current-main-recheck.md
  - ../../../raw/research/0456-2026-05-05-avoid-reinterprets-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md
  - ../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md
  - ../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets64.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./single-load-chains-and-bailouts.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Upstream implementation structure and tests for `avoid-reinterprets`

The 2026-04-24 primary-source manifest is [`../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`](../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md), with a focused 2026-04-26 port-readiness recheck in [`../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md) and a 2026-05-05 current-main bridge in [`../../../raw/binaryen/2026-05-05-avoid-reinterprets-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-avoid-reinterprets-current-main-recheck.md).
Use [`./starshine-strategy.md`](./starshine-strategy.md) for the local status and exact Starshine code-map bridge, and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the future first-slice plan.

## Main reviewed files

| File | What it proves | Why it matters |
| --- | --- | --- |
| `src/passes/AvoidReinterprets.cpp` | The actual pass algorithm: reinterpret-user discovery, single-load provenance lookup, full-width filtering, helper-local allocation, and final rewrites | This is the main semantic oracle. |
| `src/passes/pass.cpp` | Public registration of `avoid-reinterprets` | This is the naming and scheduler oracle. |
| `src/ir/local-graph.h` | What `LocalGraph::getSets(...)` means, including the `nullptr` and unreachable-code caveats | This explains the provenance proof and several bailout cases. |
| `src/ir/properties.h` | The `getFallthrough(...)` helper used to look through transparent wrappers | This explains why some wrappers are followed and others are not. |
| `test/lit/passes/avoid-reinterprets.wast` | The memory32 positive and negative surface | This is the main beginner-facing proof of actual rewrite shape. |
| `test/lit/passes/avoid-reinterprets64.wast` | The same surface under memory64 | This proves pointer-temp typing is part of the contract. |

## `AvoidReinterprets.cpp`

This file establishes the entire real pass contract.

The most important structural points are:

1. **first walk marks source loads**
   - `visitUnary(...)` finds reinterpret users and maps them back to a single load if possible
2. **mid-phase filters the candidate map**
   - `optimize(...)` removes anything not full-width and reachable
3. **fresh locals are allocated before the final rewrite**
   - one pointer temp and one alternate-type value temp per surviving load
4. **the inner `FinalOptimizer` rewrites both users and source loads**
   - direct reinterpret users, indirect reinterpret users, and tracked source loads all have different responsibilities

That is why the right summary is:

- compact multi-stage provenance rewrite pass

not:

- one peephole that simply flips every reinterpret of a load.

## `pass.cpp`

This file proves two simple but important facts:

### 1. Public name

Upstream registers the pass as:

- `avoid-reinterprets`

There is no local-vs-upstream naming split here.

### 2. Default-pipeline status is separate

The repo's no-DWARF scheduler page omits it, which means a future port should not silently treat public registration as proof of default-pipeline membership.

## `local-graph.h`

This file answers the most important provenance question.

`AvoidReinterprets.cpp` uses:

- `localGraph->getSets(get)`

and relies on these documented behaviors:

- a missing/empty case means no useful reaching set data for optimization
- `nullptr` may represent a parameter or entry-style value
- unreachable code may be over-approximated rather than modeled precisely

Those facts are why the pass is conservative around params, merges, and cycles.

## `properties.h`

This file matters because the pass does not directly inspect every wrapper node.
It asks for the fallthrough value of a set or reinterpret operand.

That creates an important contract boundary:

- some wrappers are transparent to the provenance walk
- others must keep the reinterpret form intact

The `nofallthrough` lit case exists mainly to prove this subtlety.

## Reviewed upstream test surface

## `avoid-reinterprets.wast`

This is the main behavioral surface for memory32.
Its function roster shows the whole intended contract:

- `simple`
  - direct full-width load/reinterpret pairs
- `one`, `one-b`
  - one reinterpret user behind a local
- `both`
  - multiple reinterpret users sharing one alternate-type helper local
- `half`
  - mixed original and reinterpreting uses of the same load result
- `copy`
  - single-source copy chains remain eligible
- `partial1`, `partial2`
  - partial loads are explicit no-op cases
- `nofallthrough`
  - non-fallthrough wrapper barrier

That is unusually good coverage for a small pass.

## `avoid-reinterprets64.wast`

This file mirrors the same function families under memory64.
Its biggest value is not new semantics.
Its value is proving that:

- helper pointer locals must be typed as `i64` in memory64 mode

A future port that hardcodes `i32` pointer temps would fail this surface.

## What each lit family proves

| Function family | Main proof |
| --- | --- |
| `simple` | Direct `reinterpret(load)` can flip straight to the opposite typed load |
| `one` / `one-b` | One indirect reinterpret user causes helper-local duplication at the source load |
| `both` | One source load can feed many reinterpret users through the same helper local |
| `half` | Mixed original-use and reinterpret-use is preserved instead of retargeting the original local |
| `copy` | A unique copy chain can still resolve back to one source load |
| `partial1` / `partial2` | Partial loads are intentionally untouched |
| `nofallthrough` | Non-fallthrough wrappers block the provenance proof |
| memory64 mirror file | Pointer temp type must follow memory address width |

## Beginner-friendly file map summary

If you only remember one source role per file, remember this:

- `AvoidReinterprets.cpp` = **how the pass proves and rewrites load/reinterpret pairs**
- `pass.cpp` = **what the public pass is called**
- `local-graph.h` = **why single-source local chains are required**
- `properties.h` = **why some wrappers are transparent and others are barriers**
- `avoid-reinterprets*.wast` = **proof of direct, indirect, mixed-use, partial-load, and memory64 behavior**

## What a future Starshine port must preserve

The local status and likely HOT-IR building blocks are mapped in [`./starshine-strategy.md`](./starshine-strategy.md).
The future slice order and reduced validation ladder are mapped in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
A future port should preserve:

- the split between direct and indirect reinterpret users
- the single-load provenance requirement
- the helper-local duplication shape
- the exact partial-load and wrapper bailouts
- the memory64 pointer-temp rule

## Sources

- [`../../../raw/binaryen/2026-05-05-avoid-reinterprets-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-avoid-reinterprets-current-main-recheck.md)
- [`../../../raw/research/0456-2026-05-05-avoid-reinterprets-current-main-recheck.md`](../../../raw/research/0456-2026-05-05-avoid-reinterprets-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-avoid-reinterprets-port-readiness-primary-sources.md)
- [`../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md`](../../../raw/research/0381-2026-04-26-avoid-reinterprets-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md`](../../../raw/binaryen/2026-04-24-avoid-reinterprets-primary-sources.md)
- [`../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md`](../../../raw/research/0281-2026-04-24-avoid-reinterprets-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md`](../../../raw/research/0172-2026-04-21-avoid-reinterprets-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/AvoidReinterprets.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/avoid-reinterprets64.wast>
