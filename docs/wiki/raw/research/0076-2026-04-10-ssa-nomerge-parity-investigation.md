# SSA No-Merge Parity Investigation

## Scope

- Determine whether `ssa-nomerge` still has any discoverable parity issues using the supported random compare harness and the large-artifact compare path.
- Separate genuine Starshine failures from Binaryen parser-family command failures.
- Record the current repro commands, evidence, and next reduction work.

## Current Behavior

- `2026-04-10`: `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --max-failures 5 --out-dir .tmp/ssa-pass-fuzz-smoke --pass ssa-nomerge`
  - Result: `20 / 20` compared, `20` normalized matches, `0` mismatches, `0` validation failures, `0` command failures.
- `2026-04-10`: `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --max-failures 5 --out-dir .tmp/ssa-pass-fuzz-100 --starshine-bin _build/native/release/build/cmd/cmd.exe --pass ssa-nomerge`
  - Result: `99 / 100` compared, `99` normalized matches, `0` mismatches, `0` validation failures, `1` command failure.
  - The single command failure was Binaryen-only:
    - `binaryen-rec-group-zero`
    - `wasm-opt` rejected a wasm-smith input that prints as a module starting with `(rec)` followed by an empty recursion group.
- `2026-04-10`: `wasm-tools validate tests/node/dist/starshine-debug-wasi.wasm`
  - Result: success. The checked-in debug CLI artifact is currently a valid input for direct compare work.
- `2026-04-10`: `_build/native/release/build/cmd/cmd.exe --ssa-nomerge --out .tmp/ssa-self-opt-direct.wasm tests/node/dist/starshine-debug-wasi.wasm`
  - Result: nonzero exit.
  - Error prefix:
    - `error: final module validate: type mismatch`
    - `Offending function idx=(Func 523)`
  - The dumped failing function is `func code[506] abs[523]`.
- `2026-04-10`: `moon run src/cmd --target native -- --debug-serial-passes --tracing pass --ssa-nomerge --out /tmp/ssa-nomerge-current.wasm tests/node/dist/starshine-debug-wasi.wasm`
  - Result: success.
  - The traced current-source replay no longer lets the bad rewrite survive to final module validation.
  - Relevant skip:
    - `skip-invalid-lower func=(Func 523) reason=writeback-validate:type mismatch`
  - Additional observed validation-backed skip:
    - `skip-invalid-lower func=(Func 3773) reason=writeback-validate:stack underflow`
- `2026-04-10`: direct Binaryen micro-replays against reduced param-write cases plus `version_129` `src/passes/SSAify.cpp` `createNewIndexes()`
  - Result: Binaryen behavior is:
    - dead param `local.set` / `local.tee` writes spill through fresh locals,
    - live straight-line param flows stay on the canonical param slot,
    - live typed-`if` branch merges also stay on the canonical param slot.
  - This is the rule Starshine now follows in `src/passes/pass_manager.mbt`.
- `2026-04-10`: `moon test --package jtenner/starshine/passes --file ssa_nomerge_test.mbt`
  - Result: `13 / 13` pass.
- `2026-04-10`: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-rebased-2026-04-10-rerun3 --pass ssa-nomerge`
  - Result: `998 / 1000` compared, `998` normalized matches, `0` mismatches, `0` validation failures, `2` command failures.
  - Both command failures are Binaryen-only `binaryen-rec-group-zero`.
- `2026-04-10`: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-rebased-2026-04-10-signoff --pass ssa-nomerge`
  - Result: `2380 / 10000` compared, `2380` normalized matches, `0` mismatches, `0` validation failures, `5` command failures.
  - All `5` command failures are Binaryen-only `binaryen-rec-group-zero`.
- `2026-04-10`: `bun scripts/pass-fuzz-compare.ts --generator gen-valid --count 10000 --min-compared 10000 --seed 0x5eed --max-failures 5 --out-dir /tmp/ssa-pass-fuzz-rebased-2026-04-10-signoff-gen-valid --pass ssa-nomerge`
  - Result: `10000 / 10000` compared, `10000` normalized matches, `0` mismatches, `0` validation failures, `0` command failures.
