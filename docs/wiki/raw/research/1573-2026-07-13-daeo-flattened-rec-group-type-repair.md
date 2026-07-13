# DAEO flattened rec-group type repair and artifact unblock

Date: 2026-07-13

## Scope

This slice reduced the current stripped wasm-gc artifact failure that research note `1570` had provisionally routed to nondefaultable-local validation. The failure was DAEO-owned: the pass interpreted flattened WebAssembly type indices as type-section rec-entry indices. On sections containing multi-member rec groups, DAE could read an unrelated function signature and append a replacement type at the wrong index.

## Root cause

The artifact's original absolute Func 73 used flattened Type 1001 with signature `(ref $5, ref $5) -> i32`. The old `dae_type_sec_func_type(...)` indexed `TypeSec.rec_types[1001]` directly instead of walking flattened subtypes, so it read an unrelated `() -> (ref $7, i32)` signature. The removed-parameter rewrite then assigned that unrelated result vector to Func 73. Callers localized the real two operands, but the rewritten callee appeared nullary/multivalue, leaving extra values at a surrounding one-result block. The pre-fix dumped output fails both Starshine and wasm-tools validation.

After correcting signature lookup, a second issue became visible immediately: `dae_append_new_func_type(...)` used `rec_types.length()` for the new `TypeIdx`. With rec groups, that is the number of encoded rec entries, not the number of flattened subtypes, so the new index could alias an existing flattened type. Pre-fix artifact replay then rewrote absolute Func 23 to the unrelated aliased signature and failed with an invalid local index.

Classification: **DAEO validation/correctness failures**, not validator limitations and not representation drift.

## Red-first tests

`src/passes/dead_argument_elimination_wbtest.mbt` adds:

- `dae resolves flattened function type indexes inside rec groups`: failed before implementation because Type 1 resolved to the following encoded rec entry instead of the second subtype in the preceding group;
- `dae appends function types after flattened rec-group members`: failed before implementation because a section with three flattened subtypes returned appended Type 2 instead of Type 3.

`src/passes/dae_optimizing_test.mbt` adds public-pipeline coverage:

- `dae-optimizing preserves grouped function results while removing params`: a private grouped function `(i32, i32) -> i32` must lose both unused parameters, reuse the existing safe simple `() -> i32` type, preserve the `i32` result, repair its direct caller, and validate.

## Implementation

`src/passes/dead_argument_elimination.mbt` now:

- counts flattened subtype cardinality across single and grouped rec entries;
- resolves a `TypeIdx` by walking flattened subtype positions, including members inside a rec group;
- identifies an encoded single-rec entry only when a flattened index actually names that single entry, refusing in-place replacement of a group member;
- appends new function types at the flattened subtype count;
- reuses equivalent safe simple function types across mixed type sections while skipping group members and subtypes with supertypes or descriptor metadata;
- sizes non-FuncSec type-liveness maps by flattened subtype count and replaces unique single-rec function types through the encoded entry slot rather than the flattened index.

Plain `dead-argument-elimination` and `dae` continue to share only the boundary core; no optimizing-only cleanup or scheduling was added to them.

## Current artifact replay

Input:

- `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`;
- input size `3204405` bytes;
- validates with wasm-tools.

Final current native binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `be413f169ff1cc8fc779168c4093fca8291fa86fa7d672d2c2a4bb54fae73c6d`.

Direct Starshine DAEO output:

- `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-recgroup-final.wasm`;
- output size `3201580` bytes;
- SHA-256 `428476f13d683edf19d27c7ed726c40dee0be64e6832dd7db9a8c3a13df251d9`;
- validates with Starshine final validation and `wasm-tools validate --features all`;
- whole command `3979.165ms`;
- DAEO pass-local `3327.318ms`.

Retained Binaryen direct output/timing on the same input:

- output size `3177421` bytes;
- pass-local `8083.49ms`;
- whole command `8.417s`.

