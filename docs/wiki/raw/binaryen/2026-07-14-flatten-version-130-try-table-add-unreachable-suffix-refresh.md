# Binaryen v130 `flatten`: dead add-drop then unreachable suffix

## Scope

This refresh audits one supported scalar legacy-try `br_table` followed by exactly one direct `drop(i32.add(const, const))` root and then one direct `unreachable` root in the same arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-add-unreachable-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-add-unreachable-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves the dead addition, drop, and following unreachable as ordered unreachable flattened debris. It stages the addition before its drop and retains the later unreachable root, preserving source-root and left-to-right operand order after the unconditional table. Payload staging remains before selector staging and catch routing remains independent.

Neither suffix root can execute because `br_table` always transfers to one of its targets. Removing the complete exclusively owned add-drop tree together with the direct unreachable root is behavior-preserving for this exact order.

## Starshine admission

Starshine admits exactly `Drop(I32Add(Const, Const)), Unreachable`. The drop, add, two constants, and unreachable must all be distinct; the add subtree must have one HOT use per node. All five nodes are collected and preflighted before mutation, then detached and deleted together before existing terminal table routing.

The reverse order, every three-root combination, shared or repeated descendants, other rich roots, structured roots, and repair-sensitive EH remain gated. This is one exact source-probed mixed two-root order, not arbitrary composition of the single-root suffix roster.
