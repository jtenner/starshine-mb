# MergeSimilarFunctions

## Status

- Not publish-ready.
- `MergeSimilarFunctions` still has unresolved correctness, parity, and performance blockers.
- Publishing the pass in its current state risks invalid IR rewrites, misattributed failures, feature-illegal output, and poor compile-time behavior on collision-heavy workloads.

## Scope

Today the pass groups structurally similar typed functions, derives synthetic parameters for selected differences, creates a shared implementation, and replaces original members with forwarding thunks.

Current in-tree behavior is intentionally narrower than a full parity target:

- it only parameterizes literal constants / literal-like values and direct call targets,
- varying direct calls are rewritten through synthetic `funcref` parameters plus `ref.cast` and `call_ref` / `return_call_ref` only when typed-ref lowering evidence already exists in the input module,
- all merged members become thunks that forward to the shared implementation,
- merge selection uses a byte-aware profitability proxy plus a soft synthetic-parameter limit and bounded hard cap,
- unsupported varying-call-target cases skip intentionally instead of promising an alternate lowering path.

In this document, “feature parity with Binaryen” does **not** mean byte-for-byte identical output or an identical implementation. It means a comparable correctness envelope, comparable coverage of worthwhile merge opportunities, and practical compile-time/runtime economics. Where Binaryen behavior is not directly verified from repository evidence, this document treats parity claims as hypotheses to investigate, not as facts.

Relevant current source anchors for future implementation work:

- `src/passes/merge_similar_functions.mbt`
- `src/passes/optimize.mbt`
- `src/validate/env.mbt`
- `src/validate/typecheck.mbt`
- `node/passes.js`

Current publish-signoff companion:

- `docs/plans/merge-similar-functions-publish-plan.md`

## Current supported envelope

### Parameterized difference kinds

| Difference kind | Current status | Current behavior |
| --- | --- | --- |
| Literal constant differences (`i32.const`, `i64.const`, `f32.const`, `f64.const`, `ref.null`, `ref.func`, `v128.const`) | Supported | Lowered as `LiteralParam` synthetic parameters and merged through the shared implementation. |
| Direct call-target differences with the same resolved callee type, arg count, and call kind | Supported with typed-ref evidence | Lowered through synthetic `funcref` parameters plus `ref.cast` and `call_ref` / `return_call_ref`. |
| Direct call-target differences without typed-ref lowering evidence in the input module | Explicitly skipped | The class is left unchanged and traced as `reason=typed_ref_lowering_unsupported`. |
| Literal type mismatch at the same site | Explicitly rejected | `derive_params(...)` fails and the class is not merged. |
| Direct call kind mismatch (`call` vs `return_call`) | Explicitly rejected | Validation fails before rewrite proceeds. |
| Direct callee type mismatch at the same site | Explicitly rejected | Validation fails before rewrite proceeds. |
| Immediate/index/offset differences beyond direct call targets | Unsupported today | They remain out of scope for the current publish target. |

### Lowering policy

| Lowering surface | Current policy |
| --- | --- |
| Shared-member forwarders | Lower to `return(call ...)`, not `return_call`. |
| Varying direct call targets with typed-ref evidence already present | Allow the typed-ref lowering path. |
| Varying direct call targets without typed-ref evidence | Skip the merge intentionally. |
| Alternate non-typed-ref lowering for varying call targets | Not promised for v0.1.0. |

Release-facing policy summary:

- The supported envelope is the current guarded typed-ref path, not a broader alternate-lowering promise.
- The pass intentionally documents and traces unsupported varying-call-target cases instead of attempting feature-illegal output.
- New supported difference kinds should add positive regressions before this envelope expands.

## Current observed failure

Concrete late-pipeline failure:

`merge_similar_functions: call target param arity mismatch for rewritten call site`

Representative debug context:

- `primary_def_idx=8565`
- `primary_abs_idx=8587`
- `member_count=9`
- `param_count=1`
- `params=[{kind: CallTargetParam((Type 939), 4, false, [...targets...]), uses: [26]}]`

Representative diff excerpt:

```text
primary:
  call (Func 9439) => (Type 939 (Func [I32, I32, I32] -> [I32]))

secondary:
  call (Func 8730) => (Type 939 (Func [I32, I32, I32] -> [I32]))
```

This failure matters because it sits on the boundary between three publish-blocking possibilities:

