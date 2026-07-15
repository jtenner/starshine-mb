# Binaryen v130 `flatten`: two-binary dead suffix call arguments

## Scope

This refresh audits exact direct resultless two-argument calls with one `i32.add(const, const)` tree and one trapping `i32.div_s(const, const)` tree inside otherwise admitted ordered legacy-try `br_table` suffix sequences. Both immediate argument orders are covered.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-calladddiv-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-calldivadd-unreachable-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-calladddiv-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-calldivadd-unreachable-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 evaluates each binary subtree completely in immediate argument order. The first probe preserves addition before signed division; the second preserves signed division, including its zero-divisor trap, before addition. The calls remain between surrounding suffix roots, with later unary work or direct `unreachable` retained.

The calls cannot execute because the preceding `br_table` transfers unconditionally. Starshine deletes only the exact completely owned unreachable suffix; neither binary family is treated as generically pure, nontrapping, or removable.

## Starshine admission

The exact two-rich collector now accepts one `i32.add(const, const)` argument and one `i32.div_s(const, const)` argument in either immediate order. Collection records both immediate arguments first, then each argument's constant children in argument order. Every call argument and descendant must be distinct and one-use, and suffix-wide collection rejects cross-root sharing before atomic deletion.

Same-opcode binary pairs, unary-plus-conversion and same-class unary/conversion pairs, three-or-more rich vectors, additional arguments, alternate opcodes, shared descendants, result calls, indirect/reference calls, deeper trees, structured roots, and repair-sensitive EH remain gated. Public flatten wiring remains removed.
