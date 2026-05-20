---
kind: research
status: current
last_reviewed: 2026-05-19
sources:
  - ./0571-2026-05-19-late-tail-five-pass-neighborhood-baseline.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/reorder-globals/index.md
  - ../../binaryen/passes/string-gathering/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/optimize_test.mbt
  - ../../../../src/passes/registry_test.mbt
related:
  - ./0549-2026-05-08-late-tail-triple-replay-for-reorder-globals-and-directize.md
---

# Public preset late-tail scheduling

## Question

After the direct five-pass late-tail neighborhood was accepted in [`0571`](./0571-2026-05-19-late-tail-five-pass-neighborhood-baseline.md), can public `optimize` and `shrink` presets schedule the accepted suffix?

## Change

Updated `src/passes/optimize.mbt` so both public preset expansions now append:

```text
simplify-globals-optimizing
-> remove-unused-module-elements
-> string-gathering
-> reorder-globals
-> directize
```

The registry preset entries and the runtime `optimize_preset_passes(...)` / `shrink_preset_passes(...)` helpers were updated together so help/inspection and actual execution agree.

## Tests

Added / updated focused preset tests:

- `src/passes/optimize_test.mbt`
  - `optimize and shrink presets schedule the accepted SGO late-tail neighborhood` locks the suffix order for both public presets.
  - The basic `optimize` smoke fixture now exports its function because the widened preset legitimately runs `remove-unused-module-elements` and may prune unrooted functions.
- `src/passes/registry_test.mbt`
  - `preset expansion stays on implemented active pass names` now expects the late-tail suffix in both preset arrays and still verifies that each scheduled pass is active, not boundary-only or removed.

TDD evidence: before implementation, the new suffix-order test failed with the old terminal `remove-unused-names` / function-phase suffix instead of `simplify-globals-optimizing`.

## Validation

Commands run:

```sh
moon test src/passes
moon test src/cmd
moon info
moon fmt
moon test
git diff --check
```

Results:

- `moon test src/passes`: `1261/1261` passed.
- `moon test src/cmd`: `132/132` passed.
- `moon test`: `3325/3325` passed.

No full debug-artifact `--optimize` self-compare was run in this commit because repo workflow asks for approval before running the full self-optimize optimize pipeline. The direct suffix evidence remains the accepted artifact and 10k ordered-neighborhood signoff from [`0571`](./0571-2026-05-19-late-tail-five-pass-neighborhood-baseline.md).

## Conclusion

The accepted SGO late-tail suffix is now publicly scheduled by both `optimize` and `shrink`. This is still an incremental preset widening, not a claim that Starshine's entire public preset is byte-for-byte identical to Binaryen's full no-DWARF default path.
