# Binaryen v130 `flatten`: dead drop-constant then unreachable suffix

## Scope

This refresh audits one supported scalar legacy-try `br_table` followed in source order by one direct `drop(const)` root and one direct `unreachable` root in the same arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-drop-const-unreachable-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-drop-const-unreachable-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves the direct drop after the table and preserves the trailing unreachable placeholder. The table's own unreachable placeholder appears first, then the original `drop(const)`, then the original trailing `unreachable`, so the audited source order remains visible in the flattened debris. Payload staging remains before selector staging and catch routing remains independent.

Neither suffix root can execute because `br_table` always transfers to one of its targets. Removing both complete owned roots is behavior-preserving for this exact ordered mixed suffix.

## Starshine admission

Starshine admits exactly two suffix roots in the order `Drop(Const), Unreachable`. The drop, its constant child, and the unreachable root must all be distinct; complete root-node collection requires one HOT use where applicable and rejects duplicate nodes before mutation. All three nodes are detached and deleted together before existing terminal table routing.

The reverse `Unreachable, Drop(Const)` order, three-root mixed suffixes, multiple drops mixed with unreachable roots, richer roots, structured roots, and repair-sensitive EH remain gated. This is an exact source-probed mixed-root exception, not a generic mixed suffix classifier.
