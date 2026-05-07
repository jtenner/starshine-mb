---
kind: entity
status: supported
last_reviewed: 2026-05-07
sources:
  - ../../../raw/research/0554-2026-05-07-simplify-locals-notee-nostructure-backlog-closure.md
  - ../../../raw/research/0544-2026-05-06-slnns-direct-revalidation.md
  - ../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md
  - ../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md
  - ../../../raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md
  - ../../../raw/research/0489-2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - ../../../../../agent-todo.md
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../flatten/index.md
  - ../local-cse/index.md
  - ../simplify-locals-notee/index.md
  - ../simplify-locals-nostructure/index.md
  - ../tracker.md
---

# `simplify-locals-notee-nostructure`

## Role

- `simplify-locals-notee-nostructure` is an upstream Binaryen aggressive locals-cleanup pass.
- It is now an **active direct** Starshine pass: the exact upstream spelling is registered as a HOT pass, dispatches through the existing `simplify_locals` policy engine with `allowStructure = false` and `allowTee = false`, and has green direct Binaryen parity evidence.
- The old local removed-name placeholder spelling `simplify-locals-no-tee-no-structure` remains distinct from the upstream / saved-audit spelling `simplify-locals-notee-nostructure`; the newly active direct pass uses the upstream spelling.
- The dossier is now anchored by the immutable primary-source manifest in [`../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md), the 2026-05-05 current-main recheck in [`../../../raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md), the Starshine status bridge in [`./starshine-strategy.md`](./starshine-strategy.md), and the companion validation bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
- In Binaryen `version_129`, it is **not** part of the canonical no-DWARF `-O` / `-Os` path.
- Instead, `pass.cpp` inserts it only in the more aggressive `optimizeLevel >= 4` function prelude:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`

## Why it matters

- The updated pass tracker listed `simplify-locals-notee-nostructure` as the last remaining saved-audit pass with wiki status `none` when this thread started.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - top-level slot `10`
- The saved Binaryen debug log shows it is not just a one-off top-level curiosity in that captured run:
  - the top-level slot `10` execution took about `0.568566` seconds
  - the same full run executed `simplify-locals-notee-nostructure` `18` total times because later optimizing reruns reused the same aggressive default function pipeline
- The pass sits in the exact aggressive neighborhood whose behavior is easier to understand once this variant is documented clearly:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`
- The Starshine implementation adds direct-pass registry, dispatcher, script-listing, focused HOT-pipeline coverage, 10k fuzz parity evidence, `gen-valid` parity evidence, and self-opt parity evidence.
- A 2026-05-07 backlog review closed `[SLNNS]003`: the remaining `flatten -> simplify-locals-notee-nostructure -> local-cse` replay is future aggressive-path work, not active `v0.1.0` no-DWARF backlog scope.

## Beginner summary

A safe beginner mental model is:

- `flatten` introduces lots of temp locals,
- Binaryen then removes the **easy** local carriers,
- but it does that without inventing new tees or new block / `if` / loop result structure,
- and only after that does it hand the function to `local-cse`.

That is much closer to the real pass than “full simplify-locals, but smaller.”

## Current durable takeaways

- Binaryen implements this pass as `SimplifyLocals<false, false, true>`.
- So `simplify-locals-notee-nostructure` means:
  - `allowTee = false`
  - `allowStructure = false`
  - `allowNesting = true`
- The pass still does real work:
  - sink single-use locals into existing consumers
  - remove overwritten pending sets on the current linear trace
  - canonicalize equivalent `local.get`s late in the pipeline
  - remove dead or same-value sets with `UnneededSetRemover`
- The pass does **not** do two important things that nearby variants can do:
  - it does not create new `local.tee` nodes in order to sink multi-use locals
  - it does not create new block / `if` / loop return values from local traffic
- Starshine's active first slice now encodes those two policy gates directly in `src/passes/simplify_locals.mbt` rather than treating the pass as a no-op alias.
- The 2026-05-06 refreshed harness revalidation recorded 6759 compared direct-pass cases with 6759 normalized matches and 0 semantic mismatches; the 20 command failures were Binaryen/tool failures outside the compared semantic lane.
- Despite living right after `flatten`, it is **not** the same as `simplify-locals-nonesting`.
  - Because `allowNesting = true`, it may still sink a single-use local into an already-existing nested consumer position.
  - So the pass does **not** promise to preserve full Flat IR on its own.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: template identity, phase-by-phase behavior, helper dependencies, conservative invalidation rules, aggressive scheduler placement, and the exact families a future Starshine port must preserve.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner-file and test-map page for `simplify-locals-notee-nostructure`, including the shared `SimplifyLocals.cpp` engine, `pass.cpp` registration, `opt-utils.h` nested rerun surface, dedicated WAT/TXT pair, neighboring variant contrasts, and what remains source-backed rather than directly lit-isolated.
- [`./variant-surface.md`](./variant-surface.md)
  Focused guide to the easiest part of the pass to misunderstand: what “no tee” and “no structure” really disable, what still remains enabled, why this pass is not the same as `simplify-locals-nonesting`, and why Binaryen uses this exact variant after `flatten`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for single-use temp sinks, preserved multi-use locals, dead-overwrite cleanup, late equivalent-get canonicalization, trap / `try` barriers, and the main bailout families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and port map: exact upstream spelling active as a direct HOT pass, no-tee/no-structure policy mode in the shared locals engine, focused registry/dispatcher/tests, and the standing aggressive-prelude boundary.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Validation bridge: spelling policy, negative-test boundary, direct oracle evidence, and the reason no standalone `SLNNS` backlog slice remains open.

## Current maintenance rule

- Treat this folder as the canonical home for future `simplify-locals-notee-nostructure` research and port planning.
- Keep it explicitly marked as **active direct, aggressive-prelude deferred**.
- Cite `0554` when explaining why `[SLNNS]003` was pruned from the active backlog; cite `0544` for refreshed direct-pass parity evidence; cite the raw primary-source manifest and `0333` follow-up for provenance or current Starshine status; keep `0129` as historical mechanics research rather than the current status source.
- Keep the strategy page, implementation/test map, Starshine page, and variant-surface page aligned whenever new evidence changes the answer to either:
  - “what exact rewrite families remain enabled in `SimplifyLocals<false, false, true>`?” or
  - “what does this aggressive post-`flatten` slot actually preserve versus only simplify a little?”

## Sources

- [`../../../raw/research/0554-2026-05-07-simplify-locals-notee-nostructure-backlog-closure.md`](../../../raw/research/0554-2026-05-07-simplify-locals-notee-nostructure-backlog-closure.md)
- [`../../../raw/research/0544-2026-05-06-slnns-direct-revalidation.md`](../../../raw/research/0544-2026-05-06-slnns-direct-revalidation.md)
- [`../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md)
- [`../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md`](../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md)
- [`../../../raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md)
- [`../../../raw/research/0489-2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md`](../../../raw/research/0489-2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
- Narrow same-day freshness checks on current upstream `main`:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
