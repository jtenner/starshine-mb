# Binaryen v130 `flatten`: two dead multiply-drop suffix roots

## Scope

This refresh audits one supported scalar legacy-try `br_table` followed by exactly two independently owned direct `drop(i32.mul(const, const))` roots in the same arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-two-mul-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-two-mul-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves both dead multiplications and drops as ordered unreachable flattened debris. It stages the first multiplication and drop before the second multiplication and drop, preserving source-root order and each root's left-to-right operand order. Payload staging remains before selector staging and catch routing remains independent.

Neither multiply-drop root can execute because `br_table` always transfers to one of its targets. Removing both complete independently owned four-node subtrees is behavior-preserving for this exact ordered pair.

## Starshine admission

Starshine admits exactly two direct `Drop(I32Mul(Const, Const))` suffix roots. Each drop, multiply, and pair of constant children must be structurally exact; complete suffix collection then requires every node across both subtrees to be distinct with exactly one HOT use. All eight nodes are preflighted before mutation and deleted together before existing terminal table routing.

Shared descendants, repeated roots, a third multiply-drop root, mixed rich-root recognizers, other opcodes, nested trees, structured roots, and repair-sensitive EH remain gated. This is an exact source-probed two-root recognizer, not arbitrary composition of the single-root suffix roster.
