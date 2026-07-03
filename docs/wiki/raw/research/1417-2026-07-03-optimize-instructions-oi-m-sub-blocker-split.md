# OptimizeInstructions OI-M sub-blocker split

_Date:_ 2026-07-03
_Status:_ ACCEL003 completed as a docs/schema split; OI-M remains active/P0 until residual sub-blockers are implemented or explicitly accepted with evidence-backed reopening criteria.

## Question

After arbitrary direct one-use selected-child arity was implemented, what concrete OI-M tuple/multivalue blockers remain, and what evidence should reopen or close each one?

## Source and implementation baseline

Source baseline:

- Binaryen `version_130` `OptimizeInstructions.cpp::visitTupleExtract` delegates selected tuple-lane scalarization and dropped-child handling through `getDroppedChildrenAndAppend`.
- The 2026-07-03 source audit in `docs/wiki/raw/research/1416-2026-07-03-optimize-instructions-oi-m-generalized-selected-child-localization.md` found no explicit selected-child arity cap in `visitTupleExtract` or `src/ir/drop.cpp::getDroppedChildrenAndAppend`.

Starshine baseline:

- `src/passes/optimize_instructions.mbt` now supports arbitrary positive scalar selected-child result arity for a direct one-use `TupleMake` under the documented safe preconditions.
- `src/passes/optimize_instructions_test.mbt` has reusable selected-child fixture helpers and helper-backed arity 2, 26, 27, and 32 positive coverage.
- Focused selected-child tests passed 30/30, focused tuple.extract tests passed 23/23, full `moon test` passed 7246/7246, and OI-M direct/grouped runtime-enabled compare lanes reported zero validation/generator/property/command/runtime failures while retaining raw mismatches as active parity evidence.

## Sub-blockers now recorded in the parity matrix

`docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json` now records six explicit OI-M sub-blockers on row `OI-M-tuple-multivalue-selected-lanes`.

### OI-M-SB001 — direct one-use selected-child arbitrary arity

Status: covered under preconditions.

Scope:

- direct `tuple.extract(tuple.make(...))` only;
- live one-use direct tuple producer;
- scalar selected-child result lanes;
- current single-result or otherwise safe non-selected sibling handling;
- recursive exclusion of control/branch/EH/nested-region lanes.

Reopening criteria:

- any positive direct one-use scalar selected-child arity fails to localize;
- validation or runtime evidence fails;
- effect/trap order changes;
- a non-selected sibling is incorrectly dropped;
- Binaryen source/probes reveal an actual arity or ordering constraint;
- fuzz produces a counterexample inside these preconditions.

### OI-M-SB002 — multi-result non-selected siblings

Status: active P0 mismatch needing implementation.

Why separate:

- Binaryen's dropped-child helper operates over children and effects, but Starshine's current safe localizer does not yet have a source-backed way to append/drop multiple non-selected sibling lanes while preserving ordering around the selected value.

Next evidence:

- Binaryen probes for pure, effectful, and trapping multi-result non-selected siblings on either side of the selected child;
- red-first Starshine tests that demonstrate the intended preservation/drop order;
- either a narrow implementation or a precise HOT representation blocker.

### OI-M-SB003 — multi-use and local-carried tuple producers

Status: active P0 mismatch needing implementation.

Why separate:

- The implemented slice requires a live one-use direct `TupleMake` so it does not duplicate producer effects, stale shared tuple users, or local-carried tuple state.
- Existing generated profile labels already exercise local-carried, local.tee-produced, helper-call-produced, select-produced, and randomized existing-producer tuple lanes, but grouped OI-M lanes still report raw mismatches.

Next evidence:

- one reduced Binaryen probe for a local-carried tuple value;
- one reduced Binaryen probe for a multi-use tuple producer;
- red-first Starshine tests for the chosen subset;
- a decision on whether implementation needs tuple-value dataflow analysis or a narrower direct-local rewrite.

### OI-M-SB004 — control/branch/EH siblings

Status: blocked surface until safe reconstruction is source-backed.

Why separate:

- The 2026-07-02 sibling-localization slice found a real safety issue: an unsupported control sibling could be deleted before the fail-closed guard landed.
- Starshine now excludes control/branch/EH/nested-region lanes in the direct localizer, but this is a safety boundary, not parity closure.

Next evidence:

- source audit and minimal probes for branch and EH sibling shapes;
- red-first tests for either a positive safe subset or continued fail-closed behavior;
- implementation only after labels, branch targets, exception edges, and result arity can be preserved.

### OI-M-SB005 — generalized tuple-scratch reconstruction/localization

Status: active P0 mismatch needing implementation.

Why separate:

- Binaryen-shaped tuple scratch/scalar temp localization extends beyond direct selected-child extraction into broader selected-lane, all-result, multiple-selected-lane, scratch-localized, and producer-wrapper shapes.
- Starshine currently has sampled evidence for scratch-localized selected-lane labels, but those remain raw mismatches and are not family closure.

Next evidence:

- choose one source-backed scratch reconstruction shape;
- add a red-first focused test and a small grouped OI-M runtime sweep;
- implement a reusable tuple-scratch helper or document the exact HOT representation blocker.

### OI-M-SB006 — fuzz/runtime residual classification

Status: active P0 tooling accelerator, tracked by ACCEL004.

Why separate:

- Recent direct/grouped OI-M lanes have zero failures and runtime equality for sampled exports, but every case still appears as a raw mismatch.
- Runtime-green output drift is supporting evidence only. It must not be auto-classified as semantic parity or used to close OI-M or neighboring OI-G/OI-I/OI-J/OI-K rows.

Next evidence:

- inspect `scripts/oi-parity-sweep.ts --summarize-existing` and `scripts/pass-fuzz-compare.ts` result summaries;
- extend existing tooling only if compared/normalized/cleanup/raw counts, failure classes, Binaryen cache counts, runtime counts/matrix, per-label profile counts, and the raw-mismatch caveat are missing.

## Backlog effect

`agent-todo.md` removes ACCEL003 because the OI-M row now contains the requested split, evidence references, known support gaps, next evidence, and reopening criteria.

Follow-up `docs/wiki/raw/research/1418-2026-07-03-optimize-instructions-oi-m-residual-summary-tooling.md` completed ACCEL004. No immediate OI-M acceleration blockers remain; continue ordinary OI-M implementation work against the sub-blockers in the parity matrix.

## Validation

Docs/schema-only slice:

- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json` should pass after this update.
- Moon tests are not required because no executable Moon sources or behavior changed.

## Closure guard

OI-M stays active/P0. The row can move out of active/P0 only when every sub-blocker is either implemented with red-first tests and focused/fuzz/runtime evidence or explicitly accepted with source-backed evidence and reopening criteria. Do not infer OI-G or OI-I/OI-J/OI-K closure from OI-M evidence.
