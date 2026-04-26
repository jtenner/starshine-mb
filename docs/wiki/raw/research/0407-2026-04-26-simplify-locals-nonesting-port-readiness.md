# `simplify-locals-nonesting` port-readiness bridge

_Date:_ 2026-04-26  
_Status:_ absorbed into living wiki pages  
_Primary source capture:_ [`../binaryen/2026-04-26-simplify-locals-nonesting-port-readiness-primary-sources.md`](../binaryen/2026-04-26-simplify-locals-nonesting-port-readiness-primary-sources.md)

## Question

The `simplify-locals-nonesting` folder already had a source-backed dossier, but future implementers still had to infer the safe first Starshine slice from the overview and status page.
This note records the port-readiness bridge: what to implement first, what to keep disabled, and how to validate the pass without accidentally turning it into full `simplify-locals`.

## Rechecked context

- Re-read `AGENTS.md`, `docs/README.md`, `docs/wiki/`, the main wiki index/log, the Binaryen pass index/tracker, the existing `simplify-locals-nonesting` folder, neighboring `simplify-locals*`, `flatten`, `dataflow-optimization`, and `souperify` pages, and `docs/wiki/raw/research/` before adding a new page.
- Rechecked official Binaryen `version_129` and current-main owner, registration, constructor, dedicated-test, and combo-lit surfaces.
- Rechecked Starshine's removed-registry alias, CLI gate, preset omission, dispatcher, and active full-`simplify-locals` implementation surfaces.

## Findings

- The correct upstream contract remains `SimplifyLocals<false, false, false>`.
- The first local implementation slice should not start by copying the whole active Starshine `simplify-locals` behavior.
- The useful minimum is:
  1. choose spelling / alias policy;
  2. add registry and CLI tests proving the chosen state;
  3. add a no-rewrite analyzer or explicit policy-mode skeleton;
  4. implement only flat copy-chain retargeting and direct rewrite into another `local.set` value position;
  5. keep all negatives for tees, structure synthesis, and non-copy nested consumers green.
- Late equivalent-copy cleanup and dead-set cleanup are part of Binaryen's useful pass contract, but they should follow after the first slice proves the flatness policy.
- Binaryen oracle comparison should use `--simplify-locals-nonesting`, not full `--simplify-locals`, and should include fixtures from dedicated pass tests plus `flatten -> simplify-locals-nonesting -> dfo`-style neighbors.

## Uncertainties and decisions left open

- Starshine currently has only the local alias `simplify-locals-no-nesting`; the upstream spelling `simplify-locals-nonesting` is not a local registry entry. A future port must choose whether to add the upstream spelling, preserve the local alias, or support both.
- Starshine's active full `simplify-locals` implementation has raw fallback and performance guards that may need to stay keyed only to the full pass until the sibling has its own evidence.
- Current-main Binaryen was rechecked only for teaching-relevant surfaces. This note does not replace a future line-by-line port audit before implementation.

## Filed-back wiki updates

- Added `docs/wiki/binaryen/passes/simplify-locals-nonesting/starshine-port-readiness-and-validation.md`.
- Refreshed the overview and Starshine strategy page to link the readiness bridge.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.
