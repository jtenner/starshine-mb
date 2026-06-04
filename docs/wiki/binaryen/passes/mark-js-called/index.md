---
kind: entity
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md
  - ../../../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
related:
  - ../strip-toolchain-annotations/index.md
  - ../legalize-js-interface/index.md
  - ../instrument-locals/index.md
  - ../tracker.md
  - ../late-pipeline-dispatch.md
  - ../../release-horizon-and-oracles.md
---

# Binaryen `mark-js-called`

## Overview

`mark-js-called` is a Binaryen `version_130` upstream pass surface for the `@binaryen.js.called` toolchain annotation. It should be read as an annotation / call-boundary classification pass, not as a generic JS-interface legalization pass and not as export pruning. The release-horizon page now treats `version_130` as the current public Binaryen baseline, and the focused 2026-06-04 source read confirms that `MarkJSCalled.cpp` plus `test/lit/passes/mark-js-called.wast` exist in that tag.

For a beginner: Binaryen and Starshine both carry extra metadata in addition to core WebAssembly instructions. `@binaryen.js.called` is one such function-level marker. It tells Binaryen that a function is observable from JavaScript-call boundaries, which matters for later passes that might otherwise remove or change annotation-bearing functions.

For an implementer: keep this page separate from [`strip-toolchain-annotations`](../strip-toolchain-annotations/index.md). `strip-toolchain-annotations` removes selected toolchain annotations; `mark-js-called` is the upstream pass that creates or marks the `js.called` fact. A local port must preserve that lifecycle distinction.

## Current Upstream And Starshine Status

| Surface | Status |
| --- | --- |
| Upstream release horizon | Present in Binaryen `version_130`; see the source read in [`../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md`](../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md). |
| Upstream owner/test files | `src/passes/MarkJSCalled.cpp` and `test/lit/passes/mark-js-called.wast` in Binaryen `version_130`. |
| Starshine registry | Not registered on 2026-06-04; focused `src/` searches found no `mark-js-called` or `MarkJSCalled` pass spelling. |
| Starshine prerequisite representation | Present: `FuncAnnotation`, `FuncAnnotationAssoc`, `FuncAnnotationSec`, and `Module.func_annotation_sec` in [`src/lib/types.mbt`](../../../../../src/lib/types.mbt). |
| Starshine text support | Present for the annotation itself: WAST parse/lower tests cover `(@binaryen.js.called)` on function imports and definitions in [`src/wast/parser.mbt`](../../../../../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt), and [`src/wast/module_wast_tests.mbt`](../../../../../src/wast/module_wast_tests.mbt). |

Because Starshine already parses and lowers the annotation but has no pass that synthesizes it, the correct current wiki status is **upstream-only / local-unknown**, not `boundary-only` or `removed`.

## Invariants And Edge Cases For A Future Port

- **Annotation identity matters.** A faithful pass must write the exact Binaryen annotation name used by the WAST surface: `binaryen.js.called`.
- **Do not conflate with JS ABI legalization.** [`legalize-js-interface`](../legalize-js-interface/index.md) changes imports/exports/wrappers around JS-compatible ABI surfaces; `mark-js-called` is an annotation pass.
- **Do not conflate with annotation stripping.** If `strip-toolchain-annotations` later removes `js.called`, this pass must run before or after it intentionally; the scheduler must not accidentally create and then immediately erase evidence.
- **Function imports and definitions both matter locally.** Starshine WAST tests already cover the annotation on both imported and defined function declarations, so a port should keep imported-function index prefixes in mind.
- **Validation is mostly metadata integrity.** Core wasm validation should be unaffected by adding an annotation, but Starshine should still preserve function-index alignment, name-section expectations, and any annotation-section ordering/printing invariants.

## Practical First Slice

1. Re-read Binaryen `version_130` `MarkJSCalled.cpp` and `mark-js-called.wast` line-by-line.
2. Decide whether Starshine should keep the pass unknown, register a boundary-only name, or implement a no-op/analyzer first slice.
3. If implementing, start with annotation-section mutation only; do not touch function bodies.
4. Add tests that prove existing `(@binaryen.js.called)` annotations survive, newly marked functions receive exactly the expected annotation, unrelated annotations such as `binaryen.idempotent` and `metadata.code.inline` are preserved, and imports/defs keep correct function indices.
5. Compare against Binaryen `--mark-js-called` once the pass is accepted locally.

## Sources

- Focused source manifest: [`../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md`](../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md)
- Tracker-expansion note: [`../../../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md`](../../../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md)
- Local annotation representation: [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- Local WAST parse/lower/test surface: [`../../../../../src/wast/parser.mbt`](../../../../../src/wast/parser.mbt), [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt), [`../../../../../src/wast/module_wast_tests.mbt`](../../../../../src/wast/module_wast_tests.mbt)
