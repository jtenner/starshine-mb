---
kind: entity
status: supported
last_reviewed: 2026-06-03
sources:
  - ../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md
  - ../../../raw/research/0532-2026-05-06-pick-load-signs-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md
  - ../../../raw/research/0455-2026-05-05-pick-load-signs-current-main-recheck.md
  - ../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md
  - ../../../raw/research/0228-2026-04-21-pick-load-signs-implementation-followup.md
  - ../../../raw/research/0244-2026-04-22-pick-load-signs-primary-sources-and-code-map-followup.md
  - ../../../raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md
  - ../../../raw/research/0069-2026-03-26-pick-load-signs.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/PickLoadSigns.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/pick-load-signs_sign-ext.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-sign_ext.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/PickLoadSigns.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/pick-load-signs_sign-ext.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../heap-store-optimization/index.md
  - ../precompute/index.md
---

# `pick-load-signs`

## Role

- `pick-load-signs` is an active implemented **hot pass** in Starshine.
- This folder is already a deep dossier, and the 2026-05-05 bridge refresh closes the remaining freshness gap: it adds a current-main raw manifest and a dedicated Starshine strategy page, while keeping the deeper HOT implementation map in sync.
- In upstream Binaryen `version_129`, the public `pass.cpp` description is only:
  - `pick load signs based on their uses`

That description is accurate, but still leaves out the most important practical details.

A better beginner summary is:

- Binaryen looks for a narrow non-atomic integer load that is written into a local by an exact non-tee `local.set`,
- checks every `local.get` use of that local in a very small parent/grandparent AST window,
- recognizes only a few exact sign- or zero-extension shapes,
- and flips the load to the signed or unsigned variant only when **every** use is recognized at the right width.

So this is **not** a general integer canonicalization pass.
It is a tiny, shape-driven local rewrite.

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` named `pick-load-signs` as the strongest remaining implemented landing-page target.
- In the canonical no-DWARF `-O` / `-Os` scheduler, it sits in the early memory/sign cleanup cluster:
  - `... -> optimize-instructions -> heap-store-optimization -> pick-load-signs -> precompute ...`
- That placement is meaningful:
  - earlier cleanup simplifies the obvious instruction and heap-store shapes first
  - `pick-load-signs` then picks a better narrow-load signedness in the remaining exact local cases
  - later `precompute` and rerun cleanup can benefit from the simpler opcode choice
- The 2026-06-03 O4z audit refreshed direct signoff with `9975 / 10000` compared cases, `9975` normalized matches, `0` semantic mismatches, and `25` Binaryen/tool command failures; it also added focused local i64 positive tests and corrected the imported-memory fixture.
- The saved generated-artifact `-O4z` audit records a successful top-level slot here:
  - ordered audit row `15`
  - Binaryen slot `18`
  - both canonical wasm and normalized WAT matched in the saved replay
- The saved Binaryen debug log contains `18` `running pass: pick-load-signs` lines, so nested reruns matter here too.

## Most important durable takeaways

- Upstream `pick-load-signs` is much smaller than its name suggests.
- The real implementation depends mainly on:
  - `ExpressionStackWalker`
  - `Properties::getSignExt*`
  - `Properties::getZeroExt*`
- Any unrecognized use blocks the rewrite.
- `local.tee` producers are out of scope.
- Atomic loads are always skipped.
- The signed side wins ties because Binaryen expects a sign-extension shift pair to remove more follow-up instructions than a zero-extension mask usually does.
- **Most important correction:** the official `version_129` pass here is effectively **i32-only** because the helper surface it relies on only recognizes i32 sign/zero-extension patterns.

## Biggest beginner correction

The easy wrong mental model is:

- `pick-load-signs` is where Binaryen handles all narrow integer load signedness cleanup, including i64 extension families

The safer mental model is:

- `pick-load-signs` is a tiny AST-context pass for a narrow local-written load family, and in upstream `version_129` the actual recognition logic here only covers i32 sign/zero-extension shapes.

That difference matters a lot.
It explains why the dedicated official lit file is tiny, why branch-value uses block the optimization immediately, and why broader i64 sign-extension cleanup shows up in official `optimize-instructions` tests instead.

## What the pass sounds like versus what it actually does

What it sounds like:

- pick the best signedness for narrow loads everywhere

What it actually is in `version_129`:

- a function-parallel AST walker,
- with one `Usage` record per local,
- one `Load* -> local` candidate map,
- exact non-tee `local.set(load ...)` candidate discovery,
- exact parent/grandparent sign/zero-extension matching through `properties.h`,
- and a tiny final rewrite that flips only the load's `signed_` bit when the usage proof is completely clean.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the real `PickLoadSigns.cpp` structure, helper utilities, scheduler placement, and the exact i32-only recognition logic visible through `properties.h`.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Compact upstream file/test map covering the real owner split across `PickLoadSigns.cpp`, `properties.h`, `pass.cpp`, `opt-utils.h`, the tiny dedicated lit file, and the neighboring `optimize-instructions` sign-extension proof surface that this pass should not silently absorb.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering direct sign-ext positives, mask and shift-pair positives, branch/tee/atomic bailouts, and the important non-goals.
- [`./parity.md`](./parity.md)
  - Current in-tree Starshine parity state, focused evidence, and the explicit local-vs-upstream scope difference.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Concise Starshine status and code-map page for the active hot pass, including the registry, scheduler, raw-skip, test, and replay surfaces.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Deeper HOT-IR implementation note: exact MoonBit registry / dispatcher / raw-skip / rewrite / test ownership, the broader local i64 recognition surface, and the now-focused i64/imported-memory test coverage.
- [`../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md`](../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md)
  - O4z release-gating audit: direct `10000` requested compare, focused i64/imported-memory test refresh, saved slot `18` timing, and `[O4Z-AUDIT-PLS]` closure.
- [`../../../raw/research/0532-2026-05-06-pick-load-signs-direct-revalidation.md`](../../../raw/research/0532-2026-05-06-pick-load-signs-direct-revalidation.md)
  - Refreshed direct pass-fuzz signoff after the 2026-05-06 harness audit.
- [`../../../raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md)
  - Current-main refresh manifest for this folder's freshness bridge.
