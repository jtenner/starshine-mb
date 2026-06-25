# Optimize Instructions OI-G Size-13 Bulk-Memory Boundary

Date: 2026-06-25

## Question

Does Binaryen `version_130` lower constant-size-13 `memory.copy` / `memory.fill` in `--optimize-instructions`, or is the exact bulk-memory lowering boundary still limited to the covered exact lane sizes?

## Probe

Input fixture: `.tmp/oi-g-memory-copy-size13-probe.wat`.

```wat
(module
  (memory 1)
  (func (param $dst i32) (param $src i32) (param $value i32)
    (memory.copy (local.get $dst) (local.get $src) (i32.const 13))
    (memory.fill (local.get $dst) (local.get $value) (i32.const 13))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size13-probe.wat -o -
```

## Finding

Binaryen keeps both `memory.copy` and `memory.fill` with `i32.const 13`. It does not synthesize a mixed 8+4+1 load/store sequence for this size.

## Starshine coverage

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions keeps size-13 bulk-memory outside exact lowering boundary`

The test asserts the public pipeline keeps both bulk-memory operations and does not introduce scalar or SIMD load/store spellings for size 13. This is boundary-only evidence, not a red-first implementation slice.

## Status

The exact Starshine lowering set remains intentionally narrow: exact 1/2/4/8/16 `memory.copy` and exact covered `memory.fill` lanes are lowerable; size-13 is a source-backed keep-spelling boundary. Reopen this if a future Binaryen source/oracle refresh lowers size-13 or if Starshine starts partially lowering it without semantic and size evidence.
