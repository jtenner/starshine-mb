# DAEO wide nullable-default worklist measurement

Date: 2026-07-13

## Scope

This slice measures and narrows the broad-module exact/default candidate worklist introduced after research note `1574`. The goal is to reach the current stripped artifact's low Func `164` family without repeating whole-module caller-fact collection, while preserving raw/canonical/WAT size, validity, and the repository `Starshine <= 2x Binaryen` pass-local target.

## Red-first contract

`src/passes/dead_argument_elimination_wbtest.mbt` adds `dae exact-literal candidate worklist can select wide nullable-default boundaries`.

The test presents two eight-parameter uniform-constant candidates:

- one boundary whose parameters are all nullable references;
- one mixed nullable-reference/integer boundary.

It failed before implementation because the candidate collector had no `min_param_count` or `require_all_nullable_refs` policy inputs. After implementation, only the wide all-nullable-reference boundary enters the filtered worklist.

The earlier public `4097`-definition Func-164-shaped test and the two-candidate one-snapshot white-box test remain green.

## Candidate batching and safety

The reusable collector still supports ordinary exact/default candidate discovery. The active broad-module schedule now applies a narrower source/artifact-backed policy:

- inspect only the first `4096` defined functions;
- require at least `8` parameters;
- require every parameter to be a nullable reference;
- collect from one current caller-fact snapshot;
- revalidate every candidate against the evolving module before mutation;
- retain the existing productive cap of `64`;
- do not change direct-call edges, large-function cleanup guards, or nondefaultable-local safety guards.

The current artifact selects only defined Func `164` under that policy. Its ten nullable reference params match the exact low default-argument owner identified in note `1574`.

## Rejected broad probes

All probes use a freshly rebuilt explicit native binary and the same stripped input `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

### Unfiltered exact/default worklist

The initial broad worklist applied `54` productive definitions from `57` through `4034`, including Func `164`:

- output `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-low-worklist.wasm`;
- valid under `wasm-tools validate --features all`;
- pass-local `10399.947ms`, within `1.29x` Binaryen's `8083.49ms`;
- raw `3201611`, or `+31` versus committed Starshine;
- canonical `3278453`, or `-353` versus committed Starshine;
- current-tool canonical WAT `179610835`, or `-4961` versus the regenerated committed baseline `179615796`.

Agent judgment: valid and within the performance target, but raw-size-losing. The unrelated broad candidate family is not a signable Starshine win and is rejected.

### Minimum-eight-parameter worklist

A temporary minimum-eight-parameter policy selected Funcs `164` and `180`:

- output `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-low-worklist-wide8.wasm`;
- valid;
- pass-local `3841.721ms`;
- raw `3201576` (`-4` versus committed);
- canonical `3278748` (`-58`);
- current-tool canonical WAT `179615082` (`-714`).

The aggregate is smaller, but Func `180` is a mixed scalar/reference family not identified by the current source/artifact owner. Its incremental effect relative to the final nullable-only output is `+16` raw / `-3` canonical / `-39` WAT bytes. Because it is individually raw-size-losing and not needed for the attributed chain, it is not retained.

## Retained current-artifact result

Final native binary after the wide nullable-default policy:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `ea43d5d5530b5195d6874216d68fe2b889f8dc07e56ec8a551f6f52d593f944e`.

Retained output:

- `.tmp/daeo-scheduled-current-artifact-20260713/starshine-direct-low-worklist-nullwide8.wasm`;
- SHA-256 `71b37ff9a74fa3c082959400f46a4443edd3dee7a33a4bc31957cb8c322fc910`; the output validates with `wasm-tools validate --features all`;
- raw `3201560`, `-20` versus committed Starshine and `+24139` versus Binaryen;
- canonical `3278751`, `-55` versus committed Starshine and `+16295` versus Binaryen;
- current-tool canonical WAT `179615121`, `-675` versus regenerated committed Starshine and `+346973` versus regenerated Binaryen `179268148`;
- pass-local `3646.647ms`, about `0.45x` Binaryen and comfortably within the target;
- whole command `4332ms` by monotonic shell timing;
- touched set grows from `22` to `24`, and the existing `large-touched-set` nested-cleanup guard still skips broad replay.

The retained slice is a measured all-dimensions Starshine improvement over the committed baseline, but it closes only `55/16350` prior canonical gap bytes. DAEO remains open.

## Signature-chain status

Using current Starshine `--print-func` diagnostics with `21` imported functions:

- defined Func `164` / absolute Func `185` changes from ten nullable reference params and broad result `(ref $731)` to zero params with the same broad result;
- Binaryen also removes all ten params, but refines the result to exact `(ref exact $770)` and removes the remaining body locals/debris;
- defined Func `39` / absolute Func `60` remains `[] -> (ref $731)` in Starshine, while Binaryen returns exact `$770`;
- defined Funcs `37`, `38`, and `41` retain their third params in Starshine; Binaryen removes them and refines their second params to exact `$770`.

The next owner is therefore no longer low-candidate starvation. It is narrow result refinement/body cleanup for Func `164`, followed by exact-reference and removable-param propagation through Funcs `39`, `37`, `38`, and `41`. Func `41` remains above the existing instruction guard, so the follow-up must not enable blanket nested cleanup.

## Validation and status

- red filtered-candidate white-box test failed before implementation and passes after it;
- full DAE white-box tests: `206/206`;
- public DAEO tests: `310/310`;
- `moon test src/passes`: `5346/5346`;
- `moon fmt`: green;
- native release build: green with existing warnings;
- retained current artifact: valid;
- no public API was intentionally changed.

The direct four-lane compare matrix remains stale after the behavior change and must be refreshed before closeout. Scheduled public `optimize` / `shrink` current-artifact evidence also remains pending until the direct chain is closed or every remaining divergence is a measured, source-backed Starshine win.
