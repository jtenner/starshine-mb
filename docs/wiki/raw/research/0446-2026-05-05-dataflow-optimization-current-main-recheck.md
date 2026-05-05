# Dataflow optimization current-main recheck

## Context

Rechecked the upstream Binaryen `dataflow-optimization` / `dfo` sources on 2026-05-05 to keep the living wiki current.

## Primary-source result

The refreshed Binaryen current-main capture still matches the existing dossier:

- flat-input gate remains required through `Flat::verifyFlatness(func)`
- the DataFlow side graph remains integer-relevant and Souper-oriented
- the rewrite surface remains the same tiny pair: identical-constant phi collapse and nested-`precompute` constant folding
- the shipped combo lit file still teaches `flatten -> simplify-locals-nonesting -> dfo -> cleanup`
- no teaching-relevant upstream drift was found

## Starshine hygiene result

The only local hygiene issue found was stale line anchors in the Starshine status page for the removed-pass request guard.

- old anchor: `src/passes/optimize.mbt#L485-L491`
- current anchor: `src/passes/optimize.mbt#L522-L524`

## Follow-up

Use the new raw Binaryen capture together with the living dossier pages instead of the older 2026-04-25 recheck when citing current-main provenance.
