# Binaryen v130 `flatten`: unbounded direct nontrapping binary suffix sequences

## Scope

This refresh audits supported scalar legacy-try `br_table` arms followed by four-root sequences over the direct constant-binary suffix families already admitted singly: `drop(i32.add(const, const))`, `drop(i32.sub(const, const))`, `drop(i32.mul(const, const))`, and `drop(i32.and(const, const))`.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-sub-mul-and-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-and-mul-sub-add-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-sub-mul-and-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-and-mul-sub-add-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves both four-root sequences as ordered unreachable flattened debris. It stages each binary in source-root order, preserves the left-to-right constant operands of noncommutative subtraction, drops the staged result, and then proceeds to the next root. The owner rebuilds block lists without an operator-order or suffix-count cap.

The suffix cannot execute because `br_table` unconditionally transfers to a target. Deleting it is behavior-preserving only after every root is recognized as one exact direct constant-binary tree and every node across the complete suffix is distinct and one-use.

## Starshine admission

Starshine now admits any positive ordered sequence whose roots are exact direct `Drop(I32Add(Const, Const))`, `Drop(I32Sub(Const, Const))`, `Drop(I32Mul(Const, Const))`, or `Drop(I32And(Const, Const))` trees. Complete suffix collection still proves suffix-wide node distinctness and one-use ownership before mutation, then detaches and deletes every owned node atomically before existing terminal-table routing.

Other binary opcodes, nested trees, calls, unary/conversion roots, trapping roots, structured roots, repeated roots, shared descendants, mixed `Unreachable` compositions outside separately audited exact families, and repair-sensitive EH remain gated.
