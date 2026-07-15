# Binaryen v130 `flatten`: unbounded direct nontrapping suffix-root sequences

## Scope

This refresh audits whether the exact direct unary and conversion suffix roots already admitted singly can join the ordered direct nontrapping sequence: `drop(i32.clz(const))` and `drop(i64.extend_i32_s(const))`, alongside exact direct constant `i32.add`, `i32.sub`, `i32.mul`, and `i32.and` drop roots.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-clz-extend-and-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-mul-clz-sub-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-clz-extend-and-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-mul-clz-sub-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves both mixed four-root sequences as ordered unreachable flattened debris. The first probe places `i32.clz` before signed extension; the reverse probe places signed extension before `i32.clz`. In both cases Binaryen stages and drops every root in source order, preserves binary operand order, and does not impose a suffix-count or root-order cap.

The complete suffix remains dynamically unreachable because the preceding `br_table` transfers unconditionally. Starshine may delete it only after exact shape recognition and complete suffix-wide distinctness and one-use ownership proof.

## Starshine admission

Starshine now admits any positive ordered sequence over these exact direct nontrapping roots:

- `Drop(I32Add(Const, Const))`
- `Drop(I32Sub(Const, Const))`
- `Drop(I32Mul(Const, Const))`
- `Drop(I32And(Const, Const))`
- `Drop(I32Clz(Const))`
- `Drop(I64ExtendI32S(Const))`

The exact `i32.ctz` and unsigned `i64.extend_i32_u` sequence boundaries remain fail-closed. Other unary/conversion opcodes, trapping roots, nested trees, calls, structured roots, repeated roots, shared inputs, mixed `Unreachable` compositions outside separately audited families, and repair-sensitive EH remain gated.
