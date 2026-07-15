# Binaryen v130 `flatten`: direct void-call roots inside dead suffix sequences

## Scope

This refresh audits exact direct resultless calls inside otherwise admitted ordered legacy-try `br_table` suffix-root sequences. The admitted sequence slice covers zero-argument calls and one scalar-constant-argument calls only.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-call0-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-callarg-and-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-call0-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-callarg-and-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves each direct call in source order between the surrounding flattened drop roots. The zero-argument call remains after the staged addition and before the staged unary root. The scalar constant argument remains directly under its call after the staged signed extension and before the staged bitwise-and. The call argument therefore stays before the call, and neither call moves across a neighboring root.

Neither call or argument can execute because the preceding `br_table` transfers unconditionally. This is an exact unreachable-suffix ownership proof, not generic call-effect deletion.

## Starshine admission

Starshine now permits an exact direct resultless `Call` root with zero arguments or one direct scalar `Const` argument at any position in the admitted ordered suffix sequence. The existing root collector still requires one HOT use for the call and argument, and suffix-wide collection rejects every repeated or shared node before atomic deletion.

Result calls, multiple arguments, indirect/reference calls, shared arguments, and richer argument trees remain gated in sequences. In particular, the separately admitted single-root add, signed-division, signed-extension, and unary call-argument families do not yet join multiple-root sequences.
