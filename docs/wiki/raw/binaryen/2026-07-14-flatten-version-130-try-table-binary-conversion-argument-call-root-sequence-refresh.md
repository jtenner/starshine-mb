# Binaryen v130 `flatten`: binary-plus-conversion dead suffix call arguments

## Scope

This refresh audits exact direct resultless two-argument calls with one already admitted binary tree and one already admitted signed-conversion tree inside otherwise admitted ordered legacy-try `br_table` suffix sequences. The probes cover `i32.add(const, const)` before `i64.extend_i32_s(const)` and `i64.extend_i32_s(const)` before trapping `i32.div_s(const, const)`.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-calladdextend-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-callextenddiv-unreachable-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-calladdextend-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-callextenddiv-unreachable-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 evaluates each rich subtree completely in immediate argument order. The first probe preserves add operands and operation before the conversion input and operation. The second preserves the conversion before signed-division operands and the trapping operation. The calls remain between surrounding suffix roots, with later unary work or direct `unreachable` retained.

The calls cannot execute because the preceding `br_table` transfers unconditionally. Starshine deletes only the exact completely owned unreachable suffix; conversion and trapping behavior are not treated as generically removable.

## Starshine admission

The exact two-rich collector now accepts one `i32.add(const, const)` or `i32.div_s(const, const)` argument and one `i64.extend_i32_s(const)` argument in either immediate order, in addition to the prior binary-plus-unary pair. Collection records both immediate arguments first, then records each argument's constant children in argument order. Every call argument and descendant must be distinct and one-use, and suffix-wide collection rejects cross-root sharing before atomic deletion.

Two binary-rich arguments, unary-plus-conversion pairs, two unary/conversion-rich arguments, three-or-more rich vectors, alternate opcodes, additional arguments, shared descendants, result calls, indirect/reference calls, deeper trees, structured roots, and repair-sensitive EH remain gated. Public flatten wiring remains removed.
