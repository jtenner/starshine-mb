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
- `2026-04-10`: `wasm-opt tests/node/dist/starshine-debug-wasi.wasm --all-features --ssa-nomerge -o .tmp/ssa-binaryen.wasm`
  - Result: success.
- `2026-04-10`: `wasm-tools validate .tmp/ssa-binaryen.wasm`
  - Result: success.

## Correctness Constraints

- A direct single-pass `ssa-nomerge` replay on a valid input module must either:
  - produce a valid output module that passes final validation, or
  - reject the input before any invalid writeback can survive to final validation.
- The existing `skip-invalid-lower` escape-carrier guard is not sufficient if a rewritten function outside the current guard family can still poison the final module.
- Binaryen parser gaps must stay separate from Starshine parity blockers.

## Validation Plan

- Reduce `Func 523` from the debug artifact to a committed focused regression in `src/passes/ssa_nomerge_test.mbt` or a dedicated artifact-backed native replay test.
- Add an artifact-backed assertion that validates the emitted module bytes, not only decode success.
- Keep using `pass-fuzz-compare` for breadth, but pair it with direct debug-artifact replay because the random harness did not expose the real artifact failure.
- Keep Binaryen parser-gap families, including the empty-`rec` case from the seeded `100`-case run, out of the semantic mismatch bucket unless a newer Binaryen build parses them cleanly.

## Performance Impact

- This investigation found a correctness blocker, not a runtime-budget blocker.
- The direct artifact failure occurs in a normal single-pass native replay before any multi-pass cleanup chain or self-opt pipeline is needed.
- The trace from the failing direct run shows several large functions already taking the `skip-invalid-lower reason=suspicious-escape-carrier` fallback before the final `Func 523` validation failure, so the current guard is active but incomplete.

## Open Questions

- What is the minimal reduced repro for `Func 523`?
- Does `Func 523` share the same underlying carrier family as the earlier guarded `Func 225`, `230`, `231`, and `235` cases, or is it a different missing writeback/validation guard?
- What is the right long-term regression surface for main-package CLI artifact tests now that a targeted `moon test --target native --package jtenner/starshine/cmd --file src/cmd/cmd_test.mbt --filter 'run_cmd_with_adapter validates ssa-nomerge on debug artifact'` run returned `Total tests: 0` and `Warning: no test entry found`?
