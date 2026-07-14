# Binaryen v130 `flatten`: exactly two dead direct drop-constant suffix roots

## Scope

This refresh audits a supported scalar legacy-try `br_table` followed by exactly two direct `drop(const)` roots in the same try arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-two-drop-const-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-two-drop-const-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves both drops and constants as unreachable debris after the unconditional table. Payload staging remains before selector staging, the table becomes payloadless, catch routing remains independent, and the two suffix roots retain source order.

Neither drop can execute because `br_table` always transfers to one of its targets. Removing both complete owned roots is behavior-preserving for this exact four-node suffix.

## Starshine admission

Starshine admits exactly two direct `Drop(Const)` suffix roots. The two roots and two constant children must all be distinct, and every node must have exactly one HOT use. All four nodes are preflighted before mutation, then detached and deleted together before existing terminal table routing.

A shared child, a repeated root, a third non-`Unreachable` root, mixed root kinds, richer trees, structured roots, and repair-sensitive EH remain gated. This is an exact unconditional-transfer plus complete-suffix-ownership proof, not general multi-root dead-code elimination.
