# SGO no-catch `try_table` if-return read-only-to-write

## Question

Can Starshine treat no-catch `try_table` result wrappers as transparent in exact `if return; set` read-only-to-write guards, matching Binaryen `SimplifyGlobals.cpp` without widening caught exception-control paths?

## Binaryen v129 probes

All probes used local `wasm-opt version_129` with `--enable-exception-handling --simplify-globals-optimizing -S`.

Positive probes:

1. No-catch direct guard:
   - Shape: `if (try_table (result i32) (global.get $g)) return; global.set $g (i32.const 1)`.
   - Result: Binaryen made `$g` immutable and removed the fake `global.get` / `global.set` traffic.
2. No-catch `i32.eqz` guard:
   - Shape: `if (i32.eqz (try_table (result i32) (global.get $g))) return; global.set $g (i32.const 1)`.
   - Result: Binaryen made `$g` immutable and removed the fake global traffic.
3. No-catch compare guard:
   - Shape: `if (i32.eq (try_table (result i32) (global.get $g)) (i32.const 0)) return; global.set $g (i32.const 1)`.
   - Result: Binaryen made `$g` immutable and removed the fake global traffic.
4. No-catch reverse-compare guard:
   - Shape: `if (i32.eq (i32.const 0) (try_table (result i32) (global.get $g))) return; global.set $g (i32.const 1)`.
   - Result: Binaryen made `$g` immutable and removed the fake global traffic.
5. No-catch direct guard with block-wrapped set tail:
   - Shape: direct `try_table` condition followed by `if return`, then a void `block` containing the same-global const set.
   - Result: Binaryen made `$g` immutable and removed the fake global traffic.

Negative probe:

- Catch-bearing direct guard:
  - Shape: `block $exit (if (try_table (result i32) (catch $e $exit) (global.get $g)) return; global.set $g (i32.const 1))`.
  - Result: Binaryen preserved the mutable global and the `global.get` / `global.set` traffic.

## Local TDD

Added focused tests in `src/passes/simplify_globals_optimizing_test.mbt` for:

- transparent no-catch `try_table` direct `if return; set`,
- transparent no-catch `try_table` `i32.eqz` `if return; set`,
- transparent no-catch `try_table` compare `if return; set`,
- transparent no-catch `try_table` reverse-compare `if return; set`,
- transparent no-catch `try_table` direct `if return; block(set)`,
- catch-bearing direct `try_table` `if return; set` conservatism.

Before implementation, `moon test src/passes` failed the direct, `i32.eqz`, and compare positives because `$g` remained mutable. The later reverse-compare and block-wrapped-set tests are source-backed coverage for the same implemented helper paths.

## Implementation

Updated `src/passes/simplify_globals_optimizing.mbt` so the read-only-to-write scanner dispatches from `@lib.TryTable` into the existing exact `if return; set` helper family. Each newly accepted helper case requires:

- `try_table` with `catches.length() == 0`,
- an exact return guard (`if` body is `return`, no `else`),
- the already-supported direct, adjacent `i32.eqz`, compare-with-const, or reverse-compare-with-const condition shape,
- a same-global constant set tail, either direct or block-wrapped.

Catch-bearing `try_table` wrappers remain conservative. This does not add catch joins, branch/throw handling, arbitrary control-transfer matching, calls as read-only-to-write events, trapping operations, or broader `try_table` value-flow.

## Validation

- `moon test src/passes`: `1530/1530` passed after implementation.
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-if-return-rotw-10k`
  - Compared: `9975/10000`
  - Normalized matches: `9975`
  - Mismatches: `0`
  - Validation failures: `0`
  - Generator failures: `0`
  - Command failures: `25` Binaryen/tool failures

## Status

`[SGO]003` remains active/partial. This is a narrow no-catch `try_table` `if return; set` read-only-to-write alignment slice, not full Binaryen `SimplifyGlobals.cpp` parity.
