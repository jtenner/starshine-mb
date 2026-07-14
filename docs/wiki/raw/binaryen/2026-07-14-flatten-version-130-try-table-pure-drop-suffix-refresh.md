# Binaryen v130 `flatten`: legacy-try tables with one pure drop suffix

## Scope

This refresh audits one nonterminal legacy-try `br_table` followed by exactly one direct `drop(const)` root in the same arm. It does not generalize to trapping, effectful, shared, nested-control, or multiple-root suffixes.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probe: `.tmp/flatten-probes/scalar-try-table-pure-drop-suffix.wat`
- Output: `.tmp/flatten-probes/scalar-try-table-pure-drop-suffix.out.wat`

Command:

```sh
WASM_OPT=/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt
"$WASM_OPT" --all-features --flatten -S .tmp/flatten-probes/scalar-try-table-pure-drop-suffix.wat -o .tmp/flatten-probes/scalar-try-table-pure-drop-suffix.out.wat
```

## Observed contract

Binaryen v130 evaluates and stages the table payload before the selector, removes the table payload, preserves the direct `drop(i32.const 9)` as unreachable post-table debris, routes catch fallthrough independently, and validates. The suffix cannot execute because `br_table` transfers unconditionally.

## Starshine admission

Starshine treats the table as the effective terminal only when the suffix is exactly one direct `Drop` whose child is a `Const`, both nodes have exactly one HOT use, and the suffix contains no repeated node. Routing detaches and deletes the complete two-node suffix before the existing terminal legacy-try proof runs.

The ownership gate prevents deleting a constant shared with any live root or operand. Trapping drops, calls, richer pure trees, multiple non-`Unreachable` roots, nested control, and all repair-sensitive EH shapes remain gated. This is an intentional smaller dead-debris shape than Binaryen's text output, justified only by the unconditional transfer and exact exclusive deletion proof.
