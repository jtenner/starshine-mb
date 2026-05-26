# SGO call summary prerequisite closeout

## Scope

Research/bookkeeping-only `[SGO]003E2` closeout for direct-call read/write summary implementation prerequisites in `simplify-globals-optimizing`.

This slice decides whether `[SGO]003E2` should remain an active behavior item now, or be converted into an explicit prerequisite because call-shaped read-only-to-write positives need more analysis than the current mutation-only runtime fact summary provides.

## Sources checked

- `docs/wiki/raw/research/0634-2026-05-25-sgo-function-effect-read-summary-study.md`
- `docs/wiki/raw/research/0635-2026-05-25-sgo-call-effect-boundary-study.md`
- Active backlog entry in `agent-todo.md`.

## Audit

The 0634/0635 studies already answered the important safety question:

- Starshine currently has a fixed-point direct-call summary for globals a callee may mutate, used by runtime fact invalidation.
- That mutation-only summary is not enough for read-only-to-write call transparency, because a callee read of the candidate global is observable and must block fake-read/fake-write removal.
- Binaryen-positive direct-call cases exist for no-read/no-write callees and wrong-global-read callees.
- Candidate-derived call operands and direct callee reads of the candidate global are hard negatives.
- Direct callee-write/no-remaining-read, imported-call, and indirect-call positives depend on broader whole-module no-read, fake-traffic, generated-effects, or target-visibility modeling, not a simple local call whitelist.

Therefore, implementing `[SGO]003E2` directly as matcher tolerance would be unsafe. The correct next unit is an analysis prerequisite: fixed-point per-global read/write summaries with conservative unknown-call handling.

## Decision

Close `[SGO]003E2` as deferred/prerequisite-only for now.

Do not implement call-shaped read-only-to-write positives opportunistically.

A future prerequisite slice should explicitly design and implement summaries with at least:

- `reads: Array[Bool]`;
- `mutates: Array[Bool]`;
- conservative all-read/all-write rows for imports, indirect calls, `call_ref`, dynamic `return_call`, escaping or otherwise unknown targets;
- direct-call transitive closure over both reads and writes;
- monotone fixed-point recursion/cycle handling.

Only after that prerequisite should a behavior slice add direct ordinary-call positives for candidate-clean operands where the transitive callee summary neither reads nor mutates the candidate global. The first behavior slice must also add negatives for candidate-derived operands, candidate-global reads, imported/indirect/ref calls, unknown cycles, and callee writes unless a separate whole-module no-read/fake-traffic proof exists.

Imported-call, indirect-call, and callee-write/no-remaining-read Binaryen positives remain deferred to generated-effects or whole-module modeling.

## Validation

- `git diff --check` — passed.

No Moon tests or direct SGO fuzz were required for this closeout because no code, matcher logic, parser behavior, registry, preset, or normative pass docs changed.

## Status

`[SGO]003E2` is complete as a deferred/prerequisite closeout. `[SGO]003` remains active/partial; this is not a full Binaryen `SimplifyGlobals.cpp` parity claim.
