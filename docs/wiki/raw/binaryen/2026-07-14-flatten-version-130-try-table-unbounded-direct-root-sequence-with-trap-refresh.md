# Binaryen v130 `flatten`: direct suffix-root sequences with a dead signed-division trap

## Scope

This refresh audits exact direct `drop(i32.div_s(const, const))` inside otherwise admitted ordered legacy-try `br_table` suffix sequences, including a zero divisor in the middle of the sequence.

## Pinned evidence

- Owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Version: `wasm-opt version 130 (version_130)`
- Probes:
  - `.tmp/flatten-probes/scalar-try-table-add-divzero-clz-suffix.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-divzero-and-suffix.wat`
- Outputs:
  - `.tmp/flatten-probes/scalar-try-table-add-divzero-clz-suffix.out.wat`
  - `.tmp/flatten-probes/scalar-try-table-extend-divzero-and-suffix.out.wat`

Each probe was run with the pinned oracle and explicit `--all-features --flatten -S`.

## Observed contract

Binaryen v130 preserves the zero-divisor `i32.div_s` as unreachable flattened debris between the surrounding roots. It stages each root in source order, preserves dividend-before-divisor operand order, retains the zero divisor, drops the staged division result, and continues with the later root. The trap cannot occur because the preceding `br_table` transfers unconditionally.

The proof is not generic purity or effect analysis. It depends on the table being an unconditional transfer and on complete ownership of every suffix root and descendant.

## Starshine admission

Starshine now permits exact direct `Drop(I32DivS(Const, Const))` roots inside any positive ordered sequence over the previously admitted direct root roster. Complete suffix collection still requires distinct roots and descendants with one HOT use each before atomically detaching and deleting the suffix ahead of terminal table routing.

`i32.div_u`, other trapping opcodes, calls and other effects, nested trees, structured roots, repeated roots, shared descendants, mixed `Unreachable` compositions outside separately audited families, and repair-sensitive EH remain fail-closed.
