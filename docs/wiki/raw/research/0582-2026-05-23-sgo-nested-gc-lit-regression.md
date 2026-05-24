# SGO nested GC official lit regression

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Land the next source-alignment slice from [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md) after the offsets ([`0580`](./0580-2026-05-23-sgo-offsets-lit-regression.md)) and prefer-earlier ([`0581`](./0581-2026-05-23-sgo-prefer-earlier-lit-regression.md)) regressions: a startup-only guardrail for Binaryen v129 `simplify-globals-nested.wast` without claiming broader `SimplifyGlobals.cpp` parity.

The target behavior is nested global-initializer propagation through a GC `struct.new`:

- defined immutable `$a` and `$b` are propagated into nested child operands of `$struct`'s initializer,
- the imported middle global `$no` remains a `global.get`, and
- startup-only global-initializer rewrites do not mark a function touched or trigger nested cleanup.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-nested.wast`.
- Local implementation/test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior ranking: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen nested GC initializer lit` next to the startup-offset and immutable copy-chain regressions.

The fixture is exact in intent but uses Starshine's parser-supported struct field spelling:

- initial attempt with `(type $struct (struct i32 i32 i32))` failed during WAT parsing,
- changing it to `(type $struct (struct (field i32) (field i32) (field i32)))` let the exact startup shape parse and pass.

The test asserts the `$struct` global initializer becomes:

1. `i32.const 42`,
2. imported `global.get 0`,
3. `i32.const 1337`,
4. `struct.new 0`.

It also asserts no `nested-cleanup` trace appears, preserving the startup-only boundary.

## Validation

- Initial `moon test src/passes`: failed because the compact official struct type spelling did not parse locally.
- Updated the type declaration to field-explicit spelling.
- Final `moon test src/passes`: `1496/1496` passed.

The corrected test passed without implementation changes, so this is a guardrail/regression slice rather than a behavior implementation slice. No direct 10k SGO fuzz was run because no implementation behavior changed.

## Follow-up ranking

- Narrow GC `ref.cast(ref.func-global)` refinalization plus less-refined negative remains the next plausible exact GC source-alignment candidate if parser/verifier support is smooth.
- Function-effects, sibling `propagate-globals-globally`, broad same-init expression matching, loops/control, trapping/effectful surfaces, GC object-identity `struct.new_default` duplication, and broad GC/refinalization remain deferred without focused oracle evidence.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden runtime trace, FlowScanner, same-init, GC/refinalization, object-identity duplication, or typed element item-expression policies.
- `[SGO]003` remains active/partial.
