---
kind: concept
status: strong
last_reviewed: 2026-07-26
sources:
  - ./index.md
  - ./fuzzing.md
  - ../../../../../src/passes/local_subtyping.mbt
  - ../../../../../src/passes/local_subtyping_test.mbt
  - ../../../../../src/passes/local_subtyping_wbtest.mbt
---

# `local-subtyping` validation and closeout

## Verdict

The represented Binaryen v131 behavior audit is closed.

The audit combined direct source/lit review, red-first deterministic regressions, family-based GenValid generation, external validation, the required four-lane v131 comparison matrix, and a cleanup-normalized replay of the sole wasm-smith residual.

## Behavior families

| Family | Evidence |
| --- | --- |
| body-local declaration narrowing | direct child and exact assignment tests |
| concrete and abstract LUBs | sibling-parent, i31/struct eq, and distinct-function tests plus `local-subtyping-lubs` |
| null bottoms and unreachable writes | raw white-box test, incompatible unreachable test, and `local-subtyping-null-bottom` |
| non-null dominance | straight-line and structured positive/negative direct tests |
| repeated refinement | local-get, select, call-ref tests and `local-subtyping-iteration` |
| control ReFinalize | official i31 if/direct-branch block test and `local-subtyping-control-refinalize` |
| ref-catch boundaries | catch_ref/catch_all_ref direct tests and ref-catch result preservation guard |
| parameter/non-reference/nondefaultable boundaries | direct no-rewrite tests and upstream lit review |
| public wiring | registry, dispatcher, preset, and CLI tests |

## Final matrix

See [`fuzzing.md`](./fuzzing.md) for commands, hashes, cache counters, selected-family counts, and failure classes.

- regular GenValid: `100000/100000` exact normalized;
- dedicated aggregate: `10000/10000` exact normalized;
- random all-profiles: `10000/10000` exact normalized;
- wasm-smith: `9955` exact normalized plus one cleanup-normalized of `9956` comparable cases; `44` Binaryen-only tool failures; zero Starshine validation, generator, property, or true semantic failures.

## Residual classification

Case `009332` contains Binaryen removal of `drop(unreachable)` before final `unreachable`; Starshine leaves that pass-independent cleanup debris. It is not caused by local declaration narrowing, LUBs, dominance, refinalization, or ref-catch handling. The documented `unreachable-control-debris` normalizer converts it to the sole cleanup-normalized match.

Legacy `try` and the two historical invalid Binaryen nondefaultable-local outputs remain explicit boundaries, not hidden parity claims.

## Performance and integration validation

A seven-run same-session CLI wall-time comparison on `tests/node/dist/starshine-debug-wasi.wasm` used the current native release Starshine and official Binaryen v131 with all features enabled. Starshine measurements were `779, 749, 758, 759, 752, 741, 746 ms` (median `752 ms`); Binaryen measurements were `701, 719, 723, 713, 694, 703, 713 ms` (median `713 ms`). Starshine is within about `5.5%` of Binaryen wall time and comfortably meets the repository's `>=50%` target. Starshine's internal pass timer reported `116079 us`; its output validates externally.

Serial validation passed `moon info`, `moon fmt`, and full native `moon test` at `9943/9943`. The wasm-gc full gate passed formatting, check, and `9943/9943` tests. Its combined in-process `all ci` fuzz invocation aborted in the wasm runtime without a diagnostic after the suites accumulated; rerunning every one of the 14 CI fuzz suites separately at fixed seed `1785073488347772` passed, and the native aggregate at the same seed passed all suites including `86820` binary roundtrips. README/API sync passed. A direct `--debug-serial-passes --local-subtyping` run on the debug self artifact passed and validated; the broader self-optimized `-O4z` build later failed in `flatten` after that pass had already mutated thousands of functions, with `InvalidBranchArity` before flattening function `7676`, so that existing pipeline failure is not attributed to local-subtyping.

## Reopening criteria

Reopen for:

- a reduced represented-surface v131 mismatch;
- a future Binaryen release changing `LocalSubtyping.cpp`, structural dominance, or lit expectations;
- a validator change making either historical nondefaultable-local boundary valid;
- a new local-subtyping behavior family absent from `local-subtyping-all`;
- a pass-local performance regression attributable to these helpers.
