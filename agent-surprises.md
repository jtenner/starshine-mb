## 2026-03-05

- `src/passes/reorder_locals.mbt` rebuilt typed functions with `Func::t_func([], ...)`, silently dropping `TFunc` param metadata. That makes local-index accounting depend entirely on external `func_sec` type metadata and can lead to invalid `<unknown local>` references when metadata is missing or stale.

- `src/binary/encode.mbt` still had legacy `TFunc` local-prefix stripping logic during encode. With separated params/locals, that heuristic can accidentally drop real locals when local types begin with the same pattern as param types, producing invalid decoded modules (`invalid local index`).

- Many pass tests were pattern-matching `TFunc([], ...)` even for modules whose `func_sec` signatures had non-empty params. That hid constructor-site param dropping bugs and caused broad test churn once constructors were corrected to preserve separated params/locals.

- `src/passes/vacuum.mbt` models ambient stack flow with `VQStackSig { required, produced, reachable }`, so sequence pruning only reasons about stack depth, not stack value types or ordering. That makes it easy for Vacuum to keep “enough values” while deleting the `drop` or typed feeder that was preserving the correct top-of-stack type, and there is currently no focused regression test for an ambient-consuming `drop`.

- `src/passes/optimize.mbt` validation diagnostics can become a failure source themselves if they stringify entire `code_sec` snapshots for large modules; in practice this can abort command execution (`exited without a return code`) right after a validation error trace line. Limiting dumps to the offending function before/after is much safer.

- `src/passes/vacuum.mbt` only guarded stack-signature preservation for child rewrites and `None`-rewrites; in sequences containing ambient terminators (`br*`, `return*`, `throw*`), `Some(next)` rewrites could still silently change stack shape/type (e.g. ambient-consuming dropped children collapsing to `nop`) and destabilize validation on large real-world functions.
