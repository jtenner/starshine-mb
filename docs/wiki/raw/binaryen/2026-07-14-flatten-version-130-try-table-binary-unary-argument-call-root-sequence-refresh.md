# Binaryen v130 `flatten`: binary-plus-unary dead suffix call arguments

## Scope

This refresh audits exact direct resultless two-argument calls with one already admitted binary tree and one already admitted unary tree inside otherwise admitted ordered legacy-try `br_table` suffix sequences. The probes cover `i32.add(const, const)` before `i32.clz(const)` and `i32.clz(const)` before trapping `i32.div_s(const, const)`.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-calladdclz-divzero-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-callclzdiv-unreachable-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-calladdclz-divzero-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-callclzdiv-unreachable-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 evaluates each rich argument subtree completely in immediate argument order. The first probe preserves add operands, add, unary input, unary operation, and then the call. The second preserves unary input and operation before signed-division operands and the trapping operation. The calls remain between surrounding suffix roots, with later zero-divisor work or direct `unreachable` retained.

The calls cannot execute because the preceding `br_table` transfers unconditionally. Starshine deletes only the exact completely owned unreachable suffix; it does not classify either rich argument as generically pure, nontrapping, or removable.

## Starshine admission

An exact two-argument resultless direct call now admits one `i32.add(const, const)` or `i32.div_s(const, const)` argument and one `i32.clz(const)` argument in either immediate order. Collection records both immediate arguments first, then records each argument's constant children in argument order. Every call argument and descendant must be distinct and one-use, and suffix-wide collection rejects cross-root sharing before atomic deletion.

Binary-plus-conversion pairs, two binary-rich arguments, unary-plus-conversion pairs, two unary-rich arguments, alternate opcodes, additional arguments, shared descendants, result calls, indirect/reference calls, deeper trees, structured roots, and repair-sensitive EH remain gated. Public flatten wiring remains removed.
