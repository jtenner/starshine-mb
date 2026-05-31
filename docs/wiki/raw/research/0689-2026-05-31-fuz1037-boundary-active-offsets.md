# FUZ1037R2 Boundary Active-Offset Literals

Date: 2026-05-31

## Scope

This note closes `[FUZ]1037R2`: add focused GenValid coverage for boundary-ish numeric literal offsets in active data/element constant-expression contexts, keeping imported-global offset coverage separate from this literal-only slice.

## Sources Touched

- `src/validate/gen_valid.mbt`
  - `gen_valid_active_i32_boundary_offset()`
  - `gen_valid_active_i64_boundary_offset()`
  - coverage-forced active element/data segment slots
  - coverage-forced data-count floor for const-expression variants
- `src/validate/gen_valid_tests.mbt`
  - `gen-valid coverage-forced active offsets include boundary literals`
- `docs/wiki/validate/constant-expressions.md`
- `docs/wiki/fuzzing/generator-coverage-ledger.md`
- `agent-todo.md`

## What Changed

Coverage-forced GenValid now deliberately emits numeric boundary-ish active-offset literals in addition to the pre-existing imported immutable `global.get` offset cases:

- an `i32.const 65536` active data offset for memory32;
- an `i32.const 65536` active element offset for table32 active element mode;
- an `i64.const 4294967296` active data offset for memory64 when the focused no-import configuration cannot use an imported immutable `i64 global.get`.

The memory64 imported-global lane remains separate: when an imported immutable `i64` global is available, the existing memory64 active data slot continues to exercise `global.get` instead of the boundary literal. This preserves the matrix distinction audited in `0688`: literal offsets and imported-global offsets are both allowed op families for data/element offset contexts, but they are tested as separate coverage facts.

The coverage-forced data-count floor now asks for four data segments when const-expression variants are enabled. This makes the focused boundary literal slot deterministic under the default coverage-forced `max_datas: 4` budget while still clamping to lower caller budgets.

## Validation

- First TDD run: `moon test src/validate` failed in `gen-valid coverage-forced active offsets include boundary literals` because no boundary-ish `i32` active data offset literal was generated.
- After adding boundary data/memory64 literals and the data-count floor, the same test failed on the missing active element boundary literal.
- After routing the coverage-forced active element fallback through the boundary helper, `moon test src/validate` passed with `1499` tests.

## Remaining FUZ1037 Work

`[FUZ]1037R2` is closed. Remaining initializer-expression closeout work is still:

- `[FUZ]1037R3` GC descriptor initializer surface;
- `[FUZ]1037R4` context/op feature-fact attribution;
- `[FUZ]1037R5` parent closeout after R3/R4 resolve or defer.
