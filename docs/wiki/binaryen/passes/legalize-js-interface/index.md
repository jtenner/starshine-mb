---
kind: entity
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md
  - ../../../raw/research/0395-2026-04-26-legalize-js-interface-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md
  - ../../../raw/research/0291-2026-04-24-legalize-js-interface-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0223-2026-04-21-legalize-js-interface-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../i64-to-i32-lowering/index.md
  - ../legalize-and-prune-js-interface/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./temp-ret-helpers-and-pruning-split.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../i64-to-i32-lowering/index.md
  - ../legalize-and-prune-js-interface/index.md
  - ../tracker.md
---

# `legalize-js-interface`

## Role

- `legalize-js-interface` is a real public Binaryen pass.
- It is currently **upstream-only** in this repo's living pass map: it is **not** in Starshine's local optimizer registry in `src/passes/optimize.mbt`, so requests hit the unknown-pass path rather than a boundary-only or removed-pass rejection.
- It is **not** part of the repo's canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `legalize-js-interface` slice**.

## Why this dossier exists

The tracker currently has no obvious remaining pass entries with wiki status `none`.
That means a new dossier needs explicit justification.

`legalize-js-interface` meets that bar because the existing `i64-to-i32-lowering` dossier already depends on it explicitly: Binaryen's import retargeting comments say `legalize-js-interface` should already have run, but the wiki had no canonical page explaining what that earlier boundary pass actually does.

Without this folder, it was too easy to blur together:

- `legalize-js-interface`, which rewrites the JS-visible import/export ABI around `i64` with wrapper functions and temp-ret helpers, and
- `i64-to-i32-lowering`, which rewrites the whole module's internal `i64`-using code into pair-lowered forms.

## Beginner summary

A good beginner mental model is:

- if JS would see an exported function with `i64`, export a legal wrapper instead
- if wasm would call an imported function with `i64`, insert a wasm-side wrapper around a legalized import
- split each `i64` parameter into `(i32 low, i32 high)`
- return the low 32 bits directly and move the high 32 bits through temp-ret helpers
- optionally keep original exports or reuse already-exported temp-ret helpers
- in the pruning sibling, remove or stub boundary items that still cannot be made JS-legal

So this pass is best taught as:

- **JS boundary ABI legalization for `i64` imports and exports**
- not a whole-module integer lowering pass
- not a general optimizer
- not a generic "make any wasm feature valid for JS" pass

## Most important durable takeaways

- The entire reviewed `version_129` contract lives in one shared file, `LegalizeJSInterface.cpp`, with two public registrations in `pass.cpp`: plain `legalize-js-interface` and sibling `legalize-and-prune-js-interface`.
- The 2026-04-24 raw primary-source capture anchors the folder to the official `version_129` release surface and exact source/test URLs reviewed in this follow-up.
- Plain `legalize-js-interface` only treats function boundary signatures that contain `i64` params or an `i64` result.
- Illegal exports get `legalstub$...` wrappers; illegal imports get `legalimport$...` legalized imports plus `legalfunc$...` wasm-facing wrappers.
- Imported-call repair is not just for `call`; Binaryen also rewrites `ref.func` uses and scans module code in addition to ordinary function bodies.
- The pass uses `setTempRet0` / `getTempRet0` helpers for the high 32 bits of legalized `i64` results.
- `--pass-arg=legalize-js-interface-export-originals` keeps extra `orig$...` exports for non-import, non-`dynCall_*` originals.
- `--pass-arg=legalize-js-interface-exported-helpers` reuses already-exported `__set_temp_ret` / `__get_temp_ret` helpers instead of importing `setTempRet0` / `getTempRet0` from `env`.
- The pruning sibling goes further: it removes exports and replaces imports that still expose unsupported JS-surface features such as SIMD, multivalue results, exception handling, or stack switching.
- A 2026-04-26 current-`main` port-readiness recheck found `LegalizeJSInterface.cpp`, the reviewed helper headers, and the reviewed lit files unchanged in teaching-relevant ways from `version_129`.
- The current Starshine strategy is honest non-adoption: no registry entry, no owner file, no backlog slice, but clear module/import/export/ref.func code surfaces for a future module pass.
- The new Starshine port-readiness page makes the first safe implementation slice explicit: registry honesty, export stubs, default temp-ret helpers, import wrappers plus direct-call repair, `ref.func` repair, then deletion of original illegal imports; prune mode stays separate.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Main implementation walkthrough: wrapper generation, temp-ret flow, import/export rewrite phases, and the exact split from whole-module lowering.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Compact owner-file and proof-surface map for `LegalizeJSInterface.cpp`, `pass.cpp`, and the dedicated lit roster.
- [`./temp-ret-helpers-and-pruning-split.md`](./temp-ret-helpers-and-pruning-split.md)
  Focused guide to the non-obvious half of the family: temp-ret helper selection, `export-originals`, `exported-helpers`, and what the pruning sibling does beyond plain `i64` legalization.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for exported stubs, imported wrappers, `ref.func` repair, helper reuse, and prune-only removals.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future port bridge: exact registry omission, unknown-pass request path, no owner file, no backlog slice, and the local module/import/export/ref.func code surfaces a future implementation would need.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  First-slice and validation guide for a future module pass: function-index rewrite risks, export-stub and import-wrapper sequencing, `ref.func` repair coverage, temp-ret helper lanes, and Binaryen fixture comparison.

## Current maintenance rule

- Treat this folder as the canonical home for future `legalize-js-interface` research.
- Keep it explicitly marked as an **upstream-only** dossier unless Starshine later grows a real registry entry for this surface.
- Cite [`../../../raw/binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md) and [`../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md) for raw source provenance, [`./starshine-strategy.md`](./starshine-strategy.md) for current local status, and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for future implementation sequencing.
- Keep the split from `i64-to-i32-lowering` explicit: `legalize-js-interface` changes the JS boundary ABI, while `i64-to-i32-lowering` changes internal module code.
- Keep the sibling relationship explicit too: `legalize-and-prune-js-interface` is the same family plus extra pruning, not a wholly different algorithm.

## Sources

- [`../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md)
- [`../../../raw/research/0291-2026-04-24-legalize-js-interface-primary-sources-and-starshine-followup.md`](../../../raw/research/0291-2026-04-24-legalize-js-interface-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0223-2026-04-21-legalize-js-interface-binaryen-research.md`](../../../raw/research/0223-2026-04-21-legalize-js-interface-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface-exported-helpers.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast>
- Current-`main` spot-check sources:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LegalizeJSInterface.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-js-interface-exported-helpers.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-js-interface_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/legalize-and-prune-js-interface.wast>
