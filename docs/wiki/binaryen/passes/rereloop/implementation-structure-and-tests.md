---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md
  - ../../../raw/research/0484-2026-05-05-rereloop-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-30-rereloop-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md
  - ../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReReloop.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_rereloop.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/opt_flatten.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReReloop.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_rereloop.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./flat-cfg-builder-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Upstream implementation structure and test map for `rereloop`

## Why this page exists

`rereloop` is small enough to read in one sitting, but that makes it easy to blur together three different layers:

- the public pass registration
- the pass-local flat-IR-to-CFG adapter
- the generic `cfg/Relooper.*` engine

This page keeps those layers separate.

## File map

| File | Why it matters | Durable lesson |
| --- | --- | --- |
| `src/passes/ReReloop.cpp` | Core pass implementation | The pass itself is mostly a task-based flat-IR CFG builder plus a render/refinalize wrapper. |
| `src/passes/pass.cpp` | Public registration and scheduler context | Binaryen exposes `rereloop` publicly, but it is not in the reviewed default no-DWARF optimize path; instead, `-O4` has an explicit TODO near the flatten cluster. |
| `src/cfg/Relooper.h` | Public helper API and invariants | Shapes are `Simple` / `Multiple` / `Loop`, conditions must be side-effect free, and multiple-entry rendering uses a helper label local. |
| `src/cfg/Relooper.cpp` | Generic rendering engine | The visible helper blocks, break names, and label-variable dispatch behavior come from the shared relooper, not from pass-local ad hoc rewrites. |
| `src/ir/flat.h` | Formal precondition | `rereloop` depends on Binaryen Flat IR, not just vaguely “simpler code.” |
| `test/lit/passes/flatten_rereloop.wast` | Main dedicated lit surface | The real source-backed shape contract lives here: skip-empty ladders, branch-table regrouping, mergeable exits, helper locals, and unreachable/result repair. |
| `test/lit/passes/opt_flatten.wast` | Secondary integration surface | Confirms `flatten -> rereloop` also behaves on a smaller optimize-oriented example. |
| current `main` `src/passes/ReReloop.cpp` and `flatten_rereloop.wast` | Narrow freshness spot check | The reviewed current-main surfaces match `version_129` on the checked files, and the 2026-05-05 recheck keeps that result current. |

## `ReReloop.cpp` is the pass-local contract

The pass-local file proves all of these durable facts directly:

- the pass is function-parallel
- it hard-requires flat IR via `Flat::verifyFlatness`
- it builds temporary CFG blocks whose backing code is ordinary wasm `block`s
- it only directly understands a narrow set of flat control forms
- it rejects EH explicitly
- it appends terminators to dead-end CFG blocks before rendering
- it always allocates an `i32` helper local for `RelooperBuilder`
- it repairs apparent missing result flows with `unreachable`
- it ends with `ReFinalize`

If a future port gets those facts right, it will already be much closer to the real Binaryen behavior than a fuzzy “inverse flatten” intuition would be.

## `pass.cpp` adds two important lessons

The registration line makes one thing explicit:

- `rereloop` is a real public pass, not an internal helper

The optimize-path TODO adds another lesson:

- Binaryen conceptually associates the pass with the flatten-era aggressive cluster, but it has not committed it into the reviewed default optimize presets yet

That is why this dossier belongs in the upstream-only registry expansion section rather than the no-DWARF or saved-`-O4z` active queue.

## `cfg/Relooper.h` explains the non-obvious semantics

This helper header matters because it explains behaviors the pass file alone only hints at.

### Side-effect-free conditions

The header explicitly says branch conditions must not have side effects because the generic relooper may reorder or eliminate condition checks.

That is one of the strongest reasons the flatness precondition matters.
The pass assumes the input is already simple enough for those conditions to be safe.

### Shape taxonomy

The same header defines the three generic structured shapes:

- `Simple`
- `Multiple`
- `Loop`

So when test output shows multi-entry dispatch or helper break names, those are generic relooper artifacts, not one-off special cases in `ReReloop.cpp`.

### Label helper local

`RelooperBuilder` defines the helper-label-local operations:

- get current label
- set label to a block id
- test the label against an expected block id
- emit block-break and shape-continue names

That directly explains why `ReReloop.cpp` allocates one fresh `i32` local before rendering.

## `cfg/Relooper.cpp` explains the visible boilerplate

The generic implementation is much larger than the pass wrapper.
The most relevant durable lessons are:

- multiple-entry rendering uses label checks and helper nesting
- blocks may be fused with following multiple-entry shapes
- helper break names are generated systematically
- rendering is about correctness first, not perfect minimality

That is why the lit output contains helper blocks and helper names that later cleanup passes can still simplify.

## `flat.h` is not optional background reading

The reviewed `flat.h` file makes the precondition precise.
A future port that only copies the pass-local CFG builder without reproducing the same flatness discipline will risk misusing arbitrary nested values as branch conditions or CFG-edge code.

So `flat.h` is part of the real implementation contract, not just context.

## The dedicated lit surface is unusually revealing

`flatten_rereloop.wast` is the main practical oracle.
It demonstrates several visible families:

- post-flatten `if` to structured `if/else` rebuilds
- branch-table regrouping into switch-like wrappers
- empty-block skipping and join simplification
- mergeable exit forms that end in one visible `return`
- helper locals and helper break blocks introduced by the generic relooper
- explicit `unreachable` in result-typed dead-end situations

That makes the test file especially useful for teaching because the pass implementation itself is small but the rendered output is not obvious until you inspect the golden surface.

## The test surface is small but enough

Unlike some other passes, `rereloop` does not have a large dedicated file family.
The main reviewed lit coverage is centered on:

- `flatten_rereloop.wast`
- `opt_flatten.wast`

That is enough to teach the main visible contract, but it also means the source files themselves carry more of the explanatory burden than a broader lit suite would.

## Freshness check

The 2026-05-05 raw source manifest in [`../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md) refreshed the official release provenance and the current-`main` spot-check URLs for this dossier.

I compared:

- `version_129` `src/passes/ReReloop.cpp`
- current `main` `src/passes/ReReloop.cpp`
- `version_129` `test/lit/passes/flatten_rereloop.wast`
- current `main` `test/lit/passes/flatten_rereloop.wast`

Durable result:

- no drift was observed on those reviewed surfaces

So the tagged release is still a reliable oracle for the documented contract here.

## Most important maintenance lesson

For `rereloop`, you cannot understand the pass honestly by reading only one file.
A faithful port or wiki page must keep these three layers together:

1. `ReReloop.cpp` for the pass-local CFG builder
2. `flat.h` for the required input discipline
3. `cfg/Relooper.*` for the rendered structured-output model

That three-layer reading is the real implementation structure.

## Sources

- [`../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-rereloop-current-main-recheck.md)
- [`../../../raw/research/0484-2026-05-05-rereloop-current-main-recheck.md`](../../../raw/research/0484-2026-05-05-rereloop-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md`](../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md)
- [`../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md`](../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md`](../../../raw/research/0183-2026-04-21-rereloop-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReReloop.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/Relooper.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_rereloop.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/opt_flatten.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReReloop.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_rereloop.wast>
