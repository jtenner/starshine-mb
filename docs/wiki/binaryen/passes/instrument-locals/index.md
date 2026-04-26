---
kind: entity
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-instrument-locals-port-readiness-primary-sources.md
  - ../../../raw/research/0397-2026-04-26-instrument-locals-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md
  - ../../../raw/research/0287-2026-04-24-instrument-locals-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0227-2026-04-21-instrument-locals-binaryen-research.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./unsupported-types-effects-and-import-roster.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../instrument-memory/index.md
  - ../global-effects/index.md
  - ../tracker.md
---

# `instrument-locals`

## Role

- `instrument-locals` is a real public Binaryen pass.
- It is currently **upstream-only** in this repo's living pass map: it is **not** in Starshine's local optimizer registry in `src/passes/optimize.mbt`.
- It is **not** even a local boundary-only or removed compatibility name today; explicit local requests would fail as unknown.
- It is **not** part of the repo's canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `instrument-locals` slice**.

## Why this dossier exists

The tracker now has no obvious remaining pass entries with wiki status `none`, and this thread was explicitly forbidden from reusing the recently covered candidate set.
So a new dossier needed explicit justification.

`instrument-locals` meets that bar because Binaryen exposes it as a real public pass with:

- a compact dedicated owner file, `InstrumentLocals.cpp`
- a public registration in `pass.cpp`
- dedicated lit coverage
- a new raw primary-source manifest for the reviewed release/current-main source set
- and a non-obvious neighboring-pass interaction with `generate-global-effects` / `vacuum`

Without this folder, it was too easy to blur together:

- `instrument-locals`, which wraps supported local reads and writes in imported helper calls and intentionally adds effects, and
- ordinary locals optimizers such as `simplify-locals*`, which try to erase or canonicalize local traffic.

## Beginner summary

A good beginner mental model is:

- for each supported `local.get`, Binaryen wraps the read in a helper call like `get_i32(call_id, local_id, value)`
- for each supported `local.set` / `local.tee`, Binaryen wraps the assigned value in a helper call like `set_f64(call_id, local_id, value)`
- the pass injects the helper imports into the module
- and it marks itself as adding effects, so later effect-based cleanup must become more conservative

So this pass is best taught as:

- **local-access instrumentation through imported identity-style helpers**
- not a locals cleanup pass
- not a generic tracing pass for every wasm value
- not an optimization pass

## Most important durable takeaways

- The entire reviewed `version_129` contract lives in one small owner file, `InstrumentLocals.cpp`, plus public registration in `pass.cpp`; the 2026-04-24 raw manifest captures those primary sources directly.
- The pass is a `PostWalker`, so it rewrites supported local traffic after walking children, and one shared `id++` counter numbers both gets and sets.
- `local.get` is replaced by a helper call that returns the original type.
- `local.set` is preserved as a set/tee node, but its assigned value is replaced by a helper call returning that same value type.
- The pass explicitly reports `addsEffects() == true`; the dedicated effects lit file proves that this invalidates existing global-effects knowledge and changes what later `vacuum` can erase.
- Type coverage is intentionally partial: `i32`, `f32`, `f64`, nullable `funcref`, nullable `externref`, and feature-gated `v128` are instrumented, while ordinary `i64` local traffic still returns early as `TODO`.
- The helper import roster is broader than the actual rewrite surface: `get_i64` / `set_i64` imports are still injected even though ordinary `i64` gets and sets are left untouched.
- `Pop` payloads are deliberately skipped, which is why the legacy EH lit file exists.
- Starshine currently has no registry entry, owner file, tests, preset slot, or backlog slice for this pass; see [`./starshine-strategy.md`](./starshine-strategy.md).

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: postwalk rewrite shape, helper signatures, module-level import injection, and the exact type and feature gates.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Compact owner-file and proof-surface map for `InstrumentLocals.cpp`, `pass.cpp`, and the three dedicated lit files.
- [`./unsupported-types-effects-and-import-roster.md`](./unsupported-types-effects-and-import-roster.md)
  Focused guide to the most non-obvious half of the pass: partial type support, `i64` helper-import vs no-rewrite drift, typed-function-ref and general-ref boundaries, `Pop` skipping, and why `addsEffects()` matters.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for wrapped gets, wrapped sets/tees, helper-import injection, `i64` no-op cases, and the legacy-EH `pop` boundary.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current local status and future-port map: no registry spelling today, exact code locations where pass names are accepted/rejected, and the module-pass requirements a future port would need to satisfy.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Focused future-port bridge: scalar-first module-pass slice, helper-import synthesis requirements, red-herring local code surfaces, and validation ladder.

## Current maintenance rule

- Treat this folder as the canonical home for future `instrument-locals` research.
- Keep it explicitly marked as an **upstream-only** dossier unless Starshine later grows a real registry entry for this pass.
- Keep the local status precise: current Starshine rejects it as an unknown pass, not as boundary-only or removed.
- Keep the split from locals optimizers explicit: `instrument-locals` adds imported-call observations, while passes like `simplify-locals*` and `untee` remove or canonicalize local traffic.
- Keep the global-effects interaction explicit too: this pass is small, but it is intentionally effectful.
- If Starshine ever ports this pass, start from [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md): helper imports and effect invalidation are the real first problem, not just finding `LocalGet` / `LocalSet` nodes.

## Sources

- [`../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md`](../../../raw/binaryen/2026-04-24-instrument-locals-primary-sources.md)
- [`../../../raw/research/0287-2026-04-24-instrument-locals-primary-sources-and-starshine-followup.md`](../../../raw/research/0287-2026-04-24-instrument-locals-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0227-2026-04-21-instrument-locals-binaryen-research.md`](../../../raw/research/0227-2026-04-21-instrument-locals-binaryen-research.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/InstrumentLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals_effects.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/instrument-locals-eh-legacy.wast>
- Current-`main` spot-check sources:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentLocals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_effects.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals-eh-legacy.wast>
