---
kind: entity
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md
  - ../../../raw/research/0387-2026-04-26-minify-imports-source-correction.md
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
  - ./env-wasi-json-map-and-module-merge.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../minify-imports-and-exports/index.md
  - ../duplicate-import-elimination/index.md
---

# `minify-imports`

## Role

`minify-imports` is a public Binaryen ABI-surface pass that shortens qualifying import **base names** and emits a JSON mapping that external glue can use to follow the rename.

This page intentionally corrects a stale 2026-04-25 Starshine wiki claim. The pass is **not** a non-mutating imported-function-only report and there is no separate official `MinifyImports.cpp` owner in Binaryen `version_129` or current `main`. Official Binaryen implements the plain pass as `MinifyImportsAndExports(false, false)` in `src/passes/MinifyImportsAndExports.cpp`.[^source-correction]

| Pass | Import base names | Import module names | Export names | Mutates module? |
| --- | --- | --- | --- | --- |
| `minify-imports` | Only imports from `env` or modules beginning `wasi_`. All import kinds are eligible. | No. | No. | Yes, for qualifying import bases. |
| `minify-imports-and-exports` | Same import-base rule as `minify-imports`. | No. | Yes. | Yes. |
| `minify-imports-and-exports-and-modules` | All import base names. | Yes; all import modules become one short module name. | Yes. | Yes. |

Starshine currently treats `minify-imports` as an **upstream-only unknown pass name**. It is absent from `src/passes/optimize.mbt`, absent from `src/passes/pass_manager.mbt`, has no owner file, and has no active backlog slice.[^starshine-code]

## Beginner summary

A wasm import has two host-facing strings: `(module, name)`.

```wat
(import "env" "very_long_function_name" (func $f))
```

Binaryen `--minify-imports` may rewrite the base name to a short name:

```wat
(import "env" "a" (func $f))
```

It also prints a JSON-shaped mapping, conceptually:

```json
{"imports":{"a":["env","very_long_function_name"]},"exports":{}}
```

The exact JSON order and generated names belong to Binaryen's source and must be checked against the targeted revision. The important beginner rule is that the plain pass really changes import declarations; host code that still asks for `env.very_long_function_name` will no longer link unless it applies the map.

## Inputs and outputs

### Input

The input is a module with imports. Plain `minify-imports` scans all import kinds through the shared import traversal:

- function imports;
- table imports;
- memory imports;
- global imports;
- tag imports, where present in the module.

In plain mode, only imports from module `env` or modules whose names start with `wasi_` are renamed. Custom modules such as `"host"` are negative controls unless the `-and-modules` sibling is used.

### Output

The output is the same module structure with qualifying import base strings shortened. Code bodies, import kinds, and internal indices do not change. The pass also emits a JSON map for boundary tooling.

## Correctness constraints

- **Treat it as ABI-visible:** the host import contract changes for renamed imports.
- **Do not document it as no-op/report-only:** the corrected source-backed contract mutates import declarations.
- **Preserve the `env` / `wasi_` plain-mode gate:** custom import modules do not get base-name minification in the plain pass.
- **Keep all import kinds in scope:** the shared owner walks imports generally, not just imported functions.
- **Keep the sibling split explicit:** module-name minification belongs only to `minify-imports-and-exports-and-modules`; export-name minification belongs to the two `-exports` names.
- **Preserve the reporting channel:** a faithful port must decide how JSON mapping output coexists with Starshine's normal optimized wasm output.
- **Use Binaryen-compatible name generation:** do not invent an alphabet or collision rule without source-reading the target Binaryen revision.

## Notable edge cases

- `(import "host" "long" ...)` is unchanged by plain `minify-imports`, even though it is an import.
- `(import "wasi_snapshot_preview1" "long" ...)` is eligible in plain mode because the module name begins with `wasi_`.
- Non-function imports are eligible when their module passes the plain-mode gate.
- Identical base names from different original modules are keyed by `(oldModule, oldBase)` in Binaryen's mapping logic before optional module-name merging.
- The reviewed official tree still has no dedicated plain-`minify-imports` lit fixture, so future Starshine tests must be oracle-driven against Binaryen rather than inferred from sibling tests.

## Validation strategy

For Binaryen parity research:

1. build a module with `env` function/table/memory/global/tag imports and long base names;
2. build a negative custom-module import such as `"host"."long"`;
3. build a `wasi_` import;
4. run Binaryen `--minify-imports`;
5. assert qualifying import base names changed, custom-module bases did not, and code bodies/indices stayed stable;
6. assert stdout is JSON-shaped and describes the old module/base plus new base mapping;
7. separately run the `-and-exports` and `-and-modules` siblings to prove the broader surfaces.

For a future Starshine port:

1. make registry behavior explicit instead of leaving accidental unknown-name behavior undocumented;
2. add a module-pass/reporting API decision for JSON output;
3. implement import-section mutation before any export sibling;
4. add module map / binary roundtrip validation after mutation;
5. compare against Binaryen on reduced fixtures and then on generated modules with imports.

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - Binaryen's shared-owner strategy.
- [`env-wasi-json-map-and-module-merge.md`](env-wasi-json-map-and-module-merge.md) - focused guide to the plain-mode gate, JSON map, and sibling module merge.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files and proof gaps.
- [`wat-shapes.md`](wat-shapes.md) - concrete before/after shapes and negatives.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.

## Sources

- [`../../../raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md`](../../../raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md)
- [`../../../raw/research/0387-2026-04-26-minify-imports-source-correction.md`](../../../raw/research/0387-2026-04-26-minify-imports-source-correction.md)
- Binaryen `MinifyImportsAndExports.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/MinifyImportsAndExports.cpp>
- Binaryen pass registry: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>

[^source-correction]: See [`../../../raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md`](../../../raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md) and [`../../../raw/research/0387-2026-04-26-minify-imports-source-correction.md`](../../../raw/research/0387-2026-04-26-minify-imports-source-correction.md). The older 2026-04-25 manifest remains provenance but is superseded for the plain-pass mechanics.
[^starshine-code]: Current local status is grounded in `src/passes/optimize.mbt:127-143`, `src/passes/optimize.mbt:462-465`, and `src/passes/pass_manager.mbt:8661-8664`.
