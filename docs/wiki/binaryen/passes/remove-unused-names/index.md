---
kind: entity
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md
  - ../../../raw/research/0220-2026-04-21-remove-unused-names-source-confirmation-followup.md
  - ../../../raw/research/0235-2026-04-21-remove-unused-names-starshine-strategy-followup.md
  - ../../../../../src/passes/remove_unused_names.mbt
  - ../../../../../src/passes/remove_unused_names_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedNames.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/shared-constants.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/README.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.txt
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedNames.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/remove-unused-names.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/remove-unused-names.txt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./control-names-implicit-blocks-and-delegates.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./invalid-tag-index-parser-gap.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../dead-code-elimination/index.md
  - ../remove-unused-brs/index.md
  - ../vacuum/index.md
  - ../merge-blocks/index.md
---

# `remove-unused-names`

## Role

- `remove-unused-names` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, `pass.cpp` describes it as:
  - removes names from locations that are never branched to

That short sentence is true, but it is very easy to misread.

A better beginner summary is:

- Binaryen looks at **control labels**, not the wasm name section,
- tracks which labels are still targeted by branches or delegates,
- clears labels that no remaining scope-name use needs,
- merges a named one-child block into its named child when both scopes have the same type,
- demotes a loop into its body when the loop label no longer matters and the body type matches,
- and then relies on Binaryen's implicit-block emission rules plus nearby cleanup passes to erase now-unnecessary structure.

So this pass is **not** debug-name cleanup, **not** generic branch elimination, and **not** arbitrary block flattening.

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` identified `remove-unused-names` as the last implemented pass that still had only a landing page.
- In the canonical no-DWARF `-O` / `-Os` scheduler, upstream Binaryen runs it three times in the function pipeline:
  1. immediately after `dead-code-elimination`
  2. again right after the first `remove-unused-brs`
  3. late again after `merge-blocks -> remove-unused-brs`
- That placement is meaningful.
  - Nearby cleanup passes keep creating fresh dead label layers, so Binaryen reruns `remove-unused-names` instead of treating it as a one-shot cosmetic pass.
- In the saved generated-artifact `-O4z` audit, the local summary records three observed top-level `remove-unused-names` slots as well:
  - Binaryen slots `13`, `15`, and `41`
  - slot `13` is exact and meaningful equality
  - slots `15` and `41` are still meaningful-equality matches even when exact bytes differ later in the pipeline

That makes this pass relevant to both the canonical scheduler docs and the artifact-backed parity story.

## Most important durable takeaways

- The pass edits **control labels**, not the wasm name section.
- In Binaryen IR, block / loop / try names are semantic because branches target names rather than raw nesting depth.
- A nameless block cannot be a branch target and may be emitted as an implicit block, so clearing a label can remove visible structure later.
- The pass is intentionally cheap.
  - It does **not** use CFG, liveness, dominance, effects, or refinalization helpers.
- The source-confirmed owner surface is tiny.
  - Almost all visible behavior lives in `RemoveUnusedNames.cpp`, with `branch-utils.h` owning the generic scope-name-use / retarget helpers and `shared-constants.h` owning the caller-delegate sentinel name.
- The key explicit rewrite is a same-type one-child named-block merge.
  - Branches targeting the parent are retargeted to the child before the parent wrapper disappears.
- Loop demotion is narrower than it sounds.
  - It only happens when the loop label is dead **and** the body type matches the loop type.
- `try` / delegate handling has a special caller-target cleanup rule.
- A narrow 2026-04-21 freshness check found no current-main drift in the core pass file or the dedicated base test pair relative to `version_129`.

## Biggest beginner correction

The easy wrong mental model is:

- `remove-unused-names` cleans up optional names, maybe something adjacent to debug metadata

The safer mental model is:

- `remove-unused-names` is a control-label cleanup pass for Binaryen IR, and its visible structural effect comes partly from Binaryen's rule that nameless blocks can become implicit.

## What the pass sounds like versus what it actually does

What it sounds like:

- remove some unimportant names

What it actually is in `version_129`:

- a syntactic scope-name-use tracker
- a dead control-label remover
- a compatible parent/child block-label merger
- a narrow loop-wrapper demoter
- and a small delegate-target cleanup pass

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual `RemoveUnusedNames.cpp` structure, the `branchesSeen` map, block and loop rewrites, delegate handling, and scheduler placement.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Compact source-confirmed owner/test-map page for the pass: `RemoveUnusedNames.cpp`, `branch-utils.h`, `shared-constants.h`, the three no-DWARF scheduler slots in `pass.cpp`, the dedicated base `remove-unused-names` pair, the neighboring combo files, and the explicit note that delegate behavior is source-confirmed more from code ownership than from a dedicated standalone lit file.
- [`./control-names-implicit-blocks-and-delegates.md`](./control-names-implicit-blocks-and-delegates.md)
  - Focused guide to the hardest beginner topic here: Binaryen control labels, implicit blocks, same-type wrapper collapse, the caller-delegate sentinel, and why this is not name-section cleanup.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering unused-label stripping, same-type block merges, loop demotion, typed bailout families, and nearby pass interactions.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine HOT-IR strategy with exact code locations for the label-use bitset, same-typed block-chain peel, loop demotion, raw fast-skip path, preset placement, and the major ways the local subset is still narrower than upstream Binaryen's generic control-label cleanup pass.
- [`./invalid-tag-index-parser-gap.md`](./invalid-tag-index-parser-gap.md)
  - Existing parser-gap note for `invalid tag index` compare failures; keep treating that family as Binaryen parser noise unless Binaryen can parse the saved case and a semantic diff still remains.

## Freshness note

A narrow 2026-04-21 direct source comparison found **no semantic post-`version_129` drift** in the core official surfaces used for this dossier.

- `src/passes/RemoveUnusedNames.cpp` is identical on current `main`
- `test/passes/remove-unused-names.wast` is identical on current `main`
- `test/passes/remove-unused-names.txt` is identical on current `main`

That is a deliberately narrow statement.
It does not claim that every nearby combo test is unchanged, only that the core pass file and dedicated base test pair still match.

## Current maintenance rule

- Treat this folder as the canonical home for future `remove-unused-names` scheduler, shape, and parity notes.
- Keep the central beginner correction explicit:
  - upstream `remove-unused-names` edits control labels rather than the wasm name section.
- Keep the distinction explicit between:
  - direct same-type block / loop rewrites in the pass
  - later implicit-block disappearance or neighboring cleanup enabled by name removal on the upstream Binaryen side
  - and the narrower current Starshine subset described in `starshine-hot-ir-strategy.md`.
- Keep the parser-gap note separate from semantic mismatch notes.

## Sources

- [`../../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md`](../../../raw/research/0143-2026-04-20-remove-unused-names-binaryen-research.md)
- [`../../../raw/research/0235-2026-04-21-remove-unused-names-starshine-strategy-followup.md`](../../../raw/research/0235-2026-04-21-remove-unused-names-starshine-strategy-followup.md)
- [`../../../../../src/passes/remove_unused_names.mbt`](../../../../../src/passes/remove_unused_names.mbt)
- [`../../../../../src/passes/remove_unused_names_test.mbt`](../../../../../src/passes/remove_unused_names_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedNames.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/shared-constants.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/README.md>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-names.txt>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedNames.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/remove-unused-names.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/remove-unused-names.txt>
