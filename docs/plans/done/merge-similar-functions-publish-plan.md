# MergeSimilarFunctions Publish Plan

Date: 2026-03-16  
Owner: Compiler passes team  
Status: Done

## Completion Notes (2026-03-16)

`MergeSimilarFunctions` publish signoff is complete for the currently documented guarded envelope.

Completed signoff coverage:
- upstream-invalid direct-call preflight auditing
- validator-backed `TypeIdx` / `FuncType` resolution
- hardened call-target rewrite validation
- tail-call-free forwarders plus guarded typed-ref lowering
- stable preorder site numbering
- byte-aware profitability and adaptive synthetic-parameter policy
- stronger coarse-bucket discrimination and cached/dense analysis artifacts
- fixed-corpus timing and allocation-sensitive instrumentation harnesses
- release-facing supported-difference and lowering-policy documentation

Recorded final gate:
- `moon info && moon fmt` (pass)
- `moon test` (pass)

Recorded harness/signoff evidence:
- fixed corpus validity/determinism/instrumentation tests in [`src/passes/merge_similar_functions.mbt`](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt)
- supported-envelope summary in [`docs/merge-similar-functions.md`](/home/jtenner/Projects/starshine-mb/docs/merge-similar-functions.md)

This plan is now complete and moved to `docs/plans/done`.

## 1. Objective

This plan defines the minimum remaining work and validation needed to publish `MergeSimilarFunctions` with an explicit supported envelope.

Primary implementation target:
- [src/passes/merge_similar_functions.mbt](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt)

Design/background target:
- [docs/merge-similar-functions.md](/home/jtenner/Projects/starshine-mb/docs/merge-similar-functions.md)

## 2. Current Supported Envelope

### 2.1 Parameterized difference kinds

| Difference kind | Current status | Current behavior | Evidence |
| --- | --- | --- | --- |
| Literal constant differences (`i32.const`, `i64.const`, `f32.const`, `f64.const`, `ref.null`, `ref.func`, `v128.const`) | Supported | Derived as `LiteralParam` and merged through shared synthetic params | [src/passes/merge_similar_functions.mbt](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) |
| Direct call-target differences with same resolved callee type / arity / call kind | Supported with typed-ref evidence | Derived as `CallTargetParam`; rewritten through `ref.cast` + `call_ref` / `return_call_ref` | [src/passes/merge_similar_functions.mbt](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) |
| Direct call-target differences without typed-ref lowering evidence in the input module | Explicitly skipped | Merge class is left unchanged and traced as `reason=typed_ref_lowering_unsupported` | [src/passes/merge_similar_functions.mbt](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) |
| Literal type mismatch at the same site | Explicitly rejected | `derive_params` fails; class is not merged | [src/passes/merge_similar_functions.mbt](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) |
| Direct call kind mismatch (`call` vs `return_call`) | Explicitly rejected | `derive_params` or rewrite validation fails with precise mismatch details | [src/passes/merge_similar_functions.mbt](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) |
| Direct callee type mismatch at the same site | Explicitly rejected | Merge is rejected before invalid rewrite proceeds | [src/passes/merge_similar_functions.mbt](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) |
| Local-count mismatch / structurally different bodies outside supported site kinds | Explicitly skipped | No class forms, or `derive_params` fails cleanly | [src/passes/merge_similar_functions.mbt](/home/jtenner/Projects/starshine-mb/src/passes/merge_similar_functions.mbt) |
| Immediate/index/offset differences beyond direct call targets | Unsupported today | No parameterization support; treated as non-equivalent or derive failure | [docs/merge-similar-functions.md](/home/jtenner/Projects/starshine-mb/docs/merge-similar-functions.md) |

### 2.2 Lowering policy

