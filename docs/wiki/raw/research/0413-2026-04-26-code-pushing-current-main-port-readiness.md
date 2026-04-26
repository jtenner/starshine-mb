---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../binaryen/2026-04-26-code-pushing-current-main-port-readiness.md
  - ../../../binaryen/passes/code-pushing/index.md
  - ../../../binaryen/passes/code-pushing/binaryen-strategy.md
  - ../../../binaryen/passes/code-pushing/starshine-strategy.md
---

# `code-pushing` Current-Main Source Correction And Port Readiness

## Question

Does the existing `code-pushing` dossier still teach the right upstream Binaryen strategy, and what should future Starshine parity work do next?

## Finding

The dossier needed another correction. The 2026-04-25 text said `Pusher`, segment selection, and local profitability-style movement were stale or unsupported. The official Binaryen `version_129` and current-main owner file checked on 2026-04-26 does use a `Pusher`-centered segment algorithm.

The correct Binaryen mental model is:

1. run a function-local `LocalAnalyzer` that marks locals with one write and no pre-set read as SFA;
2. scan block roots for a segment from first pushable SFA `local.set` to a later push point;
3. admit only roots whose value effects are removable and whose local gets are accounted for;
4. move eligible sets before/into push points when cumulative effects do not invalidate the moved value;
5. handle `if` specially by sinking into the only arm that reads the local, with an important post-if-read allowance when the opposite arm is unreachable;
6. rely on later optimizer cycles for deeper recursive opportunities.

Starshine remains narrower: it only handles const-like `local.set` sinking into one consuming `if` arm plus a local dead-block flattening helper.

## Durable updates made

- Added a raw primary-source manifest: `docs/wiki/raw/binaryen/2026-04-26-code-pushing-current-main-port-readiness.md`.
- Added `docs/wiki/binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md` as the first-slice / validation bridge.
- Refreshed the `code-pushing` overview, Binaryen strategy, implementation/test-map, movement-boundary, WAT-shape, and Starshine strategy pages to supersede the 2026-04-25 miscorrection while preserving the valid local-status material.
- Updated the main wiki index, pass index, tracker, and log.

## Starshine first-slice recommendation

Do not jump directly to broad Binaryen parity. The safe next implementation slice is a no-rewrite analyzer/debug slice or a focused `LocalAnalyzer` analogue that can classify candidate `local.set` roots and explain why they are or are not pushable. Only after that should Starshine widen beyond const-like values toward SFA/effect-checked segment motion.

## Remaining uncertainty

The official C++ source renders as very long lines in the raw fetch used by the agent, so exact line anchors are intentionally not treated as stable evidence in the new pages. The pages cite official file URLs and class/function names instead.
