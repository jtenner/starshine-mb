# Binaryen v130 `flatten`: unary/conversion dead suffix call pairs

## Scope

This refresh audits exact direct resultless two-argument calls whose arguments are drawn from the already admitted `i32.clz(const)` and `i64.extend_i32_s(const)` trees inside otherwise admitted ordered legacy-try `br_table` suffix sequences. It covers both mixed immediate orders and both same-class pairs.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-callclzextend-divzero-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-callextendclz-unreachable-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-add-callclzclz-divzero-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-callextendextend-unreachable-suffix.wat`
- Outputs use the same basenames with `.out.wat`.

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 evaluates each unary or conversion subtree completely in immediate argument order. Mixed pairs retain `clz` before signed extension and signed extension before `clz`; same-class pairs retain both distinct inputs and operations in source order. The calls remain between surrounding suffix roots, with later zero-divisor work or direct `unreachable` retained.

The calls cannot execute because the preceding `br_table` transfers unconditionally. Starshine deletes only the exact completely owned unreachable suffix; neither unary nor conversion behavior is treated as generically removable.

## Starshine admission

The exact two-rich collector now accepts every two-argument pair drawn from exact `i32.clz(const)` and `i64.extend_i32_s(const)` trees. This is a structural two-rich contract, not a same-class count cap. Collection records both immediate arguments first, then their distinct one-use inputs in argument order. Suffix-wide collection rejects cross-root sharing before atomic deletion.

Same-opcode binary pairs, three-or-more rich vectors, additional arguments, alternate opcodes, shared descendants, result calls, indirect/reference calls, deeper trees, structured roots, and repair-sensitive EH remain gated. Public flatten wiring remains removed.
