# SGO direct function-effects runtime facts

_Date:_ 2026-05-24  
_Status:_ filed into living SGO docs/backlog

## Question

Can Starshine move beyond the previous direct-call barrier and match the first Binaryen v129 `simplify-globals_func-effects.wast` positive in direct `simplify-globals-optimizing`, while preserving imported/unknown-call conservatism and the earlier read-only-to-write call negatives?

## Sources

- Binaryen v129 lit source: `.tmp/sgo-lit/simplify-globals_func-effects.wast`
- Implementation: `src/passes/simplify_globals_optimizing.mbt`
- Tests: `src/passes/simplify_globals_optimizing_test.mbt`
- Prior guardrails:
  - [`0591`](./0591-2026-05-23-sgo-function-effects-call-negatives.md)
  - [`0592`](./0592-2026-05-23-sgo-function-effects-wrong-global-negative.md)
  - [`0593`](./0593-2026-05-23-sgo-function-effects-generated-effects-boundary.md)

## Result

Implemented a narrow module-local function global-effects summary for runtime trace propagation:

- imported functions are treated as mutating every global,
- defined functions record all syntactic `global.set`s in nested bodies,
- direct `call` / `return_call` edges are unioned to a fixed point so transitive direct callees are included,
- indirect/reference calls and return-call variants through dynamic targets conservatively mark all globals as mutable by the call,
- runtime trace propagation across an ordinary direct `call` now clears only facts for globals the callee may mutate.

This is intentionally narrower than a full public `--generate-global-effects` pass. It feeds only the existing SGO runtime trace rewrite and does not make calls count as syntactic local read-only-to-write events.

## Tests

Changed the previous generated-effects boundary guardrail into `simplify-globals-optimizing uses direct function effects across safe calls`:

- `$set` mutates `$A`,
- `$test` writes `$A` and `$C`, reads `$A/$B/$C`, calls `$set`, then reads `$A/$B/$C` again,
- Starshine now preserves the post-call `$A` read but rewrites `$B` and `$C` to constants across the call, matching the lit intent for globals unaffected by the callee.

Updated old blanket call-barrier tests so they continue to pin imported/unknown-call conservatism:

- `simplify-globals-optimizing stops runtime global propagation at imported calls`,
- `simplify-globals-optimizing clears imported and exported runtime facts across calls` now calls an imported `$unknown` function.

The existing 0591/0592 read-only-to-write call negatives remain green, which keeps call expressions from being miscounted as local syntactic global reads/writes.

## Validation

- TDD failure before implementation: `moon test src/passes` failed the generated-effects positive because `$C` remained a post-call `global.get`.
- Focused validation after implementation: `moon test src/passes` passed (`1516/1516`).
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-function-effects-10k` reported `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.
- Quick gate: `moon info && moon fmt && moon test` passed (`3592/3592` tests; existing DAE/pass-manager unused warnings only).

## Non-claims

- This does not implement a standalone `generate-global-effects` pass.
- This does not weaken imported, indirect, `call_ref`, or dynamic return-call barriers.
- This does not make calls participate in read-only-to-write counting.
- This does not claim full Binaryen `SimplifyGlobals.cpp` parity; `[SGO]003` remains active/partial.
