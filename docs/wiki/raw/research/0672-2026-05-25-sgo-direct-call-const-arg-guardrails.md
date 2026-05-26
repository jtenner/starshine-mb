# SGO direct-call constant-argument guardrails

Date: 2026-05-25

Slice: `[SGO]003E2` Direct-Call Read/Write Summary Implementation follow-up

## Scope

Add focused guardrails for direct ordinary calls with constant operands inside `read-only-to-write` conditions after the 0671 read/write summary implementation. This is a test/source-alignment slice, not a matcher broadening: the existing FlowScanner/direct-call path already accepts the safe constant-argument positive and preserves the candidate-derived operand negative.

## Binaryen probe

A reduced probe with a private mutable `$g`, a direct `$inc (param i32) (result i32)` that does not read or write `$g`, and an outer guard shaped as `(i32.add (call $inc (i32.const 4)) (global.get $g))` was checked with:

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-call-param-probe.wat -o -
```

Binaryen made `$g` immutable, removed the fake global read/write guard, and preserved the direct call with its constant operand. This is a source-backed positive for clean constant call operands when the callee summary is independent of the candidate global.

## Tests

Added three focused tests in `src/passes/simplify_globals_optimizing_test.mbt`:

- positive: a direct one-param/one-result call with an `i32.const` operand is preserved while the candidate global guard is removed;
- negative: a direct call whose operand is derived from the candidate global remains conservative when a later candidate read participates in the same outer guard;
- negative: a direct one-param/one-result call with a constant operand remains conservative when the callee reads the candidate global.

The pre-existing candidate-derived direct-call operand test still covers the simpler call-as-condition negative.

## Validation

Commands run:

```sh
moon info
moon fmt
moon test src/passes
moon fmt
moon test src/passes
moon test
```

Results:

- `moon info`: finished with four pre-existing DAE unused-value warnings.
- `moon fmt`: finished.
- `moon test src/passes`: passed, `1608/1608` tests.
- `moon test`: passed, `3684/3684` tests.

## Status

This closes the constant-argument direct-call guardrail follow-up under `[SGO]003E2`. No optimizer behavior changed and no full call-shaped `SimplifyGlobals.cpp` parity is claimed. Deferred call breadth remains: callee-write/no-remaining-read positives, imported-call positives, indirect-call and `call_ref` positives, generated-effects/visibility modeling, richer non-constant call operands, and broader call placements.
