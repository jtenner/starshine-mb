---
kind: concept
status: working
last_reviewed: 2026-05-05
sources:
  - ../../README.md
  - ../../../agent-todo.md
  - ../../../src/validate/gen_valid.mbt
  - ../../../src/validate/validate.mbt
  - ../../../src/wast/arbitrary.mbt
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

1. Mirror already-valid generated instruction families where the parser supports the syntax: GC refs/types, exception forms, memory/table bulk ops, ref casts, call-ref and tail-call forms, SIMD text forms, and richer import/export declarations.
2. Keep WAST-only syntax cases local when they are parser/printer concerns rather than typed valid-module concerns.
3. Add or update WAST package tests for each new syntax family before raising profile floors or claiming parity.
4. If a helper starts needing typed index-space construction, extract a small shared surface-intent helper instead of importing `gen_valid` wholesale.

## Stale-picker rule

The opcode pickers in `src/wast/arbitrary.mbt` are intentionally duplicated text-generation surfaces. They are allowed to lag the valid generator only when the lag is recorded here or in `docs/wiki/fuzzing/generator-coverage-ledger.md` with an explicit FZG row. Unrecorded silent divergence is a bug.

## Current gaps

- The WAST numeric pickers cover representative scalar instructions, but not the full `[FZG]002` scalar opcode matrix.
- WAST generation has some reference, table, memory, import/export, and SIMD shapes, but it does not yet mirror all `[FZG]003` through `[FZG]023` valid-generator surfaces.
- Invalid-AST and invalid-binary strategy widening remain separate from this WAST plan; they should keep starting from valid bases or binary-malformed strategies as described in `agent-todo.md`.
