# `inlining-optimizing` post-reachability cache performance follow-up

Date: 2026-06-15

## Question

After the reachability-cache fix, which remaining `inlining-optimizing` 10s-scale buckets still owned self-optimization time, and did caching/deferring them reduce pass-local wall time?

## Artifact and commands

Primary replay artifact:

- input: `_build/wasm/debug/build/cmd/cmd.wasm`
- output: `tests/node/dist/starshine-self-optimized-wasi.wasm`
- command shape: `_build/native/release/build/cmd/cmd.exe --tracing pass --debug-serial-passes --optimize -O4z --out tests/node/dist/starshine-self-optimized-wasi.wasm _build/wasm/debug/build/cmd/cmd.wasm`

Post-fix replay log:

- `.tmp/self-opt-inlining-final-perf.stderr`

Direct compare after the follow-up:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass inlining-optimizing --normalize drop-consts --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-inlining-optimizing-perf-cache-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Result: `7607/10000` compared, `3794` normalized matches, `3813` compare-normalized matches, `0` mismatches, `0` validation failures, `0` property failures, and `20` Binaryen/tool command failures. Cache counters: wasm-smith `3813` hits / `1` miss; Binaryen `7606` hits / `1` miss; Binaryen failures `20` hits / `0` misses.

## Fixes

The prior reachability fix exposed two additional repeated-analysis costs:

1. Same-signature root-cycle dead-suffix preservation recomputed global-use flags, function signatures, and dead-suffix call counts for every candidate function. The follow-up builds `InlDeadSuffixPreserveFacts` once per module state and reuses cached signatures plus per-function dead-suffix target counts in `inl_has_same_sig_root_cycle_dead_suffix(...)` and `inl_collapse_unreachable_roots(...)`.
2. `inl_run_module_pass_once(...)` built original-reachability prediction state before knowing whether a rewrite changed anything. The no-change terminal iteration does not consume that prediction state, so the follow-up defers it until after `inl_rewrite_all_calls(...)` reports `changed`.
3. The original-reachability prediction helpers still repeatedly rendered the same function signature keys. The follow-up adds `inl_build_func_signature_keys(...)` and uses per-helper signature arrays instead of repeated `inl_func_signature_key(...)` calls in the prediction loops.

The behavior intent is unchanged: the dead-suffix preservation test still protects the same same-signature root-cycle/orphan shape, and the original-reachability predictions are only skipped for the iteration that already proved no inlining rewrite happened.

## Timing impact

Baseline after the reachability-cache fix, from `0724` / `.tmp/self-opt-inlining-reach-wrapper.stderr`:

| Timer | Total |
| --- | ---: |
| `pass:inlining-optimizing` | about `40.919s` |
| `detail:inlining:iteration` | about `37.666s` |
| `detail:inlining:once:original-reachable-private-cycle-funcs` | about `14.592s` |
| `detail:inlining:once:preserve-root-cycle-check` | about `12.274s` |
| `detail:inlining:once:collapse-unreachable-roots` | about `8.835s` |
| `detail:inlining:initial-original-reachable-private-cycle-funcs` | about `3.321s` |

After this follow-up, from `.tmp/self-opt-inlining-final-perf.stderr`:

| Timer | Total |
| --- | ---: |
| `pass:inlining-optimizing` | `3.528s` |
| `detail:inlining:iteration` | `3.144s` |
| `detail:inlining:once:original-reachable-private-cycle-funcs` | `0.867s` |
| `detail:inlining:initial-original-reachable-private-cycle-funcs` | `0.285s` |
| `detail:inlining:once:collapse-unreachable-roots` | `0.271s` |
| `detail:inlining:once:preserve-root-cycle-check` | `0.159s` |

Net pass-local movement on the same artifact family:

- post-reachability baseline: `~40.9s`
- after same-signature/dead-suffix facts, lazy original prediction, and signature-key caching: `3.528s`
- improvement from this follow-up: about `11.6x`
- improvement from the original multi-minute baseline in `0724`: about `690.716s -> 3.528s` (`~196x`)

No remaining traced `inlining-optimizing` subphase is in the 10s range on this replay.

## Validation

Commands run serially:

- `moon fmt`: pass.
- `moon info`: pass, with existing unused-value warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `moon test --package jtenner/starshine/passes --file inlining_wbtest.mbt`: pass, `12/12`.
- `moon test --package jtenner/starshine/passes --file inlining_test.mbt`: pass, `98/98`.
- `moon test`: pass, `5784/5784`.
- `moon build --target native --release --package jtenner/starshine/cmd`: pass, with existing `pass_manager.mbt` unused-function warnings.
- Artifact replay above: pass, `pass:inlining-optimizing` `3.528s`.
- Direct compare above: `0` mismatches and `0` validation failures.

## Remaining work

`[WALL]002` should no longer treat the prior 10s-scale `preserve-root-cycle-check`, `collapse-unreachable-roots`, or original-reachability signature-rendering buckets as active on this artifact. Future inlining performance work should start from the current sub-second traced buckets or from a new artifact that reproduces a fresh 10s-scale owner.
