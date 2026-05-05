# 0451 - `signature-refining` current-main recheck and source-anchor refresh

Date: 2026-05-05  
Status: completed research ingest  
Pass: `signature-refining` / upstream closed-world GC/type-cluster signature-tightening pass  
Local registry status: boundary-only  
Related living dossier: `docs/wiki/binaryen/passes/signature-refining/`

## Why this follow-up exists

The `signature-refining` dossier was already source-correct, but its freshness layer was still pinned to the 2026-04-26 bridge.
This follow-up records a 2026-05-05 current-main recheck so the living pages can carry a fresher provenance layer and tighter local code anchors.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/SignatureRefining.cpp`
  - `src/passes/pass.cpp`
  - `test/lit/passes/signature-refining.wast`
- Tagged comparison anchors:
  - the same owner and registration files on `version_129`
- Existing living dossier pages for the pass family

## Source-backed Binaryen conclusions

- Current `main` still matches the corrected `version_129` teaching contract on the reviewed surfaces.
- The pass remains heap-type-wide, GC-gated, and table-free.
- The result-side and intrinsic-side behavior is still part of the real contract, not an implementation footnote.
- No teaching-relevant current-main drift was found.

## Starshine local status

The local status is unchanged by this source refresh:

- `signature-refining` remains boundary-only in the registry;
- the future implementation is still module/type-graph work, not a HOT peephole;
- direct `call_ref` text fixtures and `call.without.effects` modeling are still the clearest local gaps.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/raw/binaryen/2026-05-05-signature-refining-current-main-recheck.md`
- `docs/wiki/binaryen/passes/signature-refining/index.md`
- `docs/wiki/binaryen/passes/signature-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/signature-refining/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/signature-refining/params-results-publicity-and-intrinsics.md`
- `docs/wiki/binaryen/passes/signature-refining/wat-shapes.md`
- `docs/wiki/binaryen/passes/signature-refining/starshine-strategy.md`
- `docs/wiki/binaryen/passes/signature-refining/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the 2026-04-24 primary-source capture and the 2026-04-26 port-readiness bridge.
It does not change the contract story; it only refreshes the provenance and exact local code anchors while keeping the boundary-only status explicit.
