# DAE002 call-summary runtime attribution

Date: 2026-05-12

## Question

Why did the debug-artifact `--dae-optimizing` replay time out before the nested cleanup marker after the guarded touched-cleanup scheduler slice, and can that be improved without broadening the nested cleanup lane or changing direct DAE semantics?

## Finding

The timeout was inside the DAE core, before touched nested cleanup. Two hot families were doing repeated broad scans on the 4,671-defined-function debug artifact:

- original call fact collection recomputed per-callee call counts by rescanning functions for each callee;
- dead-suffix preservation helpers repeatedly asked whether each candidate callee appeared in a caller suffix instead of collecting the suffix's direct-call targets once.

`src/passes/dead_argument_elimination.mbt` now builds a single `DaeOriginalCallSummary` over direct-call targets and undropped-call targets, replacing the repeated original call-count collectors used by the DAE core. It also collects dead-suffix direct-call targets once for the broad preservation-count families that blocked the artifact before the nested marker, and it precomputes the escape bitmap for dead-suffix self-operand origin tracking instead of rebuilding it while scanning each call.

This is intended as a behavior-preserving runtime attribution/fix. It does not change the guarded touched-function nested cleanup scheduler, does not add a whole-module nested cleanup lane, and does not implement `precompute-propagate`.

## Evidence

Before this attribution pass, a traced artifact command timed out after 30s while still at:

```text
pass[dead-argument-elimination-optimizing]:start
```

and no nested cleanup marker appeared.

After the call-summary and suffix-target aggregation change, the same traced direct command completes and reaches the guarded nested cleanup skip:

```sh
timeout 30s target/native/release/build/cmd/cmd.exe \
  --tracing pass \
  --dead-argument-elimination-optimizing \
  --out .tmp/trace-dae-call-summary-final.wasm \
  tests/node/dist/starshine-debug-wasi.wasm
```

Result:

- exit `0`;
- nested marker emitted with `touched=12`;
- guarded nested cleanup skipped as `reason=large-touched-set`;
- Starshine traced pass timer remained under the 30s timeout; recorded traced post-fix runs ranged from about `6.87s` to `8.03s` locally.

Direct fuzz frontier remained unchanged:

- `.tmp/dae002-call-summary-200`: `199/200` compared, `198` normalized matches, `1` mismatch, `0` validation failures, `1` Binaryen/tool command failure.
- `.tmp/dae002-call-summary-1000`: `998/1000` compared, `985` normalized matches, `13` mismatches, `0` validation failures, `2` Binaryen/tool command failures.

Artifact replay is now feasible again but still red:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --out-dir .tmp/dae002-call-summary-artifact-final3 \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing
```

Result:

- first differing function remains `defined=11 abs=28`;
- Starshine runtime `7659.977ms`;
- Binaryen runtime `1379.697ms`;
- Starshine pass runtime `6945.212ms`;
- Binaryen pass runtime `927.876ms`.

Same-source artifact replays varied locally (`6833.433ms`, `10228.070ms`, and one outlier `17812.881ms` Starshine pass time), but every completed replay agrees on the durable conclusion: the 30s+ pre-marker timeout was removed, artifact comparison is feasible again, and DAE remains slower than the desired Binaryen pass-local speed floor.

## Conclusion

The current artifact runtime discrepancy is no longer an unexplained nested-cleanup issue. The first blocker was repeated DAE core scanning before the nested marker. That has been reduced enough for replay, with unchanged direct-fuzz parity shape.

Remaining `[DAE]002` runtime work is still open: the DAE core is usually about `7x` slower than Binaryen on the debug artifact in the recorded post-fix replays, and broader nested cleanup work should still wait for a performant touched-function default pipeline and real `precompute-propagate` support.
