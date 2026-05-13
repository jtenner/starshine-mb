---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../raw/wasm/2026-05-13-ref-func-declaration-sources.md
  - ../raw/wasm/2026-05-13-function-import-export-section-sources.md
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
  - ../../../src/validate/gen_invalid.mbt
  - ../binary/function-import-export-and-code-sections.md
  - ../binary/data-element-and-datacount-sections.md
related:
  - ./module-validation-phases.md
  - ./fuzz-hardening.md
  - ./trace-benchmark-baseline.md
  - ../binary/function-import-export-and-code-sections.md
  - ../binary/data-element-and-datacount-sections.md
  - ../binary/module-section-map.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../validation/moonbit-prove-strategy.md
---

# `ref.func` Declaration Validation

## Overview

`ref.func` is not just another function-index instruction. A module can only form a function reference for an index that is both:

1. a valid function index in the module's imported-prefix function index space; and
2. present in the module's declared function-reference set.

The official WebAssembly 3.0 validation sources call that second set `refs`. The focused raw-source snapshot in [`../raw/wasm/2026-05-13-ref-func-declaration-sources.md`](../raw/wasm/2026-05-13-ref-func-declaration-sources.md) records the current primary-source rule: `ref.func x` requires `x` in the validation context's `funcs` and `refs`, and module validation builds `refs` from function-index occurrences in module-level declaration sources such as globals, tables, element segments, start, and exports.

Starshine implements the same idea as a separate `ref_func_declarations` validation phase in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt), within the broader phase order documented in [`./module-validation-phases.md`](./module-validation-phases.md). It has one visible local/spec divergence: current Starshine does **not** treat `start_sec` alone as a `ref.func` declaration source. That stricter local policy is deliberate enough to have a regression test, so keep it visible until a validator change intentionally aligns it with the official rule.

## Beginner Model

Think of module validation as building two function-index facts before code bodies are checked:

```text
function index exists?      imported functions + defined function declarations
function reference allowed? exports + module-level ref.func declarations + element function lists
```

Then each `ref.func $f` in an initializer, element expression, or body asks both questions. A direct `call $f` only needs the ordinary function-index/type rule; `ref.func $f` also needs the declaration rule because it creates a first-class function reference.

## Starshine Phase Order

`validate_module_impl` validates enough of the module to build environments, then runs the declaration check before full code-section typechecking:

