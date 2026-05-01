---
kind: concept
status: working
last_reviewed: 2026-04-30
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

## Ledger status meanings

| Status | Meaning |
| --- | --- |
| `Covered` | The observed count is nonzero and satisfies the configured floor. |
| `MissingOptional` | The observed count is zero, but the current profile did not require the surface. |
| `MissingRequired` | The observed count is below a nonzero explicit floor. |

## Intended FZG rows

The ledger now names the slice backlog's target surfaces up front: full scalar numeric ops, core control additions (`br_table`, standalone `unreachable`, `local.tee`, typed `select`), tail calls, memory op/memarg and memory/table limit variants, const expressions, basic refs, i31/extern conversions, GC constructors/accessors, string ops, exception/try-table matrices, SIMD phases 1-3, atomics, subtyping and rich GC field plans, import/export topology, element/data segment range expansion, name/custom sections, invalid AST/binary strategies, and WAST arbitrary parity.

## Known zero-coverage rows as of 2026-04-30

Most new FZG rows intentionally report `0` today because the generator has not been widened yet and because several existing private surface scans are not part of the public profile-floor counters. This is expected for `[FZG]001`: it establishes stable row names and failure semantics before later slices attach exact counters or generation paths.

The coarse pre-existing counters still cover current smoke/CI/stress floors for sections, exports, starts, tables, memories, globals, tags, elems, datas, data-count, ref types, v128 constants, direct/indirect calls, and branch-heavy control. Later FZG slices should replace broad proxy rows with exact family counters when they add each generator surface.

## Validation anchors

- `validate_valid_feature_ledger reports optional missing FZG surfaces` proves the ledger reports both covered existing rows and optional zero-count future rows.
- `check_validate_valid_feature_floors fails future FZG surfaces only when required` proves missing future rows remain non-fatal unless a caller adds an explicit floor.
