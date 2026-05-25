# SGO003 call breadth closeout

Date: 2026-05-25

Slice: `[SGO]003` / `[SGO]003E2` evidence-gated closeout

## Scope

Close the currently enumerated active SGO breadth work after the direct-call read/write summary implementation and constant-argument guardrails. This is docs/backlog closeout only: it does not claim full Binaryen `SimplifyGlobals.cpp` parity, and it does not change optimizer behavior.

## Evidence reviewed

- [`0573`](./0573-2026-05-19-sgo-v010-signoff.md): v0.1.0 supported-surface signoff for direct `simplify-globals-optimizing`, nested runtime, and late-tail scheduling.
- [`0633`](./0633-2026-05-25-sgo-next-slice-probe-inventory-refresh.md): the active post-signoff probe queue that ranked wrapper guardrails, loop boundaries, and call-effect modeling.
- [`0634`](./0634-2026-05-25-sgo-function-effect-read-summary-study.md), [`0635`](./0635-2026-05-25-sgo-call-effect-boundary-study.md), and [`0660`](./0660-2026-05-25-sgo-call-summary-prerequisite-closeout.md): the source-backed call-summary prerequisite and boundaries.
- [`0671`](./0671-2026-05-25-sgo-direct-call-read-summary.md): fixed-point per-global read/write summaries and the first behavior-bearing direct ordinary call subset.
- [`0672`](./0672-2026-05-25-sgo-direct-call-const-arg-guardrails.md): constant-argument direct-call guardrails showing the current matcher already accepts clean independent constant operands and preserves candidate-derived/candidate-reading cases.
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md`: the living family matrix and explicit out-of-scope breadth.
- `agent-todo.md`: active backlog state before this closeout.

## Closeout decision

The visible `[SGO]003E2` behavior-ready call-summary slice is complete for the bounded direct-call surface:

- Starshine has fixed-point summaries for per-global reads and writes.
- Ordinary direct calls can participate in read-only-to-write guards when their transitive summary proves they neither read nor mutate the candidate global.
- Zero-param and constant-argument direct-call positives are pinned.
- Candidate-derived operands, candidate-reading callees, imported calls, indirect calls, `call_ref`, and unknown/dynamic effects remain conservative.

The remaining named call breadth is evidence-gated rather than active:

- **Callee-write/no-remaining-read positives** still need an exact Binaryen-positive reduced fixture and a proof that Starshine can preserve value-observable writes while removing only fake global traffic.
- **Imported-call positives** need visibility/modeling evidence; imported calls remain all-read/all-write by default.
- **Indirect calls and `call_ref` positives** need target-set or type/visibility modeling plus paired dynamic-target negatives.
- **Generated-effects / visibility modeling** needs a concrete source-backed contract before summaries should distinguish it from unknown effects.
- **Richer non-constant call operands and broader call placements** need one exact positive grammar at a time, with candidate-derived, trapping/effectful, multi-read, and non-branch-consumer guardrails.

The parent `[SGO]003` breadth coordination item is also no longer an active cron-sized implementation queue. The supported v0.1.0 surface remains signed off, many v0.1.1 guardrail/breadth slices are recorded, and the known incomplete families are either implemented partially by design or require fresh evidence before behavior changes. Future SGO work should be filed as a new explicit child slice with Binaryen-positive evidence, tests-first scope, paired negatives, direct SGO fuzz for behavior changes, and docs/backlog updates.

## Validation

No optimizer behavior, tests, registry entries, dispatcher code, or public API changed in this closeout. No Moon or fuzz validation was required for the docs/backlog-only update. The latest behavior-bearing validation remains:

- [`0671`](./0671-2026-05-25-sgo-direct-call-read-summary.md): direct SGO fuzz `.tmp/pass-fuzz-sgo-direct-call-read-summary-10k` compared `9975/10000` with `9975` normalized matches, `0` mismatches, `0` validation failures, and `25` Binaryen/tool command failures.
- [`0672`](./0672-2026-05-25-sgo-direct-call-const-arg-guardrails.md): `moon info`, `moon fmt`, `moon test src/passes` (`1608/1608`), and full `moon test` (`3684/3684`) passed.

## Status

Close `[SGO]003E2` and the currently enumerated `[SGO]003` active queue as evidence-gated. This is not a full `SimplifyGlobals.cpp` parity claim; it is a backlog hygiene decision that prevents implicit broad work from staying active without a concrete source-backed next slice.
