# SGO shared family exposure

Date: 2026-05-26

## Slice

`[SGO]003H` exposed the shared SimplifyGlobals family under distinct public pass names instead of leaving the siblings boundary-only.

## Change

- `simplify-globals` is now an active module pass that runs the shared SGO core without the optimizing nested cleanup rerun.
- `simplify-globals-optimizing` keeps the existing shared core plus touched-function nested cleanup behavior.
- `propagate-globals-globally` is now an active module pass that runs only startup/global propagation over global initializers, table initializers, active element/data offsets, and exact typed element item expressions already covered by the SGO startup path.
- `propagate-globals-globally` deliberately does not rewrite function bodies and deliberately does not use SGO's single-use complex-initializer inlining, matching the Binaryen sibling boundary recorded in the propagate-globals-globally dossier.
- `scripts/pass-fuzz-compare.ts` now accepts `simplify-globals` and `propagate-globals-globally` as direct pass names.

## Tests and validation

TDD failure was observed before implementation:

- `moon test src/passes` failed because `simplify-globals` and `propagate-globals-globally` were still boundary-only and direct requests rejected.

Post-implementation validation passed:

- `moon test src/passes`: `1647/1647` passed.
- `moon fmt`: passed.
- `moon info`: passed with existing DAE unused warnings.
- `moon test`: `3723/3723` passed with existing DAE/pass-manager unused warnings.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass simplify-globals --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-plain-sibling-0699-10000`: `6759/10000` compared before the configured command-failure stop, `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and `20` Binaryen/tool command failures.
- Initial `propagate-globals-globally` fuzz at `.tmp/pass-fuzz-pgg-sibling-0699-10000` found two mismatches where Starshine incorrectly single-use-inlined a complex immutable global initializer into another global initializer while Binaryen preserved a `global.get`.
- After disabling single-use complex-initializer inlining for the startup-only sibling, `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass propagate-globals-globally --max-failures 20 --out-dir .tmp/pass-fuzz-pgg-sibling-0699b-10000`: `6759/10000` compared before the configured command-failure stop, `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and `20` Binaryen/tool command failures.

## Mismatch classification

- The initial `propagate-globals-globally` mismatches at cases `003541` and `005949` were true pass-boundary mismatches: Starshine performed an optimizing/shared-engine single-use complex initializer fold that the Binaryen startup-only sibling does not perform. They were fixed by making `sgo_rewrite_global_sec(...)` parameterize single-use initializer inlining and disabling it for `sgo_run_startup_only_core(...)`.
- The remaining direct fuzz command failures are tool/Binaryen failures, matching the established parser/tool classes for generated inputs. They are not Starshine validation failures or semantic mismatches.

## Status

`[SGO]003H` is accepted for v0.1.0. Future sibling work should require a new direct fuzz mismatch, validation failure, or source-backed behavior gap beyond the exposed plain/core and startup-only wrappers.
