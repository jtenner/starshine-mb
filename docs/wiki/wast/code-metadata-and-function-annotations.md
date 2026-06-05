---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md
  - ../raw/wasm/2026-06-05-compilation-hints-boundary-refresh.md
  - ../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md
  - ../raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md
  - ../raw/wasm/2026-05-20-code-metadata-and-function-annotation-sources.md
  - ../raw/wasm/2026-05-19-wast-identifier-name-sources.md
  - ../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md
  - ../../../src/wast/lexer.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/passes/no_inline.mbt
  - ../../../src/passes/inlining.mbt
  - ../../../src/passes/duplicate_function_elimination.mbt
  - ../../../src/passes/duplicate_import_elimination.mbt
  - ../../../src/passes/remove_unused_module_elements.mbt
related:
  - identifier-name-and-annotation-authoring.md
  - ../binary/custom-and-name-sections.md
  - ../binary/function-import-export-and-code-sections.md
  - ../wasm-compilation-hints-boundary.md
  - ../binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ../binaryen/passes/mark-js-called/index.md
  - ../binaryen/passes/strip-toolchain-annotations/index.md
  - ../binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md
  - ../binaryen/passes/vacuum/wat-shapes.md
  - ../binaryen/passes/remove-unused-brs/index.md
---

# WAST Code Metadata And Function Annotations

## Overview

Use this page when a fixture, pass, or CLI policy mentions `(@...)`, `@metadata.code.inline`, `@metadata.code.branch_hint`, `@binaryen.idempotent`, `@binaryen.js.called`, or Starshine's internal no-inline markers. The important split is:

- **Official WebAssembly custom annotation syntax and branch hinting** are finished/Core-3.0 metadata surfaces. `@name` / `@custom` live in the custom-section appendix, and branch hints use the code-metadata mechanism as `metadata.code.branch_hint`.
- **WebAssembly/Binaryen code metadata** can describe instruction-location metadata such as inline hints, branch hints, and toolchain-owned annotations. Code metadata attaches to a concrete instruction location, not to a whole function by default.
- **Compilation Hints** is a separate active Phase-2 proposal over `metadata.code.compilation_priority`, `metadata.code.instr_freq`, and `metadata.code.call_targets`; route that through [`../wasm-compilation-hints-boundary.md`](../wasm-compilation-hints-boundary.md) instead of treating local annotations or branch hints as support.
- **Starshine today supports only a narrow function/import annotation lane** in WAST and in memory. Its `(@...)` syntax looks similar to code metadata text, but it attaches to the following function/import field and lowers to `FuncAnnotationSec`. It does not yet model official `@name`, placement-aware `@custom`, expression-level code metadata, `metadata.code.branch_hint`, or binary custom-section encoding for those annotations.

The current 2026-06-05 status refresh is [`../raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md`](../raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md). It rechecked the current Core 3.0 custom appendix, code-metadata pages, branch-hinting spec, finished-proposals table, active proposals tracker, and Starshine repository evidence. The older source manifest [`../raw/wasm/2026-05-20-code-metadata-and-function-annotation-sources.md`](../raw/wasm/2026-05-20-code-metadata-and-function-annotation-sources.md) remains useful for the original source map, while the 2026-06-04 custom/name refresh adds one more practical warning: official text `(@name ...)` and `(@custom ...)` have name-section and placement-aware custom-section meanings upstream, but Starshine's current WAST `(@...)` lane does not implement those official semantics.

## Layer Map

