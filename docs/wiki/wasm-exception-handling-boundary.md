---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-exception-handling-core-boundary-routing.md
  - raw/wasm/2026-06-04-exception-tag-current-refresh.md
  - raw/wasm/2026-05-20-exception-throwref-nullability-refresh.md
  - raw/wasm/2026-05-19-wast-exception-tag-sources.md
  - ../src/lib/types.mbt
  - ../src/wast/parser.mbt
  - ../src/wast/lower_to_lib.mbt
  - ../src/wast/module_wast.mbt
  - ../src/binary/decode.mbt
  - ../src/binary/encode.mbt
  - ../src/validate/validate.mbt
  - ../src/validate/typecheck.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wast/exception-tag-authoring.md
  - wast/control-flow-authoring.md
  - wast/static-assertion-harness.md
  - binary/type-table-memory-global-tag-sections.md
  - binary/instruction-and-expression-encoding.md
  - validate/module-validation-phases.md
  - validate/stack-polymorphism-and-bottom.md
  - validate/local-spec-divergence-ledger.md
  - fuzzing/generator-coverage-ledger.md
  - wasm-stack-switching-boundary.md
  - wasm-jspi-host-async-boundary.md
  - wasm-relaxed-dead-code-validation-boundary.md
---

# WebAssembly Exception Handling Boundary

## Overview

Use this page when a standards-status claim, fixture, validator change, binary codec change, fuzz generator, or optimizer pass touches WebAssembly Exception Handling: `tag`, `throw`, `throw_ref`, `try_table`, `catch`, `catch_ref`, `catch_all`, and `catch_all_ref`.

For beginners: an exception tag is a typed description of what values an exception carries. `throw` builds and throws a new exception from a tag plus its payload values. `throw_ref` rethrows an existing exception reference, trapping if that reference is null. `try_table` runs a protected body and routes matching exceptions to ordinary labels with catch payloads.

The current source bridge is [`raw/wasm/2026-06-05-exception-handling-core-boundary-routing.md`](raw/wasm/2026-06-05-exception-handling-core-boundary-routing.md). It rechecked the official WebAssembly finished-proposals table, active proposal tracker, archived Exception Handling proposal repository, current Core 3.0 instruction/validation/execution pages, Stack Switching proposal repository, and Starshine WAST/core/validator evidence. The detailed owner-file and tag-result-shape source map remains [`raw/wasm/2026-06-04-exception-tag-current-refresh.md`](raw/wasm/2026-06-04-exception-tag-current-refresh.md).

No new raw source was added for this page: the 2026-06-05 bridge already captured the durable primary-source evidence, and a same-day web recheck found the same routing rule still holds. This page crystallizes that evidence into a root-level boundary page so readers do not have to infer Core feature status from the narrower WAST authoring guide alone.

## Status Rule

Treat ordinary Exception Handling as **finished/Core-3.0 WebAssembly evidence**, not active proposal work.

Use this root page for feature-status and cross-layer routing. Use [`wast/exception-tag-authoring.md`](wast/exception-tag-authoring.md) for concrete text authoring, catch-label examples, WAST legacy syntax, and test placement. Use [`binary/type-table-memory-global-tag-sections.md`](binary/type-table-memory-global-tag-sections.md) for tag-section id, imported-prefix tag index spaces, and tag remap obligations. Use [`validate/local-spec-divergence-ledger.md`](validate/local-spec-divergence-ledger.md) when documenting Starshine's current stricter resultful-tag declaration validation.

Do not confuse Exception Handling with nearby features:

| Nearby feature | What it changes | Starshine routing |
| --- | --- | --- |
| Stack Switching / typed continuations | Adds continuation types and resumable control instructions such as `cont.new`, `suspend`, `resume*`, and `switch`. | [`wasm-stack-switching-boundary.md`](wasm-stack-switching-boundary.md). |
| JSPI | Adds JavaScript embedding APIs for Promise integration. | [`wasm-jspi-host-async-boundary.md`](wasm-jspi-host-async-boundary.md). |
| Relaxed Dead Code Validation | Changes validator policy for syntactically dead code. | [`wasm-relaxed-dead-code-validation-boundary.md`](wasm-relaxed-dead-code-validation-boundary.md). |
| Legacy Starshine `try` / `delegate` / `rethrow` text | Compatibility WAST syntax accepted by the parser/lowerer, not preserved as a separate core instruction family. | [`wast/exception-tag-authoring.md`](wast/exception-tag-authoring.md). |
| Tail calls | Return-position calls that terminate the current function's continuation. | [`wast/tail-call-authoring.md`](wast/tail-call-authoring.md). |

