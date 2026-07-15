# Binaryen v130 `flatten`: direct `drop(const)` roots inside dead suffix sequences

## Scope

This refresh audits direct `drop(const)` roots as ordinary members of the exact ordered legacy-try `br_table` dead-suffix sequence, rather than limiting them to homogeneous runs or finite two-root combinations.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-dropconst-unreachable-divzero-call0-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-submul-dropconst-and-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-dropconst-unreachable-divzero-call0-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-submul-dropconst-and-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 retains the direct dropped constant in source order among other unreachable flattened debris. The first probe places it before a direct `Unreachable`, a zero-divisor signed division, and a zero-argument resultless call. The second places it after a noncommutative one-multiply-child subtraction tree and before a direct bitwise-and root. Binaryen preserves the neighboring trap, call, multiply, subtraction-side, and later-root order.

None of the suffix roots can execute because the preceding `br_table` transfers unconditionally. Starshine's deletion is therefore based on exact suffix reachability and ownership, not a claim that dropped constants can be erased across arbitrary control flow.

## Starshine admission

Direct `drop(Const)` now belongs to the same structural sequence roster as the previously audited direct roots, calls, and one- or two-multiply-child trees. The existing root collector requires one HOT use for the drop and constant, while suffix-wide collection rejects repeated roots, shared constants, and cross-root sharing before deleting the complete suffix atomically.

The admission has no order or count cap. Non-direct constants, shared/repeated constants, richer unaudited calls or trees, structured roots, and repair-sensitive EH remain gated. The older homogeneous and exact-pair recognizer flags remain behaviorally redundant but harmless; the structural sequence roster is now the general admission path for mixed direct `drop(const)` sequences.
