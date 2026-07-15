# Binaryen v130 `flatten`: dead subtract-multiply-by-constant suffix

## Scope

This refresh audits one supported scalar legacy-try `br_table` followed by exactly one `drop(i32.sub(i32.mul(const, const), const))` root in the same arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-sub-mul-const-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-sub-mul-const-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves the dead nested arithmetic as unreachable flattened debris. It stages the left-hand multiplication first, then forms the outer subtraction with the staged multiply as the left operand and the original constant as the right operand, then drops the result. This preserves noncommutative operand identity and left-to-right evaluation. Payload staging remains before selector staging and catch routing remains independent.

The arithmetic cannot execute because `br_table` always transfers to one of its targets. Removing the complete exclusively owned six-node subtree is behavior-preserving for this exact tree.

## Relationship to the prior orientation audit

This direct probe closes the pending opposite-orientation gate recorded in `2026-07-14-flatten-version-130-try-table-subtract-const-multiply-suffix-refresh.md`. It does not supersede that page's right-rich evidence; together the two pages support the exact pair of one-rich-child subtraction orientations.

## Starshine admission

Starshine admits exactly `Drop(I32Sub(I32Mul(Const, Const), Const))`. The drop, subtraction, multiplication, multiply constants, and outer constant must all be distinct with exactly one HOT use. The shared recognizer receives the audited orientation explicitly, preflights all six nodes before mutation, then detaches and deletes the complete tree before existing terminal table routing.

Other inner operators, deeper trees, shared or repeated descendants, multiple nested roots, structured roots, and repair-sensitive EH remain gated. This is the separately source-probed opposite noncommutative orientation, not recursive arithmetic admission.