Starshine is `0.41x` Binaryen pass-local time and therefore meets the `<=2x` target comfortably. The former artifact validation blocker is closed.

The artifact is not final parity evidence yet. Starshine is `24159` raw bytes larger. No-pass Binaryen canonicalization measures Starshine `3278806` versus Binaryen `3262456` bytes (`+16350`), and canonical WAT is `179309098` versus `178975283` bytes (`+333815`). The outputs are not canonically equal. The Starshine trace reports `nested-cleanup-skip reason=large-touched-set touched=23`, while Binaryen runs its touched-function nested optimization pipeline. Agent classification: **open size-losing parity gap**, likely centered on the large-touched-set nested-cleanup guard but not yet proven wholly attributable to it. This is not accepted as a Starshine win.

## Fresh direct compare matrix

The type-index repair changed behavior, so the full matrix was rerun with the final current binary and both DAE normalizers:

- dedicated `.tmp/pass-fuzz-dae-optimizing-dedicated-10000-post-recgroup-20260713`: `10000/10000` normalized, zero mismatches/failures, selected `dae-optimizing=10000`, Binaryen cache `10000/0`;
- regular `.tmp/pass-fuzz-dae-optimizing-genvalid-100000-post-recgroup-20260713`: `100000/100000` normalized, zero mismatches/failures, selected `binaryen-oracle-portable=100000`, Binaryen cache `100000/0`;
- explicit wasm-smith `.tmp/pass-fuzz-dae-optimizing-wasm-smith-10000-post-recgroup-20260713`: requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized `1`, mismatches `0`, no Starshine failure, and `44` Binaryen/oracle failures (`rec-group-zero=39`, invalid-tag=1, table-index=1, bad-section-size=3); caches wasm-smith `10000/0`, Binaryen `9956/0`, Binaryen failures `44/0`;
- random-all `.tmp/pass-fuzz-dae-optimizing-random-all-10000-post-recgroup-20260713`: `10000/10000` compared, `9633` normalized, `367` residuals, zero failures, Binaryen cache `10000/0`. The residual directory set and all `3670` files are byte-identical to note `1572`, so the same `dae-effectful-args=124` and `coverage-forced-portable=243` measured/source-backed Starshine-win classifications remain current.

No unknown/risky, canonical/WAT-size-losing generated residual, validation failure, or true-semantic mismatch remains in the required direct matrix.

## Validation

- red grouped resolver test: failed with the unrelated following-entry params before implementation;
- red flattened append test: failed `Type 2 != Type 3` before implementation;
- focused grouped whitebox tests: `2/2`;
- focused public grouped pipeline test: `1/1`;
- full DAE whitebox: `203/203`;
- full public DAEO tests: `309/309`;
- `moon test src/passes`: `5342/5342` before the final equivalent helper refactor;
- final `moon info`: `11` existing warnings, `0` errors;
- final `moon fmt`: green;
- final full `moon test`: `8800/8800`;
- final native release build: green;
- final `bun validate full --profile ci --target wasm-gc`: green at seed `1783949041195000`;
- reproducible fixed-seed full gate also green at seed `1783947860244000`.

One intervening unseeded full-gate run ended in the general fuzz runner with a bare `RuntimeError: unreachable` and no reported seed. The immediately following fixed-seed run and a later standard unseeded run both passed. This transient is recorded rather than hidden; it did not reproduce as a DAEO test, artifact, or compare failure.

No `.mbti` diff exists.

## Closeout state

DAEO remains active. The artifact now emits valid output and pass-local performance is green, but its direct output remains a measured size-losing/canonical parity gap. The next slice must attribute the `+16350` canonical bytes by function/type and test whether safely replaying the Binaryen-shaped touched cleanup for `23` functions closes the gap without violating the existing large-function safety guards. Scheduled current-artifact `optimize`/`shrink` output and performance should then be refreshed. Do not close the audit until that residual is fixed or replaced by a measured, source-backed Starshine win.
