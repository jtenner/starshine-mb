---
kind: entity
status: supported
last_reviewed: 2026-07-11
sources:
  - ../../../raw/binaryen/2026-07-11-print-boundary-current-main-source-read.md
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wat/wat_api.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ../../../binary/module-section-map.md
  - ../../../binary/function-import-export-and-code-sections.md
  - ../remove-exports/index.md
  - ../strip-toolchain-annotations/index.md
  - ../tracker.md
  - ../late-pipeline-dispatch.md
---

# Binaryen `print-boundary`

## Overview

`print-boundary` is Binaryen's public **diagnostic reporting** pass. It emits a machine-readable description of the module's import and export boundary; it is not an optimizer, a validator, or a feature-lowering pass. The current owner/registration/fixture read is captured in [`../../../raw/binaryen/2026-07-11-print-boundary-current-main-source-read.md`](../../../raw/binaryen/2026-07-11-print-boundary-current-main-source-read.md).

For a beginner, imports are host requirements and exports are host-visible capabilities. This pass reports both sides of that ABI boundary as JSON: the import module/base names and external kinds, and the export names and external kinds, together with their types. It does **not** change what the module does.

For an implementer, its output is a protocol. Printing similar WAT is not enough: a compatible port needs the same import/export record schema, field names, type encoding, output destination behavior, and bounded recursion when function types refer to themselves.

## Upstream And Starshine Status

| Surface | Current evidence |
| --- | --- |
| Upstream identity | Binaryen registers `createPrintBoundaryPass()` as public `print-boundary`. |
| Upstream behavior | The owner emits one object with `imports` and `exports` arrays. Records carry names, `kind`, and a structured or scalar `type`; the module is not mutated. |
| Current-main drift | `main` adds a recursive signature-reference depth cutoff, covered by its focused fixture. This prevents unbounded diagnostic recursion; it does not alter Wasm validation or runtime semantics. |
| Starshine registry | No `print-boundary` / `PrintBoundary` spelling was found under `src/` on 2026-07-11. |
| Starshine substrate | [`Module`](../../../../../src/lib/types.mbt), section types, and [`src/wat/wat_api.mbt`](../../../../../src/wat/wat_api.mbt) provide relevant representation/printing prerequisites, but not Binaryen's JSON boundary protocol. |
| Compare harness | `--print-boundary` is absent from [`SUPPORTED_PASS_FLAGS`](../../../../../scripts/lib/pass-fuzz-compare-task.ts), so no Starshine-vs-Binaryen compare-pass lane exists. |

The correct local classification is **upstream-only / local-unknown**. Existing section models and WAT output must not be represented as pass support.

## What It Prints

The source emits one object with `imports` and `exports` arrays. A simplified record shape is:

```json
{
  "imports": [
    { "module": "env", "base": "trace", "kind": "func",
      "type": { "params": ["i32"], "results": [] } }
  ],
  "exports": [
    { "name": "run", "kind": "func",
      "type": { "params": [], "results": ["i32"] } }
  ]
}
```

This is illustrative: actual records also describe table, memory, global, and tag boundaries. The important rules are:

1. **`imports` and `exports` are the top-level contract.** The pass does not list defined functions or the full type section as independent categories.
2. **`kind` selects the type encoding.** Function and tag types have `params`/`results`; other external types may be strings, and multi-value uses an array representation.
3. **Output is observational.** No index is remapped, no export is removed, and no pass-local optimization fact is created.
4. **Output goes to `--print-boundary=OUTFILE` or stdout.** Consumers should parse JSON rather than scrape a human-rendered listing.

This scope distinguishes the pass from nearby module operations:

| Nearby surface | Why it differs |
| --- | --- |
| [`remove-exports`](../remove-exports/index.md) | Mutates the public export list and changes host ABI; `print-boundary` only reports exports. |
| [`strip-toolchain-annotations`](../strip-toolchain-annotations/index.md) | Mutates selected metadata; `print-boundary` may expose a declaration's printed form but does not remove metadata. |
| WAT printing | Renders a module textually; `print-boundary` is a selected-declaration JSON protocol. |
| Validator | Decides whether a module is well-formed; reporting does not validate or repair it. |

## Recursive Types: The Important Current Boundary

Recursive function types can form cycles through signature references. A schematic shape is:

```wat
(module
  (type $rec (sub (func (param (ref null $rec)))))
  (import "env" "use" (func (type $rec)))
)
```

A naive boundary renderer that expands each referenced signature can recurse forever while formatting the imported function's type. Current Binaryen bounds this traversal with a depth limit, and the upstream fixture covers a terminal nested reference. This is a diagnostic-safety rule:

- preserve enough context for a human or tool to identify the declaration;
- stop before recursive expansion becomes unbounded;
- do not infer that truncation changes nominal type identity, validation, or subtyping.

A Starshine port should make the cutoff explicit in its output contract and snapshot tests. It should not silently rely on incidental recursion behavior in a generic `Show` implementation.

## Future Starshine Slice And Signoff

A faithful first slice would be output-only:

1. add an explicit command/pass policy rather than placing reporting in `optimize` or `shrink` presets;
2. define a versioned JSON schema, selected boundary categories, ordering, and stderr/stdout behavior;
3. reuse local section data but write a dedicated bounded type renderer;
4. add snapshot tests for empty modules, every import/export external kind, string escaping, output-file versus stdout routing, and recursive signature-reference cycles;
5. assert byte-for-byte module non-mutation and successful validation before/after reporting.

Do **not** use ordinary `compare-pass` as the initial proof: its canonical-Wasm output comparison cannot establish import/export JSON compatibility. If a future harness lane is added, it needs a separate JSON capture/normalization oracle and a stated recursive-depth policy. See [`fuzzing.md`](fuzzing.md).

## Sources

- Primary-source read and current-main recursive-type note: [`../../../raw/binaryen/2026-07-11-print-boundary-current-main-source-read.md`](../../../raw/binaryen/2026-07-11-print-boundary-current-main-source-read.md)
- Starshine module/section substrate: [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt), [`../../../binary/module-section-map.md`](../../../binary/module-section-map.md), [`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md)
- Current local output/harness boundaries: [`../../../../../src/wat/wat_api.mbt`](../../../../../src/wat/wat_api.mbt), [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
