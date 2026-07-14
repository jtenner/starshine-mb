# Binaryen v130 `flatten`: one dead conversion drop suffix

## Scope

This refresh audits a supported scalar legacy-try `br_table` followed by exactly one direct `drop(i64.extend_i32_s(const))` root in the same try arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-convert-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-convert-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves and flattens the signed extension plus its drop as unreachable debris after the unconditional table. Payload staging remains before selector staging, the table becomes payloadless, and catch routing remains independent.

The conversion cannot execute because `br_table` always transfers to one of its targets. Removing the complete owned subtree is therefore behavior-preserving for this exact conversion family.

## Starshine admission

Starshine admits exactly one `Drop(Convert(i64.extend_i32_s, Const))` suffix with one HOT use for the drop, conversion node, and scalar constant input. The three-node subtree is detached and deleted before the existing terminal table routing.

Shared inputs, other conversion opcodes, unary expressions, rich inputs, nested conversion trees, multiple non-`Unreachable` suffix roots, and repair-sensitive EH remain gated. This is an exact unreachable-subtree proof, not generic conversion purity or dead-expression analysis.