| Lowering surface | Current policy | Status |
| --- | --- | --- |
| Shared-member forwarders | Use `return(call ...)`, not `return_call` | Supported, tail-call-free |
| Varying direct call targets with typed-ref evidence already present | Allow `funcref` param + `ref.cast` + `call_ref` / `return_call_ref` lowering | Supported |
| Varying direct call targets without typed-ref evidence | Skip merge explicitly | Supported skip path |
| Alternate non-typed-ref lowering for varying call targets | Not implemented | Out of scope for current publish target |

Decision:
- Publishing target is the current explicit guarded typed-ref envelope, not a broader alternate-lowering promise.

## 3. Completed Foundation Work

The following blocker slices are already implemented in-tree:

- `MSF-001`: upstream-invalid direct-call preflight auditing
- `MSF-002`: validator-backed `TypeIdx` / `FuncType` resolution
- `MSF-003`: hardened call-target rewrite validation
- `MSF-004`: tail-call-free forwarders plus typed-ref guarded lowering
- `MSF-005`: stable preorder site numbering
- `MSF-006`: supported-vs-unsupported difference matrix documented in the main design doc and publish plan
- `MSF-007`: byte-aware profitability using instruction-immediate and thunk-body proxy cost
- `MSF-008`: adaptive synthetic-parameter policy using a soft limit, bounded hard cap, and explicit pressure skips
- `MSF-009`: guarded typed-ref lowering envelope documented as the release-facing policy in the main design doc and publish plan
- `MSF-010`: stronger coarse-bucket discrimination
- `MSF-011`: per-run cached analysis artifacts
- `MSF-012`: denser node-id and bucket/site metadata structures

Remaining publish work is therefore none for the pass-local `MergeSimilarFunctions` envelope.

## 4. Historical Remaining Blockers

### 4.1 `MSF-006` Parameterization parity matrix

Exit criteria:
- This plan remains the source of truth for supported vs unsupported difference kinds.
- Any new supported kind adds a positive regression first.
- Any intentionally unsupported kind has an explicit skip or reject regression.

### 4.2 `MSF-009` Lowering envelope signoff

Exit criteria:
- Current publish claim explicitly states:
  - typed-ref merge path is supported only when lowering evidence already exists
  - unsupported varying-call-target cases skip intentionally
  - no alternate lowering is promised for v0.1.0

### 4.3 `MSF-013` Final regression and benchmark signoff

Exit criteria:
- One concrete signoff checklist exists for correctness, parity, and performance.
- Future reruns do not require prior chat context.

## 5. Required Validation Matrix

### 5.1 Correctness reruns

- `moon test src/passes`
- `moon fmt`
- `moon info`
- `moon test`

### 5.2 Must-stay-green targeted areas

- upstream-invalid direct-call preflight
- grouped-rec type-index correctness
- call-target rewrite mismatch diagnostics
- typed-ref guarded skip path
- synthetic-parameter-limit skip path
- deterministic multi-class output

### 5.3 Performance reruns still needed before publish signoff

- collision-heavy coarse-bucket comparison count fixture
- bucket/site metadata allocation-sensitive fixture
- one representative end-to-end timing harness for `MergeSimilarFunctions`

Implemented:
- `merge_similar_functions.mbt` now includes a fixed-corpus timing harness plus allocation-sensitive instrumentation metrics that cover changed outputs, deterministic reruns, representative comparisons, bucket-copy churn, and dense site-map coverage.

Remaining signoff gap:
- None inside the pass-local `MergeSimilarFunctions` scope tracked by this plan.

## 6. Publish Signoff Checklist

- Supported difference matrix is documented and matches in-tree regressions.
- Supported typed-ref lowering envelope is documented and matches in-tree regressions.
- Correctness regression suite passes.
- Performance regression / benchmark suite passes.
- Changelog entry and backlog state reflect the final publish-ready scope.

## 7. Immediate Next Steps

1. Keep this plan as the historical signoff record under `docs/plans/done`.
2. Use `docs/merge-similar-functions.md` for any future envelope expansion work.
3. If the supported envelope grows, reopen this plan or create a new one with fresh rerun evidence.
