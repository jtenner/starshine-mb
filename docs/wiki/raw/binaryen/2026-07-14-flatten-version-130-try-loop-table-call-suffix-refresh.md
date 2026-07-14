# Binaryen v130 `flatten`: try-to-loop tables with one dead void call suffix

## Scope

This refresh audits a supported scalar legacy-try `br_table` that targets both the try result and one directly enclosing inputful loop, followed by exactly one direct no-argument void `call` in the same try arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Direct-call probe: `.tmp/flatten-probes/scalar-try-table-call-suffix.wat`
- Direct-call output: `.tmp/flatten-probes/scalar-try-table-call-suffix.out.wat`
- Loop-ancestry probe: `.tmp/flatten-probes/scalar-try-loop-table-call-suffix.wat`
- Loop-ancestry output: `.tmp/flatten-probes/scalar-try-loop-table-call-suffix.out.wat`

Commands use the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves a direct void call after the unconditional table as unreachable debris. Separate loop-ancestry output confirms that payload staging, try-result copying, loop-entry copying, selector order, catch routing, and loop result routing remain distinct when a nonterminal suffix exists.

The call cannot execute because `br_table` always transfers to one of its targets. Removing it therefore does not suppress an observable side effect, even though a call is conservatively effectful in every reachable context.

## Starshine admission

Starshine admits only one direct `Call` root with zero children, zero results, and exactly one HOT use. The call is detached and deleted before existing terminal table routing. The verifier-backed route additionally proves the loop entry local remains distinct from the try result and loop result channels.

Calls with arguments or results, indirect/reference calls, shared call nodes, multiple non-`Unreachable` suffix roots, skipped ancestry, unsupported backedges, and repair-sensitive EH remain gated. This admission relies on unconditional transfer plus exact root ownership; it is not a general dead-call or effect analysis.
