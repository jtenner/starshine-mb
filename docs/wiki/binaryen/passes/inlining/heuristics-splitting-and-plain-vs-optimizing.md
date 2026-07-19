---
kind: concept
status: supported
last_reviewed: 2026-07-19
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/Inlining.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/tools/optimization-options.h
  - ./index.md
related:
  - ./binaryen-strategy.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ../inlining-optimizing/index.md
---

# Inlining heuristics, splitting, and plain-vs-optimizing behavior

## 1. Two public stop points

| Pass | Shared scan/plan/rewrite | Dead-helper cleanup | Touched nested cleanup |
| --- | --- | --- | --- |
| `inlining` | yes | yes | no |
| `inlining-optimizing` | yes | yes | yes |

The optimizing suffix prepends `precompute-propagate` and runs the represented Binaryen v131 default function pipeline on changed functions only. Starshine tests this order explicitly.

## 2. Chosen actions are direct

V131 chooses reachable direct `call` / `return_call` sites. Keep that separate from other call forms:

- `ref.func` contributes references and can keep a declaration alive;
- `call_indirect` / `call_ref` and their tail forms can occur in copied code;
- indirect/ref forms do not count as direct-call recursion hazards for flexible profitability;
- speculative indirect/ref callee recovery is not part of this planner.

## 3. Profitability order

For represented functions, Starshine follows the v131 order:

1. explicit no-full-inline policy;
2. toolchain `NeverInline` / `AlwaysInline`;
3. `alwaysInlineMaxSize`;
4. one reference, not globally rooted, within `oneCallerInlineMaxSize`;
5. `TrivialInstruction::Shrinks`;
6. `flexibleInlineMaxSize`;
7. optimize level at least 3 and shrink level 0;
8. `TrivialInstruction::MayNotShrink`;
9. no direct calls and no loops unless loop inlining is enabled.

The combined caller/callee estimate must also remain strictly below `maxCombinedBinarySize`, using Binaryen's 2.5 encoded bytes per expression estimate.

## 4. Trivial instructions

### `Shrinks`

The body is one non-structured instruction whose direct children are parameter `local.get`s in order. Binaryen allows an ordered prefix: trailing unused parameters do not need to appear.

Starshine derives this from the lifted expression tree, so the policy covers all represented instruction families rather than a hand-maintained subset.

### `MayNotShrink`

The body is still one instruction and each direct operand has expression size one, but operands may be constants, repeated locals, or otherwise not the exact ordered-prefix shape. These cases are admitted only after the O3/no-shrink gate.

### Why the distinction matters

A direct call with duplicate operands, an instruction with constants, a load, a SIMD/GC instruction, or a zero-operand constant body can follow a different policy path even when its raw instruction count is small.

## 5. Policy controls

The public Binaryen-compatible controls are:

- `--always-inline-max-function-size`, `-aimfs`;
- `--one-caller-inline-max-function-size`, `-ocimfs`;
- `--flexible-inline-max-function-size`, `-fimfs`;
- `--inline-max-combined-binary-size`, `-imcbs`;
- `--inline-functions-with-loops`, `-ifwl`;
- `--partial-inlining-ifs`, `-pii`.

`@binaryen.inline`, `@metadata.code.inline`, `no-inline`, `no-full-inline`, and `no-partial-inline` are distinct channels.

## 6. Partial Pattern A

Pattern A recognizes a leading simple guard whose true arm returns from a void function. It flips the guard and calls an outlined suffix on the opposite path.

## 7. Partial Pattern B

Pattern B recognizes a bounded sequence of top-level one-armed `if`s plus an optional simple final value.

Safety checks include:

- simple conditions only;
- no else arms;
- no escaping branches;
- none-typed bodies without returns, or terminal-unreachable bodies;
- no final-value read of a local written by an outlined arm;
- configured maximum guard count.

Result-producing terminal arms may end through return, tail call, trap, throw, or another represented terminal-unreachable instruction.

## 8. Simple conditions

The v131 splitter accepts:

- `local.get`;
- `global.get`;
- any represented Binaryen Unary operation around a simple expression;
- `ref.is_null` around a simple expression.

Starshine includes scalar, conversion, SIMD, and relaxed-SIMD Unary operations represented locally. It deliberately excludes loads, ref casts, `ref.as_non_null`, and GC conversions, which are one-input operations but are not Binaryen's `Unary` class.

## 9. EH tail calls

At non-tail outer callsites, nested `return_call`, `return_call_indirect`, and `return_call_ref` normally become a call plus branch to the inlined return block.

When the nested tail call is inside `try_table`, operands are evaluated and spilled inside the EH region, then the call executes after branching out. This preserves the original rule that exceptions from the tail-called function are not caught by a handler in the exited frame.

The same mechanism repairs tail callsites inside caller `try_table` and `inline-main` wrappers. Added wrapper blocks shift existing function-target branches and catch targets correctly.

## 10. Iteration and removal

The planner avoids same-wave inline-into/inline-from races, skips self-recursion, bounds repeated work, and repeats until no action remains or the cap is reached.

Inlining a rooted function does not imply deleting it. Exports, start, elements, table/global initializers, `ref.func`, and surviving calls can preserve the declaration.

## Evidence

Focused behavior is `120/120`; white-box invariants are `14/14`; both official-v131 plain and optimizing GenValid closeouts are `10000/10000` normalized matches with zero failures.
