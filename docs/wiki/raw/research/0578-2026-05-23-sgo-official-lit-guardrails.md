# SGO official lit guardrail regressions

_Date:_ 2026-05-23  
_Status:_ filed into living SGO docs/backlog

## Question

After the 0577 official-lit breadth inventory found no obvious low-risk uncovered behavior slice in Binaryen's `simplify-globals-read_only_to_write.wast` and `simplify-globals-non-init.wast`, add exact source-alignment guardrails for the highest-value lit shapes without claiming full `SimplifyGlobals.cpp` parity.

## Sources

Primary source inventory:

- [`0577`](./0577-2026-05-23-sgo-official-lit-breadth-inventory.md)

Official Binaryen v129 lit source shapes used from the locally fetched scratch copies:

- `.tmp/sgo-lit/simplify-globals-read_only_to_write.wast`
- `.tmp/sgo-lit/simplify-globals-non-init.wast`

Local test anchor:

- `src/passes/simplify_globals_optimizing_test.mbt`

## Added tests

Added three focused source-alignment regressions:

- `simplify-globals-optimizing removes read-only-to-write additional sets`
  - Mirrors the official `$additional-set` positive family: extra writes to the candidate global are removable when the only meaningful reads are fake read-only-to-write guards.
  - Starshine's normalized result is slightly cleaner than the Binaryen lit check for the standalone extra set body: after the global is made immutable, the dropped constant can collapse to `nop`. The guarded semantic property is that no `global.get` / `global.set` remains for the fake global state.
- `simplify-globals-optimizing keeps read-only-to-write body side effects`
  - Mirrors the official `$side-effects-in-body` negative family: body effects after the candidate same-global write keep the read-only-to-write guard conservative.
  - The test pins preservation of the candidate mutable global/read-write shape while allowing independent same-function runtime cleanup such as replacing `global.get $other` with the just-written literal.
- `simplify-globals-optimizing keeps imported initializer non-init writes`
  - Mirrors the imported-initializer/non-init-write negative family from `simplify-globals-non-init.wast`.
  - The test keeps an imported `global.get` initializer local-proven-unknown, preserves the mutable global, and preserves the non-init write and later reads after two SGO runs.

## Validation

TDD loop:

```sh
moon test src/passes
```

The first run failed only because the `$additional-set` regression over-specified Binaryen's raw `drop (i32.const 2)` shape while Starshine's cleanup produced a semantically equivalent `nop`. The test was tightened to assert the intended no-global-traffic property instead of raw WAT shape.

Final focused validation:

```sh
moon test src/passes
```

Result: `1493/1493` passed.

## Non-claims

- This is a guardrail/regression test slice, not a new implementation slice.
- It does not claim full Binaryen `SimplifyGlobals.cpp` parity.
- It keeps `[SGO]003` active/partial.
- Broad same-init expression matching, body-effect broadening, loop/control broadening, and effectful/trapping surfaces still require fresh focused Binaryen positives with paired negatives.
