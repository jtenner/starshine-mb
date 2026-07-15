# Binaryen v130 `flatten`: unary and conversion call arguments inside dead suffix sequences

## Scope

This refresh audits exact direct resultless calls with one scalar unary or signed-conversion argument inside otherwise admitted ordered legacy-try `br_table` suffix sequences. The admitted arguments are `i32.clz(const)` and `i64.extend_i32_s(const)`.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-callclz-divzero-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-and-callextend-unreachable-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-callclz-divzero-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-and-callextend-unreachable-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves both argument trees in source order between surrounding flattened roots. The input constant remains before `i32.clz` or `i64.extend_i32_s`, each complete argument remains before its direct call, and later suffix work remains later. The unary probe retains a later zero-divisor `i32.div_s`, while the conversion probe retains a later direct `unreachable`, so trap and terminal-effect placement remain explicit.

Neither call argument, call, nor neighboring suffix root can execute because the preceding `br_table` transfers unconditionally. Starshine's deletion is therefore justified by exact unreachable-suffix ownership, not generic purity, effect, trap, or call analysis.

## Starshine admission

The ordered suffix call-argument roster now accepts one exact scalar `Const`, `i32.add(Const, Const)`, `i32.div_s(Const, Const)`, `i32.clz(Const)`, or `i64.extend_i32_s(Const)` argument. The existing root collector requires the call, argument, and input nodes to be distinct and one-use; suffix-wide collection rejects cross-root sharing or repetition before atomic deletion.

`i32.ctz`, unsigned conversion, alternate unary/conversion opcodes, multiple arguments or results, indirect/reference calls, shared descendants, deeper arguments, structured roots, and repair-sensitive EH remain gated.