1. `MergeSimilarFunctions` introduced invalid IR while rewriting a shared body.
2. `MergeSimilarFunctions` resolved the wrong callee signature and therefore rejected a valid rewrite.
3. An earlier pass already corrupted the IR, and `MergeSimilarFunctions` only detected that corruption late enough to look like the culprit.

Until the pass can distinguish those cases clearly and deterministically, the current failure is not safely triaged.

## High-level findings

### Correctness

The pass currently carries several correctness risks at once. It performs late rewrite-time validation for call-target parameterization, but it does not first audit whether the incoming IR is already invalid. It also maintains local `TypeIdx` / `FuncType` resolution helpers even though authoritative type resolution already exists in the validator environment, which is especially risky for wasm GC recursion groups and appended type indices. In addition, call-target rewriting depends on hidden node-id and traversal-order coupling between collection and rewrite walks, emits feature-sensitive constructs without documented legality guards, and relies on generic `funcref` synthetic parameters plus `ref.cast` invariants that are not fully documented.

### Parity

The current Starshine pass is meaningfully narrower than the likely intended Binaryen-style feature envelope. Only literal-like differences and direct call-target differences are parameterized today. Profitability is based on coarse instruction counts instead of encoded bytes, and the synthetic-parameter cap is a rigid stop condition instead of a nuanced policy. The varying-call-target strategy also assumes typed function references are acceptable, which may be too narrow for all desired parity targets. These are parity gaps or likely parity gaps, not confirmed Binaryen mismatches unless verified locally.

### Performance

The current algorithm has several likely hot spots: coarse hash buckets can degrade into quadratic representative comparisons, equivalence checks rebuild normalized bodies and type metadata repeatedly, bucket construction performs copy-heavy array growth, and site bookkeeping uses map-heavy structures even though node ids are dense traversal ordinals. Together these issues likely increase both CPU cost and GC churn, especially on large or collision-heavy modules.

## Blockers

### MSF-001 — Preflight call arity and signature auditing

#### Problem

`MergeSimilarFunctions` currently validates call-target parameterization late, during shared-body rewrite. That is too late to tell whether a failure was created by the pass or merely discovered by the pass. If an earlier pass already produced a direct `call` or `return_call` whose stored argument vector no longer matches the callee signature, `MergeSimilarFunctions` can trip on that mismatch and look like the source of the bug.

#### Why this blocks publishing

Without a preflight audit, crash reports and late-pipeline failures cannot reliably distinguish “MSF introduced invalid IR” from “MSF detected upstream invalid IR.” That makes root-cause ownership ambiguous, makes regressions harder to triage, and undermines confidence in every call-target rewrite.

#### Evidence

- The observed failure is a late rewrite-time arity mismatch.
- `msf_collect_sites(...)` records direct-call site metadata from the current IR.
- `msf_rewrite_shared_body(...)` re-checks arg counts during rewrite, but there is no pass-wide direct-call audit before equivalence classification or parameter derivation.
- Existing diagnostics are phrased as rewrite failures, not as explicit upstream-invalid-IR findings.

#### Required changes

- Add a preflight pass-wide audit for direct `call` and `return_call` sites before any equivalence grouping or rewrite work begins.
- Validate arity and resolved function signatures against authoritative module semantics, not a pass-local approximation.
- Report upstream-invalid-IR findings distinctly from rewrite-time failures.
- Keep rewrite-time checks as a second line of defense, but make their diagnostics say whether the mismatch came from collected metadata, actual IR, or preflight-invalid input.

#### Acceptance criteria

- A module with a pre-existing invalid direct `call` or `return_call` fails preflight before merge rewriting starts.
- Diagnostics clearly separate:
  - upstream-invalid IR,
  - MSF metadata mismatch,
  - and rewrite-introduced mismatch.
- Valid modules do not regress into false-positive audit failures.

#### Tests

- Regression that injects a direct-call arity/signature mismatch before the pass and verifies the pass reports upstream-invalid IR.
- Regression that exercises the previously observed arity-mismatch shape and verifies the diagnostic path is unambiguous.
- Positive coverage showing valid call-target parameterization still proceeds after the audit.

#### Dependencies

- Should be implemented before or alongside `MSF-003`.
- Should use the authoritative type-resolution work from `MSF-002` instead of duplicating lookup logic again.

#### Notes

