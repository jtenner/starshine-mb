# SimplifyLocals Work Plan

Status: pass implementation complete for current release envelope; this doc is now the compact signoff + follow-up guide.

## Current State
- All `SimplifyLocals` variants are present and scheduler-visible.
- Regression and performance test IDs are in-tree and green.
- The pass is intentionally richer than a minimal parity fork and explicitly documented.

## Scope
- Work only on the currently supported surface:
  - `SimplifyLocals`, `SimplifyLocalsNoTee`, `SimplifyLocalsNoStructure`, `SimplifyLocalsNoTeeNoStructure`, `SimplifyLocalsNoNesting`
- Variants and support decisions in `optimize.mbt` remain deliberate.

## Current Design Summary
- Canonical locals model (`Locals` + `LocalRun`) is enforced.
- Multi-pass local cleanup pipeline includes:
  - no-tee/structure variants,
  - main rewrite + cleanup,
  - late equivalent-copy cleanup.
- Validation repair and typed-rewrite safety are present and tested.
- Pathology and wide-local guardrails are active.

## Canonical Task Map (Completed)
- **Sink soundness**: precise invalidate-on-read behavior (`ID-C1`, `ID-P1`).
- **Counter accuracy**: count tracking stays correct after rewrites (`ID-C2`, `ID-F3`).
- **Typed legality**: all rewrites validate/revert safely.
- **Effect + traversal**: dense maps and invalidation strategy keep local behavior correct.
- **Profitability**: parameter and skip rules are in place for loop-result, conditional br_if, and br_table cases.

## Current Next Work (Post-Signoff)
1. Performance-only hardening:
  - replace map/set hotspots with denser local-index arrays,
  - add dirty-index clearing,
  - fuse summary collection,
  - stage cheap prechecks for non-op functions.
2. Regression hardening for dense/high-parallel cases.
3. Keep parity/performance matrix updated in pass-local docs.

## Validation Expectations
- If changing `SimplifyLocals`, keep order:
  - targeted `simplify_locals` tests
  - `moon info && moon fmt`
  - `moon test`
  - scheduler tests when pass exposure changes.
