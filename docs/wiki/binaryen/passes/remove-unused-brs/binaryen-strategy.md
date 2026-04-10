---
kind: concept
status: working
last_reviewed: 2026-04-09
sources:
  - ../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md
  - ../../../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./pattern-catalog.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
---

# Binaryen `remove-unused-brs` Strategy

## Upstream Source Rule

- Primary upstream oracle: Binaryen `version_129` `src/passes/RemoveUnusedBrs.cpp`.
- The local wiki pages are intentionally sourced from the repo's archived Binaryen comparison note first, because that note already distilled the upstream pass into the phase boundaries that matter for Starshine.
- This page should stay phase-oriented. If a future parity investigation needs line-by-line upstream coverage, add that as another pass-folder page instead of bloating the parity note.

## Binaryen Is Phase-Driven, Not Peephole-Driven

- The central lesson from the Binaryen comparison is that `RemoveUnusedBrs` is not a random pile of equivalent cleanups.
- Binaryen deliberately stages the work so that later patterns only run after earlier simplification has exposed direct, cheap shapes.
- That matters because many of Starshine's historical parity misses were real Binaryen patterns, but Starshine tried to discover them too early and too broadly.

## Phase 1: Flow Cleanup Fixpoint

- Binaryen starts with a repeated postwalk cleanup over flowing control.
- The mental model is:
  - identify terminal `br` / `return` traffic whose destination is already the surrounding continuation
  - strip those exits while preserving carried payload values
  - repeat until the enclosing structure has stabilized
- This first phase is what makes later block-local rewrites practical:
  - useless terminal exits disappear
  - branches become direct fallthroughs
  - typed wrappers shrink
  - neighboring branch structures become comparable instead of being hidden behind dead tails

## Phase 2: Loop And Block Reshaping

- Binaryen then performs loop cleanup, block sinking, and related branch-threading work.
- This matters for two reasons:
  - some branches only become removable once the pass has recognized that a loop or block wrapper is just carrying the same continuation back to its owner
  - some later optimizer patterns depend on the "interesting" branch living at the end of a simpler block body rather than inside an earlier wrapper
- The durable project rule is that loop/body reshaping is a distinct stage between raw tail cleanup and late-shape optimizer cleanup.

## Phase 3: Late Optimizer Cleanup

- Binaryen reserves a final optimizer block for the shapes that are cheapest after the earlier phases have already simplified the CFG.
- The local comparison note calls out these late families explicitly:
  - block-end `if br else br` cleanup to `br_if + fallthrough`
  - adjacent branch merging
  - `tablify`
  - `restructureIf`
  - `selectify`
  - local-set arm rewrites (`optimizeSetIf` in the comparison note's terminology)
- The practical implication is that not every remaining Starshine mismatch is a "tail branch removal" bug.
- Several late artifact gaps are really missing final-shape cleanup that Binaryen only attempts once the branch structure is already cheap and direct.

## What Binaryen Delays On Purpose

- Binaryen does not need to scan every nested region from the start.
- It relies on earlier phases to expose opportunities in direct block-local positions.
- That is the most important upstream lesson for Starshine:
  - late-shape cleanup is real and necessary
  - but discovering it through broad nested-region probing during the main walk is the wrong cost model

## Why This Matters For Starshine

- The archived comparison note already recorded the failed experiment:
  - a narrow Starshine analogue of Binaryen's `restructureIf` family did identify a real missing class
  - but the keepable version had not been found yet, because the attempted discovery path still cost too much on the artifact
- So this page is not just historical context.
- It is the reason the current pass folder keeps separating:
  - tail cleanup
  - branch/payload cleanup
  - returned-ladder HOT shapes
  - carried-guard/result-block cleanup
  - execution-model bailouts

## Binaryen-Shaped Questions To Ask On Every New Gap

- When a new mismatch appears, ask these in order:
  - Is this a genuine dead-tail cleanup opportunity?
  - Is it a loop/block reshaping opportunity that Binaryen only exposes after earlier cleanup?
  - Is it a late `restructureIf` / `selectify` / `tablify` family that Starshine is trying to discover too early?
  - Is the mismatch even in the pass, or is it lift/lower normalization noise around a function where RUB reports `changed=false`?

## Current Project Rule

- Keep using Binaryen's phase structure as the architectural oracle.
- Do not widen Starshine matchers just because one remaining artifact family looks reachable through a broader nested scan.
- If a new rewrite belongs to Binaryen's late optimizer shape, land it as a narrow final-shape cleanup with explicit guards, not as "search deeper everywhere".

## Sources

- Archived Binaryen comparison note: [`../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md`](../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md)
- Binaryen pathway note: [`../../../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`](../../../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md)
- Living no-DWARF pathway page: [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- Upstream source anchor: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedBrs.cpp>