- The current observed failure is a concrete example of why this distinction matters.
- This item does **not** assume the pass is innocent; it requires the pass to prove whether the input was already invalid.

### MSF-002 — Authoritative TypeIdx and function-type resolution

#### Problem

The pass currently maintains ad hoc local type-resolution helpers instead of sharing one authoritative `TypeIdx -> FuncType` mapping. That is especially risky in the presence of wasm GC recursion groups. A high-risk failure mode is flattening recursion groups for lookup while also computing appended type indices using rec-group entry counts instead of flattened subtype counts, which can make the pass resolve the wrong `FuncType` for a `TypeIdx`.

#### Why this blocks publishing

If the pass resolves the wrong callee signature, every downstream decision built on that signature becomes suspect: call-site arity validation, call-target grouping, `call_ref` / `return_call_ref` typing, and appended shared-function type construction. A wrong `FuncType` can directly explain the observed arity-mismatch failure without any actual mismatch in the original call sites.

#### Evidence

- `msf_collect_comp_types(...)` flattens `GroupRecType` entries into a local array.
- `msf_resolve_func_type(...)` treats `TypeIdx` and `RecIdx` through pass-local indexing logic.
- `msf_append_func_type(...)` appends a new rec entry and returns `TypeIdx::new(recs.length() - 1)`, which is rec-entry-count based rather than obviously flattened-subtype-count based.
- The validator already has authoritative environment logic in `Env::resolve_subtype(...)` and `Env::resolve_functype(...)`.
- The observed failure involves a type-index-driven call-target rewrite path.

#### Required changes

- Remove or minimize ad hoc local type-resolution logic inside `MergeSimilarFunctions`.
- Route all `TypeIdx -> FuncType` resolution through authoritative validator-compatible semantics.
- Handle recursion groups explicitly, including the difference between rec-group entries and flattened subtype indexing.
- Define how newly appended shared-function types receive their indices in a way that matches authoritative module semantics.
- Add at least one regression test that specifically targets recursion-group indexing correctness.

#### Acceptance criteria

- For the same module, MSF resolves the same `FuncType` as the validator for all call targets it touches.
- Grouped recursion types, `RecIdx`, and appended shared-function types resolve correctly.
- The pass no longer relies on a separate local indexing model that can drift from validator semantics.

#### Tests

- Regression module with grouped recursion types that validates call-target resolution through the authoritative path.
- Regression covering appended shared-function type creation in the presence of pre-existing rec groups.
- Comparison-style test proving MSF and validator resolution agree on the same `TypeIdx` values.

#### Dependencies

- Foundational for `MSF-001`, `MSF-003`, `MSF-004`, and `MSF-009`.
- Likely requires reuse of shared validator/env helpers or a new common helper extracted from them.

#### Notes

- This document treats recursion-group indexing as a strong hypothesis supported by repo evidence, not yet as a proven sole root cause of the observed failure.

### MSF-003 — Harden call-target rewrite validation

#### Problem

Call-target parameterization hardening is incomplete. The pass collects `CallTargetParam` metadata in one phase and consumes it later in rewrite, but the validation surface is still split across loosely coupled steps. It needs stricter validation of collected metadata before rewrite and stricter comparison between that metadata and the actual IR node encountered during rewrite.

#### Why this blocks publishing

This is the correctness-critical transformation unique to the pass’s current non-literal support. If metadata drift, wrong node mapping, wrong callee type, or wrong `call`/`return_call` form reaches rewrite, the pass can either emit invalid IR or fail with an opaque late diagnostic.

#### Evidence

- `derive_params(...)` checks call-site type, return-call form, and arg-count consistency while building `CallTargetParam` values.
- `msf_rewrite_shared_body(...)` separately checks expected arg count, expected `call` vs `return_call`, and callee type before emitting `call_ref` or `return_call_ref`.
- The observed failure is specifically in the call-target parameterization path.
- Node ids are re-derived during rewrite instead of consuming a shared immutable site description.

#### Required changes

- Strengthen validation of collected `CallTargetParam` metadata before rewrite begins.
- During rewrite, compare stored site metadata against the actual IR node at that site for:
  - arg count,
  - resolved callee type,
  - `call` vs `return_call` form,
  - and any assumptions about result shape needed for `return_call_ref`.
- Improve diagnostics so mismatched arg count, return-call form, and callee-type mismatch report expected vs actual details.
- Reduce the amount of implicit coupling between “site discovery” and “site replacement.”

