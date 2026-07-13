# DAEO low exact-result caller closure

Date: 2026-07-13

## Scope

This slice follows the retained wide nullable-default candidate worklist from note `1575`. It adds a narrow result-only GC refinement closure for productive low exact/default candidates and their direct caller chain, then measures the current artifact to determine whether result propagation can proceed before Func `164` body cleanup.

## Red-first regression

The existing `4097`-definition Func-164-shaped public regression already contained a result-forwarding chain:

```text
target defined 164 -> wrap1 defined 39 -> wrap2 defined 38 -> wrap3 defined 37
```

The test was strengthened to require the target's broad `(ref null $base)` result and all three forwarding wrapper results to become exact non-null `$leaf` after the null/default params are removed.

Before implementation the test failed at the target result: Starshine kept nullable broad Type `0`, while the expected result was exact non-null Type `1`.

## Implementation

`dae_try_refine_direct_gc_types(...)` now accepts a default-true `refine_params` policy. Ordinary core behavior is unchanged. The new low-candidate closure calls it with `refine_params=false`, so the closure can only refine returned GC evidence and repair the corresponding function signature/body; it cannot opportunistically change unrelated caller params.

`dae_run_direct_gc_result_refinement_caller_closure_with_facts(...)`:

- starts from the productive low exact/default definitions;
- reuses the same current direct-call facts because the preceding signature/operand rewrites do not change direct-call edges;
- visits each definition at most once;
- requires an owned non-self direct-call boundary;
- applies result-only GC refinement against the evolving module;
- enqueues direct callers only after a productive result refinement;
- is bounded to `16` productive definitions in the broad-module schedule;
- emits `low-exact-result-worklist` trace lines for productive refinements.

The public forwarding-chain regression now passes and validates. Plain DAE does not invoke the closure.

## Current artifact replay

Fresh native binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `36752eb9ea31129a2141d5dc49b00623ef1fabeb42833b23946cff811477fe70`.

Replay output:

- `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-low-result-closure.wasm`;
- SHA-256 `71b37ff9a74fa3c082959400f46a4443edd3dee7a33a4bc31957cb8c322fc910`;
- valid under `wasm-tools validate --features all`;
- byte-identical to note `1575`'s retained output;
- raw `3201560`, canonical `3278751`, current-tool canonical WAT `179615121`;
- pass-local `3864.742ms` versus Binaryen `8083.49ms`;
- whole command `4556ms` by shell monotonic timing;
- no `low-exact-result-worklist` trace line was emitted.

Agent judgment: the closure is valid, source-backed, bounded, and useful on the high-definition forwarding regression, but it is a measured no-op on the current artifact. It neither improves nor regresses artifact bytes and remains comfortably within the pass-local target.

## Blocker attribution

The post-worklist absolute Func `185` / defined Func `164` signature is already parameter-free, but its body still contains ten materialized null/default initialization chains before the final direct call:

- each former param becomes a `ref.null`-conditioned `if` that selects a default allocation or helper `ref.func` path;
- the selected value is stored through transient locals;
- the ten locals are reloaded into the final `call` to absolute Func `196`;
- the function result remains broad `(ref $731)`.

Binaryen folds that body to a small exact-returning shape and assigns exact result `$770`. The existing `dae_direct_gc_result_candidate_body(...)` cannot see through the uncleaned initialization/local chain, so result-only propagation correctly stops before Func `39`.

The next implementation owner is therefore a narrow, effect-preserving Func-164-shaped default-initialization/body cleanup before result refinement. It must prove that the null/default arms and local traffic are safe to fold, then rerun this closure. It must not enable blanket nested cleanup on nondefaultable-local functions or the oversized Func `41`.

## Validation and status

- red public forwarding-result expectation failed before implementation;
- focused public regression: `1/1`;
- full DAE white-box: `206/206`;
- full public DAEO: `310/310`;
- `moon test src/passes`: `5346/5346`;
- `moon fmt`: green;
- native release build: green with existing warnings;
- current artifact: valid and byte-identical to note `1575`;
- no intentional public API change.

DAEO remains active. The four-lane direct matrix remains stale after the worklist behavior changes, and scheduled current-artifact optimize/shrink evidence remains pending.
