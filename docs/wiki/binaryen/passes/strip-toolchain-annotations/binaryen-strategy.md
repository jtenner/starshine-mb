---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../../raw/research/1573-2026-07-18-binaryen-version-131-release-impact-audit.md
  - ../../../raw/research/0504-2026-05-06-strip-toolchain-annotations-current-main-recheck.md
  - ../../../raw/research/0394-2026-04-26-strip-toolchain-annotations-port-readiness.md
  - ../../../raw/research/0324-2026-04-24-strip-toolchain-annotations-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../strip-target-features/index.md
---

# Binaryen strategy for `strip-toolchain-annotations`

## Source-backed contract

The 2026-05-06 current-main recheck found no teaching-relevant drift from the earlier `version_129` dossier.
Binaryen's `strip-toolchain-annotations` is a narrow metadata pass.
It removes Binaryen-owned toolchain annotation bits from functions and expressions and otherwise leaves the module's executable IR alone.

The key source-backed facts from `StripToolchainAnnotations.cpp` are:

- the pass is a `WalkerPass<PostWalker<StripToolchainAnnotations>>`;
- it is function-parallel;
- it does not require non-nullable local fixups;
- it clears function-level annotations through the same `remove(...)` helper used for expression code annotations;
- it visits the function's `codeAnnotations` map and erases entries that become empty;
- `remove(CodeAnnotation&)` clears these released v131 toolchain fields:
  - `removableIfUnused`
  - `jsCalled`
  - `idempotent`
  - `toolchainInline` / `@binaryen.inline`

## Why a postwalk is enough

This pass does not need dataflow, dominance, effect analysis, or expression rebuilding.
Each annotation can be inspected independently:

1. take the annotation record;
2. turn off the Binaryen/toolchain-specific bits;
3. leave other annotation fields alone;
4. erase the wrapper if the record is now empty.

Because the pass does not rewrite expressions, there is no need to repair stack types, rebuild locals, or rerun a semantic optimizer.

## What is preserved

The official lit surface distinguishes two inline metadata families:

```wat
(@metadata.code.inline "\00")
```

survives, while v131's Binaryen-owned `@binaryen.inline` toolchain hint is removed. The pass therefore strips the released inliner policy hint without becoming a generic Compilation Hints metadata stripper.

## Ordering in a pipeline

The file header says the pass is intended for the point after toolchain optimizations have already consumed these annotations.
That gives the main ordering rule:

- run it late enough that annotations such as `removableIfUnused` and `idempotent` are no longer needed by optimization passes;
- do not run it as an early canonicalization pass just because annotations are non-semantic for wasm execution.

## What this pass is not

Do not teach `strip-toolchain-annotations` as any of these:

- **not `strip-debug`:** it does not remove debug names or source-map style metadata;
- **not `strip-producers`:** it does not target the producers custom section;
- **not [`strip-target-features`](../strip-target-features/index.md):** it does not suppress target-feature metadata output;
- **not a generic custom-section stripper:** source review only proves Binaryen code-annotation cleanup;
- **not an optimizer:** it should not change generated code shape or runtime behavior.

## Main caveats

The source clears `jsCalled`, but the dedicated `strip-toolchain-annotations.wast` file reviewed in this pass focuses on `@binaryen.removable.if.unused`, `@binaryen.idempotent`, and `@metadata.code.inline` preservation.
So the `jsCalled` behavior is source-backed, while the other two removed families also have direct lit proof.

Binaryen's strategy covers two annotation surfaces: function-level annotations and per-expression `codeAnnotations`.
That distinction matters for Starshine because the local model currently has `FuncAnnotationSec` for function/import annotations but no matching expression-annotation map; see [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).
