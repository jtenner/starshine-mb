---
kind: entity
status: supported
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/PrintBoundary.cpp
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

`print-boundary` is Binaryen's public **diagnostic reporting** pass. It emits a machine-readable description of the module's import and export boundary; it is not an optimizer, a validator, or a feature-lowering pass. The current owner, registration, and fixture are [`PrintBoundary.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/PrintBoundary.cpp), [`pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp), and the [focused fixture](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/print-boundary.wast).

For a beginner, imports are host requirements and exports are host-visible capabilities. This pass reports both sides of that ABI boundary as JSON: the import module/base names and external kinds, and the export names and external kinds, together with their types. It does **not** change what the module does.

For an implementer, its output is a protocol. Printing similar WAT is not enough: a compatible port needs the same import/export record schema, field names, type encoding, output destination behavior, and bounded recursion when function types refer to themselves.

## Upstream And Starshine Status

| Surface | Current evidence |
| --- | --- |
| Upstream identity | Binaryen registers `createPrintBoundaryPass()` as public `print-boundary`. |
| Upstream behavior | The owner emits one object with `imports` and `exports` arrays. Records carry names, `kind`, and a structured or scalar `type`; the module is not mutated. |
| Current-main drift | `main` expands only the outermost signature reference into `{params, results}` and renders nested references as terminal type strings. The focused fixture proves that one-hop policy prevents unbounded diagnostic recursion; it does not alter Wasm validation or runtime semantics. |
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

A naive boundary renderer that expands each referenced signature can recurse forever while formatting the imported function's type. Current Binaryen does **not** maintain a general visited-set or promise arbitrary-depth expansion. Its exact current policy is a one-hop formatting rule:

1. `getTypes(type, forceArray = false, depth = 0)` expands a reference only when `depth == 0` and its heap type is a function signature.
2. That outer signature becomes `{ "params": [...], "results": [...] }`; both fields are arrays, including an empty result list or a single parameter.
3. The recursive calls use `depth + 1`. At that depth, every nested type—including a reference back to the same signature—is rendered with Binaryen's terminal `Type::toString()` spelling rather than expanded again.
4. Non-signature external types follow the same scalar-versus-array helper: a single type is a JSON string unless an enclosing function/tag parameter or result list forces an array.

For example, the current fixture's recursive export is reported as a function boundary whose parameter is the terminal string `"(ref $func.0)"`, not an infinite nested JSON object. The sibling exported function's `(ref $struct)` parameter is likewise a string; this output is a concise boundary description, **not** a complete serialization of the type section or a type-identity protocol.

This is a diagnostic-safety rule:

- preserve one outer function/tag signature for ordinary consumers;
- stop before recursive expansion becomes unbounded;
- do not infer that the abbreviated nested string changes nominal type identity, validation, or subtyping.

A Starshine port should make this one-hop policy explicit in its output contract and snapshot tests. It should not silently rely on incidental recursion behavior in a generic `Show` implementation, and it should not claim recursive structural equality from this diagnostic output.

## Future Starshine Slice And Signoff

A faithful first slice would be output-only:

1. add an explicit command/pass policy rather than placing reporting in `optimize` or `shrink` presets;
2. define a versioned JSON schema, selected boundary categories, ordering, and stderr/stdout behavior;
3. reuse local section data but write a dedicated bounded type renderer;
4. add snapshot tests for empty modules, every import/export external kind, string escaping, output-file versus stdout routing, and recursive signature-reference cycles;
5. assert byte-for-byte module non-mutation and successful validation before/after reporting.

Do **not** use ordinary `compare-pass` as the initial proof: its canonical-Wasm output comparison cannot establish import/export JSON compatibility. If a future harness lane is added, it needs a separate JSON capture/normalization oracle and a stated recursive-depth policy. See [`fuzzing.md`](fuzzing.md).

## Sources

- Current-main owner, registration, fixture, and recursive-type repair: [`PrintBoundary.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/PrintBoundary.cpp), [`pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp), [fixture](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/print-boundary.wast), and [PR #8786](https://github.com/WebAssembly/binaryen/pull/8786)
- Starshine module/section substrate: [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt), [`../../../binary/module-section-map.md`](../../../binary/module-section-map.md), [`../../../binary/function-import-export-and-code-sections.md`](../../../binary/function-import-export-and-code-sections.md)
- Current local output/harness boundaries: [`../../../../../src/wat/wat_api.mbt`](../../../../../src/wat/wat_api.mbt), [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
