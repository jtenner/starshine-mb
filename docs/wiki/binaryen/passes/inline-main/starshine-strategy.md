---
kind: concept
status: supported
last_reviewed: 2026-07-19
sources:
  - ./index.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./binaryen-strategy.md
  - ./special-case-contract-and-boundaries.md
  - ./fuzzing.md
  - ../inlining/starshine-strategy.md
---

# Starshine Strategy For `inline-main`

## Current status

`inline-main` is an active supported module pass and compare-harness name. It remains intentionally absent from default presets.

## Local path

- `inline_main_run_module_pass(...)` resolves exact names and defined endpoints.
- `inl_count_direct_target_calls(...)` enforces exactly one direct matching call.
- `inl_inline_exact_target_instrs(...)` recursively rewrites only that target.
- `inl_make_inline_replacement(...)` provides the shared local/type/return/tail repair.
- `inl_wrap_tail_callsite_hoists(...)` preserves tail-call exception semantics when the matching call is inside `try_table`.

## Behavior

- ordinary `call` and `return_call` are supported;
- nested placement is supported;
- tail calls nested in `try_table` evaluate operands inside the EH region and execute the copied tail body after leaving it;
- nested tail calls inside `__original_main` use the same direct/indirect/ref repair as ordinary inlining;
- `__original_main` is retained;
- no profitability threshold or ordinary inliner chooser is consulted;
- zero/multiple matching calls, missing names, and imported endpoints are no-ops.

## Tests

Focused coverage lives in `src/passes/inlining_test.mbt` and includes positive direct, tail, EH-tail, multiple-call, missing/imported, and helper-retention families. The shared suite is `120/120`; full repository tests are `9452/9452`.

## Fuzzing rule

Generic random corpora almost never contain the exact names and relation. Treat them as registry/dispatcher smoke only. A meaningful generated lane must author the exact names, one matching direct call, and a manifest label for the selected shape.

## Boundaries

Expression-level code metadata, branch hints, source maps, copied callee debug-name synthesis, and legacy `try_delegate` are shared substrate concerns, not missing `inline-main` behavior.
