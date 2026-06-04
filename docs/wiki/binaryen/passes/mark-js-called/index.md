---
kind: entity
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md
  - ../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md
  - ../../../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
related:
  - ../../../wast/code-metadata-and-function-annotations.md
  - ../strip-toolchain-annotations/index.md
  - ../legalize-js-interface/index.md
  - ../instrument-locals/index.md
  - ../tracker.md
  - ../late-pipeline-dispatch.md
  - ../../release-horizon-and-oracles.md
---

# Binaryen `mark-js-called`

## Overview

`mark-js-called` is Binaryen's configureAll-driven pass for adding the `@binaryen.js.called` toolchain annotation to functions. It should be read as an annotation-synthesis pass, not as generic JS-interface legalization, export pruning, or ordinary call-graph optimization. The release-horizon page now treats `version_130` as the current public Binaryen baseline, and the behavior refresh in [`../../../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md`](../../../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md) confirms that the released `version_130` source and current `main` source still have the same small contract.

For a beginner: WebAssembly function bodies are not the only facts an optimizer tracks. Binaryen also carries function annotations. `@binaryen.js.called` marks a function as observable from a JavaScript-call boundary, which can matter to later passes that would otherwise treat the function as internally callable only. The pass does not itself call JavaScript or change a function signature; it writes metadata.

For an implementer: keep this page separate from [`strip-toolchain-annotations`](../strip-toolchain-annotations/index.md) and [`legalize-js-interface`](../legalize-js-interface/index.md). `strip-toolchain-annotations` removes selected Binaryen-owned annotations; `legalize-js-interface` changes ABI-facing wrappers and calls; `mark-js-called` discovers configureAll references and sets the `js.called` fact. A local port must preserve that lifecycle distinction.

## Current Upstream And Starshine Status

| Surface | Status |
| --- | --- |
| Upstream release horizon | Present in Binaryen `version_130`; see the source read in [`../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md`](../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md). |
| Upstream owner/test files | `src/passes/MarkJSCalled.cpp` and `test/lit/passes/mark-js-called.wast` in Binaryen `version_130` and still materially unchanged on current `main` as of [`../../../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md`](../../../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md). |
| Starshine registry | Not registered on 2026-06-04; focused `src/` searches found no `mark-js-called` or `MarkJSCalled` pass spelling. |
| Starshine prerequisite representation | Present: `FuncAnnotation`, `FuncAnnotationAssoc`, `FuncAnnotationSec`, and `Module.func_annotation_sec` in [`src/lib/types.mbt`](../../../../../src/lib/types.mbt). |
| Starshine text support | Present for the annotation itself: WAST parse/lower tests cover `(@binaryen.js.called)` on function imports and definitions in [`src/wast/parser.mbt`](../../../../../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt), and [`src/wast/module_wast_tests.mbt`](../../../../../src/wast/module_wast_tests.mbt). |

Because Starshine already parses and lowers the annotation but has no pass that synthesizes it from configureAll calls, the correct current wiki status is **upstream-only / local-unknown**, not `boundary-only`, `removed`, or implemented-by-WAST-support.

## Upstream Behavior Shape

Binaryen's pass has two phases:

1. **Scan for configured targets.** If no intrinsic `configureAll` function exists in the module, the pass exits. Otherwise it walks defined functions, finds calls that Binaryen recognizes as `configureAll`, extracts the function names carried by that intrinsic payload, and records the referred functions.
2. **Mark the functions.** It then sets the `jsCalled` annotation bit on each referred function. It does not rewrite exports, call instructions, imports, bodies, or signatures. Existing annotations remain metadata on their original functions; the pass only adds the missing `js.called` fact for discovered targets.

A teaching example is therefore:

```wat
(module
  ;; Pseudocode-level shape: the real Binaryen fixture uses the
  ;; configureAll intrinsic form recognized by Binaryen's intrinsics layer.
  (func $configure (call $configureAll ... "$callback" ...))
  (func $callback)
  ;; after --mark-js-called, Binaryen annotates $callback as js-called
)
```

The important caveat is that a Starshine fixture containing an existing `(@binaryen.js.called)` annotation only proves local metadata parsing/lowering. It does **not** prove the `mark-js-called` pass unless the fixture also exercises Binaryen-style configureAll recognition and annotation synthesis.

## Invariants And Edge Cases For A Future Port

- **Annotation identity matters.** A faithful pass must write the exact Binaryen annotation name used by the WAST surface: `binaryen.js.called`.
- **ConfigureAll is the semantic trigger.** Preserving or printing pre-existing `(@binaryen.js.called)` annotations is prerequisite metadata support, not the pass contract. A local implementation needs a source-backed model of configureAll intrinsic calls and payload extraction.
- **Do not conflate with JS ABI legalization.** [`legalize-js-interface`](../legalize-js-interface/index.md) changes imports/exports/wrappers around JS-compatible ABI surfaces; `mark-js-called` is an annotation pass.
- **Do not conflate with annotation stripping.** If [`strip-toolchain-annotations`](../strip-toolchain-annotations/index.md) removes `js.called`, this pass must run before or after it intentionally; the scheduler must not accidentally create and then immediately erase evidence.
- **Function imports and definitions both matter locally.** Starshine WAST tests already cover the annotation on both imported and defined function declarations, so a port should keep imported-function index prefixes in mind even though Binaryen's current marking scan walks defined function bodies.
- **Validation is mostly metadata integrity.** Core wasm validation should be unaffected by adding an annotation, but Starshine should still preserve function-index alignment, name-section expectations, and any annotation-section ordering/printing invariants.

## Practical First Slice

1. Re-read Binaryen `version_130` and current `main` `MarkJSCalled.cpp`, `mark-js-called.wast`, and the relevant intrinsics helpers line-by-line.
2. Decide whether Starshine should keep the pass unknown, register a boundary-only name, or implement an analyzer first slice.
3. If implementing, start by recognizing the configureAll intrinsic shape and collecting target function indices without mutation. Only then add annotation-section mutation.
4. Add tests that prove existing `(@binaryen.js.called)` annotations survive, configureAll-referred functions receive exactly the expected annotation, unrelated annotations such as `binaryen.idempotent` and `metadata.code.inline` are preserved, non-referred functions remain unmarked, and imports/defs keep correct function indices.
5. Compare against Binaryen `--mark-js-called` once the pass is accepted locally.

## Sources

- Behavior refresh: [`../../../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md`](../../../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md)
- Focused source manifest: [`../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md`](../../../raw/binaryen/2026-06-04-v130-mark-js-called-remove-exports-source-read.md)
- Tracker-expansion note: [`../../../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md`](../../../raw/research/0706-2026-06-04-v130-mark-js-called-remove-exports-tracker-expansion.md)
- Local annotation representation: [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- Local WAST parse/lower/test surface: [`../../../../../src/wast/parser.mbt`](../../../../../src/wast/parser.mbt), [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt), [`../../../../../src/wast/module_wast_tests.mbt`](../../../../../src/wast/module_wast_tests.mbt)
