# SGO try_table select read-only-to-write

Date: 2026-05-24

## Scope

Continue `[SGO]003` by treating a no-catch `try_table` that wraps the candidate global read as transparent when the `try_table` result feeds a small pure `select` guard before the same global is written. This is another narrow `read-only-to-write` source-alignment slice, not a full `SimplifyGlobals.cpp` parity claim.

## Binaryen oracle probes

Focused probes used Binaryen v129 via:

```sh
wasm-opt --enable-exception-handling --simplify-globals-optimizing -S <fixture.wat> -o -
```

Observed positives:

- no-catch `select` with the `try_table` result as the condition, then same-global constant `global.set`: Binaryen made the global immutable and removed the fake `global.get` / `global.set` traffic;
- no-catch `select` with the `try_table` result as the first selected value, then same-global constant `global.set`: Binaryen made the global immutable and removed the traffic;
- no-catch `select` guard in the exact `if return; global.set` tail shape: Binaryen made the global immutable and removed the traffic.

Observed guardrail:

- the catch-bearing `try_table` `select` guard preserved mutable global traffic, matching the existing conservative catch-bearing policy.

## Starshine implementation

Implemented a narrow `try_table`-only select helper in `src/passes/simplify_globals_optimizing.mbt`:

- requires `@lib.TryTable(_, catches, @lib.Expr(body))` with `catches.length() == 0`;
- accepts pure-constant sibling operands around the `try_table` result for the three stack positions covered by the probes: select condition, first value, and second value;
- reuses the existing safe-body reader so only already-supported body flows are counted;
- supports both no-else same-global constant-set guards and exact `if return; set` / block-wrapped set tails;
- leaves catch-bearing `try_table` wrappers conservative.

Tests added in `src/passes/simplify_globals_optimizing_test.mbt`:

- `simplify-globals-optimizing treats transparent try_table select-condition guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table select-value guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table select-second-value guards as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table select if-return guards as read-only-to-write`
- `simplify-globals-optimizing keeps caught try_table select guards conservative`

The first TDD run failed the three no-catch positives because `$g` remained mutable; the source-backed second-value variant was added as coverage for the same implemented helper family. After implementation `moon test src/passes` passed.

## Non-claims

This does not add caught `try_table` handling, broader arbitrary `select` value-flow, trapping/effectful sibling operands, calls, arity-dependent operations, branches/throws beyond the exact probed `if return; set` tail, or broader `try_table` control-transfer reasoning.
