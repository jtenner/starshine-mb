---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md
  - ../raw/wasm/2026-05-20-start-section-validation-sources.md
  - ../raw/wasm/2026-05-20-ref-func-declaration-refresh.md
  - ../../../src/lib/types.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/binary/decode.mbt
  - ../../../src/binary/encode.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/invalid_fuzzer.mbt
  - ../../../src/validate/gen_invalid.mbt
  - ../../../src/fuzz/invalid_binary.mbt
  - ../../../src/fuzz/invalid_text.mbt
related:
  - ./module-validation-phases.md
  - ./ref-func-declarations.md
  - ./diagnostics-and-invalid-repro.md
  - ./fuzz-hardening.md
  - ../binary/function-import-export-and-code-sections.md
  - ../binary/module-section-map.md
  - ../wast/function-call-and-module-authoring.md
  - ../fuzzing/generator-coverage-ledger.md
---

# Start Section Validation

## Overview

The WebAssembly start section is the module's optional instantiation entrypoint. It names one function that the runtime calls automatically after the module instance is created and before the instance is handed to the embedder. In Starshine, this is the `start_sec` field on the core `Module`; in text fixtures it appears as `(start $init)` or `(start 0)`; in binary it is standard section id `8` carrying one function index.

A valid start function must satisfy exactly two signature rules:

1. the referenced function index must exist in the module's full function index space; and
2. the target function type must have **no parameters** and **no results**.

Imports matter because they occupy the prefix of the function index space. A start target may be an imported function if that import has an empty signature. A defined start target still has an ordinary code body in `CodeSec`, whose body ordinal is offset by the number of function imports.

This page owns start-section validation and rewrite guidance. For the wider function-index section map, use [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md). For fixture authoring, use [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md). For the separate `ref.func` declaration-source rule, use [`ref-func-declarations.md`](ref-func-declarations.md).

## Beginner Model

A start declaration is closer to metadata than to a call instruction:

```wat
(module
  (func $init)
  (start $init))
```

There is no operand stack at the start declaration itself. Validation only asks whether `$init` resolves to an empty function type. The function body is checked later through normal code-section validation.

The following shape is invalid because the runtime would have no argument to pass to `$init`:

```wat
(module
  (func $init (param i32))
  (start $init))
```

The following shape is also invalid because start functions cannot produce a value for anyone to consume:

```wat
(module
  (func $init (result i32)
    (i32.const 1))
  (start $init))
```

Imported starts follow the same rule:

```wat
(module
  (import "env" "init" (func $init))
  (start $init))
```

That import can be the start function because its type is `[] -> []`. The same import with `(param i32)`, `(result i32)`, `(param externref)`, or any other non-empty parameter/result list is invalid as a start target.

## Official Versus Starshine Contract

The current official WebAssembly sources checked in [`../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md`](../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md), with the focused start-section baseline still preserved in [`../raw/wasm/2026-05-20-start-section-validation-sources.md`](../raw/wasm/2026-05-20-start-section-validation-sources.md), establish these portable facts:

- start is optional and stores a single function index;
- binary section id `8` is the start section;
- text format uses a `(start ...)` module field;
- validation requires an existing empty-signature function; and
- module validation includes the optional start function in the `refs` set used by `ref.func` declaration checking.

