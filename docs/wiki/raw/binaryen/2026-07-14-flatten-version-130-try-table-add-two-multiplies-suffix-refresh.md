# Binaryen v130 `flatten`: dead add-of-two-multiplies suffix

## Scope

This refresh audits one supported scalar legacy-try `br_table` followed by exactly one `drop(i32.add(i32.mul(const, const), i32.mul(const, const)))` root in the same arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-two-multiply-children-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-two-multiply-children-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves the dead nested arithmetic as unreachable flattened debris. It stages the left multiplication first, then the right multiplication, then the outer addition from those two local reads before dropping the result. This preserves left-to-right operand evaluation, both tree dependencies, and root order after the unconditional table. Payload staging remains before selector staging and catch routing remains independent.

The arithmetic cannot execute because `br_table` always transfers to one of its targets. Removing the complete exclusively owned eight-node subtree is behavior-preserving for this exact tree.

## Starshine admission

Starshine admits exactly `Drop(I32Add(I32Mul(Const, Const), I32Mul(Const, Const)))`. The drop, add, both multiplies, and four constants must all be distinct and have exactly one HOT use. All eight nodes are preflighted before mutation, then detached and deleted together before existing terminal table routing.

Shared descendants, repeated descendants, other outer or inner operators, deeper trees, multiple two-rich-child roots, structured roots, and repair-sensitive EH remain gated. This is one exact source-probed two-rich-child tree, not a recursive purity or effect classifier.
