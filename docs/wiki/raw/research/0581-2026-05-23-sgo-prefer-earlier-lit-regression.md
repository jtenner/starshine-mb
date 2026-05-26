# SGO prefer-earlier official lit regression

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Land the next low-risk source-alignment slice from [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md) after the offsets regression in [`0580`](./0580-2026-05-23-sgo-offsets-lit-regression.md): an exact-ish regression for Binaryen v129 `simplify-globals-prefer_earlier.wast` without claiming broader `SimplifyGlobals.cpp` parity.

The target behavior is immutable copy-chain canonicalization:

- imported immutable `$global1` is copied into `$global2`,
- `$global3` initially copies `$global2`,
- `$global4` initially copies `$global3`,
- after SGO, all later global initializers prefer the earliest equivalent global, `$global1`, and
- function-body reads of later copies are retargeted to `$global1`.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-prefer_earlier.wast`.
- Local implementation/test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior ranking: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen prefer-earlier copy-chain lit` next to the existing immutable copy-chain test.

The function-body portion is exact-ish rather than raw-lit-identical: the official lit uses dropped reads because plain `--simplify-globals` does not run Starshine's optimizing nested cleanup. In `simplify-globals-optimizing`, those dropped imported-global reads become removable cleanup debris. The local regression therefore uses an exported-result-shaped live arithmetic expression over the four reads, then asserts that no function-body reads of `$global2`, `$global3`, or `$global4` remain.

## Validation

- Initial `moon test src/passes` failed while the fixture used raw dropped reads: Starshine's optimizing nested cleanup collapsed the body to `nop(end)`, so the test over-specified a non-live raw shape rather than the intended prefer-earlier property.
- Updated the test to keep all reads live via an `i32.add` result expression.
- Final `moon test src/passes`: `1495/1495` passed.

The test passed after the fixture was corrected, so this is a guardrail/regression slice rather than a behavior implementation slice. No direct 10k SGO fuzz was run because no implementation behavior changed.

## Follow-up ranking

- Next candidate from [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md) is startup-only `simplify-globals-nested.wast` GC initializer propagation if the parser/verifier path supports the exact fixture.
- Narrow GC `ref.cast(ref.func-global)` refinalization plus less-refined negative remains a separate higher-risk candidate.
- Function-effects, sibling `propagate-globals-globally`, broad same-init expression matching, loops/control, trapping/effectful surfaces, and broad GC/refinalization remain deferred without focused oracle evidence.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden runtime trace, FlowScanner, same-init, GC/refinalization, or typed element item-expression policies.
- `[SGO]003` remains active/partial.