## Concrete Shapes

### Tag plus direct throw

```wat
(module
  (type $payload (func (param i32)))
  (tag $err (type $payload))
  (func (param i32)
    (local.get 0)
    (throw $err)))
```

The tag's type is a function type. Its parameters are the exception payload. For current portable fixtures, keep the result list empty. Starshine lowers `$err` to an absolute `TagIdx`, checks the payload stack, and marks the continuation unreachable after the throw.

### `throw_ref` must preserve null-trap versus rethrow

```wat
(module
  (func (param exnref)
    (local.get 0)
    (throw_ref)))
```

Validation accepts a nullable `exnref` operand. Execution still observes the operand: null traps, while a non-null exception reference is rethrown. Optimizer docs and tests must not drop or reorder that operand merely because the local continuation after `throw_ref` is unreachable.

### `try_table` catches branch to surrounding labels

```wat
(module
  (tag $e)
  (func
    (block $handler
      (try_table (catch $e $handler)
        (throw $e)))))
```

`try_table` has a protected body and catch clauses. A catch target is an ordinary label in the surrounding context, not an implicit handler body. `catch_ref` adds a captured non-null `(ref exn)` after the tag payload; `catch_all_ref` branches with only that non-null exception reference.

## Starshine Layer Map

| Layer | Current behavior | Evidence |
| --- | --- | --- |
| Core IR | Models tags, catch clauses, `Throw`, `ThrowRef`, and `TryTable` explicitly. | [`src/lib/types.mbt`](../src/lib/types.mbt). |
| WAST text | Parses and prints tags, modern `try_table`, all four catch clauses, `throw`, `throw_ref`, and legacy compatibility syntax. | [`src/wast/parser.mbt`](../src/wast/parser.mbt), [`src/wast/module_wast.mbt`](../src/wast/module_wast.mbt), [`wast/exception-tag-authoring.md`](wast/exception-tag-authoring.md). |
| WAST lowering | Resolves tag ids through the imported-prefix tag index space, resolves catch labels against the enclosing context, and lowers legacy EH compatibility syntax away. | [`src/wast/lower_to_lib.mbt`](../src/wast/lower_to_lib.mbt). |
| Binary codec | Decodes/encodes tag sections and tag types, plus exception instruction opcodes. The tag type leading byte remains the current `0x00` attribute slot. | [`src/binary/decode.mbt`](../src/binary/decode.mbt), [`src/binary/encode.mbt`](../src/binary/encode.mbt), [`binary/type-table-memory-global-tag-sections.md`](binary/type-table-memory-global-tag-sections.md). |
| Module validation | Validates imported and defined tag declarations before globals/code. Current Starshine requires tag function types to have empty results at declaration/import time. | [`src/validate/validate.mbt`](../src/validate/validate.mbt), [`validate/module-validation-phases.md`](validate/module-validation-phases.md). |
| Instruction typecheck | Checks throw payloads, nullable `throw_ref`, `try_table` body type, catch-label payload matching, and non-null exception-reference payloads for `catch_ref` / `catch_all_ref`. | [`src/validate/typecheck.mbt`](../src/validate/typecheck.mbt). |
| Fuzzing and generators | GenValid and WAST arbitrary surfaces include exception/tag coverage; invalid lanes keep tag and catch-family diagnostics visible. | [`fuzzing/generator-coverage-ledger.md`](fuzzing/generator-coverage-ledger.md), [`fuzzing/wast-arbitrary-parity-plan.md`](fuzzing/wast-arbitrary-parity-plan.md), [`validate/fuzz-hardening.md`](validate/fuzz-hardening.md). |
| Optimizer passes | Any transform that deletes, moves, or rewrites tag/catch/throw carriers must preserve tag indices, catch label payloads, operand evaluation, and null-trap/rethrow behavior. | Pass-specific Binaryen dossiers plus [`binary/instruction-and-expression-encoding.md`](binary/instruction-and-expression-encoding.md). |

