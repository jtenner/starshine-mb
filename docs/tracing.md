# Pass Tracing Playbook

This document captures a reusable tracing strategy for optimization/lowering passes, based on the current `simplify_locals` implementation and optimizer pipeline wiring.

## Goals

- Keep tracing cheap when disabled.
- Make logs machine-parseable and easy to grep.
- Provide enough detail to diagnose phase behavior, regressions, and hotspots.
- Prevent runaway log spam from repeated failures.

## 1. Standard Trace Interface

Expose optional trace controls on the pass entrypoint:

- `trace? : (String) -> Unit = <pass>_trace_noop`
- `trace_all_funcs? : Bool = false`

Inside per-function traversal, compute:

- `ordinal` (stable per-function index for log keys)
- `log_func = pass_trace_log_enabled(ordinal, trace_all_funcs)` (or direct `trace_all_funcs` if you truly want all functions)
- `func_trace = if log_func { fn(msg) { trace("func[\{ordinal}] \{msg}") } } else { <pass>_trace_noop }`

This keeps call sites simple and avoids repeated `if trace_all_funcs` checks everywhere.

## 2. Log Taxonomy (Keep It Structured)

Use `key=value` text with consistent tokens:

- Pass lifecycle: `pass[..]:start`, `pass[..]:done`, `pass[..]:error`
- Function lifecycle: `func[N] start ...`, `func[N] done ...`
- Internal phases: include `phase=...` and `:start` / `:done`
- Iterative loops: include `cycle=` or `iter=`
- Final summaries: one compact line (for example hotspot summary)

Recommended required keys:

- `func[...]`
- `phase=...` (when inside sub-steps)
- `changed=true|false`
- elapsed time (`elapsed_ms=` or `*_us=`)
- one or two cardinality metrics (for example `locals=`, `top_instrs=`)

## 3. Timing + Counters Pattern

Use shared timer helpers (for example from `src/passes/util.mbt`) behind pass-local wrappers:

- `<pass>_trace_now_ms/us`
- `<pass>_trace_elapsed_ms/us_since`
- `<pass>_trace_delta_us_to_ms`

For helper-level profiling, maintain ref-backed counters:

- elapsed time per helper (`*_us`)
- invocation counts per helper (`*_calls`)

Implement:

- snapshot struct
- `snapshot()`
- `zero()`
- `diff(after, before)`
- `has_nonzero()`
- `emit_helper_timing(...)`

Pattern:

1. take per-function snapshot before work
2. run pass logic and accumulate helper timings
3. take snapshot after work
4. emit only the delta for this function

This avoids expensive resets while keeping per-function timing attribution clear.

## 4. Hotspot Tracking

Collect top-N expensive functions with bounded memory:

- record `(ordinal, primary_ticks, secondary_ticks, size metrics...)`
- keep only top `N` by primary ticks
- emit one final sorted summary line at end-of-pass

Use this to quickly identify where optimization time is concentrated without logging full details for every helper call.

## 5. Anti-Spam and Safety Guards

Add two controls:

- Repeated-failure suppression:
  - emit first `K` detailed failures
  - emit one `"additional ... suppressed"` notice
- Pathological budget guard (optional for expensive passes):
  - track per-function elapsed ticks
  - abort/revert work for that function if budget exceeded
  - emit explicit summary reason (`budget_exceeded=true action=...`)

These controls keep traces actionable in large modules.

## 6. Optimizer Pipeline Integration

When wiring pass tracing in `optimize.mbt`:

- prefix messages by pass name/variant:
  - `simplify_locals:...`
  - `simplify_locals (no-tee):...`
- pass `trace_all_funcs=trace_pass_details`
- rely on optimizer trace-level gates (`Pass`, `Phase`, `Helper`) to decide whether detailed per-function messages should flow

This ensures each pass follows the same top-level tracing contract and trace verbosity knobs.

## 7. Trace-Test Expectations

Add focused tests for tracing behavior, not full log snapshots:

- when verbose tracing is enabled, expected phase markers appear
- redundant iterations are not logged when optimization path should short-circuit
- suppression logic caps repeated rejection logs and emits suppression notice
- counters/snapshots reflect expected increments in representative scenarios

Prefer targeted `contains(...)` assertions over brittle whole-log equality.

## 8. Implementation Checklist (Copy/Paste)

1. Add pass-local trace noop + time wrappers.
2. Add optional `trace` and `trace_all_funcs` params to pass entrypoint.
3. Add per-function `ordinal` and `log_func` gating.
4. Emit structured `start`, phase, and `done` logs with stable keys.
5. Add helper timing snapshot/diff + delta emission.
6. Add bounded hotspot collector + final summary.
7. Add rejection/failure suppression guard if pass can emit repeated errors.
8. Wire pass through `optimize.mbt` with pass-name prefix.
9. Add tracing-focused tests for verbosity, suppression, and critical counters.