#### Acceptance criteria

- Mismatched arg count, callee type, or `call`/`return_call` form produce precise, non-generic errors.
- Valid varying-call-target rewrites still produce well-typed `call_ref` and `return_call_ref` sites.
- Rewrite does not silently proceed when metadata and actual IR disagree.

#### Tests

- Regression for mismatched arg count at a rewritten call site.
- Regression for mismatched `call` vs `return_call` form.
- Regression for callee-type mismatch.
- Positive coverage for both `call_ref` and `return_call_ref` rewrites on valid inputs.

#### Dependencies

- Depends on `MSF-001` for clean triage of upstream-invalid IR.
- Depends on `MSF-002` for authoritative callee-type resolution.
- Benefits from `MSF-005` if node-id coupling is reduced at the same time.

#### Notes

- Existing checks are useful but not yet sufficient for publish-grade fault isolation.

### MSF-004 — Feature-safe lowering for tail calls and typed function references

#### Problem

The pass emits feature-sensitive constructs without a documented legality policy. Thunks currently use tail-call forms, and call-target parameterization emits `call_ref` / `return_call_ref` plus `ref.cast`. The pass needs explicit legality checks, feature gating, or a documented fallback / skip path.

#### Why this blocks publishing

Publishing a pass that unconditionally emits feature-dependent IR is unsafe. If tail calls, typed function references, or related GC/reference features are unavailable in the module or compilation mode, the pass can produce output that is semantically unsupported or validator-illegal.

#### Evidence

- `replace_with_thunk(...)` emits `return_call(shared, args)`.
- `msf_rewrite_shared_body(...)` emits `ref_cast(... HeapType::new(type_idx) ...)` plus `call_ref` / `return_call_ref`.
- `msf_add_target_elem_segment(...)` adds a declarative element segment for collected targets.
- Validator/typechecker logic already treats these operations as feature- and type-sensitive.
- No documented feature gate is visible in the current pass-level flow.

#### Required changes

- Document legality checks for tail calls, `call_ref`, `return_call_ref`, and `ref.cast`.
- Implement one of the following policies for each emitted construct:
  - explicit feature gating,
  - a valid fallback lowering,
  - or an explicit unsupported-path guard that skips the merge.
- Add tests for feature-disabled behavior.
- Record how the pass should behave when only part of the required feature set is available.

#### Acceptance criteria

- The pass never emits tail-call or typed-function-reference constructs when the required feature support is unavailable.
- Unsupported configurations either skip the merge or fail with an explicit, actionable reason.
- Feature-enabled configurations keep the current valid behavior.

#### Tests

- Feature-disabled regression covering thunk generation.
- Feature-disabled regression covering call-target parameterization.
- Positive feature-enabled regression covering valid tail-call and typed-ref output.

#### Dependencies

- Depends on authoritative typing from `MSF-002`.
- Interacts closely with the strategy decision in `MSF-009`.

#### Notes

- This item does not assume a fallback exists today; “explicit unsupported” is acceptable if intentional and documented.

### MSF-005 — Stabilize node-id and traversal-order invariants

#### Problem

Equivalence classification, site collection, and rewrite mapping all rely on deterministic traversal order and stable node numbering. Those assumptions are currently implicit. If transformer traversal behavior changes, the pass can silently misassociate collected site metadata with the wrong nodes during rewrite.

#### Why this blocks publishing

Hidden node-order coupling is a correctness surface, not a cosmetic implementation detail. A future refactor in traversal helpers could break the pass without changing any explicit `MergeSimilarFunctions` logic, and the resulting failures could appear nondeterministic or unrelated.

#### Evidence

- `msf_collect_sites(...)` assigns dense sequential node ids while walking the body.
- `msf_rewrite_shared_body(...)` independently assigns sequential node ids during rewrite.
- The rewrite walker includes an explicit comment warning that a second default walk would skew node-id-based bookkeeping.
- Existing determinism coverage checks output stability across reruns, but there is no documented invariant contract for traversal/order assumptions.

#### Required changes

- Document the exact node-id determinism assumptions used by collection, equivalence checks, and rewrite.
- Add tests that fail if traversal order or site numbering becomes unstable.
- Reduce hidden coupling between collection and rewrite where practical, for example by centralizing site numbering or reusing a shared site vector.
- Make any required ordering guarantees explicit in helper APIs or local comments.

