# 0904 - code-pushing import identity metadata prerequisite

Date: 2026-06-25

## Question

Can Starshine remove the first prerequisite blocker for Binaryen's `binaryen-intrinsics/call.without.effects` `code-pushing` surface by making function import module/name identity visible to HOT passes?

## Answer

Yes. `HotModuleContext` now records exact module/base import identity for function indices, aligned with the existing absolute function-index order used for function type resolution. Imported function entries store `Some((module_name, base_name))`; defined function entries store `None`.

This is intentionally metadata-only. It does **not** yet treat any call as movable and does not weaken ordinary call barriers. It provides the exact safe path needed for a follow-up `code-pushing` slice to recognize only the imported `binaryen-intrinsics` / `call.without.effects` function by absolute function index instead of using an unsafe type/arity heuristic.

## Behavior and API added

- `HotModuleContext.func_imports : Array[(@lib.Name, @lib.Name)?]` preserves import identity for function indices.
- `hot_module_resolve_func_import(ctx, func_idx)` returns the exact import module/base names for imported functions and `None` for defined or out-of-range functions.
- `hot_module_func_import_matches(ctx, func_idx, module_name, base_name)` provides a convenient exact-name predicate for pass code.

## TDD evidence

Red-first test:

```sh
moon test --target native src/ir/hot_module_context_test.mbt --filter '*import identity*'
```

failed before implementation because `hot_module_resolve_func_import` and `hot_module_func_import_matches` were unbound.

Final focused validation:

```sh
moon fmt
moon info
moon test --target native src/ir/hot_module_context_test.mbt --filter '*import identity*'
moon test --target native src/ir/hot_module_context_test.mbt
moon test --target native src/ir
```

Results:

- `moon fmt` passed.
- `moon info` passed with pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Focused import identity test passed `1/1`.
- Focused hot module context file passed `6/6`.
- Full `src/ir` native tests passed `310/310`.

## Remaining work

Next `code-pushing` slice should use this metadata to add an exact intrinsic predicate and then implement only the source-backed no-effects call movement from Binaryen `code-pushing_into_if.wast`:

- positive `sink-call` and `sink-call-3` shapes for `binaryen-intrinsics/call.without.effects`;
- post-`if` use negatives (`no-sink-call*`);
- `local.tee` / effectful argument negative (`no-sink-call-sub`);
- ordinary import and defined-call same-signature negatives proving no type/arity heuristic is used.

No pass-fuzz lane was run in this metadata-only slice because direct `code-pushing` behavior did not change.