| Layer | Portable or local? | Starshine status | What not to infer |
| --- | --- | --- | --- |
| WebAssembly name/custom annotations | Finished/Core-3.0 text name-section/custom-section model | Starshine preserves opaque non-`name` custom sections at the binary layer and lowers function `$` ids into function names, but it does not implement official `@name` lowering or exact `@custom` placement. See [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md). | Do not infer official `@name` or exact `@custom` support from Starshine's `(@...)` parser lane. |
| WebAssembly/Binaryen code metadata | Core/code-metadata plus Binaryen optimizer metadata | Starshine documents `metadata.code.inline` and branch hints through Binaryen pass pages, but has no general expression annotation model. Branch hints are now finished/Core-3.0 metadata. | Do not treat a pass WAT example containing `@metadata.code.branch_hint` as proof that Starshine can parse/lower that expression annotation or preserve byte-offset metadata sections. |
| Compilation Hints | Active Phase-2 proposal over `metadata.code.compilation_priority`, `metadata.code.instr_freq`, and `metadata.code.call_targets` | No first-class Starshine payload parser, byte-offset metadata model, structured WAST hint syntax, generator gate, or optimizer consumer. | Do not infer proposal support from raw function annotations, local no-inline markers, Binaryen metadata examples, or opaque custom-section preservation. |
| Starshine WAST function annotations | Local WAST and in-memory metadata | `(@...)` immediately before a defined function or func import becomes `FuncAnnotationSec` keyed by absolute `FuncIdx`. | Do not assume annotations on globals, memories, tables, expressions, modules, arbitrary custom sections, or instruction offsets are supported. |
| Starshine no-inline policy | Local optimizer policy | `no-inline*` passes add internal `starshine.no-full-inline` / `starshine.no-partial-inline` function annotations. | Do not confuse those markers with Binaryen `@metadata.code.inline` bytes. |

## Supported Starshine Shape

Starshine's accepted WAST shape is one or more `(@...)` forms immediately before a function definition or a function import:

```wat
(module
  (@binaryen.js.called)
  (import "env" "callback" (func $callback))

  (@binaryen.idempotent)
  (@metadata.code.inline "\00")
  (func $work (result i32)
    (i32.const 1)))
```

The parser stores each annotation as `{ name, args }`, where args are raw token/literal text. The lowerer writes them into `Module.func_annotation_sec` as `FuncAnnotationAssoc(FuncIdx, Array[FuncAnnotation])`. Function indices are absolute: imported functions come first, followed by defined functions. Pair this page with [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md) whenever a pass remaps functions.

Because the parser does not interpret official annotation names, `(@name "debug") (func ...)` and `(@custom "x" "payload") (func ...)` are legal only as Starshine-local function annotations when attached to a function/import; they do not produce `NameSec` entries or `CustomSec` payloads. The official text forms belong to [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md) until Starshine grows dedicated support.

The same spelling before an instruction is different: in WebAssembly code-metadata text, it annotates that instruction location; in Starshine today, `parse_annotated_module_field(...)` only consumes annotations before top-level module fields and `attach_annotations(...)` rejects every field except functions and func imports. That is why the following branch-hint shape is unsupported locally even though it is meaningful upstream:

```wat
(module
  ;; Not a proven Starshine surface today: expression-level annotation.
  (func $branchy (param i32) (result i32)
    (if (result i32)
      (@metadata.code.branch_hint "\01")
      (local.get 0)
      (then (i32.const 1))
      (else (i32.const 0)))))
```

Binaryen uses branch-hint examples in pass tests, and pass dossiers may describe how Binaryen preserves, flips, or ignores them. In Starshine docs, those examples are **upstream oracle shapes** unless a local parser/lowerer/core model is cited.

## Local Implementation Flow

1. [`src/wast/lexer.mbt`](../../../src/wast/lexer.mbt) recognizes an annotation opener token for `(@...`.
2. [`parse_annotation(...)`](../../../src/wast/parser.mbt) records a name and raw arguments.
3. [`parse_annotated_module_field(...)`](../../../src/wast/parser.mbt) accumulates adjacent annotations before a module field.
4. [`attach_annotations(...)`](../../../src/wast/parser.mbt) accepts only defined functions and func imports, rejecting every other annotated field family.
5. [`module_wast.mbt`](../../../src/wast/module_wast.mbt) prints supported annotations before the associated function/import field.
6. [`wt_func_annotations(...)`](../../../src/wast/lower_to_lib.mbt) and [`wt_lower_module(...)`](../../../src/wast/lower_to_lib.mbt) lower them into [`FuncAnnotationSec`](../../../src/lib/types.mbt).
7. The binary codec currently has no `FuncAnnotationSec` encoding or decoding path. WAST-origin function annotations are useful in memory during the same command/lowering pipeline, but they are not a binary roundtrip guarantee.

## Optimizer Policy And Rewrite Rules

### Binaryen `js.called` markers

