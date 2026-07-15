# Binaryen v130 `flatten`: two-constant-argument void calls inside dead suffix sequences

## Scope

This refresh audits exact direct resultless calls with two scalar constant arguments inside otherwise admitted ordered legacy-try `br_table` suffix sequences. The probes reverse the `i32`/`i64` argument type order so source-order ownership is explicit.

## Why this slice follows roster work

A higher-value mixed/nonexclusive table or loop extension was considered first. The remaining named boundaries require ambiguous/shared false-path ownership or broader channel reconstruction, so weakening those gates in this bounded slice would not be safe. This exact call/effect composition is representable with the existing dead-suffix ownership proof and does not alter control, label, loop-entry, or loop-result channels.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-call2-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-call2-divzero-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-call2-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-call2-divzero-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves both constant arguments in source order directly under the call, preserves the call between its surrounding suffix roots, and retains later unary or zero-divisor signed-division work. Reversing the scalar types in the second probe preserves the reversed argument order rather than canonicalizing it.

The arguments and call cannot execute because the preceding `br_table` transfers unconditionally. Starshine's deletion is therefore justified by exact unreachable-suffix ownership, not generic call-effect or argument-purity analysis.

## Starshine admission

The ordered suffix roster now accepts an exact direct resultless call with two distinct, one-use scalar `Const` children. The root collector returns the call and arguments in source order; suffix-wide collection rejects cross-root sharing or repetition before atomic deletion.

Repeated/shared arguments, three or more arguments, a rich argument mixed with a constant, result-carrying calls, indirect/reference calls, deeper arguments, structured roots, and repair-sensitive EH remain gated. Public flatten wiring remains removed.
