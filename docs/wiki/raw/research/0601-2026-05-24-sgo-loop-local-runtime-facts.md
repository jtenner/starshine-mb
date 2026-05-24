# SGO loop-local runtime facts

_Date:_ 2026-05-24  
_Status:_ filed into living SGO docs/backlog

## Question

Can Starshine rewrite runtime facts established inside a loop body itself, without carrying pre-loop facts into the loop or carrying loop facts out through the backedge/join?

## Source probes

Focused Binaryen v129 probes used `wasm-opt --simplify-globals-optimizing -S`:

1. Exported mutable `$g`, loop body runs `i32.const 5; global.set $g; global.get $g; drop; local.get $p; br_if 0`.
   - Binaryen rewrites the same-iteration `global.get $g` to `i32.const 5`, and later cleanup removes the drop.
2. Pre-loop `global.set $g (i32.const 9)` followed by a loop that only reads `$g` before a possible backedge.
   - Binaryen preserves the loop-body `global.get $g`.

Together these support a fresh loop-local runtime fact table: facts created inside the loop body can rewrite later same-body reads, but incoming facts should not be trusted inside the loop.

## Result

Implemented a narrow runtime trace rewrite for `loop` bodies:

- loop bodies are rewritten with a fresh empty fact table,
- same-body constant writes can rewrite later reads before a branch/backedge barrier,
- incoming facts are intentionally not copied into the loop body,
- facts after the loop are still cleared.

Existing branch handling inside the recursive body remains conservative: `br`, `br_if`, returns, calls that clear facts, and other barriers still clear the loop-local facts at the point where they appear.

## Tests

Added `simplify-globals-optimizing propagates loop-local runtime facts`:

- uses an exported mutable global to avoid proving away the global itself,
- confirms the loop keeps the observable `global.set`,
- confirms the same-body `global.get` disappears.

Existing loop-contained block and reference-loop conservative tests remain green.

## Validation

- TDD failure before implementation: `moon test src/passes` failed the new loop-local runtime test because the loop body still contained `global.get $g`.
- Focused validation after implementation: `moon test src/passes` passed (`1519/1519`; existing DAE/pass-manager unused warnings only).
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-loop-local-runtime-10k` reported `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

## Non-claims

- This does not carry pre-loop facts into loops.
- This does not carry loop facts out after loops.
- This does not reason about loop fixed points, backedge values, or branch joins.
- This does not broaden read-only-to-write loop matching or full Binaryen `FlowScanner` behavior.
- This does not claim full Binaryen `SimplifyGlobals.cpp` parity; `[SGO]003` remains active/partial.
