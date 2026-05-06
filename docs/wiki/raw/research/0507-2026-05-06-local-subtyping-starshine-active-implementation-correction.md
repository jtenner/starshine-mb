# `local-subtyping` Starshine active-implementation correction

_Capture date:_ 2026-05-06  
_Status:_ immutable repo-source correction note for the `docs/wiki/binaryen/passes/local-subtyping/` dossier

## Scope

This note records the repo-local source inspection that corrected the older wiki reading of Starshine `local-subtyping`.
The previous living pages treated the pass as removed-registry-only / unimplemented. That is stale.

## Current Starshine source surfaces

- `src/passes/local_subtyping.mbt`
  - owner file and active module-pass implementation
- `src/passes/local_subtyping_test.mbt`
  - direct registry / narrowing tests
- `src/cmd/cmd_wbtest.mbt`
  - CLI integration test for `--local-subtyping`
- `src/passes/registry_test.mbt`
  - registry category proof
- `src/passes/optimize.mbt`
  - registry entry and preset inclusion
- `src/passes/pass_manager.mbt`
  - active dispatcher case
- `src/passes/optimize_test.mbt`
  - preset slot and neighborhood proof

## Corrected observations

- `local-subtyping` is an active Starshine module pass.
- The pass summary says it narrows reference-typed body locals to the most specific safe supertype of their writes.
- The implementation is narrower than Binaryen:
  - it collects assignment types from `local.set` / `local.tee` only;
  - it narrows body locals when the collected types share a safe subtype relation;
  - it rewrites body-local declarations and rebuilds the module when changed.
- Current Starshine code does **not** implement the upstream Binaryen get-aware non-null dominance / retagging / iterative refinalization contract.
- The older wiki claims about removed-registry-only status, missing dispatcher, and future-only landing zone are stale and should be replaced with an active-implementation plus parity-gap reading.

## Implication for the living wiki

The living pages should now describe:

- active module-pass status;
- exact current local code map;
- current direct tests and CLI exposure;
- remaining parity gaps versus Binaryen's richer `LocalSubtyping.cpp` contract.

## Primary upstream source still used

The upstream Binaryen sources remain the same source layer for the semantic comparison:

- `docs/wiki/raw/binaryen/2026-05-05-local-subtyping-current-main-recheck.md`
- `docs/wiki/raw/binaryen/2026-04-25-local-subtyping-implementation-test-map-source-correction.md`
