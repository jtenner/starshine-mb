---
kind: research
status: supported
last_reviewed: 2026-04-24
sources:
  - ../binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md
  - ../../binaryen/passes/strip-toolchain-annotations/index.md
  - ../../binaryen/passes/strip-toolchain-annotations/binaryen-strategy.md
  - ../../binaryen/passes/strip-toolchain-annotations/wat-shapes.md
  - ../../binaryen/passes/strip-toolchain-annotations/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast_tests.mbt
  - ../../../../src/passes/duplicate_function_elimination.mbt
related:
  - ../../binaryen/passes/late-pipeline-dispatch.md
  - ../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../binaryen/passes/instrument-locals/index.md
---

# `strip-toolchain-annotations` primary sources and Starshine follow-up

## Question

The late-pass chronology already mentioned Binaryen `--strip-toolchain-annotations` as a newer upstream-only pass, but the pass wiki had no dedicated dossier explaining which annotation families it removes, what it deliberately preserves, or how that maps to Starshine's current annotation model.

## Sources reviewed

- Official Binaryen `version_129` release page and `CHANGELOG.md`.
- Binaryen `version_129` and current-`main` `StripToolchainAnnotations.cpp`.
- Binaryen `version_129` `pass.cpp` and `passes.h`.
- Binaryen `version_129` and current-`main` `test/lit/passes/strip-toolchain-annotations.wast`.
- Local Starshine registry and annotation surfaces in `src/passes/optimize.mbt`, `src/lib/types.mbt`, `src/wast/parser.mbt`, `src/wast/lower_to_lib.mbt`, `src/wast/module_wast_tests.mbt`, and `src/passes/duplicate_function_elimination.mbt`.

## Findings

- `strip-toolchain-annotations` is a real public Binaryen pass. The tagged `version_129` changelog still records it as a `version_126` addition.
- Binaryen's implementation is deliberately narrow: it clears Binaryen/toolchain annotation bits and does not rewrite executable expressions.
- The source-backed removed fields are `removableIfUnused`, `jsCalled`, and `idempotent`.
- The official lit file directly proves `@binaryen.removable.if.unused` and `@binaryen.idempotent` removal plus `@metadata.code.inline` preservation.
- `@binaryen.js.called` removal is source-backed by `remove(CodeAnnotation&)` and release-note context, but the reviewed dedicated lit file does not isolate that exact spelling.
- Starshine has no registry entry for `strip-toolchain-annotations`; explicit requests therefore hit the generic unknown-pass path today.
- Starshine already has a smaller annotation surface: WAT parsing/printing and lowering for function/function-import annotations plus `FuncAnnotationSec` in-memory storage. It does not currently expose a Binaryen-equivalent per-expression `codeAnnotations` surface in HOT IR.
- DFE has annotation remap/equivalence/hash helpers, so annotations are not invisible to local pass behavior even though there is no standalone strip pass.

## Durable wiki updates made

- Added a raw Binaryen primary-source manifest at `docs/wiki/raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md`.
- Added a new living dossier under `docs/wiki/binaryen/passes/strip-toolchain-annotations/` with:
  - landing overview;
  - Binaryen strategy;
  - implementation/test map;
  - annotation-shape catalog;
  - Starshine status and port map.
- Updated the pass folder catalog, tracker, top-level wiki index, late-pipeline terminology page, changelog, and log so the formerly only-mentioned upstream pass now has a stable home.

## Uncertainty

- Starshine's function annotation model is not one-to-one with Binaryen's function-level plus per-expression code annotations. A future port must decide whether to match Binaryen's printed WAT behavior, Binaryen's binary custom annotation sections, or only Starshine's current in-memory `FuncAnnotationSec` subset.
- The local binary encoder/decoder grep in this run did not expose a direct `func_annotation_sec` binary custom-section path, so binary-roundtrip support should be source-confirmed before it is promised.
- The pass is not a generic metadata stripper. Separate Binaryen names such as `strip-target-features`, `strip-producers`, and `strip-debug` should keep separate docs if they become relevant.

## Follow-up questions

- Should Starshine keep `strip-toolchain-annotations` unknown, or add it as boundary-only to document intentional non-support?
- If implemented, should the first local subset strip only `FuncAnnotationSec`, or wait until Starshine has a per-expression code-annotation model?
- Should DFE's local annotation-equivalence behavior be documented more directly as a dependency if annotation-stripping work becomes active?
