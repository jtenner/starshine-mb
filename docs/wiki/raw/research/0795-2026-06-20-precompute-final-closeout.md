# Precompute final closeout

## Question

Finish the current recursive `[O4Z-AUDIT-PC]` closeout for canonical pass `precompute`: decide the explicit wasm-smith reachable-`atomic.fence` boundary, run the missing final regular GenValid `100000` lane, and determine whether the pass can be closed under the repo's current pass-audit/signoff standard.

## Files reviewed

- `docs/README.md` — repo docs/wiki, pass signoff, validation, and commit policy.
- `.pi/skills/recursive-handoff/SKILL.md` — bounded recursive continuation rules.
- `.pi/skills/starshine-pass-implementation/SKILL.md` — final pass closeout matrix and mismatch-classification rules.
- `.pi/skills/commit/SKILL.md` — commit policy.
- `agent-todo.md` — active `[O4Z-AUDIT-PC]` release-gating state.
- `docs/wiki/binaryen/passes/precompute/` — current precompute dossier, final-lane guidance, and open-boundary wording.
- `docs/wiki/raw/research/0785-2026-06-20-precompute-modern-signoff-refresh.md` through `0794-2026-06-20-precompute-final-evidence-refresh.md` — current recursive status chain.
- `docs/wiki/raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md` — source for preserving `atomic.fence` as an ordering barrier.
- `.tmp/pass-fuzz-precompute-final-regular-100000/result.json` — final regular GenValid closeout result.

## Atomic-fence boundary decision

Accepted the explicit wasm-smith `case-006523-wasm-smith` divergence from `0794` as a narrow Starshine correctness boundary for `precompute` closeout.

The inspected shape has a reachable `atomic.fence` before a branch to the function/block end. Binaryen `--precompute` erases it to `nop`; Starshine preserves the fence and the local atomics note says pass docs must preserve `atomic.fence` as an ordering barrier even though it has no stack or memory operands. The focused test `precompute intentionally preserves reachable atomic fence before branch-to-end` guards that policy. Therefore this is not an implementation recovery target unless the project deliberately changes the atomics preservation policy.

This acceptance is narrow. It does not approve arbitrary Binaryen-vs-Starshine output drift and does not change the O4z no-op boundary accepted in `0793`.

## Final closeout validation

Command:

```sh
git status --short --branch && moon info && moon fmt && moon test --package jtenner/starshine/passes --file precompute_test.mbt && moon test src/passes && moon test && moon build --target native --release src/cmd && ls -l _build/native/release/build/cmd/cmd.exe && test ! -e target/native/release/build/cmd/cmd.exe && echo 'target-native-absent' || true
```

Result:

- initial worktree was clean: `## starshine-gsi`;
- `moon info` passed with the three pre-existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`;
- `moon fmt` passed;
- focused precompute tests passed `37/37`;
- `moon test src/passes` passed `2694/2694`;
- full `moon test` passed `6016/6016`;
- native build completed with no work to do;
- `_build/native/release/build/cmd/cmd.exe` existed and was executable;
- `target/native/release/build/cmd/cmd.exe` remained absent in this checkout.

## Missing regular GenValid `100000` lane

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass precompute --normalize drop-consts --normalize local-cleanup-debris --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-precompute-final-regular-100000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result:

- requested `100000`, compared `100000/100000`;
- normalized matches `15491`;
- cleanup-normalized matches `84509`;
- mismatches `0`;
- validation failures `0`;
- generator failures `0`;
- property failures `0`;
- command failures `0`;
- jobs `16`;
- selected profile `binaryen-oracle-portable=100000`;
- cache: Binaryen `10356` hits / `89644` misses; wasm-smith `0` hits / `0` misses; Binaryen failure cache `0` hits / `0` misses;
- normalizers: `drop-consts`, `local-cleanup-debris`, `unreachable-control-debris`.

No pass-local timing was reported in the result JSON; runtime execution was off.

## Final closeout matrix status

The final closeout matrix is now complete for current `precompute` source, using the checkout-local explicit native path `_build/native/release/build/cmd/cmd.exe`:

1. Regular GenValid `100000`: `.tmp/pass-fuzz-precompute-final-regular-100000` compared `100000/100000`, normalized `15491`, cleanup-normalized `84509`, mismatches/failures `0`.
2. Explicit wasm-smith `10000`: `.tmp/pass-fuzz-precompute-final-refresh-wasm-smith-10000` from `0794` compared `9956/10000`, normalized `9952`, cleanup-normalized `3`, command failures `44` in Binaryen/oracle classes, and one accepted reachable-`atomic.fence` Starshine correctness-boundary mismatch.
3. Dedicated `precompute-all` GenValid `10000`: `.tmp/pass-fuzz-precompute-final-refresh-precompute-all-10000` from `0794` compared `10000/10000`, normalized `5413`, cleanup-normalized `4587`, mismatches/failures `0`; selected leaves were `precompute-scalar=2323`, `precompute-control=1560`, `precompute-global=1535`, `precompute-drop-cleanup=1518`, `precompute-effect-boundary=1509`, `precompute-direct-prefix-watch=793`, and `precompute-gc-atomic-boundary=762`.
4. Broad named `pass-fuzz-stress` GenValid `10000`: `.tmp/pass-fuzz-precompute-final-refresh-pass-fuzz-stress-10000` from `0794` compared `10000/10000`, normalized `1529`, cleanup-normalized `8471`, mismatches/failures `0`.

The `0794` dedicated, broad, and wasm-smith lanes are reused for final matrix accounting because no pass behavior changed after they ran; the later code change was the focused boundary test proving the already-observed `atomic.fence` preservation policy.

## Classification

- `[O4Z-AUDIT-PC]`: closed for v0.1.0 under the current pass-audit/signoff standard.
- Direct `precompute` behavior: closed with the four-lane evidence above and the accepted atomic-fence boundary.
- O4z behavior: closed only as the explicit v0.1.0 release boundary accepted in `0793`; this is not a claim of full O4z PC-slot optimization parity. Under O4z, only changed `raw-scalar-folds` run; HOT-only cleanup, load/call ownership hazards, large lowered functions, br_table/parser stack hazards, unchanged raw no-candidate cases, and changed non-scalar repair reasons remain `o4z-precompute-noop` with documented reopening criteria.
- Historical slot19/slot43 replay: still not refreshed in this checkout because `.artifacts` is absent. Do not claim refreshed historical slot replay until fixtures return or are replaced.
- Command failures: only the previously recorded wasm-smith Binaryen/oracle command-failure classes from `0794`; the final regular GenValid `100000` lane had none.
- Pass-local timing: not reported by the compare harness result JSON for the final lane.

## Commands not run

- The dedicated `precompute-all`, broad `pass-fuzz-stress`, and explicit wasm-smith lanes were not rerun in this slice because `0794` already ran them on current pass behavior and the only subsequent source change was a focused test that preserves the observed atomic-fence boundary.
- Historical O4z slot19/slot43 replay was not run because `.artifacts` is absent.

## Follow-up / reopening criteria

Reopen `precompute` if a future lane finds a true semantic mismatch, Starshine validation failure, Starshine-specific command failure, broad unclassified output-shape family, regression in `precompute-all`, change to the local `atomic.fence` preservation policy, restored slot19/slot43 artifacts contradict the historical retirement story, or the project decides to chase broader O4z PC-slot optimization parity beyond the accepted `o4z-precompute-noop` release boundary.
