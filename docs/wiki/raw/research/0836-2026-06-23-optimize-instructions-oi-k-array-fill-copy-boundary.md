# 0836 - optimize-instructions OI-K array.fill / array.copy fresh-array parity boundary

## Scope

Continue `[O4Z-AUDIT-OI-K]` with a boundary classification sub-slice: determine whether `array.fill` and `array.copy` over fresh one-use pure arrays are an `optimize-instructions` parity gap, and lock the conclusion with a test.

This slice classifies only:

- `array.fill` over a fresh one-use pure `array.new_fixed` / `array.new_default` producer with constant in-bounds `start` / `value` / `count`;
- `array.copy` between two fresh one-use pure `array.new_default` producers with constant in-bounds indices and count.

The conclusion is a parity boundary: these are **not** an `optimize-instructions` gap.

## Binaryen oracle

Probe files: `.tmp/oi-k-array-fill-probe.wat` and `.tmp/oi-k-array-copy-probe.wat`.

Commands:

```sh
wasm-opt .tmp/oi-k-array-fill-probe.wat --enable-gc --enable-reference-types -S --optimize-instructions -o -
wasm-opt .tmp/oi-k-array-fill-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
wasm-opt .tmp/oi-k-array-copy-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior: neither the direct `--optimize-instructions` lane nor the O4z-style `-O --optimize-instructions` lane folded any probed shape. Pure in-bounds `array.fill`, pure out-of-bounds `array.fill` (`0+3 > 2`), `array.fill` over `array.new_default` / `array.new` producers, effectful-value `array.fill`, and pure in-bounds/out-of-bounds `array.copy` between fresh arrays were all kept verbatim. In other words, fresh-array `array.fill` / `array.copy` removal is outside the Binaryen `optimize-instructions` contract.

## Starshine behavior

Starshine keeps these shapes unchanged through the `optimize-instructions` hot pipeline, matching Binaryen. This was confirmed by a direct-core boundary test that runs `optimize_instructions_test_run_module` (which invokes `run_hot_pipeline` with only `["optimize-instructions"]`) on fresh-array `array.fill` and `array.copy` fixtures and asserts the operations are still present afterward.

A test-indexing note for future slices: `optimize_instructions_test_run_module` fixtures with **no imported function** index local functions starting at `FuncIdx 0`, whereas the common fixtures that import an `m.effect` function index local functions starting at `FuncIdx 1`. An initial off-by-one in the boundary test falsely suggested a divergence; the corrected indices showed pure parity.

## Tests and validation

This is a coverage / boundary-only slice. Red-first positive implementation does not apply because the classified behavior (keeping `array.fill` / `array.copy`) is intentional correct parity, not a missing optimization. The boundary test is named and commented to say so.

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.fill and array.copy*'` passed `1/1`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `221/221`.
- `moon fmt` passed.
- `moon test src/passes` passed `2751/2751`.
- `git diff --check && git diff --cached --check` passed.
- The native `src/cmd` build, `moon info`, and direct compare smoke were not rerun because this slice changes no optimizer source (test + docs only); the binary is identical to the prior commit.

## Boundaries and conclusion

- `array.fill` and `array.copy` fresh-array removal is **not** a Binaryen `optimize-instructions` parity gap. Starshine keeping these operations is correct OI parity. Any future OI folding of these bulk array operations would need a fresh Binaryen comparison and a documented Starshine-win justification (for example, provably removing a dead in-bounds fill that cannot trap).
- Effectful-value localization for `array.fill` / `array.copy`, overlap-safe `array.copy` rewrites, shared/atomic array operations, and broader ordering rewrites remain open `[O4Z-AUDIT-OI-K]` / `[O4Z-AUDIT-OI-L]` work, but not as OI parity gaps against the current Binaryen `optimize-instructions` contract.
- The remaining open OI-K items are primarily blocked on safe localizing/HOT lowering (effectful sibling/value preservation) or HOT descriptor-operand support (descriptor default constructors), or are out of OI scope (shared/atomic).
