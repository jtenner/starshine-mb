# Binaryen version_130 flatten reverse try-if-block table refresh

## Source and command

- Captured owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Confirmed version: `wasm-opt version 130 (version_130)`
- Commands:

  ```text
  wasm-opt --all-features --flatten -S .tmp/flatten-probes/scalar-try-if-block-table-targets.wat -o .tmp/flatten-probes/scalar-try-if-block-table-targets.out.wat
  wasm-opt --all-features --flatten -S .tmp/flatten-probes/multivalue-try-if-block-table-targets.wat -o .tmp/flatten-probes/multivalue-try-if-block-table-targets.out.wat
  ```

The ignored probes place a value-carrying legacy `try` directly inside the selected arm of a value `if`, then place that `if` directly inside a value `block`. The terminal `br_table` targets the try, the if, and the block. This is the reverse of Starshine's previously admitted blocks-before-ifs ancestry.

## Owner evidence

`Flatten.cpp` lines 311-326 stage one concrete `Switch` value, then copy it to every unique target temp before clearing the switch payload. The postorder `Try`, `If`, and `Block` handlers independently remove each value control and route its fallthrough through a typed temp. None of those handlers imposes a block-before-if ancestry order.

## Probe observations

Both scalar and `(i32, i64)` probes validate and flatten successfully with `--all-features`.

- Payload work occurs before selector work.
- The payload is evaluated once and staged once.
- Distinct try, if, and block target channels are initialized before the payloadless `br_table`.
- The catch writes the try-result channel.
- Selected try fallthrough copies into the if channel.
- The if else arm writes its own if-result channel independently.
- Selected if fallthrough copies into the enclosing block channel.
- The original table payload is removed.
- Scalar and concrete multivalue output preserve the same routing contract; Binaryen's emitted multivalue locals are tuple typed, while Starshine's HOT representation uses ordered scalar local lanes.

## Starshine admission and retained boundaries

The internal Starshine preflight now admits this exact direct mixed order for scalar and independently scalar multivalue payloads. It still requires the complete unique target roster, direct root-to-control ancestry, exact target and payload types, defaultable lanes, supported payload origins, terminal placement in the legacy try, one evaluation per lane, distinct per-label channels, catch and fallthrough routing, and validation.

Skipped controls, loops or other target kinds, non-root containment, extra try labels, nonterminal tables, nondefaultable lanes, shared or ambiguous payload ownership, arbitrary whole-tuple producers, repair-sensitive EH, and public exposure remain gated. Exclusively owned repeated-HOT-`TupleMake` reverse-order payloads remain a separate red-first audit surface.
