# SGO try_table-local runtime facts

_Date:_ 2026-05-24  
_Status:_ filed into living SGO docs/backlog

## Question

Can Starshine rewrite runtime facts that are known while walking the body of a `try_table`, without carrying facts out past the exception-control join?

## Source probes

Focused Binaryen v129 probes used `wasm-opt --enable-exception-handling --simplify-globals-optimizing -S`:

1. A `try_table` body runs `i32.const 5; global.set $g; global.get $g; return` inside a block catch target.
   - Binaryen rewrites the body-local `global.get $g` to `i32.const 5`.
2. A pre-`try_table` `global.set $g (i32.const 7)` followed by a body-local `global.get $g`.
   - Binaryen rewrites the body-local read to `i32.const 7`.
3. A `try_table` body writes `$g = 5`, then execution continues after the enclosing block and reads `$g`.
   - Binaryen preserves the post-`try_table` `global.get $g`.

Together these support a narrow `try_table` body walk: facts available before the `try_table` may be used while rewriting the body, and facts created in the body may rewrite later same-body reads, but facts must be cleared after the `try_table` because catches/control joins can skip the normal body suffix.

## Result

Implemented a narrow runtime trace rewrite for `try_table` bodies:

- the body is rewritten with a copy of incoming facts,
- body-local constant writes can rewrite later reads before local barriers,
- existing `throw`, `throw_ref`, branch, return, call, and nested-control barriers still clear facts at the point where they appear,
- facts after the `try_table` are always cleared.

The previous post-`try_table` conservative guardrail remains green.

## Tests

Added `simplify-globals-optimizing propagates try_table-local runtime facts`:

- uses an exception-tagged `try_table` with a catch target,
- writes a mutable global to `5`, immediately reads it in the `try_table` body, and returns,
- confirms the body-local read is replaced and no `global.get` remains in that function.

Existing `simplify-globals-optimizing keeps nested try_table block runtime facts conservative` continues to pin that facts from inside the `try_table` are not carried out to a post-block read.

## Validation

- TDD failure before implementation: `moon test src/passes` failed the new try-table-local runtime test because the `try_table` body still contained `global.get $g`.
- Focused validation after implementation: `moon test src/passes` passed (`1520/1520`; existing DAE/pass-manager unused warnings only).
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-try-table-local-runtime-10k` reported `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

## Non-claims

- This does not carry `try_table` body facts out after the exception-control join.
- This does not reason about catch-specific values or joins.
- This does not broaden `throw`, `throw_ref`, branch, return, or `try_table` read-only-to-write matching.
- This does not claim full Binaryen `SimplifyGlobals.cpp` parity; `[SGO]003` remains active/partial.
