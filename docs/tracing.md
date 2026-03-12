# Pass Tracing Playbook

This document captures a reusable tracing strategy for optimization/lowering passes and validation flows, based on the current `simplify_locals` implementation and `validate_module_with_trace` wiring.

## Goals

- Keep tracing cheap when disabled.
- Make logs machine-parseable and easy to grep.
- Provide enough detail to diagnose phase behavior, regressions, and hotspots.
- Track cumulative time per phase/helper for end-of-run summaries.
- Prevent runaway log spam from repeated failures.

## 1. Standard Trace Interface

Expose optional trace controls on the traced entrypoint:

- `trace? : (String) -> Unit = <pass>_trace_noop`
- `trace_all_funcs? : Bool = false`

For APIs that already have a non-traced call path, prefer a dedicated traced wrapper:

- `validate_module(...)` (no tracing overhead path)
- `validate_module_with_trace(..., trace, trace_all_funcs?)` (tracing enabled)

Inside per-function traversal, compute:

- `ordinal` (stable per-function index for log keys)
- `log_func = pass_trace_log_enabled(ordinal, trace_all_funcs)` (or direct `trace_all_funcs` if you truly want all functions)
- `func_trace = if log_func { fn(msg) { trace("func[\{ordinal}] \{msg}") } } else { <pass>_trace_noop }`

This keeps call sites simple and avoids repeated `if trace_all_funcs` checks everywhere. For module-level phase tracing, use an explicit internal `trace_enabled` gate so non-traced calls skip timing work.

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
- optimizer pass summaries should include both `transform_elapsed_ms=` and `validation_elapsed_ms=` when the runner performs post-pass validation, so expensive validation walks do not get conflated with transform cost on pathological modules
- one or two cardinality metrics (for example `locals=`, `top_instrs=`)

## 3. Timing + Counters Pattern

Use shared timer helpers from util modules and avoid re-implementing clock logic in each pass/package.

Prefer the canonical helpers in `src/lib/util.mbt`:

- `trace_now_ms/us`
- `trace_elapsed_ms/us_since`
- `trace_delta_us_to_ms`

If a package has pass-local wrappers (for naming or compatibility), those wrappers should delegate to shared util helpers instead of duplicating timing internals.

Typical wrapper surface:

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

### Totals Pattern (Now Required)

In addition to per-function helper deltas, maintain run-level totals:

- phase totals: `Map[String, UInt64]` for `*_ms`, plus `Map[String, Int]` for `*_calls`
- helper totals: ref-backed `*_us` and `*_calls` counters

Emit both success and error summaries:

- `phase_totals <phase>_ms=<...> <phase>_calls=<...> ...`
- `helper_totals <helper>_ms=<...> <helper>_calls=<...> ...`

If a phase fails, commit that phase’s partial elapsed time before returning `...:error`.

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

## 7. Validate Module Integration

`src/validate/validate.mbt` now follows the same contract:

- lifecycle:
  - `pass[validate_module]:start ...`
  - `pass[validate_module]:done ...`
  - `pass[validate_module]:error ...`
- phases:
  - `phase=<name>:start`
  - `phase=<name>:done elapsed_ms=...`
  - `phase=<name>:error elapsed_ms=...`
- function detail (when `trace_all_funcs=true`):
  - `func[N] start ...`
  - `func[N] helper_timing ...`
  - `func[N] done ...`
  - final `hotspots ...`
- totals:
  - final `phase_totals ...`
  - final `helper_totals ...`

## 8. Validation Expectations

**Dedicated tracing tests are strictly forbidden.**

Tracing should be validated through existing functional/integration coverage only. Do not add, keep, or expand trace-only tests.

**Trace-only tests add no value and should not be used as a quality gate for tracing changes.**

## 9. Implementation Checklist (Copy/Paste)

1. Add pass-local trace noop + time wrappers.
2. Add optional `trace` and `trace_all_funcs` params to traced entrypoint.
3. Add per-function `ordinal` and `log_func` gating.
4. Emit structured `start`, phase, and `done` logs with stable keys.
5. Add helper timing snapshot/diff + per-function delta emission.
6. Add phase/helper total counters and emit `phase_totals` + `helper_totals`.
7. Add bounded hotspot collector + final summary.
8. Ensure error paths emit `...:error` and still commit/emit totals.
9. Wire pass through `optimize.mbt` (or traced entry wrapper) with pass-name prefix when applicable.