Starshine can parse, print, and lower existing `(@binaryen.js.called)` function/import annotations through the same `FuncAnnotationSec` lane as other function annotations. That is metadata support, not implementation of Binaryen's [`mark-js-called`](../binaryen/passes/mark-js-called/index.md) pass. The current Binaryen pass scans configureAll intrinsic calls and synthesizes `js.called` annotations for referred functions; it does not merely preserve annotations that already appear in WAST. Keep this distinction visible when using `(@binaryen.js.called)` fixtures: a parser/lowerer fixture proves annotation carriage, while a future pass fixture must prove configureAll-driven marking.

### No-inline markers

Starshine's no-inline passes deliberately avoid overloading `metadata.code.inline`. Instead, [`src/passes/no_inline.mbt`](../../../src/passes/no_inline.mbt) creates internal annotations:

- `starshine.no-full-inline`
- `starshine.no-partial-inline`

`no-inline=<pattern>` adds both markers, while `no-full-inline=<pattern>` and `no-partial-inline=<pattern>` add one marker each. [`src/passes/inlining.mbt`](../../../src/passes/inlining.mbt) reads those markers for the local direct inliner. The Binaryen policy split is documented in [`../binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md`](../binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md): `@metadata.code.inline` is preserved metadata, while actual no-inline policy is a separate function-level control.

### Function-index remaps

Any pass that deletes, merges, duplicates, imports, or reorders functions must rewrite or intentionally clear function annotations together with all other `FuncIdx` carriers:

- direct and tail calls;
- `ref.func` declarations and uses;
- start, exports, element payloads/expressions, globals, tables, and data offsets containing function references;
- function names in `NameSec.func_names`; and
- `FuncAnnotationSec` entries.

Current examples:

- [`duplicate_import_elimination`](../../../src/passes/duplicate_import_elimination.mbt) remaps annotations when duplicate imported functions collapse.
- [`remove_unused_module_elements`](../../../src/passes/remove_unused_module_elements.mbt) drops annotations for removed functions and rewrites retained entries.
- [`inlining`](../../../src/passes/inlining.mbt) remaps annotations after helper compaction and deduplicates merged annotation arrays.
- [`duplicate_function_elimination`](../../../src/passes/duplicate_function_elimination.mbt) treats function annotations as part of the function-equivalence key where they can affect optimizer behavior, then rewrites survivors.

### Branch hints and expression annotations

Branch hints are not modeled locally yet. The current WebAssembly branch-hinting spec makes `metadata.code.branch_hint` a finished/Core-3.0 code-metadata surface attached only to `if` and `br_if` instruction locations, with a one-byte likely/unlikely payload. That upstream status does not change Starshine's local layer: no `branch_hint` representation, parser/lowerer path, binary code-metadata section, or expression-remap tests exist today. This matters because several Binaryen pass pages discuss branch-hint behavior:

- [`vacuum`](../binaryen/passes/vacuum/wat-shapes.md) can flip branch hints when it flips empty `if` arms upstream.
- [`remove-unused-brs`](../binaryen/passes/remove-unused-brs/index.md) treats branch hints as part of the upstream rewrite contract.
- [`duplicate-function-elimination`](../binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md) teaches that non-semantic metadata such as branch hints does not block merging, while semantics-altering function annotations can.

For Starshine work, do not claim branch-hint parity unless the change adds a local representation, parser/lowerer support, binary behavior, and pass tests that keep hints attached to the right expression after rewrites.

## Edge Cases And Invariants

