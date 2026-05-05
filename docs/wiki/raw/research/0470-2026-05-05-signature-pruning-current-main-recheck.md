# `signature-pruning` current-main freshness refresh

## Why this follow-up exists

The `signature-pruning` dossier was already source-correct and teaching-complete, but its freshness layer was still anchored to the 2026-04-26 current-main capture.
This follow-up records the 2026-05-05 source refresh and updates the living pages so the current-main bridge is visible from the canonical overview, strategy, implementation, shape, boundary, and Starshine planning pages.

## Primary source rechecked

The refreshed source manifest rechecked official Binaryen current-main sources for:

- `src/passes/SignaturePruning.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/signature-pruning.wast`

The review did not surface teaching-relevant drift from the existing contract.
The same broad `signature-pruning` family still stands:

- nominal function heap-type pruning in a closed-world GC/type cluster
- direct `call` and `call_ref` user updates together
- constant-actual promotion before pruning when needed
- one delayed localization rerun after signature rewrite
- the same public / tag / continuation / JS / table / subtyping boundaries

## Durable update

The living dossier pages now point at the 2026-05-05 bridge so future maintainers can see that the pass was rechecked after the earlier 2026-04-26 planning wave.
No semantic retcon was required; this is a freshness and reference-hygiene update only.

## Supersession note

This note extends the earlier 2026-04-26 `signature-pruning` source notes.
It does not replace the earlier algorithm or implementation-test explanations, which remain the canonical detailed contract pages.
