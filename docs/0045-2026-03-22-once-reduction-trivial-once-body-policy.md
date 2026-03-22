# OnceReduction Trivial Once-Body Policy

## Scope

Record the first-four-pass no-DWARF policy decision for the remaining focused
`OnceReduction` output diff against Binaryen: trivial once bodies where
Starshine drops a now-redundant `global.set once, 1` and Binaryen keeps it.

## Decision

Keep the smaller Starshine output.

For this shape, Starshine intentionally collapses the trivial once body to
`nop` instead of preserving Binaryen's retained redundant `global.set`.

## Why

- The rewrite is already covered by the typed `OnceReduction` whitebox suite.
- The direct comparison in
  [`docs/0016-2026-03-22-no-dwarf-four-pass-comparison.md`](/home/jtenner/Projects/starshine-mb/docs/0016-2026-03-22-no-dwarf-four-pass-comparison.md)
  shows the Starshine output is smaller on the focused fixtures.
- Preserving Binaryen's exact text shape here would add output parity but no
  demonstrated size or correctness win.

## Validation

- Added generated-pipeline coverage in
  [`src/cmd/generated_pipeline_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/generated_pipeline_wbtest.mbt)
  for the raw-input trivial once-body case under the first four passes.
- Verified with
  `moon test src/cmd/generated_pipeline_wbtest.mbt -F '*smaller trivial once body*'`.

## Follow-Up

- Keep benchmarking `MemoryPacking` profitability on broader corpora.
- Revisit this policy only if a downstream consumer needs closer Binaryen text
  parity than smaller output.
