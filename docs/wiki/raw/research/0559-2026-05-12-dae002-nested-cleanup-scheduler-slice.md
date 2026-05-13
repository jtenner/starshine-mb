# DAE002 nested cleanup scheduler slice

Date: 2026-05-12

## Question

Can Starshine safely move `dae-optimizing` beyond a trace-only nested cleanup marker without reviving the prior whole-module cleanup lane that rewrote untouched functions?

## Implementation finding

A narrow touched-function scheduler now exists in `src/passes/pass_manager.mbt` for the `dae-optimizing` / `dead-argument-elimination-optimizing` module-pass dispatcher path.

Current scope is deliberately smaller than Binaryen's full `OptUtils::optimizeAfterInlining(...)` contract:

- it uses DAE's existing touched defined-function bitmap rather than running cleanup over the whole module;
- it runs a small local cleanup subset, currently `dead-code-elimination -> simplify-locals -> vacuum`, on touched functions only;
- it leaves `precompute-propagate` as a trace-visible upstream prefix requirement, not as a local implementation claim;
- it skips the nested lane for broad or large modules (`>100` defined functions, `>8` touched functions, or a touched function over the local size guard) until a faster filtered batch runner and the real `precompute-propagate` sibling exist.

This is a scheduler-safety slice, not completion of `[DAE]002`.

## Tests

Focused tests in `src/passes/dae_optimizing_test.mbt` now prove two nested-lane properties:

- touched callee cleanup can remove DAE-created dead local traffic;
- an equivalent dead-local cleanup opportunity in an untouched exported sibling remains unchanged.

The older value-producing `if` removed-actual test was adjusted to assert the durable semantic property after nested cleanup: side-effecting operands are preserved (`global.set` remains), while now-dead pure value materialization can be removed by cleanup.

## Direct fuzz evidence

After the scheduler slice and narrow cleanup guard:

- `.tmp/dae002-mincleanup-200`: `199/200` compared, `198` normalized matches, `1` mismatch, `0` validation failures, and `1` Binaryen/tool command failure (`binaryen-rec-group-zero`).
- `.tmp/dae002-mincleanup-1000`: `998/1000` compared, `985` normalized matches, `13` mismatches, `0` validation failures, and `2` Binaryen/tool command failures.

Those counts match the prior DAE001 local-declaration frontier shape; no new non-local-declaration direct semantic regression was exposed by this probe.

## Artifact evidence and blocker

The debug-artifact replay remains red at the same first differing function family:

- `.tmp/dae002-nested-artifact-mincleanup2`
- command: `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --out-dir .tmp/dae002-nested-artifact-mincleanup2 --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing`
- result: first differing function `defined=11 abs=28`.

In this session the direct artifact command was unexpectedly very slow (`~296s` Starshine pass time versus `~945ms` Binaryen in the final replay). A traced manual run timed out after 20s while still inside `pass[dead-argument-elimination-optimizing]:start`, before the nested cleanup marker was emitted, so the observed artifact slowness should not be attributed solely to the narrow nested cleanup subset. The prior backlog evidence still records a faster `.tmp/dae-optimizing-artifact-replay-finish2` run; this discrepancy needs a separate runtime attribution pass before `[DAE]002` can be closed.

## Conclusion

The safe next state is:

1. keep the small touched-function cleanup scheduler and regression coverage;
2. keep `[DAE]002` open for the real `precompute-propagate` + default-function-pipeline replay;
3. do not enable a broad nested lane on large artifact modules until the filtered scheduler is performant;
4. keep the artifact compare red at `defined=11 abs=28` and investigate the current artifact runtime discrepancy separately from direct-fuzz local-declaration drift.
