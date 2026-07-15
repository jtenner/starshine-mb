# Binaryen v130 `flatten`: one rich argument among constant call vectors

## Scope

This refresh audits direct resultless calls with exactly one already admitted rich argument and one or more distinct scalar constants at arbitrary argument positions inside otherwise admitted ordered legacy-try `br_table` suffix sequences. The probes place an exact `i32.add(const, const)` in the middle of a three-argument vector and an exact `i64.extend_i32_s(const)` last in a four-argument vector.

## Control-family re-audit

The existing shared multivalue loop `br_if` boundary remains representation-blocked. Its extra false-path use is manufactured by reusing one HOT node id after lift, while Binaryen tree IR cannot directly express one expression object as both the branch payload and an additional sibling consumer. No new v130 source shape proves equivalent ownership, so the family remains fail-closed rather than being admitted from verifier success alone.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-callconstaddconst-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-call3constextend-divzero-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-callconstaddconst-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-call3constextend-divzero-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves immediate argument order with the rich argument in a non-edge position, preserves each rich subtree's input or left-to-right operands before the operation, keeps the call between surrounding suffix roots, and retains later unary or zero-divisor signed-division work.

The call and its arguments cannot execute because the preceding `br_table` transfers unconditionally. Starshine's smaller deletion remains justified only by complete exact unreachable-suffix ownership, not by generic call-effect, purity, or trap analysis.

## Starshine admission

A direct resultless call now admits exactly one audited rich argument—`i32.add(const, const)`, `i32.div_s(const, const)`, `i32.clz(const)`, or `i64.extend_i32_s(const)`—plus any positive number of distinct one-use scalar constants at any argument positions. Collection preserves the complete immediate argument vector first, then owns the rich argument's constant children. Every node must be distinct and one-use, and suffix-wide collection still rejects cross-root sharing before atomic deletion.

Two rich arguments, alternate rich opcodes, repeated/shared descendants, result calls, indirect/reference calls, deeper trees, structured roots, and repair-sensitive EH remain gated. Public flatten wiring remains removed.
