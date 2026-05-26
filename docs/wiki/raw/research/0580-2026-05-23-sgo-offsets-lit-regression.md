# SGO offsets official lit regression

_Date:_ 2026-05-23
_Status:_ filed into living SGO docs/backlog

## Question

Land the best-ranked tiny source-alignment slice from [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md): an exact-ish regression for Binaryen v129 `simplify-globals-offsets.wast` without claiming broader `SimplifyGlobals.cpp` parity.

The target behavior is startup-only propagation into segment offsets:

- defined immutable `i32` globals used as active data offsets become constants,
- imported global offsets remain `global.get`,
- passive data segments are accepted and preserved as passive,
- defined immutable `i32` globals used as active elem offsets become constants,
- imported elem offsets remain `global.get`, and
- startup-only segment/global-initializer rewrites do not trigger the optimizing nested cleanup lane.

## Sources

- Official Binaryen v129 lit fixture: `.tmp/sgo-lit/simplify-globals-offsets.wast`.
- Local implementation/test anchor: [`src/passes/simplify_globals_optimizing_test.mbt`](../../../../src/passes/simplify_globals_optimizing_test.mbt).
- Prior ranking: [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md).

## Local change

Added `simplify-globals-optimizing follows Binaryen offsets lit for active segments` plus small test helpers for indexed data/elem offset inspection.

The fixture keeps the slice startup-only: it includes imported memory/table/global, a defined immutable `$defined`, a `$use-defined` global initializer alias, active data with imported and defined offsets, passive data, active elem with imported and defined offsets, and an exported empty function used by the elem segments. It intentionally avoids function-body reads so the trace can continue to assert no nested cleanup is triggered by the startup-only rewrites.

## Validation

- `moon test src/passes`: `1494/1494` passed.

The test passed immediately, so this is a guardrail/regression slice rather than a behavior implementation slice. No direct 10k SGO fuzz was run because no implementation behavior changed.

## Follow-up ranking

- Next lowest-risk source-alignment guardrail remains the exact `simplify-globals-prefer_earlier.wast` copy-chain shape from [`0579`](./0579-2026-05-23-sgo-remaining-lit-inventory.md).
- Startup-only nested GC and narrow GC/refinalization remain separate, higher-risk slices.
- Function-effects, sibling `propagate-globals-globally`, broad same-init expression matching, loops/control, trapping/effectful surfaces, and broad GC/refinalization remain deferred without focused oracle evidence.

## Non-claims

- This does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- This does not broaden the runtime trace, FlowScanner, same-init, GC/refinalization, or typed element item-expression policies.
- `[SGO]003` remains active/partial.