- `2026-04-10`: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --ssa-nomerge`
  - Result:
    - `Canonical wasm equal: no`
    - `Normalized WAT equal: yes`
    - `Canonical function compare equal: yes`
    - `Starshine pass skipped raw: yes`
- `2026-04-10`: `moon run src/cmd --target native -- --debug-serial-passes --tracing pass --ssa-nomerge --out /tmp/ssa-nomerge-final.wasm tests/node/dist/starshine-debug-wasi.wasm`
  - Result: success and `wasm-tools validate /tmp/ssa-nomerge-final.wasm` succeeds.
  - The output-facing artifact blocker is fixed on current source, but the trace still records:
    - `skip-invalid-lower func=(Func 523) reason=writeback-validate:type mismatch`
    - `skip-invalid-lower func=(Func 3773) reason=writeback-validate:stack underflow`
    - many `skip-invalid-lower ... reason=suspicious-escape-carrier`
- `2026-04-10`: `wasm-opt tests/node/dist/starshine-debug-wasi.wasm --all-features --ssa-nomerge -o .tmp/ssa-binaryen.wasm`
  - Result: success.
- `2026-04-10`: `wasm-tools validate .tmp/ssa-binaryen.wasm`
  - Result: success.

## Correctness Constraints

- A direct single-pass `ssa-nomerge` replay on a valid input module must either:
  - produce a valid output module that passes final validation, or
  - reject the input before any invalid writeback can survive to final validation.
- For current-source parity, dead param writes must spill through fresh locals while live param flows stay on the canonical param slot, matching direct Binaryen micro-replays.
- The current per-function writeback-validation guard is sufficient to restore final-module safety for the known debug-artifact repros, but it is still only a fail-closed safety rail for the remaining raw-lowering skip families.
- Binaryen parser gaps must stay separate from Starshine parity blockers.

## Validation Plan

- Keep the committed native artifact replay in `src/cmd/cmd_test.mbt` green as the safety regression for current-source `ssa-nomerge`.
- Keep the `10000 / 10000` `gen-valid` compare-pass lane green as the semantic parity signoff floor for reduced cases.
- Reduce `Func 523` and the still-visible `Func 3773` validation-backed skip families to focused repros in `src/passes/ssa_nomerge_test.mbt` or adjacent lowering tests.
- Add artifact-backed assertions that validate the emitted module bytes, not only decode success, whenever a new replay surface is introduced.
- Keep using `pass-fuzz-compare` for breadth, but pair it with direct debug-artifact replay because the random harness did not expose the original artifact failure and the mixed-generator lane still stops on Binaryen parser gaps.
- Keep Binaryen parser-gap families, including the empty-`rec` case from the seeded `100`-case run, out of the semantic mismatch bucket unless a newer Binaryen build parses them cleanly.

## Performance Impact

- This investigation first found a correctness blocker, then landed a semantic fix for the dead-param family plus the earlier safety rail that restores final validation by fail-closing the remaining bad writebacks.
- The direct artifact failure occurred in a normal single-pass native replay before any multi-pass cleanup chain or self-opt pipeline was needed.
- The current source replay still reports many `skip-invalid-lower` bailouts, so the remaining work is still raw-lowering coverage and exact parity reduction first, not runtime-budget tuning.

## Open Questions

- What is the minimal reduced repro for the remaining `Func 523` `writeback-validate:type mismatch` family now that the dead-param mismatch is fixed?
- What is the minimal reduced repro for the newly visible `Func 3773` `writeback-validate:stack underflow` family?
- Which of the remaining validation-backed and `suspicious-escape-carrier` skips represent genuine Starshine/Binaryen semantic gaps, and which are only representation-boundary differences that should stay out of scope?
