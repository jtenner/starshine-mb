---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md
  - ../../../raw/research/0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../tracker.md
  - ../index.md
  - ../type-refining/binaryen-strategy.md
  - ../global-refining/binaryen-strategy.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./constant-actuals-localization-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../tracker.md
  - ../index.md
  - ../type-refining/index.md
  - ../global-refining/index.md
---

# `signature-pruning`

## Role

- `signature-pruning` is an upstream Binaryen **module pass**.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- In Binaryen `version_129`, the public pass summary in `pass.cpp` is:
  - `remove params from function signature types where possible`

That summary is true, but too small.

A better beginner summary is:

- Binaryen looks at every function sharing a **nominal function heap type**,
- looks at every direct `call` and `call_ref` that uses that heap type,
- sometimes first materializes a constant actual value inside the callee body,
- then removes parameters that are dead for the whole heap-type family,
- and finally rewrites the nominal signature type everywhere at once.

So this is not generic signature cleanup.
It is **heap-type-level dead-argument elimination for nominal function signatures**.

## Why this pass matters

- The main no-DWARF / saved-`-O4z` parity queue is now fully dossier-covered, so this campaign needs another eligible pass from the tracker's upstream-only registry table.
- `signature-pruning` is already named in the local boundary-only registry, so this is a real Starshine-facing pass name.
- The current `type-refining` and `global-refining` dossiers already record it as a real closed-world scheduler neighbor between those passes.
- `agent-todo.md` still has **no dedicated `signature-pruning` slice**, so a stable wiki home matters even more here.
- The official implementation hides several teaching traps that deserve an explicit dossier:
  - the pass body requires `--closed-world`
  - any table in the module disables the entire pass today
  - the optimization happens per **heap type**, not per function
  - public, imported, tag-used, continuation-used, JS-called, and function-subtyped signatures are all blocked for different reasons
  - `ParamUtils::applyConstantValues(...)` can create new dead parameters before the real pruning step
  - `ChildLocalizer` can trigger one extra rerun cycle after the signature rewrite
  - distinct heap types stay distinct even if they shrink to the same final `(func ...)` shape

## Most important durable takeaways

- The dossier is now anchored to the immutable raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md) and the Starshine status bridge in [`./starshine-strategy.md`](./starshine-strategy.md).
- `signature-pruning` is **not** part of the repo's main open-world no-DWARF `-O` / `-Os` path.
- The default scheduler places it only in the **closed-world GC/type cluster** after `type-refining` and before `signature-refining` / `global-refining`.
- The pass body itself checks:
  - GC features enabled
  - `--closed-world`
  - no tables in the module
- The pass prunes **parameters only**.
  It does **not** prune results and does **not** refine parameter types.
- Binaryen decides per **function heap type**, so one live or blocked sibling can stop pruning for the entire type family.
- Constant-actual rewriting is part of the real contract, not optional polish.
- Side-effect localization plus one extra cycle is part of the real contract too.
- A narrow 2026-04-24 freshness check on the owner file, registration surface, helpers, and dedicated lit file did not find teaching-relevant drift from the reviewed `version_129` story; keep that claim narrow.

## Beginner warning: what the name hides

The easy wrong mental model is:

- Binaryen scans signatures and removes unused things from them.

The safer mental model is:

- Binaryen performs a DAE-like optimization over **nominal function heap types**,
- proves that a parameter is dead across all functions with that type,
- proves that all direct and `call_ref` users of that type can drop the corresponding argument,
- rewrites the signature heap type module-wide in one step,
- and may need a second cycle after localizing effectful call operands.

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- a small arity-cleanup pass over signatures

What it actually is in `version_129`:

- a closed-world, GC-gated module pass with:
  - per-function entry-liveness analysis for parameters
  - heap-type-level aggregation across sibling functions
  - direct-call plus `call_ref` user tracking
  - public/import/tag/continuation/JS-called/subtyping exclusion logic
  - constant actual materialization through `PossibleConstantValues`
  - parameter-to-local body rewrites via `ParamUtils`
  - atomic signature rewriting via `GlobalTypeRewriter`
  - delayed `ChildLocalizer` reruns for blocked call operands

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, helper dependencies, scheduler placement, main phases, and the exact two-cycle rewrite contract.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - File map for `SignaturePruning.cpp`, `param-utils.*`, `module-utils.*`, `type-updating.h`, `intrinsics.*`, and the dedicated lit file, plus the narrow current-`main` freshness note.
- [`./constant-actuals-localization-and-boundaries.md`](./constant-actuals-localization-and-boundaries.md)
  - Focused guide to the most easy-to-misread half of the pass: constant-actual promotion, delayed localization, public-rec-group boundaries, and the tag / continuation / table / `call.without.effects` no-op rules.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly WAT-shape catalog covering direct and `call_ref` positives, all-param removal, overwritten-param liveness, constant/ref/null actuals, localization-driven wins, and the main bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Exact Starshine status and future-port map: boundary-only registry entry, active request rejection, active-preset omission, no owner file, no active backlog slice, and the local type/call/validation/binary surfaces a future heap-type-level signature rewrite would need.

## Current maintenance rule

- Treat this folder as the canonical home for future `signature-pruning` research in this repo.
- Keep this dossier clearly labeled as an **upstream-only boundary-only** pass for Starshine today.
- Keep the page honest about scheduler scope:
  - it belongs to Binaryen's closed-world GC/type cluster
  - it does **not** belong to the repo's current open-world no-DWARF optimize path
- Keep the distinction between `signature-pruning` and the later `signature-refining` pass explicit.
- Keep any future current-`main` drift notes explicit instead of silently rewriting the `version_129` contract.

## Sources

- [`../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md`](../../../raw/binaryen/2026-04-24-signature-pruning-primary-sources.md)
- [`../../../raw/research/0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md`](../../../raw/research/0304-2026-04-24-signature-pruning-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md`](../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../type-refining/binaryen-strategy.md`](../type-refining/binaryen-strategy.md)
- [`../global-refining/binaryen-strategy.md`](../global-refining/binaryen-strategy.md)
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignaturePruning.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/param-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/param-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/eh-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/cfg/liveness-traversal.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-pruning.wast>
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SignaturePruning.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/signature-pruning.wast>
