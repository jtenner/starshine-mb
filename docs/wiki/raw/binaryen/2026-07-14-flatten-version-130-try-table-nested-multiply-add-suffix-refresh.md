# Binaryen v130 `flatten`: dead nested multiply-add suffix

## Scope

This refresh audits one supported scalar legacy-try `br_table` followed by exactly one `drop(i32.add(i32.mul(const, const), const))` root in the same arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-nested-mul-add-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-nested-mul-add-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves the dead nested arithmetic as unreachable flattened debris. It stages the left multiply before the outer add, and the outer add reads the multiply result before evaluating its right constant, preserving left-to-right operand evaluation and tree dependency order after the unconditional table. Payload staging remains before selector staging and catch routing remains independent.

The arithmetic cannot execute because `br_table` always transfers to one of its targets. Removing the complete exclusively owned six-node subtree is behavior-preserving for this exact opposite orientation.

## Starshine admission

Starshine admits exactly `Drop(I32Add(I32Mul(Const, Const), Const))`, complementing the separately audited `Drop(I32Add(Const, I32Mul(Const, Const)))` orientation. The drop, add, multiply, outer constant, and both multiply constants must all be distinct and have exactly one HOT use. All six nodes are preflighted before mutation, then detached and deleted together before existing terminal table routing.

Shared descendants, repeated descendants, other nested operators, deeper trees, multiple nested rich roots, structured roots, and repair-sensitive EH remain gated. This is the second exact source-probed two-level tree orientation, not a recursive purity or effect classifier.
