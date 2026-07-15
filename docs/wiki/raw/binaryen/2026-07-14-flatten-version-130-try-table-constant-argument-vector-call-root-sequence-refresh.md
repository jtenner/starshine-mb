# Binaryen v130 `flatten`: unbounded scalar-constant argument vectors in dead suffix calls

## Scope

This refresh audits direct resultless calls whose complete argument vector consists of distinct scalar constants inside otherwise admitted ordered legacy-try `br_table` suffix sequences. Three- and four-argument probes use mixed `i32`/`i64` order so the admission is structural rather than a homogeneous-type or exact-count special case.

## Why this is not an arbitrary arity cap

The previous implementation admitted exactly two constant arguments and rejected three. Binaryen's generic prelude algorithm does not impose a call-argument count cap. The local proof now walks every argument, preserving source order and requiring the same exact scalar-constant, distinctness, and one-use invariants for the complete vector. Three and four arguments are representative tests, not maximums.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-call3-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-call4-divzero-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-call3-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-call4-divzero-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves all three `i32`/`i64`/`i32` arguments and all four `i64`/`i32`/`i64`/`i32` arguments in source order directly under the call. It keeps each call between its surrounding suffix roots and retains later unary or zero-divisor signed-division work.

The calls cannot execute because the preceding `br_table` transfers unconditionally. Starshine's smaller deletion remains justified only by complete exact unreachable-suffix ownership, not by generic call-effect or argument analysis.

## Starshine admission

Any positive argument count is accepted when every direct call argument is a distinct one-use scalar `Const`. Collection returns the call followed by every argument in source order. Suffix-wide collection then rejects cross-root sharing or repeated nodes before atomic deletion.

Vectors containing any rich argument still use only the separately audited exact two-argument one-rich-plus-constant route. Three-or-more-argument vectors with a rich argument, repeated/shared constants, result calls, indirect/reference calls, structured roots, and repair-sensitive EH remain gated. Public flatten wiring remains removed.
