# Binaryen v130 `flatten`: unary/conversion-plus-constant void calls inside dead suffix sequences

## Scope

This refresh audits exact direct resultless calls with two arguments where one argument is an already-audited `i32.clz(const)` or `i64.extend_i32_s(const)` tree and the other is a direct scalar constant. The probes cover rich-first and constant-first order and retain later trapping or direct-unreachable suffix work.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-callclzconst-divzero-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-and-callconstextend-unreachable-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-callclzconst-divzero-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-and-callconstextend-unreachable-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves the `clz` input before the unary operation and keeps that rich argument before the later scalar constant in the first call. The second probe preserves the scalar constant before the signed-extension input and operation. Both calls remain in source order relative to surrounding roots; the first retains a later zero-divisor signed division and the second retains direct `unreachable` debris.

The arguments and call cannot execute because the preceding `br_table` transfers unconditionally. Starshine deletes only the exact fully owned suffix; the proof does not classify calls, unary operations, conversions, or traps as generically removable.

## Starshine admission

The two-argument collector now accepts exactly one direct scalar constant plus either exact `i32.clz(const)` or exact `i64.extend_i32_s(const)`, in either argument order. Immediate argument order is preserved before the nested input node is collected. The call, rich argument, input, and constant must all be distinct; every non-root node has one use; suffix-wide collection rejects cross-root sharing before atomic deletion.

Two rich arguments, alternate unary/conversion opcodes, repeated/shared descendants, three or more arguments, result calls, indirect/reference calls, deeper trees, structured roots, and repair-sensitive EH remain gated. Public flatten wiring remains removed.
