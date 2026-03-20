# MergeSimilarFunctions Publish Plan

Status: done.

## Completed
- Upstream-invalid direct-call preflight auditing.
- Validator-backed recursive type resolution.
- Hardened metadata and rewrite validation.
- Tail-safe forwarders, guarded typed-ref path, and stable traversal ordering.
- Byte-aware profitability and adaptive synthetic-parameter handling.
- Dedicated performance and allocation-sensitive coverage.

## Completed Verification
- `moon info && moon fmt`
- `moon test`
- Existing fixed-corpus and deterministic rerun tests in `src/passes/merge_similar_functions.mbt`.

## Publish Scope
- Release supports:
  - literal-like merges,
  - typed-ref supported direct-call merges with matching features.
- Out of scope:
  - alternate varying-call-target lowering,
  - full Binaryen-style widening until explicitly documented.

## Ongoing Responsibility
- This document is the historical signoff record.
- Any scope expansion must update:
  - `docs/0007-2026-03-16-merge-similar-functions.md`,
  - regression matrix,
  - and this publish plan (or a new replacement plan).
