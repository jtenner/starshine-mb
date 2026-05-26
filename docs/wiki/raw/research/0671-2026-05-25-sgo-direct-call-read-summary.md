# SGO direct-call read summary implementation

Date: 2026-05-25

Slice: `[SGO]003E2` Direct-Call Read/Write Summary Implementation

## Scope

Implement the first behavior-bearing call-shaped `read-only-to-write` subset requested after the 0634/0635 studies. This is not full Binaryen `SimplifyGlobals.cpp` parity: it only admits direct ordinary calls whose summary proves independence from the candidate global.

## Source-backed target

The source/probe basis remains:

- [`0634`](./0634-2026-05-25-sgo-function-effect-read-summary-study.md): direct no-read/no-write calls in a read-only-to-write condition are Binaryen-positive, while callees that read the candidate global are a hard negative.
- [`0635`](./0635-2026-05-25-sgo-call-effect-boundary-study.md): wrong-global reads can be independent for the candidate global, but imported/indirect/generated-effects positives need separate modeling.
- [`0660`](./0660-2026-05-25-sgo-call-summary-prerequisite-closeout.md): the required prerequisite is fixed-point per-global `reads` plus `mutates` summaries with conservative unknown-call handling.

## Implementation

Changed `src/passes/simplify_globals_optimizing.mbt`:

- Extended `SgoFunctionGlobalEffects` from write-only summaries to fixed-point `reads` plus `mutates` arrays.
- Kept imported functions conservative by marking them all-read and all-write.
- Kept dynamic/reference calls conservative by marking the containing summary all-read and all-write.
- Propagated direct-call reads and writes through the existing monotone fixed point.
- Recorded direct function arities from type/import/function sections.
- Added a narrow syntactic `read-only-to-write` call matcher: a direct call may participate in a binary condition guard only when it has zero parameters, one result, and its transitive summary neither reads nor mutates the candidate global.

## Tests

Added focused tests in `src/passes/simplify_globals_optimizing_test.mbt` for:

- direct no-read/no-write call positive,
- direct wrong-global-read call positive,
- direct callee candidate-read negative,
- imported call negative,
- candidate-derived direct-call operand negative.

## Validation

Commands run:

```sh
moon test src/passes
bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-direct-call-read-summary-10k
moon fmt
moon test src/passes
```

Results:

- `moon test src/passes`: passed, `1605/1605` tests.
- Direct SGO compare fuzz: wrote `.tmp/pass-fuzz-sgo-direct-call-read-summary-10k`, compared `9975/10000`, normalized matches `9975`, validation failures `0`, generator failures `0`, command failures `25`, mismatches `0`.
- `moon fmt`: finished.
- Final `moon test src/passes`: passed, `1605/1605` tests.

## Remaining boundaries

Still deferred and not claimed by this slice:

- callee-write/no-remaining-read positives,
- imported-call positives,
- indirect-call and `call_ref` positives,
- `return_call`/tail-call surfaces,
- generated-effects and target-visibility modeling,
- richer arities or call placements beyond the zero-param/one-result binary-guard subset.

`[SGO]003` remains active/partial.
