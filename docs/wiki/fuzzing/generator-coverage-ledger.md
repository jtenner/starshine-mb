---
kind: concept
status: working
last_reviewed: 2026-05-01
sources:
  - ../../README.md
  - ../../../agent-todo.md
  - ../../../src/validate/validate.mbt
  - ../../../src/validate/gen_valid.mbt
---

# Generator Coverage Ledger

Starshine's fuzzer generator widening work uses a durable coverage ledger so generator smoke and CI runs can report both covered and intentionally missing surfaces without treating every future family as a hard gate.

## Current contract

- `src/validate/validate.mbt` owns the public ledger API: `validate_valid_feature_ledger(stats, floors)` returns one row per intended surface with a stable key, label, observed count, required minimum, and status.
- `check_validate_valid_feature_floors(stats, floors)` still fails only for floors explicitly listed by a profile or caller. Missing future FZG families are reported as `MissingOptional` until a profile adds a nonzero floor.
- Existing smoke/CI/stress profiles keep their previous floors. The new FZG rows are available for diagnostics and later floor retuning, but they are not required by default yet.
- `[FZG]002` attaches the first widened-surface counter: `NumericFullOps` now counts modules whose instruction scan sees expanded scalar numeric opcodes.
- `[FZG]003` attaches exact core-control counters for `br_table`, standalone `unreachable`, `local.tee`, and typed `select`; coverage-forced modules emit a deterministic valid prelude for those forms.
- `[FZG]004` attaches the tail-call counter: `TailCalls` reports nonzero coverage when direct, indirect, or ref tail-call forms appear. Coverage-forced modules now emit all three valid tail-call forms where callable results match the current function return type.

## Ledger status meanings

| Status | Meaning |
| --- | --- |
| `Covered` | The observed count is nonzero and satisfies the configured floor. |
| `MissingOptional` | The observed count is zero, but the current profile did not require the surface. |
| `MissingRequired` | The observed count is below a nonzero explicit floor. |

## Intended FZG rows

The ledger now names the slice backlog's target surfaces up front: full scalar numeric ops, core control additions (`br_table`, standalone `unreachable`, `local.tee`, typed `select`), tail calls, memory op/memarg and memory/table limit variants, const expressions, basic refs, i31/extern conversions, GC constructors/accessors, string ops, exception/try-table matrices, SIMD phases 1-3, atomics, subtyping and rich GC field plans, import/export topology, element/data segment range expansion, name/custom sections, invalid AST/binary strategies, and WAST arbitrary parity.

## Known zero-coverage rows as of 2026-05-01

Most new FZG rows intentionally report `0` today because the generator has not been widened yet and because several existing private surface scans are not part of the public profile-floor counters. `[FZG]002`, `[FZG]003`, and `[FZG]004` are the current exceptions: coverage-forced valid modules now emit deterministic expanded scalar numeric, core-control, and tail-call preludes and report nonzero `numeric_full_ops`, `br_table`, `standalone_unreachable`, `local_tee`, `typed_select`, and `tail_calls` coverage.

The coarse pre-existing counters still cover current smoke/CI/stress floors for sections, exports, starts, tables, memories, globals, tags, elems, datas, data-count, ref types, v128 constants, direct/indirect calls, branch-heavy control, expanded scalar numeric instructions, and the exact core-control and tail-call rows above. Later FZG slices should replace broad proxy rows with exact family counters when they add each generator surface.

## Validation anchors

- `validate_valid_feature_ledger reports optional missing FZG surfaces` proves the ledger reports both covered existing rows and optional zero-count future rows.
- `check_validate_valid_feature_floors fails future FZG surfaces only when required` proves missing future rows remain non-fatal unless a caller adds an explicit floor.
- `gen_valid coverage-forced emits expanded scalar numeric surface` proves the `[FZG]002` prelude validates and satisfies an explicit `NumericFullOps` floor.
- `gen_valid coverage-forced emits core control surface` proves the `[FZG]003` prelude validates and satisfies explicit `BrTable`, `StandaloneUnreachable`, `LocalTee`, and `TypedSelect` floors.
- `gen_valid coverage-forced emits tail-call surface` proves the `[FZG]004` prelude validates, emits `return_call`, `return_call_indirect`, and `return_call_ref`, and satisfies an explicit `TailCalls` floor.
- `.tmp/pass-fuzz-genvalid-wide-smoke-rume` is the first post-FZG002 compare smoke: `remove-unused-module-elements` over 1000 `gen-valid` cases reached `1000/1000` normalized matches.
- `.tmp/pass-fuzz-genvalid-fzg003-rume` is the post-FZG003 compare smoke: `remove-unused-module-elements` over 1000 widened `gen-valid` cases reached `1000/1000` normalized matches.
- `.tmp/pass-fuzz-genvalid-fzg004-rume` is the post-FZG004 compare smoke: `remove-unused-module-elements` over 1000 widened `gen-valid` cases reached `1000/1000` normalized matches with no validation, generator, command, or semantic failures.
