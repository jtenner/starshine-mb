---
kind: concept
status: supported
last_reviewed: 2026-07-19
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/Inlining.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/opt-utils.h
  - ./index.md
  - ../inlining/index.md
related:
  - ./starshine-strategy.md
  - ./implementation-structure-and-tests.md
---

# `inlining-optimizing`: planning, splitting, and reruns

## 1. Planning is module-wide

The chosen actions are direct `call` / `return_call` sites, but the decision depends on module-wide facts:

- references from direct calls and `ref.func`;
- export/start/element/table/global roots;
- function size, direct calls, loops, types, and policies;
- same-wave inline-into/inline-from conflicts;
- strict combined-size admission;
- bounded repeated work.

Indirect/ref calls matter to copied-body behavior and flexible policy, but v131 does not use them as chosen callee-recovery actions.

## 2. Profitability is layered

The order is policy-significant:

1. explicit no-full-inline policy;
2. toolchain Never/Always;
3. always-inline size;
4. one-caller size;
5. shrinking trivial instructions;
6. flexible maximum;
7. O3/no-shrink gate;
8. may-grow trivial instructions;
9. no-direct-call and loop policy.

The trivial classes are derived from the actual one-instruction expression tree, not a narrow opcode list.

## 3. Partial inlining is its own transform

Pattern A outlines the heavy suffix after a leading simple return guard. Pattern B outlines one or more guarded bodies and retains an optional simple final value.

The represented condition family matches v131 `LocalGet` / `GlobalGet` followed by Unary operations or `RefIsNull`. Result arms may terminate through return, tail call, trap, throw, or another represented unreachable exit.

`no-full-inline` allows splitting; `no-partial-inline` and `no-inline` suppress it.

## 4. EH tail calls require localization

A nested tail call inside `try_table` cannot simply become an ordinary call in place: that would make the callee's exceptions catchable by a handler that the original tail call had exited.

Starshine now matches the v131 strategy:

1. evaluate operands inside the original EH region;
2. spill them to correctly typed locals;
3. branch out through generated wrapper blocks;
4. reload operands and execute the non-tail call outside that EH region;
5. branch to the inlined return target.

This applies to direct, indirect, and reference tail calls, including table64 indirect indices. Existing function-target branches and catch targets are depth-shifted when wrappers are added.

## 5. The optimizing suffix is touched-only

After inlining, Binaryen prepends `precompute-propagate` and runs the default function pipeline only on changed functions. Starshine follows that order and tests the exact represented roster.

Plain `inlining` stops before this stage.

## 6. Evidence

- focused behavior: `120/120`;
- white-box invariants: `14/14`;
- full repository: `9452/9452`;
- official v131 plain and optimizing GenValid: `10000/10000` normalized matches each, no failures.

## 7. Remaining infrastructure work

`[O4Z-NESTED]001` owns one shared expansion API for DAE, inlining, and SGO. It must not change the already-tested inlining roster or touched-only semantics.
