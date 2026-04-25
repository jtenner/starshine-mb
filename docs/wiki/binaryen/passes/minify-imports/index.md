---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-minify-imports-family-source-correction.md
  - ../../../raw/research/0343-2026-04-25-minify-imports-source-correction.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../minify-imports-and-exports/index.md
  - ../duplicate-import-elimination/index.md
---

# `minify-imports`

## Role

`minify-imports` is a public Binaryen pass that emits a short-name mapping for imported **functions**.
It is easy to confuse with [`minify-imports-and-exports`](../minify-imports-and-exports/index.md), but the source-backed contracts are different:

| Pass | Mutates the module? | Covered names |
| --- | --- | --- |
| `minify-imports` | No. It reports `modifiesBinaryenIR() == false` and prints a mapping. | Imported function base names only. |
| `minify-imports-and-exports` | Yes. | Import base names and export names. |
| `minify-imports-and-exports-and-modules` | Yes. | Import module names, import base names, and export names. |

Starshine currently treats `minify-imports` as an **upstream-only unknown pass name**.
It is absent from `src/passes/optimize.mbt`, absent from `src/passes/pass_manager.mbt`, has no owner file, and has no active backlog slice.

## Beginner summary

A wasm import has two host-facing strings: `(module, name)`.
For a function import such as:

```wat
(import "very_long_module" "very_long_function" (func $f))
```

Binaryen `--minify-imports` does not rewrite the module to:

```wat
(import "very_long_module" "a" (func $f))
```

Instead, it emits a map that tells external tooling the old imported function base name and the generated short name, conceptually:

```text
very_long_function:a
```

The exact output order and generated short names belong to Binaryen's traversal plus `Names::MinifiedNameGenerator` and must be rechecked in parity tests.

## Inputs and outputs

### Input

The input is a module with imported functions.
Imported globals, memories, tables, and tags are not the target of this pass.
Exports are not the target either.

### Output

The in-memory module is unchanged.
The visible output is a textual mapping on stdout from imported function base names to generated short names.

## Correctness constraints

- **Do not mutate IR:** Binaryen's pass advertises `modifiesBinaryenIR() == false`; a faithful port should not silently rewrite import declarations under this pass name.
- **Keep the scope function-only:** the reviewed owner uses `ModuleUtils::iterImportedFunctions(...)`, so imported memories/tables/globals/tags are out of scope for `minify-imports`.
- **Do not include exports:** export-name mutation belongs to `minify-imports-and-exports`.
- **Do not include import module names:** module-name mutation belongs to `minify-imports-and-exports-and-modules`.
- **Preserve host ABI warning:** the map is only useful if the producer, host glue, and downstream consumers agree on how it is applied.
- **Preserve Binaryen name generation:** a future local implementation should source-read `Names::MinifiedNameGenerator` in the targeted upstream revision.

## Notable edge cases

- Duplicate imported function base names should not be documented as duplicate import elimination. This pass reports names; it does not merge imports.
- Imported memory/table/global/tag declarations remain invisible to `minify-imports` even though the mutating `minify-imports-and-exports` family can rename their import base names.
- The pass is not validation-sensitive in the same way mutating passes are because it does not change the module.
- This run did not find a dedicated official `minify-imports.wast` fixture; the contract is source-confirmed through the owner file, factory declaration, and registry help text.

## Validation strategy

For Binaryen parity research:

1. create a module with multiple imported functions and long base names;
2. include imported memories, tables, globals, and tags as negative controls;
3. run Binaryen `--minify-imports`;
4. assert the module text/binary remains unchanged after the pass;
5. assert stdout contains only imported-function base-name mappings;
6. compare generated names and order with the exact targeted Binaryen revision.

For a future Starshine port:

1. decide whether pass output belongs on stdout, a structured result channel, or both;
2. add registry tests for deliberate unknown, boundary-only, or active status;
3. add CLI tests for output and no module mutation;
4. add negative tests proving non-function imports and exports do not appear;
5. keep mutating import/export minification in a separate pass family.

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - Binaryen's map-emission strategy.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files and proof gaps.
- [`wat-shapes.md`](wat-shapes.md) - concrete before/map-output shapes and negative controls.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.

## Sources

- [`../../../raw/binaryen/2026-04-25-minify-imports-family-source-correction.md`](../../../raw/binaryen/2026-04-25-minify-imports-family-source-correction.md)
- [`../../../raw/research/0343-2026-04-25-minify-imports-source-correction.md`](../../../raw/research/0343-2026-04-25-minify-imports-source-correction.md)
- Binaryen `MinifyImports.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImports.cpp>
- Binaryen pass registry: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
