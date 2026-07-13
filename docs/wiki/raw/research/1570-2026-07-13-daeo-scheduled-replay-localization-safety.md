# DAEO scheduled replay and localization safety

Date: 2026-07-13

## Scope

This slice exercised direct `dae-optimizing`, public `--optimize`, public `--shrink`, and synthesized `-O4z` after the fresh direct compare matrix. It found and fixed a native crash in DAE callsite localization, measured direct and scheduled performance, and isolated a separate current-artifact validator blocker.

## Red artifact evidence

`moon build --target wasm-gc src/cmd` refreshed `_build/wasm-gc/debug/build/cmd/cmd.wasm`. Starshine cannot decode that debug artifact directly because its name section has `InvalidNameSubsectionOrder`, so the no-DWARF test input was produced with:

```sh
wasm-opt _build/wasm-gc/debug/build/cmd/cmd.wasm --all-features --strip-debug \
  -o .tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
wasm-tools validate --features all \
  .tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm
```

The stripped input is `3204405` bytes and validates with wasm-tools.

Before the fix, native direct DAEO aborted after four productive fixed-core iterations. A debug native replay identified the exact panic:

```text
PanicError
  at dae_rewrite_local_idx
  at dae_rewrite_instruction_locals
  at dae_removed_param_callee_rewrite_evidence
```

The failing local-map access was `raw=2 length=2`. The artifact also exposed a transient-signature localization collision: while rewriting a nested call in defined caller `50`, the caller's current signature had one parameter but its body still used local indexes through `21`; localization selected scratch indexes `20` and `21`, colliding with existing body locals before the later signature restoration.

Classification: **Starshine command/crash correctness failure**, not a Binaryen representation difference.

## Red-first tests and fix

Two whitebox tests were added to `src/passes/dead_argument_elimination_wbtest.mbt`:

- `dae removed-param callee rewrite rejects invalid out-of-range local input` failed with the same array-bounds panic before implementation;
- `dae localization scratch floor stays above transient body local indexes` failed to compile while the required body-aware scratch-floor helper was absent.

`src/passes/dead_argument_elimination.mbt` now:

- recursively computes `dae_next_free_local_idx(...)` across local get/set/tee uses in block, loop, try-table, and if bodies;
- chooses caller scratch indexes above both the declared caller local range and every local index already present in the body, so transient signature narrowing cannot collide with body locals;
- recursively checks local-index bounds before and after removed-parameter callee projection, returning `None` transactionally instead of indexing outside the local map or accepting an out-of-range rewrite.

After the fix, the artifact uses scratch indexes `22` and `23` instead of colliding with existing `20` and `21`, and native DAEO no longer aborts.

## Direct performance and remaining artifact blocker

On the stripped current wasm-gc artifact:

- Starshine direct DAEO pass timer: `9692.498ms`;
- Binaryen `--dae-optimizing --debug` pass timer: `8083.49ms`;
- ratio: `1.20x` Binaryen, inside the repository `<=2x` pass-local target;
- Starshine whole command reached final validation in `10.217s`;
- Binaryen whole command completed in `8.417s`.

The Starshine pass now completes but final Starshine validation rejects defined function `50` / absolute function `71` with `local type has no default value`. The original stripped artifact validates with wasm-tools and contains non-nullable GC body locals initialized along structured paths. The post-fix body-aware scratch indexes are non-colliding, but Starshine's current final validator cannot sign this artifact-local nondefaultable-local initialization surface.

Classification: **concrete validator/tooling blocker after the DAEO crash fix**. It prevents a valid emitted Starshine artifact from being captured for this current wasm-gc build, so current-artifact output parity is not claimed. Reopen under DAEO if a reduced rewrite itself violates local initialization; otherwise the next owner is the validator's nondefaultable-local structured-initialization contract.

## Scheduled profile evidence

The deterministic `dae-optimizing` profile input `gen-valid-000001.wasm` was run through public `--optimize`, public `--shrink`, and synthesized `-O4z` with `--tracing pass`.

All three:

- validate with wasm-tools;
- contain exactly one top-level `pass[dae-optimizing]:start`;
- place it immediately after the late top-level `heap-store-optimization` skip at trace line `268` and before `inlining-optimizing` at line `491` for `optimize`/`shrink` (`236` and `425` for `-O4z`);
- produce the same `38`-byte output, SHA-256 `6412e2f194adbecb12178dc516b0e5e491eec20f83c8d73bf6d82a8095cd3c30`;
- shrink the `94`-byte input by `56` bytes;
- complete in `3-4ms` whole-command wall time.

Binaryen `-O4 --shrink-level 4 --all-features` also produces the same `38`-byte canonical output and completes in `4ms` wall time. Starshine DAEO pass-local timers inside the scheduled runs were `707us` (`optimize`), `650us` (`shrink`), and `566us` (`-O4z`).

A separate direct timing-only compare on the same dedicated input has canonical equality and equal `78`-byte direct outputs. Whole-command timing favors Starshine (`3.209ms` versus `3.547ms`); pass-local timing is `2.093ms` versus Binaryen `0.739ms`, over the ratio target on this tiny input but far below the repository's `<1s` absolute pass target. The representative large stripped artifact is the ratio-bearing measurement and meets `<=2x` before the validator gate.

## Validation

- red focused invalid-local test: failed with array bounds panic before implementation;
- red scratch-floor test: failed while `dae_next_free_local_idx` was unbound;
- focused `moon test src/passes/dead_argument_elimination_wbtest.mbt --filter 'dae *local*'`: `42/42`;
- full DAE whitebox: `202/202`;
- public DAEO tests: `308/308`;
- `moon test src/passes`: `5340/5340`;
- `moon fmt`: passed;
- native release build: passed with existing warnings;
- post-fix dedicated profile: `10000/10000` normalized, zero mismatches or failures.

## Closeout state

The audit remains active. Research notes `1571` and `1572` subsequently refreshed regular GenValid, explicit wasm-smith, and random-all with the post-fix binary, completing the current direct matrix without unknown/risky, size-losing canonical/WAT, validation, or true-semantic residuals. Full `moon test`, `moon info`, full release validation, `.mbti` review, and current-artifact validator ownership remain.