Starshine matches the empty-signature validation rule and imported-prefix index model, but it intentionally does **not** match the last point today: `start_sec` alone is not treated as a declaration source for `ref.func`. The negative regression `validate_module does not treat start as a ref.func declaration source` in [`src/validate/validate.mbt`](../../../src/validate/validate.mbt#L9227-L9255) keeps that divergence explicit. If Starshine changes this policy, update this page and [`ref-func-declarations.md`](ref-func-declarations.md) in the same change.

## Starshine Validation Flow

[`validate_module_impl`](../../../src/validate/validate.mbt) validates starts only after function imports and definitions have extended the environment:

```text
types
imports              -- imported funcs become FuncIdx prefix
function declarations -- defined funcs append their signatures
resource sections / globals / elements / data / datacount
startsec             -- target exists and has [] -> []
exports
ref_func_declarations
code bodies
name section
```

The start-specific helper is [`validate_startsec`](../../../src/validate/validate.mbt):

- `None` succeeds;
- an unknown `FuncIdx` fails with `start: invalid function index`;
- a target with parameters fails with `start function must have empty parameter list`; and
- a target with results fails with `start function must have empty result list`.

When `validate_module_impl` reports a start failure, it wraps the message as `ValidationIssue::StartSection` and attaches the target `FuncIdx` when one was present. Use [`diagnostics-and-invalid-repro.md`](diagnostics-and-invalid-repro.md) for the generic family/stage/repro contract.

## Layer Map

| Layer | Evidence | Start-specific rule |
| --- | --- | --- |
| Core model | [`Module.start_sec`](../../../src/lib/types.mbt), `StartSec(FuncIdx)` | One optional absolute function index; no body or signature stored in the start field itself. |
| WAST parser/lowerer | [`src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Parses `(start ...)`, resolves `$` or numeric function references through the imported-prefix function index map, and prints one start field from the core module. |
| Binary codec | [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | Decodes/encodes section id `8` as one function index. |
| Validation | [`validate_startsec`](../../../src/validate/validate.mbt) | Rejects missing targets and non-empty signatures. |
| Invalid fuzzing | [`src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt), [`src/validate/gen_invalid.mbt`](../../../src/validate/gen_invalid.mbt), [`src/fuzz/invalid_binary.mbt`](../../../src/fuzz/invalid_binary.mbt), [`src/fuzz/invalid_text.mbt`](../../../src/fuzz/invalid_text.mbt) | Keeps AST, binary, and text invalid-start strategies under the `start` family. |

## Invalid Strategy Matrix

Start validation is one of the better-covered invalid families. Current checked-in strategy surfaces include:

| Family | Stable ids / strategy names | What they prove |
| --- | --- | --- |
| Defined function with params | `invalid-start-signature`, `invalid-start-func-param` | A defined target with a non-empty parameter list reports the start family. |
| Defined function with results | `invalid-start-func-result` in text, plus binary/AST signature variants | A defined target with a result list reports the start family. |
| Imported function with params/results | `invalid-imported-start-func-param`, `invalid-imported-start-func-result`, `invalid-imported-start-func-param-result`, `invalid-imported-start-func-multi-param`, `invalid-imported-start-func-f32-param`, `invalid-imported-start-func-externref-param`, `invalid-imported-start-func-funcref-param` and `*-module` binary mirrors | Imported function indices are legitimate start targets only when their imported type is empty. |
| Out-of-range function index | `start-func-out-of-range`, `invalid-start-func-out-of-range` | The target index is checked against the full imported-plus-defined function index space. |
| Wrong-kind numeric index | `start-func-wrong-kind-index` | A numeric index that resolves in another index space, such as table `0`, does not satisfy the start section's function-index requirement. |

Use [`fuzz-hardening.md`](fuzz-hardening.md) for the broader AST/binary/text/spec-seed invalid-lane contract and [`../tooling/fuzz-runner.md`](../tooling/fuzz-runner.md) for command shapes.

## Pass And Rewrite Invariants

Start is a function-index carrier. Any module transform that changes function identity or order must treat it as part of the same remap set as calls, exports, element payloads, `ref.func`, names, and annotations.

Checklist for mutating passes:

1. **Remap or delete `start_sec` deliberately.** Never leave a stale `FuncIdx` after deleting, merging, or reordering functions.
2. **Revalidate signatures after retargeting.** A replacement function that is call-compatible elsewhere can still be invalid as start if it has params or results.
3. **Separate start metadata from function body liveness.** Some optimization families may delete a start declaration while preserving the target function body, or root a target function because startup effects matter. Record which behavior the pass owns.
4. **Do not infer `ref.func` declaration coverage from start today.** A surviving body `ref.func $f` still needs an export, global/table initializer, or element declaration source under current Starshine policy.
5. **Preserve imported-prefix arithmetic.** A start target of `FuncIdx(0)` may be an import. Defined body ordinal `0` is `FuncIdx(imported_func_count)`, not necessarily `FuncIdx(0)`.

Pass dossiers that should link back here when they touch start metadata include [`remove-unused-module-elements`](../binaryen/passes/remove-unused-module-elements/index.md), [`remove-unused-non-function-elements`](../binaryen/passes/remove-unused-non-function-elements/index.md), [`duplicate-import-elimination`](../binaryen/passes/duplicate-import-elimination/index.md), [`duplicate-function-elimination`](../binaryen/passes/duplicate-function-elimination/index.md), [`reorder-functions`](../binaryen/passes/reorder-functions/index.md), and [`reorder-functions-by-name`](../binaryen/passes/reorder-functions-by-name/index.md).

## Common Mistakes

- **Mistake: “Start is just a call.”** It is not encoded in a function body and has no operand stack. It is a module field validated against function signatures.
- **Mistake: “Imported functions cannot be starts.”** They can, if their imported function type is empty.
- **Mistake: “Start declares `ref.func` in Starshine.”** Not today. Current official WebAssembly includes start in the `refs` source set, but Starshine intentionally keeps start-only `ref.func` uses invalid.
- **Mistake: “Deleting a no-op start is always equivalent to deleting the function.”** Start metadata and the target function body are separate module surfaces. A pass may remove one without the other only if its contract and validation evidence prove that behavior.

## Sources

- Current `refs` / start cross-check: [`../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md`](../raw/wasm/2026-06-04-ref-func-start-refs-current-refresh.md)
- Start-section source bridge: [`../raw/wasm/2026-05-20-start-section-validation-sources.md`](../raw/wasm/2026-05-20-start-section-validation-sources.md)
- Previous `ref.func` declaration refresh: [`../raw/wasm/2026-05-20-ref-func-declaration-refresh.md`](../raw/wasm/2026-05-20-ref-func-declaration-refresh.md)
- Core, WAST, and binary surfaces: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt), [`../../../src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`../../../src/binary/encode.mbt`](../../../src/binary/encode.mbt)
- Validator implementation and tests: [`../../../src/validate/validate.mbt`](../../../src/validate/validate.mbt)
- Invalid-fuzz surfaces: [`../../../src/validate/invalid_fuzzer.mbt`](../../../src/validate/invalid_fuzzer.mbt), [`../../../src/validate/gen_invalid.mbt`](../../../src/validate/gen_invalid.mbt), [`../../../src/fuzz/invalid_binary.mbt`](../../../src/fuzz/invalid_binary.mbt), [`../../../src/fuzz/invalid_text.mbt`](../../../src/fuzz/invalid_text.mbt)
- Related wiki pages: [`module-validation-phases.md`](module-validation-phases.md), [`ref-func-declarations.md`](ref-func-declarations.md), [`diagnostics-and-invalid-repro.md`](diagnostics-and-invalid-repro.md), [`../binary/function-import-export-and-code-sections.md`](../binary/function-import-export-and-code-sections.md), [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md)
