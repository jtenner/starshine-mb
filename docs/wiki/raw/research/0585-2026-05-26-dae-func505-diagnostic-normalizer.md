# DAE Func505 diagnostic normalizer

Date: 2026-05-26

## Scope

This note closes the compare-tool follow-up chosen by `[DAE]006` after notes `0576` through `0584` reduced the saved Func505 body at `.tmp/dae-func505-bool-carrier-artifact`, `defined=505 abs=522`.

## Change

Added a diagnostic-only canonical-function fallback normalizer in `scripts/lib/self-optimize-compare-task.ts` for the inspected Func505 parser-loop family. The normalizer is marker-rich and requires the parser-loop allocation/setup constants, `Func4495` underscore check, `Func4490` digit conversion, `Func4211` error-construction markers, unsigned division/loads/stores, and the final result allocation marker before collapsing the body to `Func505ParserLoop`.

This does not affect raw wasm equality, normalized WAT text equality, Starshine pass behavior, or broad pass-fuzz comparison. It only applies after the self-optimize helper has already fallen back to canonical function pretty-printing for a differing function body.

## Test evidence

- Added `scripts/test/self-optimize-compare-dae-func505-normalizer.ts`, a fake-tool fixture that emits two compact Func505-like parser-loop bodies differing in the same classified representation families. Before the normalizer this fixture reports `canonicalFuncPrettyEqual: false`; after the normalizer it reports canonical fallback equality while preserving `normalizedWatTextEqual: false`.
- Ran:
  - `bun scripts/test/self-optimize-compare-dae-func505-normalizer.ts`
  - `bun scripts/test/self-optimize-compare-canonical-func-command.ts`
  - `bun scripts/test/self-optimize-compare-dropped-value-if-command.ts`

## Artifact replay status

A full both-canonical artifact replay was attempted with:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/dae-func505-normalizer-after --starshine-bin target/native/release/build/cmd/cmd.exe --canonicalize-binaryen-output --dae-optimizing
```

In this recovery run it timed out after 300 seconds before writing `result.json`, so this note does not claim the next artifact frontier. The durable completion is the narrow diagnostic normalizer plus fixture coverage; `[DAE]006` remains open for a future successful full artifact replay and next-frontier classification.

## Classification

Agent classification: the normalized Func505 family is representation-only compare-layer drift, backed by notes `0582`, `0583`, and `0584` for underscore guard polarity, overflow/temp polarity, and loop-carrier/control-local drift. The normalizer is intentionally scoped to the exact marker-rich parser-loop family so unrelated function bodies still surface as mismatches.
