# DAE004 singleton fallback 445 removal

Date: 2026-05-26

## Scope

Recovery/completion slice for `[DAE004-D3]` and the first narrow `[DAE004-D4]` behavior change: prove that one smallest selected dropped-result singleton no longer needs a handpicked fallback entry, then remove that entry from the selected fallback list.

## Test-first evidence

Added `dae-optimizing reaches singleton fallback-neighborhood dropped result through fact path` in `src/passes/dae_optimizing_test.mbt`.

The fixture builds a broad-large module with a one-call singleton callee at defined function `445` plus eight high dropped-result candidates near `4644..4651`. It asserts that DAE removes Func445's result and, more importantly, that no selected-fallback trace candidate or selected-fallback primary-def line for `445` appears.

Initial focused validation failed before the implementation change:

```sh
moon test src/passes -f 'dae-optimizing reaches singleton fallback-neighborhood dropped result through fact path'
```

The failure showed the result was already removed by the ordinary DAE core (`pass[dae-optimizing]:core iter=0 primary_def=445`), but the selected fallback loop still traced `selected-dropped-result-candidate def=445`. That made `445` a safe first singleton to retire from the handpicked selected dropped-result fallback list without broadening the large-module fact scheduler.

## Implementation

Removed `445` from the hardcoded selected dropped-result fallback loop in `src/passes/dead_argument_elimination.mbt`.

This is intentionally narrower than the rejected broad bucketed switch from note `0632`: it does not raise the broad-large productive cap, does not enable the staged bucketed collector, and does not remove any other singleton (`3834`, `4106`, or `4249`).

## Focused and artifact validation

After removing `445`, the focused regression passed:

```sh
moon test src/passes -f 'dae-optimizing reaches singleton fallback-neighborhood dropped result through fact path'
```

The pass trace still shows Func445 handled by the normal core path in the synthetic broad-large regression, and no selected fallback candidate for `445` remains.

A debug-artifact direct replay using the freshly built native debug command also validated and produced no selected-fallback trace for `445`:

```sh
_build/native/debug/build/cmd/cmd.exe --tracing pass --dae-optimizing \
  -o .tmp/dae004-445-artifact/out-debug.wasm \
  tests/node/dist/starshine-debug-wasi.wasm \
  > .tmp/dae004-445-artifact/stdout-debug.txt \
  2> .tmp/dae004-445-artifact/stderr-debug.txt
wasm-opt --all-features .tmp/dae004-445-artifact/out-debug.wasm \
  -o /tmp/dae004-445-debug-validated.wasm
grep 'selected-dropped-result-candidate def=445\|selected-dropped-result primary_def=445' \
  .tmp/dae004-445-artifact/stderr-debug.txt || true
```

The `wasm-opt` command succeeded with only the existing large-local-count VM warning, and `grep` printed no matches.

## Status

`[DAE004-D3]` is complete for the first singleton (`445`), and `[DAE004-D4]` has one narrow family-specific removal. `[DAE004-D]` remains open for artifact validation/timing/compare evidence and for any additional singleton or family removals.
