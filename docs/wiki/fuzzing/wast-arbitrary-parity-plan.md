---
kind: concept
status: working
last_reviewed: 2026-05-20
sources:
  - ../../README.md
  - ../../../agent-todo.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/wast/arbitrary.mbt
  - ../raw/wasm/2026-05-19-wast-control-flow-sources.md
  - ../raw/wasm/2026-05-20-wast-parametric-select-sources.md
  - ../raw/wasm/2026-05-19-wast-reference-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-variable-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-numeric-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-memory-instruction-sources.md
  - ../raw/wasm/2026-05-20-atomic-memory-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-data-segment-sources.md
  - ../raw/wasm/2026-05-20-call-ref-source-refresh.md
  - ../raw/wasm/2026-05-19-wast-call-and-function-sources.md
  - ../raw/wasm/2026-05-20-exception-throwref-nullability-refresh.md
  - ../raw/wasm/2026-05-19-wast-gc-aggregate-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-string-instruction-sources.md
related:
  - ../wast/control-flow-authoring.md
  - ../wast/parametric-instruction-authoring.md
  - ../wast/function-call-and-module-authoring.md
  - ../wast/exception-tag-authoring.md
  - ../wast/reference-instruction-authoring.md
  - ../wast/gc-aggregate-instruction-authoring.md
  - ../wast/string-instruction-authoring.md
  - ../wast/numeric-instruction-authoring.md
  - ../wast/memory-instruction-authoring.md
  - ../wast/atomic-memory-instruction-authoring.md
  - ../wast/memory-argument-authoring.md
  - ../wast/data-segment-authoring.md
  - ../wast/simd-authoring.md
  - ../wast/tail-call-authoring.md
  - ../wast/variable-instruction-authoring.md
  - generator-coverage-ledger.md
---

# WAST Arbitrary Parity Plan

`src/wast/arbitrary.mbt` should stay a text-roundtrip generator, but it must not silently drift from the richer `gen-valid` coverage model.

## Decision

Keep WAST generation independent from `src/validate/gen_valid.mbt` for now. Do not call the valid module generator directly from WAST arbitrary generation.

Reasons:

- `gen_valid` builds typed binary-AST modules with feature-floor accounting, valid index spaces, and validator-facing invariants.
- `wast/arbitrary` builds compact text syntax fragments for WAT/WAST parser and printer roundtrip coverage, including intentionally lightweight shapes that are not trying to exercise every binary-AST invariant.
- Direct reuse would couple WAST fuzzing to binary module construction and make parser-oriented failures harder to reduce.

Instead, share the coverage vocabulary: every duplicated opcode picker or surface helper in `wast/arbitrary.mbt` is a text-shape mirror of an FZG ledger family, and wider WAST work should cite the matching ledger row when it adds syntax.

## Boundary for `[FZG]027`

Future WAST widening should add text syntax in this order:

1. Mirror already-valid generated instruction families where the parser supports the syntax: scalar numeric forms, GC refs/types, supported GC aggregate/i31 forms, exception forms, memory/table bulk ops, descriptor reference test/cast forms, tail-call forms, SIMD text forms, resource declarations, and richer function/import/export/start declarations. Function/call/module text mirrors should stay aligned with [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md); table/memory/global declaration mirrors should stay aligned with [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md). Ordinary non-tail `call_ref`, ordinary `ref.test`, ordinary `ref.cast`, `br_on_*`, official `struct.set`, all `array.*` instructions, dedicated string-helper arbitrary text, atomic memory text keywords, inline table/memory/global import shorthand, and WAST memory64/shared resource declarations remain blocked on WAST parser/printer or generator widening; see [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md), [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md), [`../wast/atomic-memory-instruction-authoring.md`](../wast/atomic-memory-instruction-authoring.md), and [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md).
2. Keep WAST-only syntax cases local when they are parser/printer concerns rather than typed valid-module concerns.
3. Add or update WAST package tests for each new syntax family before raising profile floors or claiming parity.
4. If a helper starts needing typed index-space construction, extract a small shared surface-intent helper instead of importing `gen_valid` wholesale.

## Stale-picker rule

The opcode pickers in `src/wast/arbitrary.mbt` are intentionally duplicated text-generation surfaces. They are allowed to lag the valid generator only when the lag is recorded here or in `docs/wiki/fuzzing/generator-coverage-ledger.md` with an explicit FZG row. Unrecorded silent divergence is a bug.

## Current coverage