#### Acceptance criteria

- The pass has a documented invariant for how site ids are assigned and reused.
- A traversal-order change that would misalign site ids causes targeted tests to fail.
- Collection and rewrite are less dependent on undocumented transformer behavior.

#### Tests

- Determinism regression covering multiple reruns of the same input.
- Regression that mixes literal and call-target parameterization so site numbering matters across categories.
- Regression designed to detect accidental double-walk or reordered traversal behavior.

#### Dependencies

- Foundational for `MSF-003`, `MSF-011`, and `MSF-012`.

#### Notes

- The existing comment in the rewrite walker is a strong signal that this invariant already matters in practice.

### MSF-006 — Investigate parity gaps in parameterizable differences

#### Problem

The current pass only parameterizes literal-like values and direct call targets. That leaves the overall merge-opportunity envelope much narrower than a likely Binaryen-style target, but the exact parity gap is not yet fully cataloged.

#### Why this blocks publishing

Without a documented parity matrix, future implementation work cannot tell whether a missed merge is an intended non-goal, a safety exclusion, or simply unimplemented coverage. Publish readiness requires a clear statement of what difference kinds are intentionally supported, plausibly worthwhile next, or explicitly out of scope.

#### Evidence

- `MSFSiteValue` only models `ConstSite` and `CallTargetSite`.
- `derive_params(...)` only derives `LiteralParam` and `CallTargetParam`.
- The pass description and in-tree tests currently focus on constant merging and direct call-target merging.
- No existing document enumerates unsupported difference categories.

#### Required changes

- Document which difference kinds are unsupported today.
- Add a parity matrix classifying candidate difference kinds as:
  - supported today,
  - likely worthwhile to investigate,
  - unsafe or currently out of scope.
- Investigate additional categories conservatively, such as immediate/index/offset/operand differences, only where local evidence justifies it.
- Avoid asserting Binaryen support for a category unless verified locally.

#### Acceptance criteria

- The doc contains a parity matrix for parameterizable difference kinds.
- Future work items can cite that matrix to justify scope decisions.
- Unsupported categories are documented as explicit skips, not silent gaps.

#### Tests

- Representative positive tests for categories supported today.
- Negative tests that prove clearly unsupported categories are skipped cleanly.
- Follow-up parity tests for any newly approved category before implementation lands.

#### Dependencies

- Should follow the correctness foundation (`MSF-001` through `MSF-005`).
- Informs profitability work in `MSF-007` and parameter-pressure work in `MSF-008`.

#### Notes

- This is a parity-gap investigation item, not a claim that Starshine must match every Binaryen behavior.

### MSF-007 — Byte-size-aware profitability modeling

#### Problem

The current profitability heuristic is too simplistic. It mostly compares instruction/node counts and does not model encoded byte size precisely. It also risks undercounting transformation costs because all non-primary members become thunks and varying-call-target rewrites add `ref.cast` + `call_ref` / `return_call_ref` overhead.

#### Why this blocks publishing

An inaccurate profitability model can make the pass look correct while still making output worse. It can merge cases that increase binary size or skip cases that should clearly win. Publishing without a byte-size-aware or close-proxy model would leave a core pass policy unjustified.

#### Evidence

- `has_merge_benefit(...)` computes `removed` and `added` from body instruction counts, parameter counts, and thunk counts.
- The current formula does not obviously account for encoded byte costs of:
  - shared-function type growth,
  - all thunk bodies,
  - `ref.cast` and `call_ref` / `return_call_ref`,
  - declarative element-segment growth,
  - or any additional section-level overhead.
- Existing tests only cover a coarse “tiny loses, larger wins” threshold.

#### Required changes

- Replace the current heuristic with a byte-size-aware model or a close, documented proxy.
- Explicitly account for:
  - shared-function body size,
  - all wrapper thunk cost,
  - `call_ref` / `ref.cast` overhead,
  - added element-segment or declaration overhead where applicable,
  - and appended type-section overhead where applicable.
- Record the assumptions of the model so parity and performance work can reason about it.

#### Acceptance criteria

- The pass no longer relies on a raw node-count heuristic alone.
- The model explains why obviously profitable larger merges still merge and obviously unprofitable cases do not.
- Cost accounting includes thunking and typed-ref rewrite overhead explicitly.

#### Tests