- **Attachment is syntactic and narrow.** `(@...)` must appear immediately before a function definition or func import. Module-, resource-, data-, element-, local-, and expression-level annotations should be rejected today.
- **Official `@name` and `@custom` are not interpreted.** In the current local lane they are just annotation names plus raw args, not requests to update `NameSec` or `custom_secs`.
- **Arguments are not interpreted by the parser.** Starshine preserves argument token text in `FuncAnnotation.args`; pass policy must decide which names and args it understands.
- **Function-import annotations use imported-prefix indices.** An annotation on the first imported function is keyed at `FuncIdx(0)`, not at a separate import ordinal.
- **Existing `js.called` syntax is not `mark-js-called` parity.** Use [`../binaryen/passes/mark-js-called/index.md`](../binaryen/passes/mark-js-called/index.md) for the upstream configureAll-driven pass contract.
- **Branch-hinting is upstream/Core metadata, not local support.** A Binaryen or official WAT example with `@metadata.code.branch_hint` is source-oracle evidence until Starshine grows an expression-level representation and remap tests.
- **Compilation Hints is proposal metadata, not local optimizer policy.** Starshine's current no-inline/inlining annotations do not consume `metadata.code.compilation_priority`, `metadata.code.instr_freq`, `metadata.code.call_targets`, `never_opt`, or `always_opt`; use [`../wasm-compilation-hints-boundary.md`](../wasm-compilation-hints-boundary.md).
- **Binary roundtrip is absent for `FuncAnnotationSec`.** If a test needs annotation preservation after binary encode/decode, it must first implement and document the binary custom/code-metadata format or preserve an opaque custom section separately.
- **Name-section and annotation-section repairs are separate.** A function can have a debug name, annotations, both, or neither. Rewriting one map does not repair the other automatically.
- **Toolchain-stripping is not generic metadata stripping.** [`strip-toolchain-annotations`](../binaryen/passes/strip-toolchain-annotations/index.md) removes selected Binaryen-owned annotations and preserves `metadata.code.inline`; future local support should make the same subset boundary explicit.
- **Unknown annotations should be preserved by default.** Unless a pass owns a specific policy, keep annotation names/args unchanged and remap only the function index association.

## Validation And Signoff Guidance

- Parser/printer changes belong in [`src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), and their focused tests.
- Lowering changes should add WAST-to-core tests in [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt) and assert exact `FuncAnnotationSec` entries.
- Function-remapping passes should add tests that annotations follow surviving functions, removed functions lose annotations, and repeated remaps do not duplicate markers.
- No-inline policy changes should update [`src/passes/no_inline.mbt`](../../../src/passes/no_inline.mbt), [`src/passes/inlining.mbt`](../../../src/passes/inlining.mbt), the inlining dossier, and CLI/registry docs if command-facing behavior changes.
- Official `@name` / `@custom` text work should start in the WAST parser/lowerer/printer and binary custom/name docs, with tests proving `NameSec` or `CustomSec` effects rather than `FuncAnnotationSec` effects.
- Expression-level code-metadata, branch-hint, or Compilation Hints work should start with a representation design and source-backed tests before updating pass pages that currently describe only Binaryen oracle behavior.

## Sources

- Current code-metadata / branch-hint status refresh: [`../raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md`](../raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md)
- Compilation Hints boundary refresh: [`../raw/wasm/2026-06-05-compilation-hints-boundary-refresh.md`](../raw/wasm/2026-06-05-compilation-hints-boundary-refresh.md), [`../wasm-compilation-hints-boundary.md`](../wasm-compilation-hints-boundary.md)
- Binaryen `mark-js-called` behavior refresh: [`../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md`](../raw/binaryen/2026-06-04-mark-js-called-remove-exports-behavior-refresh.md)
- Current custom/name/text-annotation refresh: [`../raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md`](../raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md)
- Source refresh: [`../raw/wasm/2026-05-20-code-metadata-and-function-annotation-sources.md`](../raw/wasm/2026-05-20-code-metadata-and-function-annotation-sources.md)
- WAST identifier/name baseline: [`../raw/wasm/2026-05-19-wast-identifier-name-sources.md`](../raw/wasm/2026-05-19-wast-identifier-name-sources.md), [`identifier-name-and-annotation-authoring.md`](identifier-name-and-annotation-authoring.md)
- Binaryen inlining and strip-toolchain evidence: [`../raw/binaryen/2026-04-23-inlining-primary-sources.md`](../raw/binaryen/2026-04-23-inlining-primary-sources.md), [`../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md`](../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md)
- Starshine code: [`../../../src/wast/lexer.mbt`](../../../src/wast/lexer.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/passes/no_inline.mbt`](../../../src/passes/no_inline.mbt), [`../../../src/passes/inlining.mbt`](../../../src/passes/inlining.mbt), [`../../../src/passes/duplicate_function_elimination.mbt`](../../../src/passes/duplicate_function_elimination.mbt), [`../../../src/passes/duplicate_import_elimination.mbt`](../../../src/passes/duplicate_import_elimination.mbt), [`../../../src/passes/remove_unused_module_elements.mbt`](../../../src/passes/remove_unused_module_elements.mbt)
