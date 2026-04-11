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
- `2026-04-10`: `wasm-opt tests/node/dist/starshine-debug-wasi.wasm --all-features --ssa-nomerge -o .tmp/ssa-binaryen.wasm`
  - Result: success.
- `2026-04-10`: `wasm-tools validate .tmp/ssa-binaryen.wasm`
  - Result: success.

## Correctness Constraints

- A direct single-pass `ssa-nomerge` replay on a valid input module must either:
  - produce a valid output module that passes final validation, or
  - reject the input before any invalid writeback can survive to final validation.
- The current per-function writeback-validation guard is sufficient to restore final-module safety for the known debug-artifact repros, but it is still only a fail-closed safety rail, not true Binaryen parity.
- Binaryen parser gaps must stay separate from Starshine parity blockers.

## Validation Plan

- Keep the committed native artifact replay in `src/cmd/cmd_test.mbt` green as the safety regression for current-source `ssa-nomerge`.
- Reduce `Func 523` and the newly visible `Func 3773` validation-backed skip families to focused repros in `src/passes/ssa_nomerge_test.mbt` or adjacent lowering tests.
- Add artifact-backed assertions that validate the emitted module bytes, not only decode success, whenever a new replay surface is introduced.
- Keep using `pass-fuzz-compare` for breadth, but pair it with direct debug-artifact replay because the random harness did not expose the real artifact failure.
- Keep Binaryen parser-gap families, including the empty-`rec` case from the seeded `100`-case run, out of the semantic mismatch bucket unless a newer Binaryen build parses them cleanly.

## Performance Impact

- This investigation first found a correctness blocker, then landed a safety fix that restores final validation by fail-closing bad writebacks.
- The direct artifact failure occurred in a normal single-pass native replay before any multi-pass cleanup chain or self-opt pipeline was needed.
- The current source replay still reports many `skip-invalid-lower` bailouts, so the remaining work is still correctness/parity reduction first, not runtime-budget tuning.

## Open Questions

- What is the minimal reduced repro for `Func 523`'s `writeback-validate:type mismatch` family?
- What is the minimal reduced repro for the newly visible `Func 3773` `writeback-validate:stack underflow` family?
- Which of the remaining validation-backed skips represent genuine Starshine/Binaryen semantic gaps, and which are only representation-boundary differences that should stay out of scope?