- Regression proving the heuristic does not regress obvious profitable cases.
- Regression proving obvious low-value merges remain rejected.
- Fixture(s) that exercise varying-call-target overhead so the cost model sees `ref.cast` / `call_ref` expenses.

#### Dependencies

- Depends on the legality/lowering policy from `MSF-004` and `MSF-009`.
- Informs parameter-cap redesign in `MSF-008`.

#### Notes

- This is documented as a likely parity gap, not as a confirmed Binaryen formula mismatch.

### MSF-008 — Adaptive synthetic-parameter policy

#### Problem

The pass currently uses a hard synthetic-parameter cap as a blunt stop condition. That policy is probably too rigid: it can reject profitable merges simply because parameter pressure crossed a fixed threshold, even when the merge might still win under a better profitability model.

#### Why this blocks publishing

An overly rigid cap narrows the pass’s effectiveness and can hide missed opportunities without enough diagnostic clarity. Publish readiness requires a documented reason why a merge was skipped and a policy that is aligned with actual cost rather than a fixed ceiling alone.

#### Evidence

- `derive_params(...)` and the outer apply loop both skip merges when `primary_param_count + params.length()` exceeds `MSF_MAX_SYNTHETIC_FUNCTION_PARAMS`.
- The pass has an existing test that locks the current hard limit behavior.
- The current heuristic does not combine cap decisions with encoded-size-aware profitability.

#### Required changes

- Review the current hard synthetic-parameter cap.
- Consider adaptive thresholds or policy combinations that include body size, member count, and projected encoded-size benefit.
- Document when and why a merge is skipped due to parameter pressure.
- Preserve some bounded safety policy; this item is about making it more nuanced, not removing limits entirely.

#### Acceptance criteria

- Merge skips due to parameter pressure are explicit in diagnostics/tracing.
- The parameter policy is documented and justified relative to profitability.
- Profitable merges are not automatically excluded solely because they barely exceed an arbitrary legacy cap.

#### Tests

- Boundary tests around the parameter-pressure threshold.
- Regression showing a previously too-rigid skip can be reconsidered when profitable.
- Regression showing clearly excessive parameter growth still skips intentionally.

#### Dependencies

- Depends on `MSF-007` so parameter policy can be tied to a better cost model.

#### Notes

- This is an effectiveness/parity blocker, not a license to let parameter counts grow unbounded.

### MSF-009 — Alternate or guarded lowering for varying call targets

#### Problem

The current lowering for varying direct call targets is intentionally narrow: synthetic `funcref` parameters are cast to the desired heap type and then invoked via `call_ref` / `return_call_ref`. That strategy may be valid for some configurations, but it is not guaranteed to be the right choice everywhere the pass might otherwise want to merge.

#### Why this blocks publishing

If typed-function-reference lowering is unavailable, undesirable, or too expensive for a given configuration, the pass needs either an alternate lowering strategy or an explicit, well-documented refusal to perform that class of merge. Without that policy, the pass has an unclear supported envelope.

#### Evidence

- `CallTargetParam` values become synthetic `funcref` parameters.
- Rewritten call sites insert `ref.cast` and `call_ref` / `return_call_ref`.
- The pass also adds a declarative element segment for collected call targets.
- Current tests validate the typed-ref path, but there is no documented alternative strategy or unsupported-path policy.

#### Required changes

- Investigate alternate lowering strategies for varying call targets.
- If alternate lowering is out of scope, document that the pass intentionally supports only typed-ref-capable cases.
- Add clear skip behavior when the current typed-ref strategy is unsuitable or feature-illegal.
- Document how this decision interacts with profitability and feature gating.

#### Acceptance criteria

- Unsupported varying-call-target cases are skipped or rejected intentionally, not by late accidental failure.
- The supported lowering envelope is documented in one place.
- The pass’s policy is explicit about whether alternate lowering is in scope for Starshine.

#### Tests

- Positive regression for the currently supported typed-ref path.
- Negative/skip regression for unsupported or intentionally unhandled cases.
- Follow-up tests for any alternate lowering that is later approved.

#### Dependencies

- Depends on `MSF-002` for authoritative typing.
- Depends on `MSF-004` for feature legality.
- Interacts with profitability work in `MSF-007`.

#### Notes

- This item is phrased as investigation or explicit guarding, not as a claim that Starshine must implement every possible lowering strategy.

### MSF-010 — Remove quadratic coarse-bucket partitioning

