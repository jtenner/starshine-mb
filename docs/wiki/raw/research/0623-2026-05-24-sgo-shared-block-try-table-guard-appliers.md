# SGO shared block/try_table guard appliers

Date: 2026-05-24

## Question

Can the read-only-to-write condition guard appliers shared by transparent blocks and no-catch `try_table` wrappers be structurally consolidated without changing the accepted `[SGO]003` behavior?

## Change

Refactor-only structural slice in `src/passes/simplify_globals_optimizing.mbt`:

- Added `sgo_block_or_no_catch_try_table_body` so external pure-condition matchers use one body extractor for plain `block` wrappers and no-catch `try_table` wrappers.
- Added shared body-level guard appliers for direct `if`/`global.set` and exact `if return; set` tails.
- Routed the four external pure-condition counters (`normal`, `normal if-return`, `reverse`, and `reverse if-return`) through the shared extractor and appliers.
- Reused the same shared body-level appliers from the existing no-catch `try_table` compare/select/ref.is_null-select families, replacing the previous try-table-specific duplicates.

No intentional behavior change: this preserves the already-probed block and no-catch `try_table` external-pure, compare, select, and `ref.is_null` select read-only-to-write subsets. Catch-bearing `try_table` wrappers remain excluded by the shared extractor.

## Validation

- `moon test src/passes`: 1590/1590 passed.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-block-try-table-shared-guard-10k-final`: 9975/10000 compared, 9975 normalized matches, 0 mismatches, 0 validation failures, 0 generator failures, 25 Binaryen/tool command failures.

## Remaining work

`[SGO]003` remains active/partial. This refactor does not claim full Binaryen `SimplifyGlobals.cpp` parity and does not broaden calls, caught `try_table`, trapping/effectful consumers, control-transfer, or same-init expression equivalence.
