# SGO block-carried direct function effects

_Date:_ 2026-05-24  
_Status:_ filed into living SGO docs/backlog

## Question

After the 0598 direct-call function-effects slice, can the same unaffected-global runtime facts be carried through a plain `block` that contains an ordinary direct call, without weakening branch, loop, imported-call, indirect-call, or return/control-transfer barriers?

## Source probe

A focused Binaryen v129 probe used `wasm-opt --generate-global-effects --simplify-globals -S` on this shape:

- `$test` writes `$A = 11` and `$B = 22`,
- a plain `block` calls `$setA`,
- `$setA` syntactically mutates only `$A`,
- after the block, `$test` reads `$A` and `$B`.

Binaryen keeps the post-block `$A` read and rewrites the post-block `$B` read to `i32.const 22`. That makes a plain block with only carryable ordinary direct calls a safe follow-up to 0598's direct-call runtime fact invalidation.

## Result

Implemented a narrow carryable-barrier check for SGO runtime trace propagation:

- ordinary direct `call` instructions are carryable because the existing 0598 effect rows clear only mutated globals from the copied fact set,
- nested plain blocks are carryable only if their body is carryable,
- all other existing runtime barriers remain uncarryable and still clear facts after the block, including imported/unknown effects through the callee row, indirect calls, `call_ref`, return calls, loops, branches, `if`, `try_table`, throws, and returns.

This intentionally does not join facts across `if`/`else`, reason about loops, or carry facts through control-transfer instructions.

## Tests

Added `simplify-globals-optimizing carries direct function effects through plain blocks`:

- confirms the block-local call remains,
- confirms the post-block `$A` read remains conservative,
- confirms the unaffected post-block `$B` read is rewritten to `I32(22)`.

The existing imported-call-in-block and nested-branch block guardrails remain green and continue to pin non-carryable block conservatism.

## Validation

- TDD failure before implementation: `moon test src/passes` failed the new block-carried function-effects positive because `$B` remained a post-block `global.get`.
- Focused validation after implementation: `moon test src/passes` passed (`1517/1517`; existing DAE/pass-manager unused warnings only).
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-block-call-effects-10k` reported `9975/10000` compared, `9975` normalized matches, `0` mismatches, `0` validation failures, `0` generator failures, and `25` Binaryen/tool command failures.

## Non-claims

- This does not implement standalone `generate-global-effects`.
- This does not make calls count as local read-only-to-write events.
- This does not broaden `if`, loop, branch, return, `try_table`, indirect-call, `call_ref`, or dynamic return-call runtime propagation.
- This does not claim full Binaryen `SimplifyGlobals.cpp` parity; `[SGO]003` remains active/partial.
