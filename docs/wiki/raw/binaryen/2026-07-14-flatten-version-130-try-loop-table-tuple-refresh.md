# Binaryen v130 `flatten`: explicit tuple payload from a legacy try into an inputful loop

## Scope

This refresh follows the scalar/independently scalar try-to-loop table slice with an explicit Binaryen tuple-valued `br_table` payload. It audits Starshine's repeated-HOT-`TupleMake` representation boundary before admission.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/multivalue-try-loop-table-tuple-payload.wat`
- Output: `.tmp/flatten-probes/multivalue-try-loop-table-tuple-payload.out.wat`

Command:

```sh
WASM_OPT=/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt
"$WASM_OPT" --version
"$WASM_OPT" --all-features --flatten -S .tmp/flatten-probes/multivalue-try-loop-table-tuple-payload.wat -o .tmp/flatten-probes/multivalue-try-loop-table-tuple-payload.out.wat
```

## Observed contract

The explicit `(tuple i32 i64)` payload confirms the same owner contract as `Flatten.cpp` lines 311-326:

1. The tuple components execute once and in source order.
2. The concrete tuple is staged before selector evaluation.
3. The staged tuple is copied into both the try result channel and loop input channel.
4. The loop input vector is independent from the loop result vector even when their types are equal.
5. The table becomes payloadless.
6. Catch fallthrough writes the try channel independently.
7. The flattened module remains valid with all features enabled.

## HOT representation audit

HOT stores the same tuple producer id in each scalar branch slot while body locals remain scalar `ValType` lanes. Safe Starshine admission therefore requires all of the following before mutation:

- every table payload slot names the same `TupleMake` node;
- use sites are exactly the table payload slots and no others;
- tuple result types and component count exactly match the target vector;
- every component has one scalar result, the exact expected type, a supported origin, and a defaultable type;
- component evaluation order is preserved;
- the tuple shell is deleted only after payload staging and target-copy preflight succeeds;
- loop backedge preflight recognizes the exact tuple table shape rather than treating the tuple id as one scalar lane;
- try result, loop entry, and loop result locals remain distinct.

Shared tuples, mixed tuple/scalar payloads, arbitrary tuple producers, nondefaultable lanes, skipped ancestry, and unsupported loop backedges remain fail-closed.
