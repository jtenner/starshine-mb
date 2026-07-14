# Binaryen v130 `flatten`: one dead multiply suffix

## Scope

This refresh audits a supported scalar legacy-try `br_table` followed by exactly one direct `drop(i32.mul(const, const))` root in the same try arm.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-pure-mul-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-pure-mul-suffix.out.wat`

Command: the pinned oracle with `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves and flattens the multiply as unreachable debris after the unconditional table. Payload staging remains before selector staging, the table becomes payloadless, and catch routing remains independent.

The multiply and its operands cannot execute because `br_table` always transfers to one of its targets. Removing the complete owned scalar subtree is behavior-preserving for this exact nontrapping binary shape.

## Starshine admission

Starshine admits exactly one `Drop(Binary(i32.mul, Const, Const))` suffix. The two constants must be distinct nodes, and the drop, multiply, and both operands must each have exactly one HOT use. All four nodes are detached and deleted before existing terminal table routing.

Shared or repeated operands, other unaudited binary opcodes, nested trees, multiple non-`Unreachable` roots, structured roots, and repair-sensitive EH remain gated. This is an unconditional-transfer plus exact-subtree-ownership proof, not a generic purity classifier.
