# Optimize-instructions OI-G local dynamic bulk-memory boundary

Date: 2026-06-25

## Summary

This OI-G boundary/status slice locks the local-size dynamic bulk-memory behavior for direct `--optimize-instructions` parity work. Binaryen `version_130` keeps `memory.copy` and `memory.fill` when the size operand is a nonconstant local, and Starshine now has public-pipeline coverage proving it also keeps the bulk-memory operations rather than guessing one of the exact constant tiny lowerings.

This is coverage/status evidence for existing behavior, not a red-first implementation slice.

## Binaryen oracle

Probe: `.tmp/oi-g-local-dynamic-bulk-probe.wat`

```wat
(module
  (memory 1)
  (func (param $dst i32) (param $src i32) (param $size i32) (param $val i32)
    local.get $dst
    local.get $src
    local.get $size
    memory.copy
    local.get $dst
    local.get $val
    local.get $size
    memory.fill))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-local-dynamic-bulk-probe.wat -o -
```

Observed Binaryen output kept both operations with local operands:

- `memory.copy(local.get $dst, local.get $src, local.get $size)`
- `memory.fill(local.get $dst, local.get $val, local.get $size)`

## Starshine coverage

Added public-pipeline test:

- `optimize-instructions keeps local dynamic-size bulk-memory`

The test asserts that Starshine keeps `memory.copy` and `memory.fill`, preserves the local operand order, and does not emit any exact tiny lowering such as `i32.load8u` / `i32.store8`, `i32.load16u` / `i32.store16`, `i64.load` / `i64.store`, or `v128.load` / `v128.store`.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-local-dynamic-bulk-probe.wat -o -` passed and kept both dynamic bulk-memory operations.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*local dynamic-size bulk-memory*'` passed `1/1`.

## Remaining OI-G work

This slice narrows only the local dynamic-size boundary. Remaining OI-G work still includes broader load/store canonicalization, broader raw-gate escapes, non-flat/control/effect bulk-memory localization, and trap-relaxed zero-size cleanup only if/when Starshine supports the required modes.
