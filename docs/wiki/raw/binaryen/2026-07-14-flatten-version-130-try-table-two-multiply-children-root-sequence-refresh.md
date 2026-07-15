# Binaryen v130 `flatten`: two-multiply-child drop roots inside dead suffix sequences

## Scope

This refresh audits exact two-rich-child drop roots inside otherwise admitted ordered legacy-try `br_table` suffix sequences. The admitted tree is `drop(i32.add(mul(const, const), mul(const, const)))` or the noncommutative `drop(i32.sub(mul(const, const), mul(const, const)))` counterpart.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-tworichadd-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-tworichsub-and-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-tworichadd-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-tworichsub-and-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves both inner multiplications before the outer operation and retains the complete root between its surrounding suffix roots. The subtraction probe preserves left-multiply, right-multiply, then subtraction order, so operand orientation is explicit rather than inferred from commutativity. Later suffix work remains later.

None of these roots can execute because the preceding `br_table` transfers unconditionally. Admission therefore depends on complete exact subtree ownership and source order, not generic purity or tree-depth reasoning.

## Starshine admission

The ordered suffix roster now accepts exact outer `i32.add` or `i32.sub` trees whose two children are distinct `i32.mul(const, const)` nodes. The existing eight-node root collector requires every outer, inner, and leaf node to be distinct and one-use; suffix-wide collection then rejects cross-root sharing or repetition before atomic deletion.

The admission has no root-count cap: former two-root add and subtraction boundaries are now positive examples of the same structural sequence family. Deeper trees, alternate inner or outer operators, repeated/shared descendants, structured roots, richer unaudited calls, and repair-sensitive EH remain gated.
