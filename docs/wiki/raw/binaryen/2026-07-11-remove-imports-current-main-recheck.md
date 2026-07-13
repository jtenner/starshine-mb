# Binaryen `remove-imports` Current-Main Recheck

Capture date: 2026-07-11

Purpose: refresh the source-backed contract for Binaryen's public `remove-imports` pass after the initial 2026-07-10 owner read. This is upstream and local-admission evidence only; it does not claim that Starshine implements, schedules, or can safely expose the transform.

## Primary URLs checked

- Binaryen current-main owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveImports.cpp>
- Binaryen current-main pass registry and default scheduler: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Binaryen current-main element-reference helper: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/element-utils.h>
- Binaryen current-main imported-function helper: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>

## Durable findings

- `RemoveImports.cpp` is still a function-import-specific `WalkerPass`. Its `visitCall` replaces a direct call to an imported function with `nop` for `none` results and with a default `Literal(type)` for value results. Its `visitModule` collects imported function names, preserves names referenced by `ElementUtils::iterAllElementFunctionNames`, and calls `removeFunction` for the rest.
- The two actions remain independent. An imported function retained because an element segment names it can still have every direct call stubbed. The helper is a table/element retention guard, not a general proof that host-call effects or results are erasable.
- Current `pass.cpp` still registers the public `remove-imports` spelling with `createRemoveImportsPass`. The reviewed default optimization builders do not schedule that name, so public availability must not be confused with ordinary `-O` / `-Os` behavior.
- The current owner has no user argument and the review still found no dedicated pass-named lit fixture. The owner, registration, and element helper are the evidence boundary; do not infer a broader import-cleanup or host-ABI contract.
- Focused local review remains unchanged: `remove-imports` is absent from `src/passes/optimize.mbt` and from `scripts/lib/pass-fuzz-compare-task.ts`'s `SUPPORTED_PASS_FLAGS`. Starshine has no direct pass, boundary-only alias, or runnable comparison lane.

## Reconciliation and supersession

This recheck finds no behavior-bearing upstream drift from [`2026-07-10-remove-imports-current-source-read.md`](2026-07-10-remove-imports-current-source-read.md). The earlier capture remains detailed historical provenance; this file supersedes its freshness claim for current-main owner, registration, scheduler, helper, and local-admission status.

## Wiki consequence

Keep `remove-imports` classified as upstream-only in Starshine. A future implementation needs an explicit embedding policy authorizing host-call/result stubbing, complete imported-prefix `FuncIdx` repair, focused element/reference tests, registry/dispatcher admission, and a policy-aware generator before compare-pass results could be meaningful.
