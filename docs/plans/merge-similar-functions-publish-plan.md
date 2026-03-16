# MergeSimilarFunctions Publish Plan

Date: 2026-03-16  
Owner: Compiler passes team  
Status: Active

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
- `MSF-010`: stronger coarse-bucket discrimination
- `MSF-011`: per-run cached analysis artifacts
- `MSF-012`: denser node-id and bucket/site metadata structures

Remaining publish work is therefore mostly policy/signoff work plus profitability scope:

- `MSF-006`
- `MSF-007`
- `MSF-008`
- `MSF-009`
- `MSF-013`

## 4. Remaining Publish Blockers

### 4.1 `MSF-006` Parameterization parity matrix

Exit criteria:
- This plan remains the source of truth for supported vs unsupported difference kinds.
- Any new supported kind adds a positive regression first.
- Any intentionally unsupported kind has an explicit skip or reject regression.

### 4.2 `MSF-007` Profitability model

Exit criteria:
- Replace raw instruction-count profitability with a byte-size-aware or clearly documented close proxy.
- Cost model must account for:
  - shared function creation
  - wrapper thunk cost
  - typed-ref rewrite overhead
  - additional type / element-segment cost where relevant

Required tests:
- clearly profitable merge still merges
- clearly unprofitable merge still skips
- varying-call-target cost is visible to the heuristic

### 4.3 `MSF-008` Adaptive parameter policy

Exit criteria:
- Parameter-pressure skips are tied to the profitability model rather than a blunt cap alone.
- Trace output keeps an explicit skip reason.
- Boundary regressions cover both accepted and rejected near-limit cases.

### 4.4 `MSF-009` Lowering envelope signoff

Exit criteria:
- Current publish claim explicitly states:
  - typed-ref merge path is supported only when lowering evidence already exists
  - unsupported varying-call-target cases skip intentionally
  - no alternate lowering is promised for v0.1.0

### 4.5 `MSF-013` Final regression and benchmark signoff

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

Open gap:
- A dedicated in-tree timing/allocation harness for `MergeSimilarFunctions` still needs to be added before final signoff.

## 6. Publish Signoff Checklist

- Supported difference matrix is documented and matches in-tree regressions.
- Supported typed-ref lowering envelope is documented and matches in-tree regressions.
- Profitability policy is documented and byte-size-aware enough for release.
- Parameter-pressure policy is explicit and regression-covered.
- Correctness regression suite passes.
- Performance regression / benchmark suite passes.
- Changelog entry and backlog state reflect the final publish-ready scope.

## 7. Immediate Next Steps

1. Finish `MSF-007` by replacing the instruction-count heuristic with a byte-size-aware cost model.
2. Fold `MSF-008` into that profitability work so near-limit profitable merges can be accepted intentionally.
3. Treat this document as the source of truth for `MSF-006`, `MSF-009`, and `MSF-013` until signoff is complete.
