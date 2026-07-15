# Binaryen v130 `flatten`: one-multiply-child drop roots inside dead suffix sequences

## Scope

This refresh audits exact nested drop roots with one direct `i32.mul(const, const)` child and one direct outer constant inside otherwise admitted ordered legacy-try `br_table` suffix sequences. The structural family covers outer `i32.add` or `i32.sub` with the multiply on either side; all four single-root orientations were already audited separately.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Sequence probes:
  - `.tmp/flatten-probes/scalar-try-table-add-nested-addmul-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-nested-submul-and-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-nested-addmul-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-nested-submul-and-suffix.out.wat`
- Prior single-root orientation evidence:
  - `2026-07-14-flatten-version-130-try-table-nested-add-multiply-suffix-refresh.md`
  - `2026-07-14-flatten-version-130-try-table-nested-multiply-add-suffix-refresh.md`
  - `2026-07-14-flatten-version-130-try-table-subtract-const-multiply-suffix-refresh.md`
  - `2026-07-14-flatten-version-130-try-table-subtract-multiply-const-suffix-refresh.md`

Each sequence probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves both nested trees in source order between the surrounding direct roots. It stages the inner multiplication before the noncommutative outer operation, preserves the outer constant side, drops the staged result, and then continues to the later suffix root. The second probe specifically retains multiply-before-right-constant subtraction order.

The trees cannot execute because the preceding `br_table` transfers unconditionally. Admission still requires complete cross-root ownership rather than relying on generic purity or trap analysis.

## Starshine admission

Starshine now permits any positive ordered sequence over the prior direct roster plus exact direct `drop(i32.add(const, i32.mul(const, const)))`, `drop(i32.add(i32.mul(const, const), const))`, `drop(i32.sub(const, i32.mul(const, const)))`, and `drop(i32.sub(i32.mul(const, const), const))` roots. The existing root collector proves every six-node tree, and suffix-wide collection rejects shared descendants, repeated nodes, or partial ownership before atomic deletion.

Two-rich-child trees, deeper trees, alternate inner or outer opcodes, richer call arguments, structured roots, and repair-sensitive EH remain gated in sequences. Former exact-two boundaries for the same one-multiply-child family are now positive examples rather than arbitrary count caps.
