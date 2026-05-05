---
kind: concept
status: working
last_reviewed: 2026-05-05
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
- `[FZG]005` attaches scalar-memory counters: `ScalarMemoryWidths` reports nonzero coverage when narrow scalar load/store width or sign variants appear, and `NonzeroMemarg` reports nonzero coverage when memory instructions use nonzero alignment or offset immediates. Coverage-forced modules now emit every scalar load/store width/sign variant with varied valid memargs.
- `[FZG]006` attaches the memory-limit/proposal counter: `MemoryLimitVariants` reports nonzero coverage when generated modules contain zero-min, unbounded, shared, or memory64 memories. Coverage-forced modules now emit all four shapes while keeping shared memories bounded and memory64 behind explicit toggles.
- `[FZG]007` attaches the table-limit/initializer counter: `TableLimitVariants` reports nonzero coverage when generated modules contain zero-min or unbounded table limits, non-funcref table ref types, or table initializer expressions. Coverage-forced modules now emit zero-min and unbounded tables, externref and GC/reference-typed tables, and matching table initializer const expressions behind `allow_table_limit_variants`.
- `[FZG]008` attaches the const-expression counter: `ConstExprVariants` reports nonzero coverage when const-expression sites contain widened forms such as `global.get`, `ref.func`, or safe GC constructors. Coverage-forced modules now emit immutable imported/previous globals for `global.get`, `ref.func` global initializers, a safe struct default constructor in a global initializer, table initializer `global.get`, and active element/data offsets backed by immutable `i32` globals behind `allow_const_expr_variants`.
- `[FZG]009` attaches the basic-reference-instruction counter: `BasicRefInstructions` reports nonzero coverage when the instruction scan sees widened basic ref forms. Coverage-forced modules now emit `ref.is_null`, `ref.null none`, `ref.null nofunc`, `ref.null noextern`, nullable and nonnullable `ref.test`/`ref.cast`, and nullable/nonnullable-target `br_on_cast`/`br_on_cast_fail` behind the existing `allow_ref_types` gate.
- `[FZG]010` attaches the i31/extern-conversion counter: `I31ExternConversions` reports nonzero coverage when the instruction scan sees `ref.i31`, `i31.get_s`, `i31.get_u`, `any.convert_extern`, or `extern.convert_any`. Coverage-forced modules now emit a deterministic valid prelude for those forms behind the existing `allow_ref_types` gate.
- `[FZG]011` attaches exact GC constructor/accessor counters: `GcConstructors` reports nonzero coverage when the instruction scan sees non-default/default struct or array constructors, and `GcAccessors` reports nonzero coverage when it sees struct/array get/set/len/fill/copy/init forms. Coverage-forced modules now emit non-default `struct.new`, non-default `array.new`, `array.new_fixed`, packed `struct.get_s`/`struct.get_u`, packed `array.get_s`/`array.get_u`, `array.fill`, and `array.copy` behind the existing `allow_ref_types` gate.
- `[FZG]012` attaches the supported string-operation counter: `StringOps` reports nonzero coverage when the instruction scan sees the string instructions currently represented by the AST and validator: `string.const`, string array new forms, and string array encode forms. Measurement, comparison, hash, view, and iterator forms remain outside the generator until the AST and validator support them.
- `[FZG]013` attaches the exception/try-table matrix counter: `ExceptionTryTableMatrix` reports nonzero coverage when the instruction scan sees mixed `try_table` catch lists that pair `catch` with `catch_all` or `catch_ref` with `catch_all_ref`. Coverage-forced modules now emit valid void and `exnref` result forms behind the existing `allow_ref_types` and tag gates.
- `[FZG]014` attaches the SIMD phase-1 counter: `SimdPhase1` reports nonzero coverage when the instruction scan sees v128 constants, splats, lane extract/replace operations, `v128.not/and/andnot/or/xor/bitselect`, or `v128.any_true`. Coverage-forced modules now emit valid drop-wrapped phase-1 SIMD forms behind `allow_v128`.
- `[FZG]015` attaches the SIMD phase-2 counter: `SimdPhase2` reports nonzero coverage when the instruction scan sees generated SIMD comparisons, all-true/bitmask forms, integer and float arithmetic, saturating add/sub, min/max/avgr, or float rounding ops. Coverage-forced modules now emit valid drop-wrapped phase-2 SIMD forms behind `allow_v128`.
- `[FZG]016` attaches the SIMD phase-3 counter: `SimdPhase3` reports nonzero coverage when the instruction scan sees SIMD memory, shuffle/swizzle, narrow, pairwise-add, dot-product, or float demote/promote forms. Coverage-forced modules now emit valid drop-wrapped phase-3 SIMD forms behind `allow_v128` when a memory is available.
- `[FZG]017` attaches the atomics counter: `Atomics` reports nonzero coverage when the instruction scan sees atomic loads, stores, RMW, compare/exchange, wait/notify, or fence forms. Coverage-forced modules now emit valid drop-wrapped atomic forms behind `allow_atomics` when a memory is available.

