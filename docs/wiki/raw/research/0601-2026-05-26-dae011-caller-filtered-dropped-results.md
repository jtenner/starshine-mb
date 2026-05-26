# DAE011 caller-filtered dropped-result rewrite

Date: 2026-05-26

## Scope

Recovery/completion slice for `[DAE]011` performance stabilization. Previous note `0600` attributed the selected dropped-result helper cost mostly to repeated whole-module scans and rewrites inside `dae_try_remove_dropped_results(...)`:

- whole-module dropped-call rewrite;
- whole-module `call; drop` cleanup;
- whole-module undropped-call scans.

This slice uses the already collected `DaeCurrentCallFacts.direct_callers[callee]` list to keep the mutating selected-def helper focused on functions that actually reference the candidate callee.

## Change

Code:

- `src/passes/dead_argument_elimination.mbt`
  - added caller-filtered helper variants for dropped-result `call; drop` cleanup, undropped-call checks, and dead-suffix repair;
  - extended `dae_try_remove_dropped_results(...)` with an optional `caller_defs` parameter;
  - threads `call_facts.direct_callers[callee_abs]` from `dae_try_remove_selected_defs_dropped_results_with_facts_once(...)` into the helper;
  - preserves the old whole-module path for existing callers that do not pass caller facts.
- `src/passes/pass_manager_wbtest.mbt`
  - updates the selected dropped-result helper timing fixture so it supplies a consistent direct-caller fact;
  - adds coverage that the selected wrapper returns caller touched flags from the caller-filtered rewrite, guarding both behavior and scheduler consistency.

## Timing evidence

Command:

```sh
moon build --target native --release && \
  bun scripts/self-optimize-compare.ts \
    tests/node/dist/starshine-debug-wasi.wasm \
    --starshine-bin target/native/release/build/cmd/cmd.exe \
    --dae-optimizing \
    --canonicalize-binaryen-output \
    --timing-only \
    --out-dir .tmp/dae011-caller-filtered-timing-20260526
```

Result:

- Starshine pass runtime: `1461.100ms`.
- Binaryen pass runtime: `864.852ms`.
- Ratio: about `1.69x`, within the repo target of `Starshine <= 2x Binaryen`.
- Canonical wasm equality is still `no`, as expected for the already documented DAE diagnostic/body-frontier drift.

Repeat command:

```sh
bun scripts/self-optimize-compare.ts \
  tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing \
  --canonicalize-binaryen-output \
  --timing-only \
  --out-dir .tmp/dae011-caller-filtered-timing-repeat-20260526
```

Repeat result:

- Starshine pass runtime: `1577.403ms`.
- Binaryen pass runtime: `851.431ms`.
- Ratio: about `1.85x`, still within target.

Validation:

- `wasm-opt --all-features .tmp/dae011-caller-filtered-timing-20260526/starshine.wasm -o /tmp/starshine-dae011-validated.wasm` passed with only the existing large-local-count VM warning.
- `wasm-opt --all-features .tmp/dae011-caller-filtered-timing-repeat-20260526/starshine.wasm -o /tmp/starshine-dae011-repeat-validated.wasm` passed with the same warning.
- `moon test src/passes` passed before full signoff.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --max-failures 5000 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-dae011-caller-filtered-20260526-full` reported `9975/10000` compared, `6078` normalized matches, `3897` mismatches, `0` validation failures, and `25` Binaryen/tool command failures (`22` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, `1` `binaryen-invalid-tag-index`).

## Classification and remaining work

`[DAE]011` is closed for the current debug-artifact performance target: the selected dropped-result candidate loop now has a caller-filtered rewrite path and repeated timing-only artifact replays are inside the `Starshine <= 2x Binaryen` pass-local target.

The 10k compare-pass result matches the accepted `[DAE]010` shape. Agent classification: the `3897` mismatches are the known `gen-valid` size-winning semantic-safe raw-cleanup family where Starshine strips generator leading dropped pure/nontrapping constant debris that Binaryen preserves; the command failures are Binaryen/tool parser failures, and there are `0` validation failures. This slice does not close broader DAE parity slices. The both-canonical artifact still differs, currently documented as the closed `[DAE]006` lowerer/diagnostic boundary plus other known representation/size drift. Future DAE performance work should reopen only with a new measured DAE-owned regression, a full-fuzz/runtime cliff, or a preset-integration timing need.
