# SGO no-catch `try_table` pure-chain read-only-to-write

## Question

Can Starshine reuse the existing external pure-condition read-only-to-write scanner when a no-catch `try_table` result is the value source before pure condition operators, matching Binaryen while keeping caught exception-control wrappers conservative?

## Binaryen v129 probes

All probes used local `wasm-opt version_129` with `--enable-exception-handling --simplify-globals-optimizing -S`.

Positive probes:

1. No-catch pure condition chain:
   - Shape: `if (i32.eqz (i32.add (try_table (result i32) (global.get $g)) (i32.const 1))) then global.set $g (i32.const 1)`.
   - Result: Binaryen made `$g` immutable and removed the fake `global.get` / `global.set` traffic.
2. No-catch pure-chain exact `if return; set` guard:
   - Shape: `if (i32.eqz (i32.add (try_table (result i32) (global.get $g)) (i32.const 1))) return; global.set $g (i32.const 1)`.
   - Result: Binaryen made `$g` immutable and removed the fake global traffic.

Negative probe:

- Catch-bearing pure condition chain:
  - Shape: `block $exit (if (i32.eqz (i32.add (try_table (result i32) (catch $e $exit) (global.get $g)) (i32.const 1))) then global.set $g (i32.const 1))`.
  - Result: Binaryen preserved the mutable global and global traffic family.

## Local TDD

Added focused tests in `src/passes/simplify_globals_optimizing_test.mbt` for:

- transparent no-catch `try_table` feeding an `i32.add` / `i32.eqz` condition chain,
- catch-bearing `try_table` feeding the same chain conservatism,
- transparent no-catch `try_table` feeding the same chain into exact `if return; set`.

Before implementation, `moon test src/passes` failed the two no-catch positives because `$g` remained mutable.

## Implementation

Updated `src/passes/simplify_globals_optimizing.mbt` so the `TryTable` read-only-to-write scanner dispatches into the already-audited external pure condition helpers. Those helpers now accept either:

- a block wrapper, as before, or
- a `try_table` wrapper only when `catches.length() == 0`.

The accepted no-catch `try_table` body read is still checked by the existing safe body reader, and the subsequent condition chain is still checked by `sgo_external_condition_stack_after(...)`. The if-return helper path also reuses the exact existing tail constraints for direct const sets or block-wrapped const-set tails.

Catch-bearing `try_table` wrappers remain conservative. This does not add arbitrary caught-path joins, branch/throw handling, trapping operation support, call operand support, or broader control-transfer matching.

## Validation

- `moon test src/passes`: `1537/1537` passed after implementation.
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-pure-chain-rotw-10k`
  - Compared: `9975/10000`
  - Normalized matches: `9975`
  - Mismatches: `0`
  - Validation failures: `0`
  - Generator failures: `0`
  - Command failures: `25` Binaryen/tool failures

## Status

`[SGO]003` remains active/partial. This is a narrow no-catch `try_table` + existing external pure-condition scanner alignment slice, not full Binaryen `SimplifyGlobals.cpp` parity.
