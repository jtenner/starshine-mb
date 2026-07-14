# Binaryen version_130 flatten reverse try-if-block tuple table refresh

## Source and command

- Captured owner: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Confirmed version: `wasm-opt version 130 (version_130)`
- Command:

  ```text
  wasm-opt --all-features --flatten -S .tmp/flatten-probes/multivalue-try-if-block-table-tuple-payload.wat -o .tmp/flatten-probes/multivalue-try-if-block-table-tuple-payload.out.wat
  ```

The ignored probe is the concrete `(i32, i64)` try-inside-if-inside-block table family, named separately for the repeated-HOT-`TupleMake` ownership audit. Binaryen's internal concrete multivalue `Type` is emitted through tuple-typed locals and explicit `tuple.make` staging. HOT lifts that one concrete producer as repeated node ids across scalar result slots, so Starshine needs an additional exclusive-ownership and deletion proof even though the WAT source is ordinary multivalue syntax.

## Owner and output evidence

`Flatten.cpp` lines 311-326 stage the concrete `Switch` value once, copy it to every unique target temp, clear the switch payload, and rely on postorder `Try`, `If`, and `Block` routing without an ancestry-kind ordering restriction.

The output confirms:

- `$first` and `$second` execute once and in source order;
- one tuple is assembled before selector work;
- the selector executes after tuple staging;
- distinct try, if, and block channels are initialized before the payloadless table;
- catch routing writes the try channel;
- selected fallthrough copies try to if and then if to block;
- the else arm constructs its own result independently;
- the original table payload is removed.

## Starshine admission and retained boundaries

A red-first repeated-HOT-`TupleMake` fixture failed unchanged while the tuple-specific blocks-before-ifs gate remained. The admitted route requires the same complete strict direct target chain as scalar and independently scalar payloads, plus exact repeated tuple identity across every table lane, exclusive ownership, supported ordered scalar components, exact component types, defaultable lanes, one evaluation, selector-after-payload order, distinct per-label vectors, safe tuple-shell deletion after complete preflight, Flat IR classification, and verification.

Arbitrary whole-tuple producers, shared or mixed tuple ownership, skipped or non-root ancestry, loop or other target kinds, extra try labels, nonterminal tables, nondefaultable lanes, repair-sensitive EH, and public exposure remain gated.
