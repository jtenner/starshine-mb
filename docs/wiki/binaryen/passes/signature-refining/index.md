---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md
  - ../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../index.md
  - ../signature-pruning/binaryen-strategy.md
  - ../global-refining/binaryen-strategy.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./params-results-publicity-and-intrinsics.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../tracker.md
  - ../index.md
  - ../signature-pruning/index.md
  - ../global-refining/index.md
---

# `signature-refining`

## Role

- `signature-refining` is an upstream Binaryen **module pass**.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- In Binaryen `version_129`, the public pass summary in `pass.cpp` is:
  - `apply more specific subtypes to signature types where possible`

That summary is true, but too small.

A better beginner summary is:

- Binaryen looks at every function sharing a **nominal function heap type**,
- looks at every direct `call`, `call_ref`, and relevant `call.without.effects` use of that heap type,
- computes sharper **parameter** types from the least upper bound of actual arguments,
- computes sharper **result** types from the least upper bound of actual returned values,
- rewrites the nominal signature type everywhere at once,
- and then repairs the few helper surfaces that need custom follow-up, especially `call.without.effects` imports.

So this is not generic signature cleanup.
It is **heap-type-level subtype-tightening for nominal function signatures**.

## Why this pass matters

- The main no-DWARF / saved-`-O4z` parity queue is now fully dossier-covered, so this campaign needs another eligible pass from the tracker's upstream-only registry table.
- `signature-refining` is already named in the local boundary-only registry, so this is a real Starshine-facing pass name.
- The current `signature-pruning` and `global-refining` dossiers already record it as a real closed-world scheduler neighbor.
- `agent-todo.md` still has **no dedicated `signature-refining` slice**, so a stable wiki home matters even more here.
- The official implementation hides several teaching traps that deserve an explicit dossier:
  - the pass refines **results as well as params**
  - the decision unit is the **heap type**, not the function
  - the default scheduler places it only in the closed-world GC cluster, but the pass body itself does **not** require `--closed-world`
  - any table in the module disables the entire pass today
  - public, imported, tag-used, and signature-subtyped types are blocked for different reasons
  - JS-called and continuation-used signatures freeze **param refinement only**, not the whole type
  - `call.without.effects` participates in parameter refinement and later needs cloned intrinsic imports when results sharpen

## Most important durable takeaways

- `signature-refining` is **not** part of the repo's main open-world no-DWARF `-O` / `-Os` path.
- The default scheduler places it only in the **closed-world GC/type cluster** after `signature-pruning` and before `global-refining`.
- The pass body itself checks only:
  - GC features enabled
  - no tables in the module
- The pass refines **parameter types and result types**.
- Binaryen decides per **function heap type**, so one blocked sibling can stop optimization for the whole type family.
- Parameter refinement comes from **call operand LUBs**.
- Result refinement comes from **returned-value LUBs**.
- `call.without.effects` is part of the real contract, not a side note.
- The dossier is now anchored to the immutable raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md) and the Starshine status bridge in [`./starshine-strategy.md`](./starshine-strategy.md).
- A narrow 2026-04-24 freshness check on the owner file, registration surface, helpers, and dedicated lit file did not find teaching-relevant drift from the reviewed `version_129` story; keep that claim narrow.

## Beginner warning: what the name hides

The easy wrong mental model is:

- Binaryen scans signatures and makes them more specific.

The safer mental model is:

- Binaryen performs a heap-type-wide LUB analysis over **inputs** and **outputs**,
- separately decides what it can do for params and results,
- keeps a long list of public or currently unsupported type families frozen,
- repairs body-local validity when sharper params conflict with old broader local writes,
- rewrites the nominal signature heap type atomically,
- and then repairs special intrinsic users and enclosing expression types.

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- a small signature-tightening cleanup pass

What it actually is in `version_129`:

- a GC-gated module pass with:
  - per-function direct `call` / `call_ref` collection
  - `call.without.effects` extra-call handling
  - per-function returned-value LUB collection via `LUB::getResultsLUB(...)`
  - heap-type-level aggregation across sibling functions
  - public/import/tag/JS-called/continuation/subtyping boundary logic
  - parameter-body fixup rewrites through `TypeUpdating::updateParamTypes(...)`
  - atomic signature rewriting through `GlobalTypeRewriter::updateSignatures(...)`
  - cloned intrinsic-import repair for refined `call.without.effects` results
  - final `ReFinalize`

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, helper dependencies, scheduler placement, main phases, and the exact one-pass rewrite contract.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - File map for `SignatureRefining.cpp`, `lubs.*`, `module-utils.*`, `type-updating.*`, `intrinsics.*`, and the dedicated lit file, plus the narrow current-`main` freshness note.
- [`./params-results-publicity-and-intrinsics.md`](./params-results-publicity-and-intrinsics.md)
  - Focused guide to the most easy-to-misread half of the pass: the split between full-type blockers and params-only blockers, the difference between param-LUB and result-LUB reasoning, and the special `call.without.effects` update contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly WAT-shape catalog covering direct and `call_ref` positives, mixed-LUB outcomes, result refinement, body-fixup locals, intrinsic positives and negatives, and the main bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status and future-port map: boundary-only registry entry, active request rejection, active-preset omission, no owner file, no active backlog slice, local `TypeIdx` / `FuncType` / `CallRef` / validator / binary surfaces, and the reason a faithful port must be module/type-graph work rather than a HOT peephole.

## Current maintenance rule

- Treat this folder as the canonical home for future `signature-refining` research in this repo.
- Keep this dossier clearly labeled as an **upstream-only boundary-only** pass for Starshine today.
- Keep the page honest about scheduler scope:
  - it belongs to Binaryen's closed-world GC/type cluster
  - it does **not** belong to the repo's current open-world no-DWARF optimize path
- Keep the distinction between `signature-pruning` and `signature-refining` explicit.
- Keep the distinction between scheduler gating and pass-local gates explicit.
- Keep any future current-`main` drift notes explicit instead of silently rewriting the `version_129` contract.

## Sources

- [`../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md)
- [`../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0307-2026-04-24-signature-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md`](../../../raw/research/0152-2026-04-21-signature-refining-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../signature-pruning/binaryen-strategy.md`](../signature-pruning/binaryen-strategy.md)
- [`../global-refining/binaryen-strategy.md`](../global-refining/binaryen-strategy.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignatureRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-refining.wast>
- Narrow freshness-check sources are captured in [`../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-refining-primary-sources.md).
