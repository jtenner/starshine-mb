# SGO else-local runtime facts

_Date:_ 2026-05-24  
_Status:_ filed into living SGO docs/backlog

## Question

Can Starshine rewrite runtime facts that are created inside an `else` arm itself, while preserving the existing conservative boundary that does not carry pre-`if` facts into else arms or past post-`if` joins?

## Source probe

A focused Binaryen v129 probe used `wasm-opt --simplify-globals-optimizing -S` on this shape:

- a mutable `$g` starts at `0`,
- an exported function branches on a parameter,
- the `then` arm returns `i32.const 0`,
- the `else` arm runs `i32.const 5; global.set $g; global.get $g`.

Binaryen rewrites the else-local read to `i32.const 5` while keeping the `global.set`. This shows that an else arm can have its own linear runtime trace even though facts from before the `if` are not carried into the else arm and no facts are joined after the `if`.

## Result

Implemented a narrow runtime trace rewrite for `if` instructions with `else` arms:

- the existing then-arm behavior is unchanged and still receives a copy of the incoming facts for the dominated-then-body subset,
- the else arm is now rewritten with a fresh empty fact table, so facts established inside the else arm can rewrite later reads in that same arm,
- incoming facts are intentionally not copied into the else arm,
- facts after the `if` are still cleared, so this does not implement branch joins.

## Tests

Added `simplify-globals-optimizing propagates else-local runtime facts`:

- confirms an else-local `global.set $g (i32.const 5)` lets the following same-arm `global.get $g` become `I32(5)`,
- preserves the existing `simplify-globals-optimizing keeps else-arm runtime reads conservative` guardrail for pre-`if` facts.

## Validation

- TDD failure before implementation: `moon test src/passes` failed the new else-local runtime test because the else arm still contained `global.get $g`.
- Focused validation after implementation: `moon test src/passes` passed (`1518/1518`; existing DAE/pass-manager unused warnings only).
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-else-local-runtime-10k` reported `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

## Non-claims

- This does not propagate pre-`if` facts into else arms.
- This does not join facts after `if` expressions.
- This does not broaden branch/control-transfer matching or read-only-to-write call counting.
- This does not claim full Binaryen `SimplifyGlobals.cpp` parity; `[SGO]003` remains active/partial.
