# Binaryen v130 `flatten`: homogeneous dead direct drop-constant suffix roots

## Scope

This refresh audits a supported scalar legacy-try `br_table` followed by three direct `drop(const)` roots and removes Starshine's exact-two count cap for that homogeneous family.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-three-drop-const-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-three-drop-const-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves all three drops and constants as ordered unreachable debris after the unconditional table. `Flatten.cpp` rebuilds every block list by appending each item's preludes and the item itself; it has no suffix-root count cap. Payload staging remains before selector staging, the table becomes payloadless, catch routing remains independent, and suffix order remains source order.

No suffix root can execute because `br_table` always transfers to one of its targets. Removing the complete owned suffix is behavior-preserving for any positive homogeneous sequence of direct `drop(const)` roots.

## Starshine admission

Starshine admits any positive number of direct `Drop(Const)` suffix roots. Every root and constant child must be distinct, and every node must have exactly one HOT use. The entire ordered suffix is preflighted before mutation, then detached and deleted as one unit before existing terminal table routing.

Shared children, repeated roots, mixed root kinds, richer trees, structured roots, and repair-sensitive EH remain gated. This removes only the count cap from one homogeneous ownership proof; it is not general multi-root dead-code elimination.
