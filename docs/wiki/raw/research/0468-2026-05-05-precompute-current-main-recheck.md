# `precompute` current-main freshness refresh

## Why this follow-up exists

The `precompute` dossier was already source-correct and teaching-complete, but its freshness layer was still anchored to the 2026-04-26 current-main capture.
This follow-up records the 2026-05-05 source refresh and updates the living pages so the current-main bridge is visible from the canonical overview, strategy, implementation, and Starshine planning pages.

## Primary source rechecked

The refreshed source manifest rechecked official Binaryen current-main sources for:

- `src/passes/Precompute.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- representative `precompute*.wast` family tests

The review did not surface teaching-relevant drift from the existing contract.
The same broad `precompute` family still stands:

- plain `precompute` as the shared semantic-evaluator core in its non-propagating public mode
- `precompute-propagate` as the sibling with the extra propagation phase and nested rerun

## Durable update

The living dossier pages now point at the 2026-05-05 bridge so future maintainers can see that the pass was rechecked after the earlier 2026-04-26 pass-planning wave.
No semantic retcon was required; this is a freshness and reference-hygiene update only.

## Supersession note

This note extends the earlier 2026-04-26 `precompute` source notes.
It does not replace the earlier algorithm or implementation-test explanations, which remain the canonical detailed contract pages.
