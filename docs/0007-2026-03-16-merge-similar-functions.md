# MergeSimilarFunctions

Status: guarded publish envelope complete in broad strokes; remaining work is expansion and performance hardening.

## Current Supported Envelope
- Supported parameterized differences:
  - literal-like constants (`i32/i64/f32/f64/ref.const`, `ref.func`, `v128.const`)
  - direct call-target differences through typed-ref path (`call_ref` / `return_call_ref`) when evidence exists
- Explicitly skipped:
  - non-typed direct-call lowering,
  - direct call kind mismatches,
  - immediate/index/offset/other operand differences,
  - mutable or wrong-type reuse cases.
- Unsupported cases are traced as intentional skips, not silent rewrites.

## Known Failure Profile
- A late rewrite/arbitrary mismatch can come from:
  1. upstream-invalid IR,
  2. local metadata drift,
  3. rewrite-time type/shape divergence.
- Preflight audit is required to separate these cases cleanly.

## Completed and Closed Items
- Upstream-invalid direct-call preflight auditing.
- Authoritative validator-backed `TypeIdx` / `FuncType` resolution.
- Stronger call-target rewrite validation.
- Tail-call-free forwarders and guarded typed-ref lowering.
- Stable site numbering policy.
- Byte-aware profitability and adaptive synthetic-parameter policy.
- Better buckets + cached/dense artifacts.

## Remaining Focus (MSF-style blocker set)
- MSF-004: explicit feature legality for any feature-dependent constructs (`tail call`, `call_ref`, `ref.cast`).
- MSF-006: maintain a visible parity matrix for difference kinds.
- MSF-010: reduce quadratic behavior in coarse bucket comparison.
- MSF-011/012: cache and data-structure churn reduction in hot loops.
- MSF-013: dedicated publish regression + benchmark matrix.

## Recommended Order
1. Correctness foundation (`MSF-001` to `MSF-003`).
2. Feature gating + supported-lowering policy (`MSF-004`, `MSF-009`).
3. Performance: bucket discrimination + cached artifacts.
4. Publish matrix verification before any broader scope expansion.

## Publish Readiness Checklist
- Clear diagnostics for:
  - upstream-invalid IR,
  - metadata mismatch,
  - rewrite mismatch.
- Deterministic behavior and idempotent runs.
- Recursion-group typing correctness covered by dedicated regression.
- Explicit skip reasons for unsupported configurations.
- Benchmarks and regression matrix in one section for future maintainers.