#### Problem

Partitioning within coarse hash buckets is quadratic in the worst case. Candidate functions are first grouped by a shallow bucket key, then each candidate is compared against existing partition representatives until a match is found or a new partition is created.

#### Why this blocks publishing

On collision-heavy workloads, compile time can degrade badly. That hurts pass practicality even if correctness is fixed, and it makes future parity expansion riskier because broader candidate sets would only worsen the current asymptotics.

#### Evidence

- `collect_equivalent_classes(...)` builds buckets from `type_idx`, local-count, and hash.
- For each bucket, it compares each candidate against partition representatives in a loop.
- Large, weakly discriminated buckets therefore degrade toward repeated representative comparisons.
- The current bucket key is cheap but not highly discriminative.

#### Required changes

- Replace or mitigate the worst-case quadratic partitioning behavior.
- Add stronger cheap discriminators to bucket keys or prefilters.
- Reduce the number of expensive representative comparisons required before class membership is decided.
- Preserve deterministic class formation.

#### Acceptance criteria

- Collision-heavy buckets no longer exhibit naive quadratic representative-comparison behavior.
- The pass has a documented strategy for cheap early discrimination before expensive equivalence checks.
- Deterministic output ordering is preserved.

#### Tests

- Microbenchmark or pass-level benchmark with intentionally collision-heavy buckets.
- Counters or assertions that track representative-comparison counts.
- Regression ensuring output determinism is unchanged after the performance fix.

#### Dependencies

- Best tackled after the correctness foundation is stable.
- Pairs naturally with `MSF-011` and `MSF-012`.

#### Notes

- This item is about worst-case scalability, not about changing the pass’s external semantics.

### MSF-011 — Cache per-function analysis artifacts

#### Problem

The pass does too much repeated whole-body work inside hot loops. Likely repeated costs include rebuilding normalized bodies, recollecting call-site summaries, and recomputing type metadata that could be computed once per function or once per module context.

#### Why this blocks publishing

Repeated whole-body walks raise compile time and allocation pressure, especially inside coarse-bucket partitioning where the same candidate may be compared multiple times. Without caching, performance work elsewhere will have limited effect.

#### Evidence

- `are_in_equivalent_class(...)` recomputes function-type arrays and normalizes both bodies on each comparison.
- `derive_params(...)` recollects site maps for each class.
- `has_merge_benefit(...)` recollects function types again.
- Type metadata is currently computed from the module multiple times rather than once per run/module context.

#### Required changes

- Cache per-function analysis products such as:
  - normalized body,
  - shape/signature summary,
  - call-site signature list,
  - site vector or site summary,
  - type info,
  - and, where useful, profitability metadata.
- Ensure hot comparison loops do not rebuild the same normalized body or call summary repeatedly.
- Compute module-level type metadata once per run or shared context, not inside tight loops.

#### Acceptance criteria

- Normalized bodies and call summaries are not rebuilt repeatedly in hot comparison loops.
- Module-level type metadata is shared rather than recomputed per comparison.
- Caching does not change class formation or rewrite correctness.

#### Tests

- Benchmark or instrumentation showing repeated analysis work drops materially on representative inputs.
- Regression ensuring cached and uncached results are semantically identical.
- Stress case with heavy bucket reuse to demonstrate cache payoff.

#### Dependencies

- Benefits from invariant cleanup in `MSF-005`.
- Complements `MSF-010` and `MSF-012`.

#### Notes

- Cache invalidation can stay simple if artifacts are scoped to a single pass run or module snapshot.

### MSF-012 — Reduce GC churn with denser data structures

#### Problem

The pass currently creates avoidable allocation churn. Bucket growth uses copy-then-push-then-store-back patterns, site bookkeeping uses map-heavy structures even though node ids are dense traversal ordinals, and some deterministic ordering work sorts keys that may already be naturally ordered by traversal.

#### Why this blocks publishing

GC churn is a real performance cost in MoonBit code. Excess allocation can dominate runtime on large modules even when nominal asymptotics are acceptable. Publishing the pass before addressing obvious allocation hot spots would leave practical performance unnecessarily fragile.

#### Evidence

- Bucket construction copies arrays when adding members.
- `msf_collect_sites(...)` stores dense node-id data in `Map[Int, MSFSiteValue]`.
- `msf_rewrite_shared_body(...)` builds `Map[Int, Int]` for node-to-parameter lookup.
- Several other code paths copy arrays defensively in hot paths.

