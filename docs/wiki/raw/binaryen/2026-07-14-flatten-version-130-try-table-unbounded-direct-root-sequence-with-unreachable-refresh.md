# Binaryen v130 `flatten`: direct suffix-root sequences with `unreachable`

## Scope

This refresh audits exact direct `Unreachable` roots mixed without a count or position cap into the already admitted ordered legacy-try `br_table` suffix-root roster.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-unreachable-add-divzero-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-unreachable-and-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-unreachable-add-divzero-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-unreachable-and-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves every audited suffix root as source-ordered unreachable flattened debris after the unconditional table. The first probe retains a direct `unreachable`, then the addition, then the zero-divisor signed division. The reverse-position probe retains the signed extension, a middle direct `unreachable`, then the bitwise-and. Operand order and the dead signed-division trap remain in place.

The proof is not generic dead-code or effect analysis. It depends on `br_table` transferring unconditionally before the suffix and on complete ownership of every admitted root and descendant.

## Starshine admission

Starshine now permits direct `Unreachable` roots at any position in any positive ordered sequence over the existing seven exact direct drop-root families. Complete suffix collection still rejects repeated roots, shared descendants, unsupported opcodes, nested rich trees, calls, and structured controls before atomically detaching and deleting every owned suffix node ahead of terminal table routing.

Direct resultless calls, richer nested drop trees, structured roots, other opcodes, shared/repeated ownership, and repair-sensitive EH remain separate gates even though some are admitted as single-root families elsewhere.