`[FZG]027` adds a deterministic wide-surface prelude to arbitrary modules in `src/wast/arbitrary.mbt`. Every generated arbitrary module now carries text syntax for a GC struct type, exported tag, tail-call forms including `return_call_ref`, `throw`, `try_table`, memory/table bulk operations, descriptor ref test/cast forms, richer inline exports, direct/indirect calls, and a representative `v128.const` shape. The focused package test `wast arbitrary module includes widened surface prelude` asserts these tokens and reparses the printed module. For typed `select` and future select widening, use [`../wast/parametric-instruction-authoring.md`](../wast/parametric-instruction-authoring.md) so parser/printer coverage is not overclaimed as portable multi-value typed-select or untyped reference-select conformance. For scalar numeric pickers, use [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md) so representative constants/operators are not overclaimed as the full `[FZG]002` typed matrix. For supported struct constructor/get, i31, and any/extern conversion text, and for the missing official `struct.set` / `array.*` text surface, keep future widening aligned with [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md). For supported string helper text and the current lack of dedicated arbitrary string-helper emission, keep future widening aligned with [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md). For descriptor reference forms and the currently missing ordinary `ref.test` / `ref.cast` / `br_on_*` text surface, keep future widening aligned with [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md). For the tail-call portion, keep future widening aligned with [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md) so parser/printer coverage does not overclaim return-type, table, reference, or CFG validity. For the exception-tag portion of that prelude, keep future widening aligned with [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md) so text coverage does not overclaim full typed `try_table` / catch-label validation or collapse the nullable `throw_ref` operand rule into the non-null catch-ref payload rule. For the SIMD portion, use [`../wast/simd-authoring.md`](../wast/simd-authoring.md) so future WAST widening distinguishes representative `v128.const` coverage from the broader deterministic valid-generator `[FZG]014` through `[FZG]016` matrix and from the separately documented relaxed-SIMD WAST spelling surface. For variable instructions, use [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md) before interpreting arbitrary `local.get`, `local.set`, `local.tee`, `global.get`, or `global.set` text as typed coverage. For memory bulk operations, use [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md) plus [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md) and [`../wast/data-segment-authoring.md`](../wast/data-segment-authoring.md) so parser/printer text coverage is not overclaimed as multi-memory, memory64, trap, data-segment, or data-count signoff. For atomics, use [`../wast/atomic-memory-instruction-authoring.md`](../wast/atomic-memory-instruction-authoring.md) so `[FZG]017` core/binary/generator evidence is not mistaken for accepted WAST text. For table/memory/global declaration text, use [`../wast/resource-declaration-authoring.md`](../wast/resource-declaration-authoring.md) so arbitrary output is not mistaken for shared-memory, memory64/table64, optional core table-initializer, or inline resource-import evidence. For function/import/export/start and direct/indirect call text, use [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md) so arbitrary output is not mistaken for full typed-validity evidence or ordinary `call_ref` WAST support.

## Current gaps

- The WAST ordinary-control picker mirrors representative `[FZG]003` text syntax (`block`, `loop`, `if`, `br`, `br_if`, `br_table`, `return`, typed `select`) but does not prove every typed branch-payload, loop-parameter, or select-portability invariant. Keep branch text fixtures aligned with [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md), keep `select` fixtures aligned with [`../wast/parametric-instruction-authoring.md`](../wast/parametric-instruction-authoring.md), and use `gen_valid` / validator evidence for typed-valid claims.
- The generic WAST instruction picker emits `local.get`, `local.set`, and `global.get` shapes, but it does not yet mirror the full variable-instruction surface from `[FZG]003` and `[FZG]008`: `local.tee`, `global.set`, identifier-form locals/globals, mutable-global negatives, and immutable-`global.get` constant-expression claims need fixtures or generator evidence tied to [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md) plus the focused validator contract in [`../validate/constant-expressions.md`](../validate/constant-expressions.md).
- The WAST numeric pickers cover representative scalar instructions, but not the full `[FZG]002` scalar opcode matrix. Use [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md) for literal parsing, stack effects, trap/signedness/NaN hazards, and the split between text coverage and valid-generator coverage; use [`../validate/constant-expressions.md`](../validate/constant-expressions.md) for initializer/offset eligibility rather than treating WAST text coverage as validation evidence.
- The WAST prelude now mirrors the broad `[FZG]027` parser/printer surface, but it remains a text-roundtrip surface rather than a typed validity oracle for every `[FZG]003` through `[FZG]023` binary-generator invariant. Reference instructions, GC aggregates, string helpers, tail calls, SIMD, and atomics are clear examples: the prelude can include descriptor `ref.test_desc` / `ref.cast_desc_eq`, supported struct/i31 text, `return_call*`, and representative `v128.const` syntax, while validator/generator evidence owns ordinary `ref.test` / `ref.cast` / `br_on_*`, ordinary non-tail `call_ref`, official `struct.set`, all `array.*` instructions, string array-helper storage/mutability validation, tail-call return-type checks, the broader deterministic phase-1/2/3 SIMD matrix, and the entire `[FZG]017` atomic memory surface documented in [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md), [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md), [`../wast/function-call-and-module-authoring.md`](../wast/function-call-and-module-authoring.md), [`../wast/gc-aggregate-instruction-authoring.md`](../wast/gc-aggregate-instruction-authoring.md), [`../wast/string-instruction-authoring.md`](../wast/string-instruction-authoring.md), [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md), [`../wast/simd-authoring.md`](../wast/simd-authoring.md), and [`../wast/atomic-memory-instruction-authoring.md`](../wast/atomic-memory-instruction-authoring.md). Current WAST arbitrary and `gen_valid` do not emit relaxed-SIMD opcodes; use the SIMD authoring page plus the Binaryen `remove-relaxed-simd` dossier when widening that surface.
- Invalid-AST and invalid-binary strategy widening remain separate from this WAST plan; they should keep starting from valid bases or binary-malformed strategies as described in `agent-todo.md`.
