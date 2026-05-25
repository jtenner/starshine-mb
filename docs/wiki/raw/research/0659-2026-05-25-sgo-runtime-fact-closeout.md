# SGO runtime fact propagation closeout

## Scope

Research/bookkeeping-only `[SGO]003H` closeout for runtime trace local fact propagation beyond the official dominance lit coverage in `simplify-globals-optimizing`.

This slice decides whether to keep an open generic runtime propagation bucket after the dominance, call-filter, else-local, loop-local, and `try_table`-local slices landed.

## Sources checked

- `docs/wiki/raw/research/0575-2026-05-23-sgo-dominance-lit-regression.md`
- `docs/wiki/raw/research/0590-2026-05-23-sgo-dominance-post-call-else-guardrails.md`
- `docs/wiki/raw/research/0598-2026-05-24-sgo-direct-call-runtime-facts.md`
- `docs/wiki/raw/research/0600-2026-05-24-sgo-else-local-runtime-facts.md`
- `docs/wiki/raw/research/0601-2026-05-24-sgo-loop-local-runtime-facts.md`
- `docs/wiki/raw/research/0602-2026-05-24-sgo-try-table-local-runtime-facts.md`
- `docs/wiki/raw/research/0633-2026-05-25-sgo-next-slice-probe-inventory-refresh.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/parity-matrix.md`
- Active backlog entry in `agent-todo.md`.

## Audit

The current runtime fact model is no longer just the original official dominance-lit subset. Source-backed slices now cover:

- straight-line and top-level-noise constant write/read traces;
- adjacent and nested plain-block runtime facts;
- official dominance-lit pre-call then-body reads, with post-call and else-arm reads preserved;
- direct-call mutation-filtered runtime facts for globals a direct callee does not syntactically/transitively set;
- else-local facts created and consumed inside the same else arm, without importing pre-`if` facts;
- loop-local same-body facts, without trusting pre-loop facts or exporting loop facts through backedges/joins;
- `try_table` body-local facts, with facts cleared at the post-`try_table` join.

The important conservative boundaries remain intentional:

- no incoming facts into else arms;
- no fact joins after `if`;
- no pre-loop facts into loops;
- no loop facts out or across backedges;
- no post-`try_table` fact joins;
- imported calls, indirect calls, `call_ref`, dynamic `return_call`, branches, returns, throws, and unknown call/effect boundaries remain conservative unless a dedicated future slice redesigns exactly one boundary.

The remaining possible broadening is therefore not a single hidden backlog item. It would require a fresh dominance/invalidation contract for each exact region shape.

## Decision

Close `[SGO]003H` now instead of keeping a generic runtime propagation bucket open.

Future runtime propagation work must be filed as a new explicit child slice. Each such slice must include:

1. a written dominance/invalidation contract for the exact region;
2. one Binaryen-positive or source-backed rewritten-read fixture;
3. one value-observable preserved-read negative for the relevant barrier or join;
4. direct SGO fuzz if behavior changes.

Call read/write summaries remain separate under `[SGO]003E2`; read-only-to-write call evidence must not be reused as runtime fact evidence.

## Validation

- `git diff --check` — passed.

No Moon tests or direct SGO fuzz were required for this closeout because no code, matcher logic, parser behavior, registry, preset, or normative pass docs changed.

## Status

`[SGO]003H` is complete as a runtime-fact closeout. `[SGO]003` remains active/partial; this is not a full Binaryen `SimplifyGlobals.cpp` parity claim.
