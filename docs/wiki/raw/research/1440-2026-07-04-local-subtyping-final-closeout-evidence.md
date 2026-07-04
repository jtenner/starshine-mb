# Local-subtyping final closeout evidence

Date: 2026-07-04

## Question

After the ref-catch raw-assignment fix, does Starshine `local-subtyping` have refreshed direct-pass evidence strong enough to close the active v0.1.0 `-O4z` LS audit scope, with only precise validator/tooling residuals left visible?

## Scope

This note refreshes evidence after [`1439-2026-07-04-local-subtyping-ref-catch-raw-assignment.md`](1439-2026-07-04-local-subtyping-ref-catch-raw-assignment.md). It does not reclassify the two remaining nondefaultable-local boundaries as Starshine wins:

- direct block-return unreachable-tail local-get narrowing remains a validator/tooling boundary from [`1437-2026-07-04-local-subtyping-direct-block-return-boundary.md`](1437-2026-07-04-local-subtyping-direct-block-return-boundary.md);
- raw-unreachable-before-write tee/get narrowing remains a validator/tooling boundary from [`1438-2026-07-04-local-subtyping-raw-unreachable-tee-boundary.md`](1438-2026-07-04-local-subtyping-raw-unreachable-tee-boundary.md).

The direct compare matrix used the current native binary at `_build/native/release/build/cmd/cmd.exe`.

## Commands and results

Focused and repository validation:

- `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` — passed `73/73`.
- `moon info` — passed with pre-existing warnings.
- `moon fmt` — passed.
- `moon test src/passes` — passed `3983/3983`.
- `moon test` — passed `7390/7390`.
- `moon build --target native --release src/cmd` — passed with pre-existing warnings.

Direct pass compare matrix:

- `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass local-subtyping --out-dir .tmp/pass-fuzz-local-subtyping-genvalid-100000-20260704-refcatch --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - requested/compared `100000/100000`;
  - normalized matches `100000`;
  - cleanup-normalized matches `0`;
  - mismatches `0`;
  - validation, generator, property, and command failures `0`;
  - cache: wasm-smith `0/0`, Binaryen `100000` hits / `0` misses, Binaryen failures `0/0`.
- `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass local-subtyping --out-dir .tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260704-refcatch --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - requested `10000`, compared `9956`;
  - normalized matches `9955`;
  - cleanup-normalized matches `0`;
  - raw mismatches `1`;
  - validation, generator, and property failures `0`;
  - command failures `44`, all Binaryen/tool-side: rec-group-zero `39`, invalid tag index `1`, table index out of range `1`, bad section size `3`;
  - cache: wasm-smith `10000` hits / `0` misses, Binaryen `9956` hits / `0` misses, Binaryen failures `44` hits / `0` misses.
- Mismatch inspection for `.tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260704-refcatch/failures/case-009332-wasm-smith`:
  - Binaryen output removes a `drop(unreachable)` before a final `unreachable`;
  - Starshine keeps `drop(unreachable)` before the same final `unreachable`;
  - no local declaration, get/tee retagging, dominance, assignment LUB, refinalization, or ref-catch behavior is involved.
- Cleanup-normalized replay: `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass local-subtyping --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260704-refcatch-unreachable-normalized --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - requested `10000`, compared `9956`;
  - normalized matches `9955`;
  - cleanup-normalized matches `1`;
  - mismatches `0`;
  - validation, generator, and property failures `0`;
  - command failures `44` with the same Binaryen/tool-side classes;
  - cache: wasm-smith `10000` hits / `0` misses, Binaryen `9956` hits / `0` misses, Binaryen failures `44` hits / `0` misses.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass local-subtyping --gen-valid-profile local-subtyping-all --out-dir .tmp/pass-fuzz-local-subtyping-genvalid-all-10000-20260704-refcatch --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - requested/compared `10000/10000`;
  - normalized matches `10000`;
  - cleanup-normalized matches `0`;
  - mismatches and failures `0`;
  - selected profiles: `local-subtyping-straight-line=5030`, `local-subtyping-structured=3296`, `local-subtyping-unreachable-tail=1674`;
  - cache: Binaryen `10000` hits / `0` misses.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5555 --pass local-subtyping --gen-valid-profile random-all-profiles --out-dir .tmp/pass-fuzz-local-subtyping-random-all-profiles-10000-20260704-refcatch --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - requested/compared `10000/10000`;
  - normalized matches `10000`;
  - cleanup-normalized matches `0`;
  - mismatches and failures `0`;
  - selected profiles: `coverage-forced-portable=1446`, `binaryen-oracle-portable=1423`, `pass-fuzz-stress=1425`, `heap2local-array=1400`, `local-subtyping-straight-line=714`, `local-subtyping-structured=466`, `local-subtyping-unreachable-tail=219`, `ssa-nomerge-smoke=1447`, `ssa-nomerge-parity=1460`;
  - cache: Binaryen `10000` hits / `0` misses.

## Agent classification

The refreshed direct-pass matrix has no LS semantic mismatches. The only raw wasm-smith mismatch is the same pass-independent unreachable-control cleanup debris family previously classified in `1429`: Binaryen deletes `drop(unreachable)` before a final `unreachable`, while Starshine leaves it. This is size-losing Starshine output and not a Starshine win, but it is not LS behavior because it does not depend on local narrowing, local get/tee retagging, dominance, assignment LUBs, refinalization, ref-catch flow, or reference-local interaction. It becomes a cleanup-normalized match with `--normalize unreachable-control-debris`.

The two remaining LS surfaces are not broad hidden gaps and not Starshine wins. They are precise validator/tooling boundaries where the reduced Binaryen v130 non-null outputs are rejected by `wasm-tools` with `uninitialized local: 1`, while Starshine emits validating nullable outputs:

1. direct block-return nondefaultable-local unreachable-tail;
2. raw-unreachable-before-write nondefaultable-local tee/get.

Reopen either boundary if the corresponding non-null output starts validating, Starshine validation intentionally adopts a spec-backed proof for that unreachable local state, Binaryen repairs the output shape, or LS can safely repair/avoid the later get while preserving valid emitted wasm.

Reopen `catch_ref` / `catch_all_ref` under LS only for a reduced case outside the current raw-assignment skipped-write subset, such as catch-payload result joins or unknown producers that cannot safely fall back to the declared local type.

## Conclusion

The active v0.1.0 `-O4z` `local-subtyping` audit scope is closed as of this evidence refresh. Starshine matches Binaryen-observable direct-pass LS behavior across the protected families and required compare lanes, except for the two explicitly documented nondefaultable-local validator/tooling boundaries above and the pass-independent cleanup-normalized wasm-smith debris case. None of those residuals is classified as a measured Starshine win.
