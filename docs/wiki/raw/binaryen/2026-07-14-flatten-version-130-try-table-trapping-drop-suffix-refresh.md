# Binaryen v130 `flatten`: legacy-try tables with one trapping drop suffix

## Scope

This refresh audits one nonterminal legacy-try `br_table` followed by exactly one direct `drop(i32.div_s(const, const))` root. It isolates a trapping subtree whose trap is dynamically unreachable after the unconditional table transfer.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-trapping-drop-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-trapping-drop-suffix.out.wat`

Command:

```sh
WASM_OPT=/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt
"$WASM_OPT" --all-features --flatten -S .tmp/flatten-probes/scalar-try-table-trapping-drop-suffix.wat -o .tmp/flatten-probes/scalar-try-table-trapping-drop-suffix.out.wat
```

## Observed contract

Binaryen v130 stages table payload work before selector work, removes the table payload, and preserves the dead division as a local-set plus drop after the unconditional transfer. The division cannot trap at runtime because no path continues past `br_table`; catch routing remains independent and output validates.

## Starshine admission

Starshine admits only exact `Drop(Binary(i32.div_s, Const, Const))`. The drop, binary, and two distinct constants must each have one HOT use, and none may repeat in the suffix deletion set. Routing detaches and deletes all four nodes before the existing terminal legacy-try proof.

The gate deliberately does not infer arbitrary effect/trap freedom. Other trapping instructions, shared operands, repeated children, nested trees, calls, memory/global effects, multiple non-`Unreachable` roots, and repair-sensitive EH remain unsupported. Deleting this exact trap is semantics-preserving because the table transfer is unconditional, not because trapping work is generally movable or removable.
