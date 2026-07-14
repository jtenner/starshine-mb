# Binaryen v130 `flatten`: legacy-try table fanout into an enclosing inputful loop

## Scope

This refresh isolates terminal legacy-`try` `br_table` payload fanout when the complete strict direct target ancestry includes an inputful loop. It is evidence for Starshine's internal `flatten` owner only; public pass wiring remains removed.

## Pinned owner

- Captured source: `.tmp/binaryen-v130/Flatten.cpp`
- SHA-256: `5b8836c46490095e98ba8202f866b153cfacc6f9c24ac498b703702adc3455b6`
- Oracle: `/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt`
- Confirmed version: `wasm-opt version 130 (version_130)`

`Flatten.cpp` lines 311-326 stage one concrete `Switch` value, enumerate every unique target, and copy that staged value into each target's break temp before clearing the switch value. The postorder `Try` and `Loop` handlers independently erase their result channels; the loop's branch target is its input vector, not its result vector.

## Probes

Ignored local probes:

- `.tmp/flatten-probes/scalar-try-loop-table-targets.wat`
- `.tmp/flatten-probes/scalar-try-loop-table-targets.out.wat`
- `.tmp/flatten-probes/multivalue-try-loop-table-targets.wat`
- `.tmp/flatten-probes/multivalue-try-loop-table-targets.out.wat`

Command:

```sh
WASM_OPT=/mise/http-tarballs/78d28b82d329cecc96d14b1872ee2a890d09be4705c634ffb04ebf8c592c1e48/binaryen-version_130/bin/wasm-opt
"$WASM_OPT" --version
"$WASM_OPT" --all-features --flatten -S .tmp/flatten-probes/scalar-try-loop-table-targets.wat -o .tmp/flatten-probes/scalar-try-loop-table-targets.out.wat
"$WASM_OPT" --all-features --flatten -S .tmp/flatten-probes/multivalue-try-loop-table-targets.wat -o .tmp/flatten-probes/multivalue-try-loop-table-targets.out.wat
```

## Observed contract

Both probes confirm:

1. Inputful loop entries are captured before loop execution.
2. The table payload is evaluated exactly once.
3. Payload staging occurs before selector evaluation.
4. Distinct target channels are created for the legacy `try` result and loop entry.
5. Selecting the loop target copies the staged payload into the loop-entry channel and backedges through the loop.
6. Selecting the try target routes through the try result channel and continues after the try.
7. Catch fallthrough writes the try result channel independently.
8. Loop result routing remains distinct from loop-entry routing, including when loop input and result types differ.
9. The output remains valid under `--all-features`.

For the concrete multivalue probe, Binaryen v130 internally stages the two scalar calls into one tuple-typed temporary before copying that concrete tuple into the try and loop channels. Starshine's HOT representation instead keeps scalar `ValType` lanes, so local admission must preserve ordered component provenance, one evaluation, exact defaultable types, and distinct per-label vectors.

## Starshine implication

A terminal legacy-try table may admit a loop target only when the loop is part of the complete strict direct enclosure chain, its input vector exactly matches the table payload vector, the loop's existing entry/backedge/result preflight is already supported, all payload types are defaultable, and try/control result channels remain distinct from loop-entry locals. Skipped ancestry, non-root containment, mismatched vectors, unsupported backedges, and nondefaultable entries remain fail-closed.
