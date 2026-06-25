# Optimize-instructions OI-H multivalue argument call_ref boundary

## Question

Does Starshine support Binaryen's `version_130` localization for select-of-`ref.func` `call_ref` when the already-evaluated call arguments come from a multi-result producer?

## Binaryen evidence

Probe: `.tmp/oi-h-multivalue-arg-select-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-h-multivalue-arg-select-probe.wat -o -
```

Binaryen rewrites the probed shape by:

1. localizing the multi-result `call $pair` into a tuple scratch local,
2. extracting both lanes into scalar locals,
3. replacing select-of-`ref.func` `call_ref` with an `if` whose arms directly call `$a` and `$b` with the scalar locals.

This is broader than Starshine's current OI-H positive localization subset.

## Starshine boundary

`src/passes/optimize_instructions.mbt` currently localizes `call_ref` arguments only when each HOT argument child has exactly one result. That covers the already-committed single-result argument select and fallthrough-known target slices, but it does not prove a safe tuple scratch / scalar extraction reconstruction for a multi-result argument producer.

The new focused test `optimize-instructions intentionally keeps multi-result argument select call_ref boundary` builds the same shape through the core module API and asserts Starshine keeps `call_ref`, `select`, and `ref.func` rather than claiming Binaryen-style multivalue localization parity.

## Validation

Focused boundary evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*multi-result argument select call_ref*'
```

The test passed immediately as intentional boundary coverage. No red-first implementation failure was expected because this slice documents a source-backed unsupported proof boundary rather than changing behavior.

## Reopen criteria

Reopen this boundary when Starshine has a safe OI-local tuple scratch / scalar-lane localization helper for already-evaluated multi-result call arguments, or if a compare/replay mismatch proves this exact shape is release-critical enough to implement before broader OI-H closeout.