## Ledger status meanings

| Status | Meaning |
| --- | --- |
| `Covered` | The observed count is nonzero and satisfies the configured floor. |
| `MissingOptional` | The observed count is zero, but the current profile did not require the surface. |
| `MissingRequired` | The observed count is below a nonzero explicit floor. |

## Intended FZG rows

The ledger now names the slice backlog's target surfaces up front: full scalar numeric ops, core control additions (`br_table`, standalone `unreachable`, `local.tee`, typed `select`), tail calls, memory op/memarg and memory/table limit variants, const expressions, basic refs, i31/extern conversions, GC constructors/accessors, string ops, exception/try-table matrices, SIMD phases 1-3, atomics, subtyping and rich GC field plans, import/export topology, element/data segment range expansion, name/custom sections, invalid AST/binary strategies, and WAST arbitrary parity.

## Known zero-coverage rows as of 2026-05-01

Most new FZG rows intentionally report `0` today because the generator has not been widened yet and because several existing private surface scans are not part of the public profile-floor counters. `[FZG]002` through `[FZG]017` are the current exceptions: coverage-forced valid modules now emit deterministic expanded scalar numeric, core-control, tail-call, scalar-memory, memory-limit/proposal, table-limit/initializer, const-expression variant, basic-reference-instruction, i31/extern-conversion, GC constructor/accessor, supported string-operation, exception/try-table matrix, SIMD phase-1/phase-2/phase-3, and atomic surfaces and report nonzero `numeric_full_ops`, `br_table`, `standalone_unreachable`, `local_tee`, `typed_select`, `tail_calls`, `scalar_memory_widths`, `nonzero_memarg`, `memory_limit_variants`, `table_limit_variants`, `const_expr_variants`, `basic_ref_instructions`, `i31_extern_conversions`, `gc_constructors`, `gc_accessors`, `string_ops`, `exception_try_table_matrix`, `simd_phase1`, `simd_phase2`, `simd_phase3`, and `atomics` coverage.

The coarse pre-existing counters still cover current smoke/CI/stress floors for sections, exports, starts, tables, memories, globals, tags, elems, datas, data-count, ref types, v128 constants, direct/indirect calls, branch-heavy control, expanded scalar numeric instructions, and the exact core-control, tail-call, scalar-memory, memory-limit/proposal, table-limit/initializer, const-expression, basic-reference, i31/extern-conversion, GC constructor/accessor, string-op, exception/try-table matrix, SIMD phase-1/phase-2/phase-3, and atomic rows above. Later FZG slices should replace broad proxy rows with exact family counters when they add each generator surface.

## Validation anchors