## Current Gaps And Caveats

- **Resultful tag declarations are a local/spec split.** Current Core 3.0 accepts tag type uses whose expansion is a function type at declaration time, while exception instruction rules still require selected tags to expand to empty results at use sites. Starshine currently rejects resultful tag declarations/imports earlier in [`Validate for TagType`](../src/validate/validate.mbt). Treat those fixtures as validator-gap evidence until a deliberate widening moves the empty-result check to EH instruction validation.
- **Legacy EH text is not a preserved core model.** New semantic fixtures should prefer modern `try_table`. Legacy `try`, `delegate`, and `rethrow` are parser/lowerer compatibility evidence only.
- **`throw_ref` is not a pure terminator.** It consumes and evaluates an operand. A pass must preserve the difference between null-trap and non-null rethrow.
- **Catch-reference payloads carry non-null exception references.** `catch_ref` and `catch_all_ref` branch with a captured non-null `(ref exn)` even if the target label is written as nullable `exnref`; subtyping/matching accounts for the difference.
- **Feature status and local implementation status are separate.** If Starshine has a WAST, validation, generator, or pass gap, name the layer rather than reclassifying Exception Handling as active proposal syntax.

## Rewrite And Signoff Checklist

When changing code or docs around Exception Handling:

1. **Pick the layer.** WAST syntax belongs in `src/wast`; tag-section bytes belong in `src/binary`; tag declaration rules belong in `src/validate/validate.mbt`; instruction stack/catch rules belong in `src/validate/typecheck.mbt`; pass rewrites belong in the owning pass plus validation signoff.
2. **Audit all tag carriers.** Remap `TagSec`, tag imports/exports, `throw` immediates, `try_table` `catch` / `catch_ref` clauses, tag name-section entries, and WAST `$tag` expectations together.
3. **Keep catch labels honest.** After moving or rewriting `try_table`, revalidate that each catch payload matches the target label result type.
4. **Preserve `throw_ref` operand semantics.** Do not erase, hoist, sink, or duplicate the operand without proving null-trap/rethrow behavior is unchanged.
5. **Route neighboring features explicitly.** If a test also involves Stack Switching, JSPI, relaxed dead-code validation, tail calls, or GC references, cite the focused boundary for that second dimension.
6. **Use the standard validation lane.** For docs-only changes, read/grep evidence and update the wiki/log. For behavior changes, follow the implementing package tests, then `moon info`, `moon fmt`, and `moon test` where practical.

## Sources

- Feature-status bridge: [`raw/wasm/2026-06-05-exception-handling-core-boundary-routing.md`](raw/wasm/2026-06-05-exception-handling-core-boundary-routing.md)
- Current exception/tag source refresh: [`raw/wasm/2026-06-04-exception-tag-current-refresh.md`](raw/wasm/2026-06-04-exception-tag-current-refresh.md)
- `throw_ref` nullability correction: [`raw/wasm/2026-05-20-exception-throwref-nullability-refresh.md`](raw/wasm/2026-05-20-exception-throwref-nullability-refresh.md)
- Detailed WAST guide: [`wast/exception-tag-authoring.md`](wast/exception-tag-authoring.md)
- Binary tag/resource guide: [`binary/type-table-memory-global-tag-sections.md`](binary/type-table-memory-global-tag-sections.md)
- Validation phase and stack-polymorphism guides: [`validate/module-validation-phases.md`](validate/module-validation-phases.md), [`validate/stack-polymorphism-and-bottom.md`](validate/stack-polymorphism-and-bottom.md)
- Current Starshine code: [`src/lib/types.mbt`](../src/lib/types.mbt), [`src/wast/parser.mbt`](../src/wast/parser.mbt), [`src/wast/lower_to_lib.mbt`](../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../src/wast/module_wast.mbt), [`src/binary/decode.mbt`](../src/binary/decode.mbt), [`src/binary/encode.mbt`](../src/binary/encode.mbt), [`src/validate/validate.mbt`](../src/validate/validate.mbt), [`src/validate/typecheck.mbt`](../src/validate/typecheck.mbt)
