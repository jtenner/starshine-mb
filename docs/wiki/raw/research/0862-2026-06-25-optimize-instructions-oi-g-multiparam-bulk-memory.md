# Optimize Instructions OI-G: multi-parameter bulk-memory raw-gate escape

Date: 2026-06-25

## Summary

Starshine now admits another source-backed OI-G stack-carried bulk-memory shape through the public/raw `stack-carried-effect-optimize-instructions-noop` gate:

- flat tiny `memory.copy` / byte `memory.fill` sequences may be mixed in one straight-line function;
- each destination/source/value operand may be a pure local/constant, a no-param one-result direct call, or a direct call with any number of pure local/constant arguments and one result;
- copy sizes are still limited to constant `1`/`2`/`4`/`8`, and stack-carried fill lowering remains limited to size `1`.

Once admitted to HOT, the existing tiny-copy and byte-fill helpers lower the covered forms to load/store and `i32.store8` respectively.

## Binaryen evidence

Probe: `.tmp/oi-g-multiparam-bulk-memory-boundary-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-multiparam-bulk-memory-boundary-probe.wat -o -
```

Observed Binaryen `version_130` output lowers the mixed function's size-1 `memory.copy` to `i32.load8_u` + `i32.store8`, and lowers the local/value-call size-1 `memory.fill` forms to `i32.store8`. It preserves the multi-parameter call operands in evaluation order.

## Starshine change

- `src/passes/pass_manager.mbt` now uses a generalized raw-gate operand parser for bulk-memory stack operands. A direct call is accepted when its parameter count exactly matches the preceding run of pure local/constant stack operands and it has one result.
- The previous separate tiny-copy and byte-fill raw-gate recognizers were unified into a tiny bulk-memory recognizer so mixed copy/fill straight-line functions no longer skip merely because both bulk operations appear in the same body.
- `src/passes/optimize_instructions_test.mbt` adds public-pipeline coverage `optimize-instructions expands stack-carried multi-parameter bulk-memory calls`.

## Validation

- Red-first focused test before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*multi-parameter bulk-memory*'` failed with `stack-carried-effect-optimize-instructions-noop`.
- After implementation, the same focused command passed `1/1`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.copy*'` passed `8/8`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.fill*'` passed `13/13`.
- `moon fmt` passed.
- `moon test src/passes` passed `2802/2802`.

## Remaining boundaries

This is still not broad stack-carried effect parity. The raw-gate escape remains limited to flat bulk-memory sequences with pure local/constant call arguments. Non-pure call arguments, control-bearing operands, nonconstant sizes, wider call-backed `memory.fill`, zero-size trap-relaxed cleanup, and non-flat/localizing forms remain open OI-G work rather than hidden parity.
