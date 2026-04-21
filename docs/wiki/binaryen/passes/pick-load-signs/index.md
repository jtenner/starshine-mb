---
kind: entity
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md
  - ../../../raw/research/0069-2026-03-26-pick-load-signs.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
  - ../../../../../src/passes/pick_load_signs.mbt
  - ../../../../../src/passes/pick_load_signs_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
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
  - ./wat-shapes.md
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
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering direct sign-ext positives, mask and shift-pair positives, branch/tee/atomic bailouts, and the important non-goals.
- [`./parity.md`](./parity.md)
  - Current in-tree Starshine parity state, focused evidence, and the explicit local-vs-upstream scope difference.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current Starshine HOT-IR strategy: what the local pass actually models today, how it differs from upstream Binaryen, and what a future strict-parity pass would need to preserve.

## Freshness note

A narrow 2026-04-20 direct source comparison found **no visible drift** here:

- `src/passes/PickLoadSigns.cpp` is identical between Binaryen `version_129` and current `main`
- the dedicated lit file `pick-load-signs_sign-ext.wast` is also identical

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

## Sources

- [`../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md`](../../../raw/research/0136-2026-04-20-pick-load-signs-binaryen-research.md)
- [`../../../raw/research/0069-2026-03-26-pick-load-signs.md`](../../../raw/research/0069-2026-03-26-pick-load-signs.md)
- [`../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md`](../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md)
- [`../../../../../src/passes/pick_load_signs.mbt`](../../../../../src/passes/pick_load_signs.mbt)
- [`../../../../../src/passes/pick_load_signs_test.mbt`](../../../../../src/passes/pick_load_signs_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
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