- `validate_valid_feature_ledger reports optional missing FZG surfaces` proves the ledger reports both covered existing rows and optional zero-count future rows.
- `check_validate_valid_feature_floors fails future FZG surfaces only when required` proves missing future rows remain non-fatal unless a caller adds an explicit floor.
- `gen_valid coverage-forced emits expanded scalar numeric surface` proves the `[FZG]002` prelude validates and satisfies an explicit `NumericFullOps` floor.
- `gen_valid coverage-forced emits core control surface` proves the `[FZG]003` prelude validates and satisfies explicit `BrTable`, `StandaloneUnreachable`, `LocalTee`, and `TypedSelect` floors.
- `gen_valid coverage-forced emits tail-call surface` proves the `[FZG]004` prelude validates, emits `return_call`, `return_call_indirect`, and `return_call_ref`, and satisfies an explicit `TailCalls` floor.
- `gen_valid coverage-forced emits scalar memory widths and memarg variation` proves the `[FZG]005` prelude validates, emits every scalar load/store width/sign variant, uses nonzero memarg alignment or offset, and satisfies explicit `ScalarMemoryWidths` and `NonzeroMemarg` floors.
- `gen_valid coverage-forced emits memory limit and proposal variants` proves the `[FZG]006` module validates, emits zero-min, unbounded, shared, and memory64 memories, and satisfies an explicit `MemoryLimitVariants` floor.
- `gen_valid memory limit variants obey proposal toggles` proves disabling memory-limit/proposal toggles prevents shared, memory64, zero-min, and unbounded memory shapes from being generated.
- `gen_valid coverage-forced emits table limit and initializer variants` proves the `[FZG]007` module validates, emits zero-min/unbounded, externref, GC/reference-typed, and initializer-bearing table forms, and satisfies an explicit `TableLimitVariants` floor.
- `gen_valid table limit variants obey toggle` proves disabling `allow_table_limit_variants` prevents zero-min, unbounded, initializer-bearing, and non-funcref table variants from being generated.
- `gen_valid coverage-forced emits const-expression variants` proves the `[FZG]008` module validates, emits `global.get` in global initializers, table initializers, and active element/data offsets, emits a `ref.func` global initializer, emits a safe GC constructor global initializer, and satisfies an explicit `ConstExprVariants` floor.
- `gen_valid coverage-forced emits basic ref instruction surface` proves the `[FZG]009` module validates, emits `ref.is_null`, `ref.null none`, `ref.null nofunc`, `ref.null noextern`, nullable and nonnullable `ref.test`/`ref.cast`, nullable/nonnullable-target `br_on_cast`/`br_on_cast_fail`, and satisfies an explicit `BasicRefInstructions` floor.
- `gen_valid coverage-forced emits i31 and extern conversion surface` proves the `[FZG]010` module validates, emits `ref.i31`, `i31.get_s`, `i31.get_u`, `any.convert_extern`, and `extern.convert_any`, and satisfies an explicit `I31ExternConversions` floor.
- `gen_valid coverage-forced emits gc constructor and accessor surface` proves the `[FZG]011`/`[FZG]012` module validates, emits non-default struct/array constructors, `array.new_fixed`, packed struct/array accessors, `array.fill`, `array.copy`, and the supported string new/encode operations, and satisfies explicit `GcConstructors`, `GcAccessors`, and `StringOps` floors.
- `gen_valid coverage-forced emits exception try_table matrix surface` proves the `[FZG]013` module validates, emits mixed `catch`/`catch_all` and `catch_ref`/`catch_all_ref` `try_table` forms, and satisfies an explicit `ExceptionTryTableMatrix` floor.
- `gen_valid coverage-forced emits simd phase 1 surface` proves the `[FZG]014` module validates, emits splats, lane extract/replace, bitwise, and `any_true` SIMD phase-1 forms, and satisfies an explicit `SimdPhase1` floor.
- `gen_valid coverage-forced emits simd phase 2 surface` proves the `[FZG]015` module validates, emits SIMD comparisons, all-true/bitmask, arithmetic, saturating, min/max/avgr, and rounding forms, and satisfies an explicit `SimdPhase2` floor.
- `gen_valid coverage-forced emits simd phase 3 surface` proves the `[FZG]016` module validates, emits SIMD memory, shuffle/swizzle, narrow, pairwise-add, dot-product, and float demote/promote forms, and satisfies an explicit `SimdPhase3` floor.
- `gen_valid coverage-forced emits atomic instruction surface` proves the `[FZG]017` module validates, emits atomic load/store, RMW, compare/exchange, wait/notify, and fence forms, and satisfies an explicit `Atomics` floor.
- `.tmp/pass-fuzz-genvalid-wide-smoke-rume` is the first post-FZG002 compare smoke: `remove-unused-module-elements` over 1000 `gen-valid` cases reached `1000/1000` normalized matches.
- `.tmp/pass-fuzz-genvalid-fzg003-rume` is the post-FZG003 compare smoke: `remove-unused-module-elements` over 1000 widened `gen-valid` cases reached `1000/1000` normalized matches.
- `.tmp/pass-fuzz-genvalid-fzg004-rume` is the post-FZG004 compare smoke: `remove-unused-module-elements` over 1000 widened `gen-valid` cases reached `1000/1000` normalized matches with no validation, generator, command, or semantic failures.
- `.tmp/pass-fuzz-genvalid-fzg005-rume` is the post-FZG005 compare smoke: `remove-unused-module-elements` over 1000 widened `gen-valid` cases reached `1000/1000` normalized matches with no validation, generator, command, or semantic failures.
- `.tmp/pass-fuzz-genvalid-fzg006-rume` is the post-FZG006 compare smoke: `remove-unused-module-elements` over 1000 widened `gen-valid` cases reached `1000/1000` normalized matches with no validation, generator, command, or semantic failures.
- `.tmp/pass-fuzz-genvalid-fzg007-rume` is the post-FZG007 compare smoke: `remove-unused-module-elements` over 1000 widened `gen-valid` cases reached `1000/1000` normalized matches with no validation, generator, command, or semantic failures.
- `.tmp/pass-fuzz-genvalid-fzg008-rume` is the post-FZG008 compare smoke: `remove-unused-module-elements` over 1000 widened `gen-valid` cases reached `1000/1000` normalized matches with no validation, generator, command, or semantic failures.
- `.tmp/pass-fuzz-genvalid-fzg009-rume` is the post-FZG009 compare smoke: `remove-unused-module-elements` over 1000 widened `gen-valid` cases reached `1000/1000` normalized matches with no validation, generator, command, or semantic failures.
- `.tmp/pass-fuzz-genvalid-fzg010-rume` is the post-FZG010 compare smoke: `remove-unused-module-elements` over 1000 widened `gen-valid` cases reached `1000/1000` normalized matches with no validation, generator, command, or semantic failures.
