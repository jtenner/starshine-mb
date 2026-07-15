# Binaryen v130 `flatten`: binary-argument void calls inside dead suffix sequences

## Scope

This refresh audits exact direct resultless calls with one richer scalar argument inside otherwise admitted ordered legacy-try `br_table` suffix-root sequences. This slice admits only `i32.add(const, const)` and `i32.div_s(const, const)` arguments; the signed-division probe uses a zero divisor so trap placement remains explicit.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-calladd-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-calldivzero-and-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-calladd-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-calldivzero-and-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves both richer call arguments in source order between surrounding flattened roots. Each argument's constants remain before its binary operation, the complete argument remains before the direct call, and the later suffix root remains after the call. The zero-divisor `i32.div_s` is retained rather than folded away, so the audited output preserves the unreachable trap position as well as call ordering.

The argument, call, and neighboring roots cannot execute because the preceding `br_table` transfers unconditionally. Starshine's deletion is therefore justified by exact unreachable-suffix ownership, not generic purity, effect, or trap analysis.

## Starshine admission

The ordered suffix roster now accepts direct resultless calls with zero arguments or one exact argument from this roster: scalar `Const`, `i32.add(Const, Const)`, or `i32.div_s(Const, Const)`. The argument recognizer is structural; the existing root collector separately requires distinct children and one HOT use for every call-subtree node, while suffix-wide collection rejects any repeated or shared node before atomic deletion.

Unary and conversion arguments remain gated in sequences even though their exact shapes are separately admitted as single roots. Multiple arguments, result calls, indirect/reference calls, shared descendants, other binary opcodes, deeper argument trees, structured roots, and repair-sensitive EH also remain gated.
