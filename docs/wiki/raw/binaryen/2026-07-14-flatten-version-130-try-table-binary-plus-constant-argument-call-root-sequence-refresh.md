# Binaryen v130 `flatten`: binary-plus-constant void calls inside dead suffix sequences

## Scope

This refresh audits exact direct resultless calls with two arguments where one argument is an already-audited `i32.add(const, const)` or `i32.div_s(const, const)` tree and the other is a direct scalar constant. The probes cover both argument orders and retain later unary, trapping, or direct-unreachable suffix work.

## Control-family audit before fallback

The existing shared multivalue loop `br_if` boundary was reviewed first. Its extra HOT use is created by manually reusing one payload node id after lifting; Binaryen's tree IR cannot express that same expression object as both the branch payload and an additional sibling consumer. Without a direct v130 source shape proving equivalent ownership, that DAG-specific boundary remains fail-closed. Broader mixed table/control candidates still require ambiguous channel reconstruction. This call slice instead reuses the complete dead-suffix ownership proof without changing labels, loop entry/result channels, or EH repair gates.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-calladdconst-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-callconstdiv-unreachable-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-calladdconst-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-callconstdiv-unreachable-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves argument order in both directions: rich binary then scalar constant, and scalar constant then trapping signed division. It preserves each binary's left-to-right constant operands, keeps the call between its surrounding suffix roots, and retains later unary work or direct `unreachable` debris.

The argument trees and call cannot execute because the preceding `br_table` transfers unconditionally. Starshine's deletion is therefore justified only by complete exact suffix ownership, not by generic call-effect, purity, or trap analysis.

## Starshine admission

The ordered suffix roster now accepts an exact resultless direct call with two distinct arguments when exactly one is a direct scalar constant and the other is exact `i32.add(const, const)` or `i32.div_s(const, const)`. The collector preserves immediate argument order, then owns both binary children; every non-root node must have one use, all subtree nodes must be distinct, and suffix-wide collection still rejects cross-root sharing before atomic deletion.

Unary/conversion-plus-constant pairs, two rich arguments, repeated/shared descendants, three or more arguments, result calls, indirect/reference calls, deeper trees, structured roots, and repair-sensitive EH remain gated. Public flatten wiring remains removed.
