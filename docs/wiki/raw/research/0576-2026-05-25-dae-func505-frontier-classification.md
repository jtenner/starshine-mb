---
kind: research
status: working
date: 2026-05-25
sources:
  - ../../binaryen/passes/dae-optimizing/starshine-strategy.md
  - ../../../../agent-todo.md
  - ../../../../.tmp/dae-func504-tail-control-artifact/result.json
  - ../../../../.tmp/dae-func504-tail-control-artifact/func-defined505-abs522.binaryen.wat
  - ../../../../.tmp/dae-func504-tail-control-artifact/func-defined505-abs522.starshine.wat
---

# DAE Func505 both-canonical frontier classification

## Question

Classify the current `[DAE]006` both-canonical diagnostic frontier at `.tmp/dae-func504-tail-control-artifact`, `defined=505 abs=522`, after the Func504 tail-control normalizer advanced the previous frontier.

## Evidence inspected

- `.tmp/dae-func504-tail-control-artifact/result.json` reports `canonicalizeBinaryenOutput: true`, `normalizedWatTextEqual: false`, `canonicalFuncPrettyEqual: false`, and first difference `defined=505 abs=522`.
- The same artifact reports pass-local timing outside the target: Starshine `2749.652ms` versus Binaryen `896.944ms`.
- The extracted pretty bodies and WAT diff show Func505 remains signature-equivalent: one `i32` parameter and one `i32` result on both sides.
- The WAT diff is much broader than the recently normalized Func503/Func504 compare-layer wrappers: Starshine declares many extra locals, keeps repeated `i32.const 0; drop` debris, spills allocator and loop-carrier values into high temporary locals, and uses inverted/pulled-apart loop and post-loop condition shapes.
- The loop body differs around the digit/error guard and parse-accumulation path. Binaryen keeps a compact induction local and direct unsigned comparisons; Starshine prints an expanded shape with `local.tee` carrier temps, a value-producing `if` for the lower-bound branch, and a later high-bound comparison from a separate temp. The inspected text is not narrow enough to justify another diagnostic-only canonical normalizer.

## Classification

Agent classification: **unknown/risky current DAE output-shape frontier**, not a safe compare-layer-only normalizer candidate yet.

Rationale:

- The function signatures already match, so this is not an immediate selected result or selected exact-literal boundary gap.
- The diff preserves the broad allocation/call/update skeleton, and the artifact remains wasm-valid, but the live loop condition and post-loop branch shapes are semantically meaningful enough that normalizing them away would require a focused proof or a reduced fixture.
- Unlike the prior Func504 tail-control family, this frontier is not a small unreachable-allocation or branch-wrapper residue after already-matching visible order; it includes loop induction, parsed-character predicates, local-carrier reuse, and accumulator bounds checks.
- Therefore, do **not** add a canonical-function normalizer for Func505 from the current artifact alone.

## Suggested next subtasks

1. Reduce Func505 into a focused WAT/Moon fixture before changing pass logic. Keep the fixture close to the observed loop-carrier and digit/error branch shape, not the whole artifact function.
2. Determine whether the leading difference is produced by DAE's raw cleanup/local-copy cleanup, the touched nested cleanup scheduler, or HOT lowering after DAE rewrites. A useful first split is to replay the artifact with DAE tracing and compare before/after nested cleanup if the harness exposes intermediate output.
3. If a reduced fixture proves semantic-equivalent local/control cleanup, implement a pass-side cleanup with TDD rather than a diagnostic normalizer. The likely shape is a selected/touched loop-carrier and local-copy cleanup for Func505-like parser loops.
4. If the reduced fixture exposes a true condition/local-carrier mismatch, add the smallest focused regression and repair the pass before advancing the both-canonical frontier.
5. Re-run `.tmp/dae-func504-tail-control-artifact` or a successor both-canonical artifact and record validation plus pass-local timing; keep `[DAE]011` visible because the current artifact remains over the 2x target.

## Outcome for this recovery slice

This slice completed classification only. No pass behavior changed and no compare-tool normalizer was added.
