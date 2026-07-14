# Binaryen v130 `flatten`: one dead pure binary drop suffix

## Scope

This refresh audits a supported scalar legacy-try `br_table` followed by exactly one direct `drop(i32.add(const, const))` root in the same try arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-pure-add-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-pure-add-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves and flattens the `i32.add` plus its drop as unreachable debris after the unconditional table. The table payload is staged before selector work, the table becomes payloadless, and catch routing remains independent.

The addition cannot execute because `br_table` always transfers to one of its targets. Removing the complete owned subtree is therefore behavior-preserving for this exact nontrapping family.

## Starshine admission

Starshine admits exactly one `Drop(Binary(i32.add, Const, Const))` suffix with two distinct constant children and one HOT use for every node. The four-node subtree is detached and deleted before the existing terminal table routing.

Shared or repeated children, other pure binaries, richer operands, unary/conversion trees, trapping operations beyond the separately audited `i32.div_s` family, multiple non-`Unreachable` suffix roots, and repair-sensitive EH remain gated. This is an exact unreachable-subtree proof, not generic purity analysis or dead-expression elimination.
