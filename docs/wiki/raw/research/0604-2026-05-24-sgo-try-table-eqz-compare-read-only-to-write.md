# SGO try_table eqz/compare read-only-to-write

_Date:_ 2026-05-24  
_Status:_ filed into living SGO docs/backlog

## Question

After the 0603 direct-condition slice, can transparent no-catch `try_table` result wrappers also count as read-only-to-write self guards when their result flows through adjacent `i32.eqz` or compare-with-const conditions?

## Source probes

Focused Binaryen v129 probes used `wasm-opt --enable-exception-handling --simplify-globals-optimizing -S`:

1. A mutable `$g` is read only in `if (i32.eqz (try_table (result i32) (global.get $g)))`, whose then arm writes `$g = 1`.
   - Binaryen makes `$g` immutable and removes the fake global traffic.
2. A mutable `$g` is read only in `if (i32.eq (try_table (result i32) (global.get $g)) (i32.const 0))`, whose then arm writes `$g = 1`.
   - Binaryen makes `$g` immutable and removes the fake global traffic.
3. The eqz shape with a catch clause on the `try_table`.
   - Binaryen preserves the mutable global, the condition read, and the write.

Together these support extending the 0603 no-catch transparent `try_table` condition wrapper through the already-supported adjacent `i32.eqz` and compare-with-const condition forms, while keeping caught exception-control wrappers conservative.

## Result

Implemented a narrow read-only-to-write counter extension:

- no-catch `try_table` wrappers directly followed by `i32.eqz` and a no-else `if` may count as read-only-to-write-safe when their body matches an existing safe block-condition read shape,
- no-catch `try_table` wrappers directly followed by a constant and supported compare before a no-else `if` may count the same way,
- reverse compare order is routed through the same helper for consistency,
- catch-bearing `try_table` wrappers remain excluded.

## Tests

Added:

- `simplify-globals-optimizing treats transparent try_table eqz conditions as read-only-to-write`
- `simplify-globals-optimizing treats transparent try_table compare conditions as read-only-to-write`

The existing 0603 catch-bearing negative continues to pin the conservative boundary for caught `try_table` conditions.

## Validation

- TDD failure before implementation: `moon test src/passes` failed both new positives because `$g` remained mutable.
- Focused validation after implementation: `moon test src/passes` passed (`1524/1524`; existing DAE/pass-manager unused warnings only).
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-eqz-compare-rotw-10k` reported `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

## Non-claims

- This does not support catch-bearing `try_table` read-only-to-write conditions.
- This does not support arbitrary exception-control joins or caught paths.
- This does not broaden call, throw, branch, return, trapping, memory/table growth, atomics, SIMD memory, or relaxed SIMD surfaces.
- This does not claim full Binaryen `SimplifyGlobals.cpp` parity; `[SGO]003` remains active/partial.
