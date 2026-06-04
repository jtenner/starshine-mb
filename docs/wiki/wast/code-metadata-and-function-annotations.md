---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
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
  - ../binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ../binaryen/passes/strip-toolchain-annotations/index.md
  - ../binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md
  - ../binaryen/passes/vacuum/wat-shapes.md
  - ../binaryen/passes/remove-unused-brs/index.md
---

# WAST Code Metadata And Function Annotations

## Overview

Use this page when a fixture, pass, or CLI policy mentions `(@...)`, `@metadata.code.inline`, `@metadata.code.branch_hint`, `@binaryen.idempotent`, `@binaryen.js.called`, or Starshine's internal no-inline markers. The important split is:

- **Official WebAssembly custom/code metadata** can describe placement-aware custom-section payloads and code-location metadata; code metadata attaches to a concrete instruction location, not to a whole function by default.
- **Binaryen code annotations** use that vocabulary for real optimizer metadata such as inline hints, branch hints, and toolchain-owned annotations.
- **Starshine today supports only a narrow function/import annotation lane** in WAST and in memory. Its `(@...)` syntax looks similar to code metadata text, but it attaches to the following function/import field and lowers to `FuncAnnotationSec`. It does not yet model Binaryen's full expression-level code metadata or binary custom-section encoding for those annotations.

The refreshed source manifest is [`../raw/wasm/2026-05-20-code-metadata-and-function-annotation-sources.md`](../raw/wasm/2026-05-20-code-metadata-and-function-annotation-sources.md). It ties the official custom-section/code-metadata proposal sources to the current Starshine parser, lowerer, core type, pass-remap, and Binaryen dossier evidence. The 2026-06-04 custom/name refresh adds one more practical warning: official text `(@name ...)` and `(@custom ...)` have name-section and placement-aware custom-section meanings upstream, but Starshine's current WAST `(@...)` lane does not implement those official semantics.

## Layer Map

| Layer | Portable or local? | Starshine status | What not to infer |
| --- | --- | --- | --- |
| WebAssembly name/custom annotations | Official text name-section/custom-section model | Starshine preserves opaque non-`name` custom sections at the binary layer and lowers function `$` ids into function names, but it does not implement official `@name` lowering or exact `@custom` placement. See [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md). | Do not infer official `@name` or exact `@custom` support from Starshine's `(@...)` parser lane. |
| WebAssembly/Binaryen code metadata | Proposal/Binaryen optimizer metadata | Starshine documents `metadata.code.inline` and branch hints through Binaryen pass pages, but has no general expression annotation model. | Do not treat a pass WAT example containing `@metadata.code.branch_hint` as proof that Starshine can parse/lower that expression annotation or preserve byte-offset metadata sections. |
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

Branch hints are not modeled locally yet. This matters because several Binaryen pass pages discuss branch-hint behavior:

- [`vacuum`](../binaryen/passes/vacuum/wat-shapes.md) can flip branch hints when it flips empty `if` arms upstream.
- [`remove-unused-brs`](../binaryen/passes/remove-unused-brs/index.md) treats branch hints as part of the upstream rewrite contract.
- [`duplicate-function-elimination`](../binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md) teaches that non-semantic metadata such as branch hints does not block merging, while semantics-altering function annotations can.

For Starshine work, do not claim branch-hint parity unless the change adds a local representation, parser/lowerer support, binary behavior, and pass tests that keep hints attached to the right expression after rewrites.

## Edge Cases And Invariants

- **Attachment is syntactic and narrow.** `(@...)` must appear immediately before a function definition or func import. Module-, resource-, data-, element-, local-, and expression-level annotations should be rejected today.
- **Official `@name` and `@custom` are not interpreted.** In the current local lane they are just annotation names plus raw args, not requests to update `NameSec` or `custom_secs`.
- **Arguments are not interpreted by the parser.** Starshine preserves argument token text in `FuncAnnotation.args`; pass policy must decide which names and args it understands.
- **Function-import annotations use imported-prefix indices.** An annotation on the first imported function is keyed at `FuncIdx(0)`, not at a separate import ordinal.
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
- Expression-level code-metadata or branch-hint work should start with a representation design and source-backed tests before updating pass pages that currently describe only Binaryen oracle behavior.

## Sources

- Current custom/name/text-annotation refresh: [`../raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md`](../raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md)
- Source refresh: [`../raw/wasm/2026-05-20-code-metadata-and-function-annotation-sources.md`](../raw/wasm/2026-05-20-code-metadata-and-function-annotation-sources.md)
- WAST identifier/name baseline: [`../raw/wasm/2026-05-19-wast-identifier-name-sources.md`](../raw/wasm/2026-05-19-wast-identifier-name-sources.md), [`identifier-name-and-annotation-authoring.md`](identifier-name-and-annotation-authoring.md)
- Binaryen inlining and strip-toolchain evidence: [`../raw/binaryen/2026-04-23-inlining-primary-sources.md`](../raw/binaryen/2026-04-23-inlining-primary-sources.md), [`../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md`](../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md)
- Starshine code: [`../../../src/wast/lexer.mbt`](../../../src/wast/lexer.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/passes/no_inline.mbt`](../../../src/passes/no_inline.mbt), [`../../../src/passes/inlining.mbt`](../../../src/passes/inlining.mbt), [`../../../src/passes/duplicate_function_elimination.mbt`](../../../src/passes/duplicate_function_elimination.mbt), [`../../../src/passes/duplicate_import_elimination.mbt`](../../../src/passes/duplicate_import_elimination.mbt), [`../../../src/passes/remove_unused_module_elements.mbt`](../../../src/passes/remove_unused_module_elements.mbt)
