---
kind: concept
status: working
last_reviewed: 2026-05-19
sources:
  - ../../README.md
  - ../../../agent-todo.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/wast/arbitrary.mbt
  - ../raw/wasm/2026-05-19-wast-control-flow-sources.md
  - ../raw/wasm/2026-05-19-wast-reference-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-variable-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-numeric-instruction-sources.md
  - ../raw/wasm/2026-05-19-wast-memory-instruction-sources.md
related:
  - ../wast/control-flow-authoring.md
  - ../wast/exception-tag-authoring.md
  - ../wast/reference-instruction-authoring.md
  - ../wast/numeric-instruction-authoring.md
  - ../wast/memory-instruction-authoring.md
  - ../wast/memory-argument-authoring.md
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

1. Mirror already-valid generated instruction families where the parser supports the syntax: scalar numeric forms, GC refs/types, exception forms, memory/table bulk ops, descriptor reference test/cast forms, call-ref and tail-call forms, SIMD text forms, and richer import/export declarations. Scalar numeric text mirrors should stay aligned with [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md). Ordinary `ref.test`, ordinary `ref.cast`, and `br_on_*` remain blocked on WAST parser/printer widening; see [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md).
2. Keep WAST-only syntax cases local when they are parser/printer concerns rather than typed valid-module concerns.
3. Add or update WAST package tests for each new syntax family before raising profile floors or claiming parity.
4. If a helper starts needing typed index-space construction, extract a small shared surface-intent helper instead of importing `gen_valid` wholesale.

## Stale-picker rule

The opcode pickers in `src/wast/arbitrary.mbt` are intentionally duplicated text-generation surfaces. They are allowed to lag the valid generator only when the lag is recorded here or in `docs/wiki/fuzzing/generator-coverage-ledger.md` with an explicit FZG row. Unrecorded silent divergence is a bug.

## Current coverage

`[FZG]027` adds a deterministic wide-surface prelude to arbitrary modules in `src/wast/arbitrary.mbt`. Every generated arbitrary module now carries text syntax for a GC struct type, exported tag, tail-call/call-ref forms, `throw`, `try_table`, memory/table bulk operations, descriptor ref test/cast forms, richer inline exports, and a representative `v128.const` shape. The focused package test `wast arbitrary module includes widened surface prelude` asserts these tokens and reparses the printed module. For scalar numeric pickers, use [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md) so representative constants/operators are not overclaimed as the full `[FZG]002` typed matrix. For descriptor reference forms and the currently missing ordinary `ref.test` / `ref.cast` / `br_on_*` text surface, keep future widening aligned with [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md). For the tail-call portion, keep future widening aligned with [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md) so parser/printer coverage does not overclaim return-type, table, reference, or CFG validity. For the exception-tag portion of that prelude, keep future widening aligned with [`../wast/exception-tag-authoring.md`](../wast/exception-tag-authoring.md) so text coverage does not overclaim full typed `try_table` / catch-label validation. For the SIMD portion, use [`../wast/simd-authoring.md`](../wast/simd-authoring.md) so future WAST widening distinguishes representative `v128.const` coverage from the broader valid-generator `[FZG]014` through `[FZG]016` matrix. For variable instructions, use [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md) before interpreting arbitrary `local.get`, `local.set`, `local.tee`, `global.get`, or `global.set` text as typed coverage. For memory bulk operations, use [`../wast/memory-instruction-authoring.md`](../wast/memory-instruction-authoring.md) plus [`../wast/memory-argument-authoring.md`](../wast/memory-argument-authoring.md) so parser/printer text coverage is not overclaimed as multi-memory, memory64, trap, or data-count signoff.

## Current gaps

- The WAST ordinary-control picker mirrors representative `[FZG]003` text syntax (`block`, `loop`, `if`, `br`, `br_if`, `br_table`, `return`, typed `select`) but does not prove every typed branch-payload or loop-parameter invariant. Keep text fixtures aligned with [`../wast/control-flow-authoring.md`](../wast/control-flow-authoring.md), and use `gen_valid` / validator evidence for typed-valid claims.
- The generic WAST instruction picker emits `local.get`, `local.set`, and `global.get` shapes, but it does not yet mirror the full variable-instruction surface from `[FZG]003` and `[FZG]008`: `local.tee`, `global.set`, identifier-form locals/globals, mutable-global negatives, and immutable-`global.get` constant-expression claims need fixtures or generator evidence tied to [`../wast/variable-instruction-authoring.md`](../wast/variable-instruction-authoring.md).
- The WAST numeric pickers cover representative scalar instructions, but not the full `[FZG]002` scalar opcode matrix. Use [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md) for literal parsing, stack effects, constant-expression behavior, trap/signedness/NaN hazards, and the split between text coverage and valid-generator coverage.
- The WAST prelude now mirrors the broad `[FZG]027` parser/printer surface, but it remains a text-roundtrip surface rather than a typed validity oracle for every `[FZG]003` through `[FZG]023` binary-generator invariant. Reference instructions, tail calls, and SIMD are clear examples: the prelude can include descriptor `ref.test_desc` / `ref.cast_desc_eq`, `return_call*`, and representative `v128.const` syntax, while validator/generator evidence owns ordinary `ref.test` / `ref.cast` / `br_on_*`, tail-call return-type checks, and the broader phase-1/2/3 SIMD matrix documented in [`../wast/numeric-instruction-authoring.md`](../wast/numeric-instruction-authoring.md), [`../wast/reference-instruction-authoring.md`](../wast/reference-instruction-authoring.md), [`../wast/tail-call-authoring.md`](../wast/tail-call-authoring.md), and [`../wast/simd-authoring.md`](../wast/simd-authoring.md).
- Invalid-AST and invalid-binary strategy widening remain separate from this WAST plan; they should keep starting from valid bases or binary-malformed strategies as described in `agent-todo.md`.
