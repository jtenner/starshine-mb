# Binaryen v130 `flatten`: legacy-try tables with unreachable-only suffixes

## Scope

This refresh audits a narrow nonterminal legacy-try `br_table` family: the table is followed only by explicit `unreachable` roots in the same try arm. Starshine intentionally does not generalize this evidence to arbitrary dead suffix expressions.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Scalar probe: `.tmp/flatten-probes/scalar-try-table-unreachable-suffix.wat`
- Scalar output: `.tmp/flatten-probes/scalar-try-table-unreachable-suffix.out.wat`
- Multivalue probe: `.tmp/flatten-probes/multivalue-try-table-unreachable-suffix.wat`
- Multivalue output: `.tmp/flatten-probes/multivalue-try-table-unreachable-suffix.out.wat`

Commands:

```sh
WASM_OPT=/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt
"$WASM_OPT" --version
"$WASM_OPT" --all-features --flatten -S .tmp/flatten-probes/scalar-try-table-unreachable-suffix.wat -o .tmp/flatten-probes/scalar-try-table-unreachable-suffix.out.wat
"$WASM_OPT" --all-features --flatten -S .tmp/flatten-probes/multivalue-try-table-unreachable-suffix.wat -o .tmp/flatten-probes/multivalue-try-table-unreachable-suffix.out.wat
```

## Observed contract

For both scalar and multivalue payloads, v130:

1. evaluates payload work once and before selector work;
2. stages the payload into the target result channel;
3. rewrites the table to carry no payload;
4. preserves the non-fallthrough fact with unreachable debris after the table;
5. routes catch fallthrough independently;
6. validates under `--all-features`.

No expression after the table can execute because `br_table` is unconditional. Binaryen's flattened text retains several unreachable placeholders as control-debris artifacts rather than as meaningful continuation work.

## Starshine boundary

Starshine admits only an exact suffix in which every same-region root after the supported table is `Unreachable`. During table routing it removes those detached roots before legacy-try result routing, leaving the table as the effective terminal root. This keeps the existing terminal routing proof unchanged while accepting a source-backed nonterminal representation.

The gate remains fail-closed for:

- any non-`Unreachable` suffix root, even if external reasoning says it is dead;
- a table nested as an operand rather than a direct region root;
- unsupported payload ownership or types;
- skipped target ancestry;
- unsupported loop backedges;
- deferred EH repair;
- nondefaultable result lanes.
