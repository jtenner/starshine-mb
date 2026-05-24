# SGO no-catch `try_table` `ref.is_null` read-only-to-write

## Question

Can Starshine treat a no-catch `try_table` result wrapper as transparent when its reference result feeds `ref.is_null` in read-only-to-write guards, matching Binaryen without widening caught exception-control paths?

## Binaryen v129 probes

All probes used local `wasm-opt version_129` with `--enable-exception-handling --enable-reference-types --simplify-globals-optimizing -S`.

Positive probes:

1. No-catch `ref.is_null` condition:
   - Shape: `if (ref.is_null (try_table (result funcref) (global.get $g))) then global.set $g (ref.func $f)`.
   - Result: Binaryen made `$g` immutable and removed the fake `global.get` / `global.set` traffic.
2. No-catch `ref.is_null` exact `if return; set` guard:
   - Shape: `if (ref.is_null (try_table (result funcref) (global.get $g))) return; global.set $g (ref.func $f)`.
   - Result: Binaryen made `$g` immutable and removed the fake global traffic.

Negative probes:

1. Catch-bearing `ref.is_null` condition:
   - Shape: `block $exit (if (ref.is_null (try_table (result funcref) (catch $e $exit) (global.get $g))) then global.set $g (ref.func $f))`.
   - Result: Binaryen preserved mutable global traffic in the condition/write family.
2. Catch-bearing `ref.is_null` `if return; set` guard:
   - Shape: `block $exit (if (ref.is_null (try_table (result funcref) (catch $e $exit) (global.get $g))) return; global.set $g (ref.func $f))`.
   - Result: Binaryen preserved the mutable-global family.

## Local TDD

Added focused tests in `src/passes/simplify_globals_optimizing_test.mbt` for:

- transparent no-catch `try_table` feeding `ref.is_null` into a same-global ref constant set,
- catch-bearing `try_table` feeding `ref.is_null` conservatism,
- transparent no-catch `try_table` feeding `ref.is_null` into exact `if return; set`,
- catch-bearing `try_table` feeding `ref.is_null` exact `if return; set` conservatism.

Before implementation, `moon test src/passes` failed the two no-catch positives because `$g` remained mutable. The catch-bearing tests pin the conservative global mutability boundary; Starshine may remove unobservable private function-body traffic through other existing cleanup, so the negative assertions intentionally focus on preserving mutable global status rather than raw body text.

## Implementation

Updated `src/passes/simplify_globals_optimizing.mbt` with narrow no-catch `try_table` + `ref.is_null` helper cases for:

- adjacent no-else same-global constant-set conditions,
- exact `if return; set` guards with a direct constant set tail.

Both helpers require `catches.length() == 0`; caught wrappers remain conservative. The implementation reuses the existing safe body reader for the `try_table` body and the existing const-set recognition for `ref.func` writes.

## Validation

- `moon test src/passes`: `1534/1534` passed after implementation.
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-ref-is-null-rotw-10k`
  - Compared: `9975/10000`
  - Normalized matches: `9975`
  - Mismatches: `0`
  - Validation failures: `0`
  - Generator failures: `0`
  - Command failures: `25` Binaryen/tool failures

## Status

`[SGO]003` remains active/partial. This is a narrow no-catch `try_table` + `ref.is_null` read-only-to-write alignment slice, not full Binaryen `SimplifyGlobals.cpp` parity.
