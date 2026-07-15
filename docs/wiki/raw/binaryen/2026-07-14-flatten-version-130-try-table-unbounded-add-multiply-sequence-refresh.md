# Binaryen v130 `flatten`: unbounded direct add/multiply suffix sequences

## Scope

This refresh audits supported scalar legacy-try `br_table` arms followed by alternating three-root sequences of direct `drop(i32.add(const, const))` and direct `drop(i32.mul(const, const))`, then generalizes Starshine from homogeneous sequences and exact heterogeneous pairs to any positive ordered sequence containing only those two exact root families.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-mul-add-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-mul-add-mul-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-mul-add-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-mul-add-mul-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S` for each probe.

## Observed contract

Binaryen v130 preserves both alternating sequences as ordered unreachable flattened debris. For each root it stages the binary in source-root order, preserves left-to-right constant operand order, then drops the staged value before proceeding to the next root. Payload staging remains before selector staging and catch routing remains independent. `Flatten.cpp` rebuilds the arm without a root-count or operator-order cap.

None of these suffix roots can execute because `br_table` unconditionally transfers to a target. Deleting the complete sequence is behavior-preserving only after every root is recognized as one exact direct add-drop or multiply-drop tree and every node across the whole suffix is exclusively owned.

## Starshine admission

Starshine now admits any positive ordered sequence whose roots are only direct `Drop(I32Add(Const, Const))` or direct `Drop(I32Mul(Const, Const))`. Complete suffix collection requires all drops, binaries, and constants across all roots to be distinct and one-use before mutation; every node is detached and deleted atomically before existing terminal table routing.

Shared descendants, repeated roots, subtraction or any other opcode, nested trees, call roots, structured roots, mixed `Unreachable` sequences outside separately audited exact pairs, and repair-sensitive EH remain gated. This is an unbounded sequence over two exact root recognizers, not generic composition of the broader single-root roster.