#### Required changes

- Eliminate repeated bucket-array copying during membership growth.
- Replace map-heavy dense node-id structures with denser array/vector-backed representations where appropriate.
- Track GC churn explicitly as a performance concern during optimization work.
- Preserve determinism while reducing allocation volume.

#### Acceptance criteria

- Bucket membership growth no longer copies arrays on every insertion.
- Dense node-id representations replace map-heavy structures where safe and justified.
- Allocation/GC behavior improves measurably on representative workloads.

#### Tests

- Allocation-sensitive benchmark or instrumentation for bucket-heavy inputs.
- Regression ensuring deterministic site ordering is unchanged after representation changes.
- Stress case that exercises dense node-id usage at scale.

#### Dependencies

- Works best alongside `MSF-010` and `MSF-011`.
- Depends on `MSF-005` if representation changes rely on documented node-order invariants.

#### Notes

- GC churn should be tracked explicitly, not treated as an incidental side effect of runtime measurements.

### MSF-013 — Regression and benchmark plan

#### Problem

The pass does not yet have a dedicated regression and benchmarking plan that covers correctness, parity, and performance together. Some targeted tests already exist, but there is no publish-ready matrix that locks the known failure modes and the expected performance envelope.

#### Why this blocks publishing

Without a dedicated plan, future fixes can land piecemeal without proving that the pass is actually ready for release. A publish blocker needs a concrete exit criterion, not just a collection of code changes.

#### Evidence

- Existing in-tree tests cover basic constant merging, typed-ref call-target rewriting, profitability gating, synthetic-param limits, determinism, and validation on some examples.
- The known blocker set goes beyond that current coverage: upstream-invalid-IR detection, recursion-group indexing correctness, feature-disabled behavior, parity gap documentation, and performance scaling are not yet locked by one cohesive plan.

#### Required changes

- Build a dedicated regression and benchmarking plan that includes:
  - correctness regressions for upstream-invalid-call detection,
  - recursion-group type-index handling,
  - call-target rewrite validation,
  - feature gating,
  - parity tests for representative merge opportunities,
  - and microbenchmarks or pass-level benchmarks for bucket-heavy workloads.
- Record measurement guidance for both runtime and allocation behavior.
- Make the plan usable by a future implementation agent without requiring prior chat history.

#### Acceptance criteria

- The full blocker matrix has explicit regression or benchmark coverage mapped to it.
- Future implementation work has a documented minimum validation sequence.
- Publish signoff can reference one concrete regression/benchmark plan instead of ad hoc reruns.

#### Tests

- Correctness regressions for:
  - upstream-invalid-call detection,
  - recursion-group type-index handling,
  - call-target rewrite validation,
  - feature gating.
- Parity tests for representative merge opportunities and intentional skip cases.
- Microbenchmarks or pass-level benchmarks for bucket-heavy workloads, measuring both runtime and allocation behavior.

#### Dependencies

- Depends on the design outputs of `MSF-001` through `MSF-012`.
- Can start as documentation immediately, but final signoff belongs last.

#### Notes

- Future implementation work should follow strict TDD: add the failing regression or benchmark expectation first, then change the pass.

## Recommended sequencing

1. **Correctness foundation** — `MSF-001`, `MSF-002`, `MSF-003`, `MSF-005`
2. **Legality and feature support** — `MSF-004`, `MSF-009`
3. **Profitability / parity expansion** — `MSF-006`, `MSF-007`, `MSF-008`
4. **Performance hardening** — `MSF-010`, `MSF-011`, `MSF-012`
5. **Final regression + benchmark sweep** — `MSF-013`

Suggested rule of thumb: do not expand merge coverage or relax profitability policy until the correctness foundation and legality policy are settled.

## Open questions

- What are the exact authoritative `TypeIdx` / recursion-group semantics for Starshine’s wasm GC model, especially after appending a new shared-function type?
- Which Binaryen parity targets for `MergeSimilarFunctions` are confirmed from local evidence versus inferred from broader pass expectations?
- Is alternate varying-call-target lowering in scope for Starshine, or should the pass explicitly remain limited to typed-ref-capable cases?
- Should upstream-invalid-IR auditing live entirely inside `MergeSimilarFunctions`, or should it be shared with other passes that depend on trusted direct-call metadata?
