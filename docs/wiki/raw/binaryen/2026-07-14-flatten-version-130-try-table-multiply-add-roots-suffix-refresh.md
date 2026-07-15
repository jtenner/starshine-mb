# Binaryen v130 `flatten`: dead multiply-drop then add-drop suffix roots

## Scope

This refresh audits one supported scalar legacy-try `br_table` followed by exactly one direct `drop(i32.mul(const, const))` root and then one independently owned direct `drop(i32.add(const, const))` root in the same arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-mul-add-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-mul-add-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves both dead roots as ordered unreachable flattened debris. It stages and drops the multiplication first, then stages and drops the addition, preserving source-root order and left-to-right operand order within each root. Payload staging remains before selector staging and catch routing remains independent.

Neither root can execute because `br_table` always transfers to one of its targets. Removing both complete independently owned subtrees is behavior-preserving for this exact heterogeneous order.

## Starshine admission

Starshine admits exactly `Drop(I32Mul(Const, Const)), Drop(I32Add(Const, Const))`. Each drop, binary node, and constant pair must be structurally exact. Complete suffix collection requires all eight nodes across both trees to be distinct with exactly one HOT use before mutation; all eight nodes are then detached and deleted together before existing terminal table routing.

Shared descendants, repeated roots, every third-rich-root combination, other mixed rich recognizers, nested trees, structured roots, and repair-sensitive EH remain gated. This is the separately source-probed reverse heterogeneous pair, not arbitrary composition of independently admitted roots.
