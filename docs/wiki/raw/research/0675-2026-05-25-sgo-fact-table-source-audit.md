# SGO fact-table source audit

Date: 2026-05-25

## Question

For `[SGO]003A`, does Starshine's `simplify-globals-optimizing` fact collection have a single enough source-shaped fact row to support the remaining full Binaryen `SimplifyGlobals.cpp` parity work?

## Source audit

Reviewed Binaryen `version_129` primary sources fetched into `.tmp/binaryen/` for this run:

- `src/passes/SimplifyGlobals.cpp`
- `src/passes/pass.cpp`

A same-run refresh of current `main` `SimplifyGlobals.cpp` found only the already-known comment spelling fixes (`noticeeable` -> `noticeable`, `anythng` -> `anything`), not semantic SGO drift.

Binaryen's source-shaped `GlobalInfo` tracks these module-wide facts per global:

- imported and exported observability;
- total writes and reads;
- whether any non-init write exists;
- how many reads are classified as `readOnlyToWrite`;
- the optimizing variant's nested cleanup trigger is tied to actual code replacements, not startup-only rewrites.

The scanner also runs across function bodies and module code. The practical Starshine equivalent needs to keep uses in function bodies, global initializers, table initializers, active data offsets, active element offsets, and element item expressions distinguishable enough that later same-init, read-only-to-write, startup, and element/refinalization slices do not add more isolated ad hoc counters.

## Change

Added a whitebox fact-table test file, `src/passes/simplify_globals_optimizing_wbtest.mbt`, and refactored `SgoGlobalInfo` in `src/passes/simplify_globals_optimizing.mbt` so one row now records:

- `imported`, `exported`, `mutable_`, `value_type`, and `init`;
- total `read_count` / `write_count`;
- source-specific function read/write counts;
- source-specific reads from global initializers, table initializers, active element offsets, typed/untyped element item expressions, and active data offsets;
- the existing same-init and read-only-to-write planning flags after the corresponding plan analyses run.

This is intentionally a fact-table alignment slice, not new optimizer behavior. Existing transformation decisions remain the same: `sgo_plan_remove_sets(...)` records the plan flags into the fact row and then reads them back instead of changing the removal criteria.

## Tests

New whitebox tests cover:

- imported global provenance and global-initializer reads;
- exported mutable global marking;
- function-body reads and writes;
- active data and element offset reads;
- typed element item expression reads.

Focused validation:

- `moon fmt` passed.
- `moon test src/passes` passed with `1610/1610` tests after the fact-table refactor.
- `moon info` passed with the existing DAE warnings.
- `moon test` passed with `3686/3686` tests.

## Direct fuzz status

No behavior broadening was intended. Direct SGO fuzz at `.tmp/pass-fuzz-sgo-fact-table-003a-10000` reported:

- requested `10000` with seed `0x5eed` and `--pass simplify-globals-optimizing`;
- `6759/10000` compared before the configured `--max-failures 20` command-failure limit stopped the run;
- `6759` normalized matches;
- `0` mismatches;
- `0` Starshine validation failures;
- `20` Binaryen/tool command failures classified by the harness as `17` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.

Agent classification: the command failures are Binaryen/tool failures, not Starshine semantic mismatches. Because this slice only refactors fact storage and the normalized compared cases stayed green with zero validation failures, `[SGO]003A` is accepted as a behavior-preserving fact-table alignment slice.

## Next slice

The next implementation child should start from `[SGO]003B` or `[SGO]003C` only with a fresh Binaryen-positive fixture/probe.
