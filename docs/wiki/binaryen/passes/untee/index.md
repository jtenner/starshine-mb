---
kind: entity
status: supported
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-untee-primary-sources.md
  - ../../../raw/research/0185-2026-04-21-untee-binaryen-research.md
  - ../../../raw/research/0279-2026-04-23-untee-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../index.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flattening-code-pushing-and-tee-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../code-pushing/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee/index.md
---

# `untee`

## Role

- `untee` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **removed** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `untee` slice**.
- Upstream `pass.cpp` describes it briefly as:
  - `removes local.tees, replacing them with sets and gets`

That summary is short, but it is basically correct.

A better beginner summary is:

- Binaryen walks `local.tee` nodes after their children have already been rewritten,
- turns reachable tees into explicit **`local.set` then `local.get`** sequences,
- and deletes unreachable tees instead of fabricating impossible get-after-unreachable shells.

## Why this pass matters

- The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only wave are already dossier-covered, so this folder is an explicit tracker expansion for another real local registry pass.
- `untee` fills a real teaching gap between the already-covered `code-pushing` and `simplify-locals*` dossiers.
- It is easy for beginners to assume `untee` is just another name for `simplify-locals-notee`, but the real contracts are different:
  - `untee` removes **existing** tees
  - `simplify-locals-notee` forbids creating **new** tees while still doing a much broader locals optimization pass
- The implementation and test surface are tiny enough to audit exactly, which makes this a high-confidence source-backed dossier addition.

## Beginner summary

A good mental model is:

- `local.tee` is shorthand for "store this value in a local and also produce that same value"
- `untee` expands that shorthand into more explicit IR
- later motion or locals passes can then reason about the set and the value read separately

So this pass is best taught as:

- **tee desugaring into explicit set-plus-get IR**
- not a broad locals optimization pass
- not a default optimize-preset slot in the current Starshine parity path
- not the same thing as `simplify-locals-notee`

## Most important durable takeaways

- The pass is a tiny `PostWalker` over `LocalSet` nodes.
- Only real `local.tee` nodes are rewritten; ordinary `local.set` stays untouched.
- Reachable tees become explicit `local.set` + `local.get` wrappers.
- The synthetic `local.get` uses the local's declared type from the function.
- If the tee's value is already `unreachable`, the tee wrapper is deleted instead of expanded.
- Nested tees expand inside-out because the walk is postorder.
- The source comment explicitly says this flatter form can help passes like `code-pushing`.
- The 2026-04-23 raw primary-source manifest now records the exact official release, source, and test URLs reviewed for this dossier, and the checked official Binaryen `version_129` release page showed publish date **2026-04-01**.
- A narrow current-`main` check found the implementation, registration, and dedicated lit file unchanged from `version_129`, so the tagged release is a reliable oracle here.

## What this pass sounds like versus what it actually does

What it sounds like:

- maybe some generic cleanup on locals
- maybe the same thing as `simplify-locals-notee`
- maybe a flatten-era preset helper

What it actually is in `version_129`:

- a very small pass that rewrites one exact IR node family, `local.tee`
- by making the write and the result value explicit
- with one important bailout: unreachable tees are just deleted

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the real implementation structure, rewrite phases, and pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./flattening-code-pushing-and-tee-boundaries.md`](./flattening-code-pushing-and-tee-boundaries.md)
  Focused guide to the easiest parts to misread: why `untee` helps make side effects flatter, why it is not `simplify-locals-notee`, and why the unreachable fast path matters.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, nested, preserved, and bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status page mapping the removed-registry entry, honest request rejection, missing backlog slice, and the nearest local `simplify-locals` / `code-pushing` landing zone for a future port.

## Current maintenance rule

- Treat this folder as the canonical home for future `untee` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass for it.
- Keep the split from `simplify-locals-notee` explicit: those passes are neighbors, not synonyms.
- Keep the split from the default optimize-path docs explicit too: this is an optional explicit pass, not a missing no-DWARF parity slot.

## Sources

- [`../../../raw/binaryen/2026-04-23-untee-primary-sources.md`](../../../raw/binaryen/2026-04-23-untee-primary-sources.md)
- [`../../../raw/research/0185-2026-04-21-untee-binaryen-research.md`](../../../raw/research/0185-2026-04-21-untee-binaryen-research.md)
- [`../../../raw/research/0279-2026-04-23-untee-primary-sources-and-starshine-followup.md`](../../../raw/research/0279-2026-04-23-untee-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Untee.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SimplifyLocals.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/untee.wast>
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Untee.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/untee.wast>
