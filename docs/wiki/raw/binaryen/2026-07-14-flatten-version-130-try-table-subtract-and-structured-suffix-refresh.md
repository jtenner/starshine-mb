# Binaryen v130 `flatten`: dead subtract suffix and structured-root boundary

## Scope

This refresh audits two supported scalar legacy-try `br_table` suffix shapes:

1. exactly one direct `drop(i32.sub(const, const))` root;
2. exactly one direct void `block` containing `drop(const)`.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Scalar probe: `.tmp/flatten-probes/scalar-try-table-pure-sub-suffix.wat`
- Scalar output: `.tmp/flatten-probes/scalar-try-table-pure-sub-suffix.out.wat`
- Structured probe: `.tmp/flatten-probes/scalar-try-table-void-block-drop-suffix.wat`
- Structured output: `.tmp/flatten-probes/scalar-try-table-void-block-drop-suffix.out.wat`

Commands: the pinned oracle with `--all-features --flatten -S` for each probe.

## Observed Binaryen contract

Binaryen v130 preserves and flattens both suffixes as unreachable debris after the unconditional table. In both probes payload staging remains before selector staging, the table becomes payloadless, and catch routing remains independent.

The subtract and its operands cannot execute because `br_table` always transfers to one of its targets. Removing that complete owned scalar subtree is behavior-preserving for this exact nontrapping binary family.

## Starshine scalar admission

Starshine admits exactly one `Drop(Binary(i32.sub, Const, Const))` suffix. The two constants must be distinct nodes, and the drop, subtract, and both operands must each have exactly one HOT use. All four nodes are detached and deleted before existing terminal table routing.

Shared or repeated operands, other unaudited binary opcodes, nested trees, multiple non-`Unreachable` roots, and repair-sensitive EH remain gated.

## Structured-root blocker

Starshine does not admit the void-block suffix. Every HOT block owns a `HotLabelInfo`, and `hot_verify` requires every label owner to remain a live matching control node. The public mutation surface can allocate labels and reassign an owner, but it has no label-removal operation. Deleting the detached block would therefore leave an invalid label owner; retaining an unreachable live orphan merely to own the label would not be complete region-subtree deletion and is not accepted as a safe transform.

The fail-closed boundary remains until HOT provides a verified way to remove an unreferenced control node together with its label metadata, or another source-backed rewrite proves equivalent label ownership without orphan nodes. Nested structured suffixes, named blocks, blocks targeted from elsewhere, and structured roots containing effects remain gated.
