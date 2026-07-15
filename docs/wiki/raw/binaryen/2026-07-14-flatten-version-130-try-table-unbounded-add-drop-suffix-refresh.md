# Binaryen v130 `flatten`: unbounded homogeneous add-drop suffix roots

## Scope

This refresh audits one supported scalar legacy-try `br_table` followed by three independently owned direct `drop(i32.add(const, const))` roots in the same arm, and removes Starshine's prior exact-two cap for that homogeneous family.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-three-add-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-three-add-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves all three additions and drops as ordered unreachable flattened debris. It stages each addition and drop in source-root order, with left-to-right operand order inside each root. Payload staging remains before selector staging and catch routing remains independent. `Flatten.cpp` rebuilds the arm without imposing a suffix-root count limit.

No suffix root can execute because `br_table` unconditionally transfers to a target. Deleting the complete suffix is behavior-preserving only after every drop, addition, and constant child is proven part of the exact homogeneous family and exclusively owned.

## Starshine admission

Starshine now admits any positive number of direct `Drop(I32Add(Const, Const))` suffix roots. Complete suffix collection requires every node across every tree to be distinct and one-use before mutation; all nodes are detached and deleted together before existing terminal table routing.

Shared descendants, repeated roots, mixed add/multiply sequences beyond the separately audited family, other opcodes, nested trees, structured roots, and repair-sensitive EH remain gated. This removes an arbitrary count cap without generalizing the structural family.