- [`../../../raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md`](../../../raw/binaryen/2026-04-22-pick-load-signs-primary-sources.md)
  - Immutable manifest of the official Binaryen release/source/test URLs reviewed for this folder on 2026-04-22.

## Freshness note

A narrow 2026-05-05 current-main recheck found **no visible drift** here:

- the reviewed `src/passes/PickLoadSigns.cpp` release and current-`main` surfaces still match on the teaching-relevant mechanics captured in this folder
- the dedicated lit file `pick-load-signs_sign-ext.wast` also still matches between the reviewed release and current `main`

So the released `version_129` source is still the right semantic oracle for this dossier.

## Important supersession note

The archived local port note `0069-2026-03-26-pick-load-signs.md` remains useful as implementation history.
But a fresh official-source review corrects one part of that older note:

- the upstream pass here should not be described as an i64-aware signedness picker
- the current in-tree Starshine pass is broader than upstream on that point

Keep that difference explicit instead of silently smoothing it away.

## Current maintenance rule

- Treat this folder as the canonical home for future `pick-load-signs` parity and scheduler research.
- Keep the main correction explicit:
  - upstream `pick-load-signs` is a narrow AST-context pass, not a generic all-width load-sign canonicalizer
- Keep the local-vs-upstream i64 scope difference explicit until it is either removed or intentionally documented as a standing divergence.
- Keep the no-memory skip, exact `local.set(load ...)` producer rule, all-uses-recognized rule, and atomic-load bailout explicit whenever future docs or code changes touch this pass.
- Keep the concise Starshine strategy page and the deeper HOT note aligned.

## Sources

- [`../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md`](../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md)
- [`../../../raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md)
- [`../../../raw/research/0455-2026-05-05-pick-load-signs-current-main-recheck.md`](../../../raw/research/0455-2026-05-05-pick-load-signs-current-main-recheck.md)
- [`../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md`](../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md)
- [`../../../raw/research/0228-2026-04-21-pick-load-signs-implementation-followup.md`](../../../raw/research/0228-2026-04-21-pick-load-signs-implementation-followup.md)
- [`../../../raw/research/0069-2026-03-26-pick-load-signs.md`](../../../raw/research/0069-2026-03-26-pick-load-signs.md)
- [`../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`](../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md)
- [`../../../../../src/passes/pick_load_signs.mbt`](../../../../../src/passes/pick_load_signs.mbt)
- [`../../../../../src/passes/pick_load_signs_test.mbt`](../../../../../src/passes/pick_load_signs_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- Saved generated-artifact slot, timing, and debug-log facts are preserved in the committed audit note [`../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md`](../../../raw/research/0702-2026-06-03-pick-load-signs-o4z-audit.md); old `.artifacts` paths are local replay identifiers rather than durable source links.
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/PickLoadSigns.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/pick-load-signs_sign-ext.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-sign_ext.wast>
- Narrow freshness-check surfaces:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/PickLoadSigns.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/pick-load-signs_sign-ext.wast>
- Starshine strategy / HOT detail:
  - [`./starshine-strategy.md`](./starshine-strategy.md)
  - [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
