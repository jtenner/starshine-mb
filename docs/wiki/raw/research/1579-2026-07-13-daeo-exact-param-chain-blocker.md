# DAEO exact-parameter chain blocker after Func 164 cleanup

Date: 2026-07-13

## Scope

This investigation follows the retained Func `164` body/result closure in notes `1577` and `1578`. It tested the next attributed Binaryen difference: defined Funcs `37`, `38`, and `41` should narrow their second parameter from broad `(ref $731)` to exact `(ref exact $731)` and remove their third parameter. No experimental implementation was retained because every tested partial endpoint was raw-size-losing and the required downstream cleanup did not converge.

## Current retained baseline

Commit `cdc94f043` produces:

- valid output `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-null-if-cleanup.wasm`;
- raw `3201361`;
- canonical wasm `3278511`;
- current-tool canonical WAT `179305591`;
- pass-local `3980.121ms` versus Binaryen `8083.49ms`;
- exact results for absolute Funcs `196`, `185`, and `60` / defined Funcs `175`, `164`, and `39`;
- zero params/locals and Binaryen-shaped effectful default producers in Func `164`.

The stable native binary after restoring the rejected probes is `_build/native/release/build/cmd/cmd.exe`, SHA-256 `ac7673e41a94c0e31cf0a957cfb8471d801f3210c90f6861324ef5dc319f7841`.

## Probe 1: exact local forwarding only

A temporary selected current-fact worklist added caller-local type evidence to direct GC parameter refinement and processed definitions `37`, `38`, and `41` after Func `164` result closure.

Artifact result:

- valid output `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-param-chain-probe2.wasm`;
- trace refined `37 -> 38 -> 41`;
- each second parameter became exact `$731`;
- no third parameter was removed;
- raw `3201396`, or `+35` versus the retained baseline.

Agent judgment: the type propagation matches the Binaryen signature direction, but the partial endpoint is raw-size-losing and does not remove the attributed parameters. It is not independently signable.

## Probe 2: broad raw-cleanup retry

A temporary retry invoked the module raw cleanup while processing the selected chain. It changed unrelated definitions (`42` and `3634` in the trace), emitted valid output `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-param-chain-probe3.wasm`, and measured:

- raw `3201384`, `+23` versus retained;
- pass-local `5392.083ms`;
- whole command `6053ms`;
- exact second params but no complete third-param chain removal.

Agent judgment: rejected. It violates the narrow attribution by cleaning unrelated functions, increases raw size, and moves toward the already-rejected blanket replay class. The large-touched-set and nondefaultable-local guards remain necessary.

## Probe 3: immutable-global materialization at Func 37

Absolute Func `57` passes immutable Global `501` as Func `58` / defined Func `37`'s third argument. Global `501` is a non-null `struct.new $0`. A temporary selected exact-literal retry with immutable-global support produced:

- valid output `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-param-chain-global.wasm`;
- SHA-256 `541eb2711559cd3c4c96e2ba580d93464b27fa83b6d6f604bbee7666cd8a0778`;
- trace `refine 37 -> 38 -> 41`, then `literal 37`;
- Func `37`: two params, exact second param;
- Func `38`: three params, exact second param;
- Func `41`: three params, exact second param;
- raw `3201404`, `+43` versus retained;
- canonical wasm `3278511`, byte-count equal to retained;
- current-tool canonical WAT `179305602`, `+11` versus retained;
- pass-local `4274.042ms`;
- whole command `4934ms`.

Agent judgment: this identifies the next real semantic dependency but remains size-losing. Func `37` materializes the immutable struct and removes its third boundary param, but its body still computes the nullable value passed to Func `38`. Binaryen's replay folds the known default field path to null, then removes Func `38`'s third param and finally Func `41`'s default-wrapper param. Starshine's general nested replay is skipped at the valid `large-touched-set` guard, and broad raw cleanup does not provide that proof.

## Precise blocker and next safe shape

The next owner is a **function-filtered precompute-propagate-prefix replay on defined Func `37` after immutable-global materialization**, followed by current-fact exact/default and unread-param convergence on Funcs `38` and `41`.

The implementation must:

1. keep the existing general `large-touched-set` guard;
2. run only on the source-attributed selected chain, not all touched functions and never blanket-clean oversized Func `41`;
3. prove Global `501`'s immutable `struct.new $0` default field makes Func `37`'s branch result null while preserving all effects;
4. materialize/remove Func `38`'s now-uniform nullable argument;
5. expose and remove Func `41`'s corresponding default-wrapper param without broad nested cleanup;
6. retain only an output that validates and is non-size-losing or a measured/source-backed Starshine win.

A reusable caller-local GC actual evidence extension is still likely needed for exact second-param forwarding, but it should land together with the converged removal chain, not as the raw-size-losing partial probe.

## Validation and status

- all three probe outputs validate with `wasm-tools validate --features all`;
- no probe source change is retained;
- the worktree was restored to commit `cdc94f043` behavior before this note;
- stable native release build is green with existing warnings;
- no `.mbti` change;
- the four-lane compare matrix remains stale because retained behavior changed in commits `53fc665c4` and `cdc94f043` and direct artifact parity remains open.

DAEO remains active. Full release validation and scheduled current-artifact optimize/shrink/O4z evidence remain deferred until the exact-param chain is closed or every residual is measured and source-backed.
