# SGO try_table condition read-only-to-write

_Date:_ 2026-05-24  
_Status:_ filed into living SGO docs/backlog

## Question

Can a transparent `try_table` result wrapper around a candidate global read count as a read-only-to-write self guard for `simplify-globals-optimizing`?

## Source probes

Focused Binaryen v129 probes used `wasm-opt --enable-exception-handling --simplify-globals-optimizing -S`:

1. A mutable `$g` is read only as the condition of `if (try_table (result i32) (global.get $g))`, whose then arm writes `$g = 1`.
   - Binaryen makes `$g` immutable and removes the fake global traffic.
2. The same shape with a catch clause on the `try_table`.
   - Binaryen preserves the mutable global, the condition read, and the write.

Together these support a very narrow read-only-to-write extension: an adjacent no-catch `try_table` condition can be treated like the already-supported transparent block/loop condition wrappers, but caught `try_table` conditions remain conservative.

## Result

Implemented a narrow read-only-to-write counter extension:

- when a `try_table` directly precedes a no-else `if`,
- and the `try_table` has no catch clauses,
- and the body matches an already-supported block-condition global-read shape,
- and the then arm is a single constant write to the same global,
- count the body read as read-only-to-write-safe.

Caught `try_table` wrappers are intentionally excluded.

## Tests

Added:

- `simplify-globals-optimizing treats transparent try_table conditions as read-only-to-write`
  - confirms the no-catch wrapper removes the fake global and makes it immutable.
- `simplify-globals-optimizing keeps caught try_table conditions conservative`
  - confirms the catch-bearing wrapper keeps the global mutable and preserves the read/write traffic.

## Validation

- TDD failure before implementation: `moon test src/passes` failed the new no-catch positive because `$g` remained mutable.
- Focused validation after implementation: `moon test src/passes` passed (`1522/1522`; existing DAE/pass-manager unused warnings only).
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-condition-rotw-10k` reported `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

## Non-claims

- This does not support caught `try_table` read-only-to-write conditions.
- This does not support `try_table` conditions with throwing/effectful/global-derived side-effect paths beyond the already-supported body scanners.
- This does not broaden branch/return/throw/catch joins or general exception-control reasoning.
- This does not claim full Binaryen `SimplifyGlobals.cpp` parity; `[SGO]003` remains active/partial.
