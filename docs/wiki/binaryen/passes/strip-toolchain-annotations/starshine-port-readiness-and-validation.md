---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-strip-toolchain-annotations-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-strip-toolchain-annotations-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md
  - ../../../raw/research/0504-2026-05-06-strip-toolchain-annotations-current-main-recheck.md
  - ../../../raw/research/0394-2026-04-26-strip-toolchain-annotations-port-readiness.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/duplicate_import_elimination.mbt
  - ../../../../../src/passes/remove_unused_module_elements.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../duplicate-function-elimination/index.md
  - ../strip-target-features/index.md
---

# Starshine port readiness and validation for `strip-toolchain-annotations`

This page is a future implementation ladder. A 2026-05-06 current-main recheck kept the upstream contract unchanged. Starshine does **not** currently implement or reserve `strip-toolchain-annotations`. For the shared local `FuncAnnotationSec` model, the absence of expression-level code metadata, and the `metadata.code.inline` / branch-hint boundary, see [`../../../wast/code-metadata-and-function-annotations.md`](../../../wast/code-metadata-and-function-annotations.md).

## Current decision point

Before writing code, choose one public stance:

1. keep the pass unknown, which is today's behavior;
2. add a boundary-only registry entry to say Starshine knows the Binaryen pass name but does not implement it;
3. add an active module pass over Starshine's current function-annotation metadata.

Do not add it to `optimize` or `shrink` presets by default. Binaryen frames the pass as late cleanup after toolchain annotations have served their purpose, not as a normal optimization that improves executable code.

## Local first slice

The safest useful slice is a module pass over `FuncAnnotationSec`:

1. Walk every `FuncAnnotationAssoc` entry.
2. Drop only annotations whose name is exactly one of:
   - `binaryen.removable.if.unused`
   - `binaryen.idempotent`
   - `binaryen.js.called`
3. Preserve every other annotation and its arguments, especially `metadata.code.inline`.
4. If an association's annotation list becomes empty, remove that association.
5. If the section has no associations left, remove `func_annotation_sec` from the module.
6. Leave functions, imports, exports, type declarations, code, names, and custom sections otherwise unchanged.

That slice should be documented as **Starshine's local function-annotation subset**, not full Binaryen parity, because Binaryen also strips per-expression `codeAnnotations` and Starshine does not expose an equivalent expression-annotation map today; the focused local boundary is [`../../../wast/code-metadata-and-function-annotations.md`](../../../wast/code-metadata-and-function-annotations.md).

## Shape matrix

| Shape | Binaryen behavior | First Starshine slice |
| --- | --- | --- |
| Function annotated only with `@binaryen.idempotent` | Strip annotation; erase empty record. | Strip annotation; erase empty function association. |
| Function import annotated with `@binaryen.js.called` | Strip if represented in Binaryen function annotations. | Strip from `FuncAnnotationSec` entry for the import index. |
| Function annotated with `@metadata.code.inline` | Preserve. | Preserve exactly, including args. |
| Mixed `@binaryen.idempotent` + `@metadata.code.inline` | Keep only `metadata.code.inline`. | Keep only `metadata.code.inline`. |
| Expression annotated with `@binaryen.removable.if.unused` | Strip per-expression `codeAnnotations`. | Not covered until Starshine has expression annotations. |
| Unknown annotation name | Preserve. | Preserve. |

## Tests to add first

Add parser/lowering/roundtrip coverage before or alongside the pass:

- `@binaryen.removable.if.unused`, because the focused 2026-04-26 grep found local tests for `binaryen.js.called`, `binaryen.idempotent`, and `metadata.code.inline`, but not this upstream-lit-covered spelling;
- mixed removed-plus-preserved function annotations;
- function-import annotations and function-definition annotations.

Then add pass tests:

- removes `binaryen.removable.if.unused` from a function association;
- removes `binaryen.idempotent`;
- removes `binaryen.js.called`;
- preserves `metadata.code.inline` and its `"\\00"` argument;
- preserves unknown annotations;
- drops empty association entries;
- removes an empty annotation section;
- preserves index associations correctly when imports precede function definitions;
- composes with DFE/DIE/RUME annotation remapping when the strip pass runs before or after those passes.

## Binaryen oracle comparison

Use Binaryen as the oracle only for shapes that both tools model:

1. WAT with function/function-import annotations supported by Starshine.
2. Run Binaryen `wasm-opt --strip-toolchain-annotations -S`.
3. Run Starshine's future pass and compare normalized WAT.
4. Keep expression-level annotation cases as expected-known-gaps until Starshine represents them.

For full parity later, add expression annotation fixtures matching Binaryen's `codeAnnotations` behavior and verify that empty annotation wrappers disappear without changing the expression tree.

## Code locations to read

- `src/passes/optimize.mbt:127-143` - boundary-only and removed name lists; the pass is absent today.
- `src/passes/optimize.mbt:156-267` - active hot/module/preset registry; no entry exists today.
- `src/passes/optimize.mbt:317-320` - boundary-only and removed names are materialized into the lookup table.
- `src/passes/optimize.mbt:525` - unknown-pass rejection path.
- `src/lib/types.mbt:348` and `src/lib/types.mbt:8105-8108` - `FuncAnnotationSec` and its constructor.
- `src/wast/parser.mbt:779-784` - annotation parsing and function/function-import attachment rule.
- `src/wast/lower_to_lib.mbt:2916-2917`, `src/wast/lower_to_lib.mbt:3016-3017`, and `src/wast/lower_to_lib.mbt:3502` - lowering annotations into `FuncAnnotationSec`.
- `src/wast/module_wast_tests.mbt:78-98`, `src/wast/parser.mbt:5378-5407`, and `src/wast/lower_to_lib.mbt:5281-5304` - current local annotation tests.
- `src/passes/duplicate_function_elimination.mbt:23-31`, `src/passes/duplicate_function_elimination.mbt:2663-2694`, `src/passes/duplicate_import_elimination.mbt:309-332`, and `src/passes/remove_unused_module_elements.mbt:1944-1966` - existing annotation index remapping helpers.
- `src/passes/duplicate_function_elimination.mbt:3034-3072` - DFE equivalence/hashing includes annotations.

## Open questions

- Should Starshine add a boundary-only spelling now, or wait until an active module pass exists?
- Does the binary codec already preserve `FuncAnnotationSec`, or is that currently WAT-only/lowered-in-memory support?
- Should a future expression-annotation model use Binaryen's per-expression map shape, WAT wrapper syntax, or a Starshine-specific metadata side table?