1. validate types and imports;
2. validate function declarations, extending `env.funcs` with defined signatures;
3. validate tables, memories, tags, globals, elements, data, data-count, start, and exports;
4. build the declared-function bitmap with [`collect_declared_funcs_bitmap`](../../../src/validate/validate.mbt#L2552-L2608);
5. run [`validate_ref_func_declarations_in_module`](../../../src/validate/validate.mbt#L2690-L2868) over globals, tables, element expressions, and code bodies;
6. typecheck code bodies through the ordinary code-section validator.

That split matters because [`typecheck_ref_func`](../../../src/validate/typecheck.mbt#L1824-L1842) can prove that a function index exists and produce the correct function-reference type, but it does not know whether the module-level declaration set allowed that reference. Declaration validity is a whole-module invariant, so Starshine checks it in the whole-module validator instead of inside the local instruction typechecker.

## Declaration Sources In Current Starshine

| Source | Counts as declared? | Evidence | Notes |
| --- | --- | --- | --- |
| Function export | Yes | `collect_declared_funcs_bitmap` marks `Export(_, FuncExternIdx(f))`; test `validate_module accepts ref.func body when function is exported`. | This matches the official module `refs` source set. |
| Global initializer `ref.func` | Yes | `collect_declared_funcs_bitmap` scans `GlobalSec`; test `validate_module treats global initializer ref.func as declaration source`. | The initializer must also be a valid constant expression and typecheck. |
| Table initializer `ref.func` | Yes | `collect_declared_funcs_bitmap` scans table initializer expressions; test `validate_module treats table initializer ref.func as declaration source`. | This is separate from active element payloads that later initialize tables. |
| Element segment function-index payload | Yes | `FuncsElemKind(funcs)` entries are marked directly. | Declarative elements are the canonical text-level way to forward-declare function references. |
| Element expression `ref.func` | Yes | `FuncExprsElemKind` and `TypedExprsElemKind` expressions are scanned; tests cover typed expression sources and mixed element declarations. | See [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md) for element-mode shapes. |
| Function body `ref.func` | Use site, not declaration source | `validate_ref_func_declarations_in_module` scans bodies after computing the bitmap. | A body `ref.func` fails unless some module-level source declared the same index. |
| Start section | **No, current local divergence** | Test `validate_module does not treat start as a ref.func declaration source`. | The official module-validation rule includes optional start in `refs`; Starshine currently does not. |
| Direct `call` / `return_call` | No | Declaration scan only matches `Instruction::RefFunc`. | Calls validate through ordinary function type rules, not reference-declaration rules. |

## Worked Shapes

### Undeclared body reference fails

```wat
(module
  (type $v (func))
  (func $f (type $v)
    (drop (ref.func $f))))
```

The function index exists, but no export, global/table initializer, or element segment declares `$f` as a function reference. Starshine reports an `undeclared function reference` diagnostic against the function body; with imports present, the diagnostic uses the absolute imported-prefix `FuncIdx`, as locked by `validate_module reports imported-prefix func idx for undeclared ref.func in body`.

### Export declaration allows a body reference

```wat
(module
  (type $v (func))
  (func $f (type $v)
    (drop (ref.func $f)))
  (export "f" (func $f)))
```

The export marks `$f` in the declaration bitmap before the body scan, so the body `ref.func` passes the declaration phase. The later code-section typecheck still validates the expression stack and reference type.

### Declarative element forward-declares a reference

```wat
(module
  (type $v (func))
  (func $f (type $v)
    (drop (ref.func $f)))
  (elem declare func $f))
```

The element function-index payload declares `$f` even though the segment is not an active table initializer. This is the beginner-friendly purpose of declarative elements: they can make function references valid without exporting the function.

### Start-only declaration is currently rejected locally

```wat
(module
  (type $v (func))
  (func $f (type $v)
    (drop (ref.func $f)))
  (start $f))
```

The official module-validation source set includes start, but current Starshine intentionally rejects this shape unless another declaration source also names `$f`. If Starshine changes this policy, update this page, [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md), the raw-source snapshot, and the validator regression tests together.

## Pass And Validator Invariants

- Function-index rewrites must preserve **both** target identity and declaration coverage. A pass that keeps a `ref.func` use but deletes the only export/element/global/table declaration for that index can create an invalid module even when ordinary call indices still resolve.
- Function deletion must treat declaration sources as roots when the corresponding `ref.func` can survive. This is why module-element removal, duplicate-function elimination, function reordering, and JS-interface legalization docs should link back to the shared function-index checklist in [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md).
- Declaration diagnostics belong to the use site. Starshine's body scan wraps undeclared body uses in `ValidationIssue::FunctionBody` and records the absolute function index computed through the imported-prefix helper path.
- Do not collapse this phase into ordinary instruction typechecking unless the replacement still has module-level visibility into exports, globals, table initializers, element payloads, and the start-policy decision.

## Fuzzing And Signoff

- The AST-invalid strategy `UndeclaredRefFunc` is registered in [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt#L251-L256) and expects the `FunctionBody` diagnostic family.
- The public invalid-generation stable id is `undeclared-ref-func` through [`src/validate/gen_invalid.mbt`](../../../src/validate/gen_invalid.mbt#L194-L204).
- When changing declaration sources, run the focused validator tests around `validate_module rejects undeclared function reference in body`, `validate_module accepts ref.func body when function is exported`, global/table/element declaration positives, mixed declared/undeclared body uses, and the start-section regression.
- For broader confidence, run the validator invalid AST lane or the shared `bun fuzz run validate-invalid-ast ...` wrapper documented in [`./fuzz-hardening.md`](./fuzz-hardening.md) and [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md).

## Sources

- Focused primary-source snapshot: [`../raw/wasm/2026-05-13-ref-func-declaration-sources.md`](../raw/wasm/2026-05-13-ref-func-declaration-sources.md)
- Broader function-section source snapshot: [`../raw/wasm/2026-05-13-function-import-export-section-sources.md`](../raw/wasm/2026-05-13-function-import-export-section-sources.md)
- Validator implementation and tests: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt)
- Invalid-fuzz registration: [`../../../src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt), [`../../../src/validate/gen_invalid.mbt`](../../../src/validate/gen_invalid.mbt)
- Related wiki pages: [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md), [`../binary/data-element-and-datacount-sections.md`](../binary/data-element-and-datacount-sections.md), [`./fuzz-hardening.md`](./fuzz-hardening.md)
