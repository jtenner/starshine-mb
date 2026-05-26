# SGO call/effect parity closeout

Date: 2026-05-25

Slice: `[SGO]003D` evidence-gated closeout

## Scope

Close the active `[SGO]003D` call, generated-effects, and function-effect parity queue as evidence-gated for v0.1.0 full-SGO backlog hygiene. This is a docs/backlog closeout only: it does not change optimizer behavior, and it does not claim complete Binaryen `SimplifyGlobals.cpp` parity for calls.

## Evidence reviewed

- [`0591`](./0591-2026-05-23-sgo-function-effects-call-negatives.md), [`0592`](./0592-2026-05-23-sgo-function-effects-wrong-global-negative.md), and [`0593`](./0593-2026-05-23-sgo-function-effects-generated-effects-boundary.md): existing guardrails for function-effect calls and generated-effects boundaries.
- [`0598`](./0598-2026-05-24-sgo-direct-function-effects-runtime-facts.md) and [`0599`](./0599-2026-05-24-sgo-block-carried-function-effects.md): runtime trace propagation over ordinary direct calls whose summaries do not mutate the tracked global.
- [`0634`](./0634-2026-05-25-sgo-function-effect-read-summary-study.md), [`0635`](./0635-2026-05-25-sgo-call-effect-boundary-study.md), and [`0660`](./0660-2026-05-25-sgo-call-summary-prerequisite-closeout.md): source-backed call/effect study and prerequisite closeout.
- [`0671`](./0671-2026-05-25-sgo-direct-call-read-summary.md): fixed-point per-global read/write summaries and the first direct-call read-only-to-write implementation.
- [`0672`](./0672-2026-05-25-sgo-direct-call-const-arg-guardrails.md): constant-argument direct-call positives and candidate-derived/candidate-reading negatives.
- [`0673`](./0673-2026-05-25-sgo003-call-breadth-closeout.md): previous visible-call-queue closeout before the full-parity backlog was reactivated.
- `src/passes/simplify_globals_optimizing.mbt`: current summaries (`SgoFunctionGlobalEffects`), direct-call independence checks, and runtime call-effect invalidation.
- `src/passes/simplify_globals_optimizing_test.mbt`: focused call/effect positives and guardrail negatives.
- A spot Binaryen/Starshine probe in `.tmp/sgo-probe/direct-call-void-prefix-postread.wat` confirmed that a zero-result independent call before a later candidate read is not an immediate behavior gap: Binaryen and Starshine normalized output matched under direct `--simplify-globals-optimizing`.

## Current accepted surface

The current implementation is adequate for the evidenced v0.1.0 call/effect surface:

- Starshine computes fixed-point per-function summaries for globals read and mutated by ordinary direct calls.
- Runtime constant-global propagation preserves facts across ordinary direct calls only for globals the callee summary proves it does not mutate, and clears facts conservatively for unknown/dynamic calls.
- Read-only-to-write matching admits direct calls when the callee summary proves it neither reads nor mutates the candidate global and call operands are clean / candidate-independent for the implemented grammar.
- Focused tests pin zero-param one-result calls, constant-argument direct calls, wrong-global reads, candidate-reading callees, imported calls, and candidate-derived operands.
- Imported calls, indirect calls, `call_ref`, return-call variants, generated-effects metadata, target-set modeling, and broader placements remain conservative unless future evidence supplies a precise Binaryen-positive grammar.

## Closeout decision

Close `[SGO]003D` as **accepted / evidence-gated** rather than keeping it as an open implementation queue. The known unsupported call/effect families are not actionable without fresh Binaryen-positive fixtures and paired guardrails:

- imported-call positives require a concrete visibility/effects contract;
- indirect-call and `call_ref` positives require target-set or type/visibility modeling plus dynamic-target negatives;
- return-call variants require control-flow and result-use guardrails;
- generated-effects requires a local source-backed contract before Starshine should distinguish it from unknown effects;
- broader call operands or placements require one exact positive at a time with candidate-derived, trapping/effectful, multi-read, and non-branch-consumer negatives.

Future work should reopen a new child slice only with exact Binaryen-positive evidence, focused tests-first scope, direct SGO fuzz for any behavior change, and parity-matrix/backlog updates.

## Validation

No optimizer behavior, tests, registry entries, dispatcher code, or public API changed in this closeout, so Moon and fuzz validation were not required. The latest behavior-bearing validation remains:

- [`0671`](./0671-2026-05-25-sgo-direct-call-read-summary.md): direct SGO fuzz `.tmp/pass-fuzz-sgo-direct-call-read-summary-10k` compared `9975/10000`, with `9975` normalized matches, `0` mismatches, `0` Starshine validation failures, and `25` Binaryen/tool command failures.
- [`0672`](./0672-2026-05-25-sgo-direct-call-const-arg-guardrails.md): `moon info`, `moon fmt`, `moon test src/passes` (`1608/1608`), and full `moon test` (`3684/3684`) passed.

## Status

`[SGO]003D` is accepted / evidence-gated for the current v0.1.0 SGO backlog. Remaining active full-parity work continues in other explicit child slices (`[SGO]003E`, `[SGO]003F`, `[SGO]003G`, `[SGO]003H`, `[SGO]004`, and `[SGO]005`) rather than as implicit call/effect breadth.
