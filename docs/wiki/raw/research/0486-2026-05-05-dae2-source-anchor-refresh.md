# [0486] 2026-05-05 DAE2 source-anchor refresh

## Question

What exact upstream Binaryen source pages should the `dae2` dossier point at so readers can follow the pass without guessing which sibling pass owns the behavior?

## Primary sources reviewed

- Binaryen `version_129` `DeadArgumentElimination2.cpp`
- Binaryen `version_129` `pass.cpp`
- Binaryen `version_129` `test/lit/passes/dae2.wast`
- Current-main recheck note: `../../../raw/binaryen/2026-05-05-dae2-current-main-recheck.md`

## Durable takeaways

- `dae2` is a separate public Binaryen pass, not a flag flip on plain `dae`.
- Its real contract is a backward fixed point over direct and indirect forwarded parameters.
- The mode split still matters: referenced-function rewriting only happens under `--closed-world` plus GC.
- The pass still treats `call.without.effects`, JS-called functions, public/root type trees, continuation/tag-related roots, and other referenced boundaries as conservative blockers.
- The reviewed `dae2.wast` surface remains the right proof surface for cycle elimination, indirect/reference-call participation, replacement-type regressions, and effect-preserving expression removal.

## Why this matters for the wiki

The living `dae2` pages already describe the algorithm well, but the folder benefits from one explicit source-anchor refresh so future readers can jump from the wiki to the upstream Binaryen files without re-deriving which sibling owns the contract.

## Follow-up

Use this note as the short provenance bridge when refreshing:

- `docs/wiki/binaryen/passes/dae2/index.md`
- `docs/wiki/binaryen/passes/dae2/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dae2/implementation-structure-and-tests.md`
