# FUZ1037R1 Const-Expression Matrix Inventory

Date: 2026-05-31

## Scope

This note closes `[FUZ]1037R1`: audit the current GenValid constant-expression matrix, generator call sites, feature-fact attribution, focused tests, and docs for remaining initializer-expression gaps. This is an inventory-only slice; it intentionally makes no generator behavior change.

## Sources Audited

- `src/validate/gen_valid.mbt`
  - `GenValidConstExprUse`
  - `GenValidConstExprOpFamily`
  - `gen_valid_const_expr_allowed_op_matrix()`
  - `gen_valid_const_expr_context_for_use(...)`
  - `gen_valid_const_expr_from_context(...)`
  - `gen_valid_const_expr_for_global(...)`
  - `gen_valid_active_offset_from(...)`
  - `gen_valid_table_init_expr(...)`
  - `gen_valid_feature_facts(...)`
- `src/validate/gen_valid_tests.mbt`
  - matrix and context gate tests
  - focused global/table/element/data initializer coverage tests
  - feature-fact table-initializer scan test
- `src/validate/validate.mbt`
  - `validate_const_instr(...)` local allow-list
  - constant-expression validator coverage for globals, tables, data, and elements
- `docs/wiki/validate/constant-expressions.md`
- `docs/wiki/fuzzing/generator-coverage-ledger.md`
- `agent-todo.md`

## Current Matrix

`gen_valid_const_expr_allowed_op_matrix()` currently exposes five context rows:

| Context | Allowed op-family rows |
| --- | --- |
| `GlobalInitializerConstExpr` | numeric constants, `ref.null`, `ref.func`, imported immutable `global.get`, `ref.i31` |
| `DataOffsetConstExpr` | numeric constants, imported immutable `global.get` |
| `ElementOffsetConstExpr` | numeric constants, imported immutable `global.get` |
| `ElementPayloadConstExpr` | `ref.null`, `ref.func`, imported immutable `global.get`, `ref.i31` |
| `TableInitializerConstExpr` | `ref.null`, `ref.func`, imported immutable `global.get`, `ref.i31` |

The executable gate helper `gen_valid_const_expr_context_for_use(...)` matches that matrix: offset rows are numeric/address-oriented plus immutable imported global reads, while payload/table rows are reference-producing only.

## Generator Call-Site Inventory

- Global initializers route through `gen_valid_const_expr_for_global(...)`.
  - Coverage-forced globals include numeric `i32`, `funcref`, exact GC struct refs when a GC type plan exists, and `(ref i31)`.
  - Generic reference globals can use an imported immutable matching reference `global.get` after the previous FUZ1037 widening.
  - Exact GC struct refs can use `struct.new_default(type_idx)`.
- Active data offsets route through `gen_valid_active_offset_from(...)`.
  - Memory32 uses `i32.const` or an immutable imported `i32 global.get`.
  - Memory64 uses `i64.const` or an immutable imported `i64 global.get` after the latest FUZ1037 memory64 widening.
- Active element offsets reuse the same address-typed active-offset helper and currently have memory/table32-style `i32` coverage.
- Element payload expressions route through `gen_valid_const_expr_context_for_use(ElementPayloadConstExpr)` for typed expression payloads, after the previous split from element offsets.
- Optional table initializers route through `gen_valid_table_init_expr(...)`.
  - They first prefer matching imported immutable reference `global.get` when available.
  - Otherwise they use `gen_valid_elem_ref_expr(...)`, which covers `ref.func`, typed `ref.null`, and the shared `ref.i31` path for matching targets.

## Feature-Fact Inventory

`gen_valid_feature_facts(...)` scans constant-expression-bearing sites in all relevant sections:

- optional table initializer expressions;
- global initializer expressions;
- active element offset expressions;
- function-expression and typed-expression element payloads;
- active data offset expressions.

All of those sites can set `has_const_expr_variants` through `gen_valid_const_expr_has_variant(...)` and also feed the shared expression scanner so GC constructor/reference/string/SIMD/etc. side facts are counted when an initializer expression contains those instructions.

Current granularity remains one ledger key: `ConstExprVariants`. It records that at least one widened const-expression shape appeared, not which context/op-family pair appeared. That is the explicit follow-up question for `[FUZ]1037R4`.

## Focused Test Inventory

Current focused tests cover:

- matrix row order and allowed op-family lists;
- executable context gates matching the matrix;
- direct helper selection for numeric constants, immutable imported `global.get`, `ref.func`, typed `ref.null`, and `ref.i31`;
- global initializer `ref.i31`;
- global initializer imported immutable reference `global.get`;
- coverage-forced table initializer `ref.func`, typed `ref.null`, imported immutable reference `global.get`, and `ref.i31`;
- active data/element offsets using imported immutable `i32 global.get`;
- memory64 active data offset `i64.const`;
- memory64 active data offset imported immutable `i64 global.get`;
- table initializer feature-fact scanning.

Validator-side tests in `src/validate/validate.mbt` also cover local acceptance/rejection for global/table/data/element constant-expression validation, including mutable-global rejection and descriptor-bearing GC const initializers.

## Remaining Gaps Confirmed By The Audit

No broad missing matrix row was found for the currently modeled contexts, and no behavior change is needed for `[FUZ]1037R1` itself. The remaining work is already accurately split into the next tiny slices:

1. `[FUZ]1037R2` — boundary active-offset literals.
   - The matrix and helpers cover numeric offsets and memory64 address typing, but the audit did not find focused boundary-ish literal coverage across memory/table32 and memory64.
2. `[FUZ]1037R3` — GC descriptor initializer surface.
   - The validator has descriptor-bearing const-initializer coverage, and the generator/type plan builds descriptor/describes type pairs, but the GenValid matrix does not yet have a descriptor-specific op-family row or focused generated module fixture proving descriptor-pair initializer generation.
3. `[FUZ]1037R4` — context/op feature-fact attribution.
   - `ConstExprVariants` remains intentionally coarse today; it does not identify `GlobalInitializerConstExpr/ref.i31` versus `DataOffsetConstExpr/global.get` and similar pairs.
4. `[FUZ]1037R5` — closeout after R2-R4 are resolved or explicitly deferred.

## Conclusion

`[FUZ]1037R1` is complete as an inventory/audit slice. The current implementation has a coherent five-row context matrix, shared executable context gates, generator call sites for each modeled context, coarse feature-fact accounting over every initializer-bearing section, focused tests for the landed FUZ1037 surfaces, and docs that describe the matrix. Remaining gaps are concrete and already mapped to R2-R4 rather than hidden inside a broad parent task.
