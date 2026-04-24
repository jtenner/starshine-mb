---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md
  - ../../../raw/research/0288-2026-04-24-instrument-memory-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
  - ../tracker.md
  - ../instrument-locals/index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./helper-import-roster-filters-and-unsupported-types.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../instrument-locals/index.md
  - ../global-effects/index.md
  - ../tracker.md
---

# `instrument-memory`

## Role

- `instrument-memory` is a real public Binaryen pass.
- It is currently **upstream-only** in this repo's living pass map: it is **not** in Starshine's local optimizer registry in `src/passes/optimize.mbt`.
- It is **not** part of the repo's canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `instrument-memory` slice**.
- The 2026-04-24 local recheck sharpened the status: an explicit Starshine request would fail as an **unknown pass flag**, not as boundary-only or removed.

## Why this dossier exists

The tracker now has no obvious remaining pass entries with wiki status `none`, so another pass dossier needed explicit justification instead of routine queue-filling.

`instrument-memory` meets that bar because:

- Binaryen exposes it as a real public pass with a compact dedicated owner file, `InstrumentMemory.cpp`.
- The neighboring `instrument-locals` dossier depends on keeping the split from `instrument-memory` explicit.
- The public help text is easy to misread: `pass.cpp` describes this as intercepting "all loads and stores", but the real `version_129` contract also covers `memory.grow` and selected GC `struct.*` / `array.*` traffic.
- The pass intentionally adds effects through imported helper calls, so it belongs in the same instrumentation-analysis neighborhood as `instrument-locals` and `global-effects`, not in the optimizer families.
- The folder now has the same provenance and local-status shape as newer dossiers: an immutable raw primary-source manifest plus a dedicated Starshine status page.

## Beginner summary

A good beginner mental model is:

- wrap a memory load's pointer in `load_ptr(id, bytes, offset, addr)`
- wrap the loaded value in `load_val_* (id, value)`
- do the analogous thing for stores
- wrap `memory.grow` in pre/post hooks
- and, with GC enabled, do similar scalar-value wrapping for `struct.get` / `struct.set` / `array.get` / `array.set`

So this pass is best taught as:

- **effectful helper-call instrumentation for memory and selected heap-access operations**
- not an optimization pass
- not a generic tracing pass for every memory-adjacent instruction
- not just the linear-memory sibling of `instrument-locals`

## Most important durable takeaways

- The whole reviewed `version_129` contract lives in one small owner file, `InstrumentMemory.cpp`, plus public registration in `pass.cpp`.
- The official Binaryen `version_129` release page reviewed on 2026-04-24 showed publish date **2026-04-01 14:31**.
- A narrow current-`main` source spot check did not surface teaching-relevant drift from the tagged `version_129` contract.
- The pass is a `PostWalker`, so it rewrites children first and then wraps the current operation.
- It covers ordinary scalar `load` / `store`, `memory.grow`, and selected GC `struct` / `array` access families.
- It does **not** cover everything the name might suggest: no `memory.size`, no bulk-memory ops, no atomic RMW/cmpxchg, and no general ref-valued GC payload instrumentation.
- The helper import roster is partly unconditional: scalar memory hooks are always injected, and GC hooks are injected whenever GC is enabled, even if a non-empty filter later leaves some families untouched.
- The filter surface is string-keyed and exact: `load`, `store`, `memory.grow`, `struct.get`, `struct.set`, `array.get`, and `array.set`.
- Memory64 changes the address-type side of the helper signatures from `i32` to `i64`, but the scalar value hooks keep their normal result types.
- The pass explicitly reports `addsEffects() == true`, so later effect-sensitive reasoning must treat the rewritten code as more effectful.
- One shared `id` counter numbers all helper observations, but not always one-per-source instruction: `array.get` / `array.set` consume separate IDs for index and value hooks.
- Current Starshine has no pass registry entry, owner file, tests, preset slot, or active backlog slice for this pass.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: public registration, postwalk rewrite mechanics, helper signatures, memory64 behavior, GC extension, and the nearby instrumentation/effects story.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Compact owner-file and proof-surface map for `InstrumentMemory.cpp`, `pass.cpp`, and the four dedicated lit files, now anchored to the raw primary-source manifest.
- [`./helper-import-roster-filters-and-unsupported-types.md`](./helper-import-roster-filters-and-unsupported-types.md)
  Focused guide to the most non-obvious half of the pass: unconditional-vs-GC helper import injection, exact filter strings, shared ID numbering, scalar-only GC payload coverage, and the current unsupported instruction/type boundaries.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for loads, stores, `memory.grow`, GC struct/array rewrites, filtered no-op cases, memory64 address widening, and preserved unsupported families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port map: no registry spelling, no owner file, no preset slot, no backlog slice, and exact local code locations to read before any future module-pass port.

## Current maintenance rule

- Treat this folder as the canonical home for future `instrument-memory` research.
- Keep it explicitly marked as an **upstream-only** dossier unless Starshine later grows a real registry entry for this pass.
- Keep the split from `instrument-locals` explicit: `instrument-memory` wraps memory and selected heap-access operations, while `instrument-locals` wraps local traffic.
- Keep the effects story explicit too: this pass is small, but it intentionally injects imported calls and therefore changes what later effect-sensitive analysis can assume.
- Keep the public-help-text caveat explicit too: the wording in `pass.cpp` understates the real surface by sounding like ordinary loads/stores only.
- Keep the local status explicit: current Starshine treats `instrument-memory` as unknown rather than as boundary-only or removed.

## Sources

- [`../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md`](../../../raw/binaryen/2026-04-24-instrument-memory-primary-sources.md)
- [`../../../raw/research/0288-2026-04-24-instrument-memory-primary-sources-and-starshine-followup.md`](../../../raw/research/0288-2026-04-24-instrument-memory-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md`](../../../raw/research/0231-2026-04-21-instrument-memory-binaryen-research.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../tracker.md`](../tracker.md)
- [`../instrument-locals/index.md`](../instrument-locals/index.md)
