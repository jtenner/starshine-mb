# Binaryen v130 `flatten`: one bounded deeper two-multiply-child root inside dead suffix sequences

## Scope

This refresh audits one exact deeper drop tree inside otherwise admitted ordered legacy-try `br_table` suffix sequences. The admitted shapes are:

- `drop(i32.add(i32.add(mul(const, const), mul(const, const)), const))`
- `drop(i32.sub(const, i32.sub(mul(const, const), mul(const, const))))`

The first probe covers the rich-left commutative orientation; the second preserves both inner and outer noncommutative subtraction orientation.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-and-deepadd-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-deepsub-divzero-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-and-deepadd-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-deepsub-divzero-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves both inner multiplications before the inner add or subtraction, then preserves the direct outer constant and outer operation before the drop. Surrounding suffix roots remain in source order. The subtraction probe retains a later zero-divisor `i32.div_s`, so noncommutative orientation and later trap placement are both explicit.

The complete tree cannot execute because the preceding `br_table` transfers unconditionally. Starshine's deletion is therefore justified by exact unreachable-suffix ownership, not recursive purity or arbitrary-tree reasoning.

## Starshine admission

Starshine admits only the two exact ten-node trees above. Every drop, outer operation, direct constant, inner operation, multiplication, and leaf must be distinct and one-use; suffix-wide collection separately rejects cross-root sharing or repetition before atomic deletion.

The opposite subtraction orientation, outer multiply or another opcode, a different inner operation, another nesting level, repeated/shared descendants, arbitrary recursive trees, structured roots, and repair-sensitive EH remain gated.
