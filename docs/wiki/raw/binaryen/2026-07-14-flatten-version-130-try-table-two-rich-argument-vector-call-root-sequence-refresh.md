# Binaryen v130 `flatten`: two rich arguments among constant call vectors

## Scope

This refresh audits direct resultless calls with exactly two already admitted rich arguments plus one or more distinct scalar constants at arbitrary immediate argument positions inside otherwise admitted ordered legacy-try `br_table` suffix sequences. The probes cover binary-plus-unary, add-plus-trapping-division, and unary-plus-conversion rich pairs in four- and five-argument vectors.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-callconstaddconstclz-divzero-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-calldivconstaddconst-unreachable-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-add-callclzconstextendconst-divzero-suffix.wat`
- Outputs use the same basenames with `.out.wat`.

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves the complete immediate argument vector in source order, including constants before, between, and after rich arguments. Each rich subtree retains its own input or left-to-right operand order before its operation. The calls remain between surrounding suffix roots, with later zero-divisor work or direct `unreachable` retained.

The calls cannot execute because the preceding `br_table` transfers unconditionally. Starshine deletes only the exact completely owned unreachable suffix; constants, trapping division, calls, unary operations, and conversions are not classified as generically removable.

## Starshine admission

The exact two-rich collector now accepts its full audited pair roster with any positive number of distinct one-use scalar constants at arbitrary immediate positions. The same collector still admits the zero-constant exact pairs. It records the complete immediate argument vector first, then each rich subtree's children in rich-argument order. Every node must be distinct and one-use, and suffix-wide collection rejects cross-root sharing before atomic deletion. There is no argument-count cap.

Same-opcode binary pairs, three-or-more rich arguments, alternate opcodes, repeated/shared descendants, result calls, indirect/reference calls, deeper trees, structured roots, and repair-sensitive EH remain gated. Public flatten wiring remains removed.

## Iteration validation

After the three code-changing commits in this iteration, the one consolidated internal matrix passed: `moon info` completed with the same 11 pre-existing warnings and 0 errors, `moon fmt` completed with the unrelated `moon.mod` rewrite restored, focused verifier tests passed `230/230`, private flatten tests passed `142/142`, and `moon test src/passes` passed `5702/5702`. Relative to the iteration start, the protected surface moved from `221` to `230` focused tests, `137` to `142` private tests, and `5688` to `5702` pass-package tests.

A public four-lane compare-pass matrix was not run because `flatten` deliberately remains absent from the registry, dispatcher, CLI execution, and compare-harness allowlist. Running that matrix would currently test removed-pass rejection rather than the internal implementation, so these results are iteration-level internal validation, not pass closeout or public parity evidence.
