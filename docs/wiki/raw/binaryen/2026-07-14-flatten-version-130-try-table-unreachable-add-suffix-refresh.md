# Binaryen v130 `flatten`: dead unreachable then add-drop suffix

## Scope

This refresh audits one supported scalar legacy-try `br_table` followed by exactly one direct `unreachable` root and then one direct `drop(i32.add(const, const))` root in the same arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-unreachable-add-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-unreachable-add-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves the direct unreachable first, then stages the dead addition before its drop as later unreachable flattened debris. The output retains source-root order and the addition's left-to-right operand order after the unconditional table. Payload staging remains before selector staging and catch routing remains independent.

Neither suffix root can execute because `br_table` always transfers to one of its targets. Removing the direct unreachable together with the complete exclusively owned add-drop tree is behavior-preserving for this exact order.

## Starshine admission

Starshine admits exactly `Unreachable, Drop(I32Add(Const, Const))`. The unreachable, drop, add, and two constants must all be distinct; the add subtree must have one HOT use per node. All five nodes are collected and preflighted before mutation, then detached and deleted together before existing terminal table routing.

Every three-root combination, shared or repeated descendants, other rich roots, structured roots, and repair-sensitive EH remain gated. This completes the two audited orders for this exact rich/unreachable pair; it does not generalize arbitrary mixed-root composition.
