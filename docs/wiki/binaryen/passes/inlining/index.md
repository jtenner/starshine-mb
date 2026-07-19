---
kind: entity
status: supported
last_reviewed: 2026-07-19
sources:
  - ../../release-horizon-and-oracles.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/Inlining.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/tools/optimization-options.h
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/inlining_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../inlining-optimizing/index.md
  - ../inline-main/index.md
---

# `inlining`

## Status

Starshine's plain `inlining` pass is supported at Binaryen `version_131` behavior parity for the represented direct-inliner surface. The July 19, 2026 audit accounts for every v131 transform and policy family in `Inlining.cpp`:

- released `@binaryen.inline` Never/Always policy;
- tiny, one-caller, shrinking-trivial, may-grow-trivial, flexible, loop, and combined-size profitability;
- Binaryen's six public tuning flags and short aliases;
- reachable direct `call` / `return_call` planning and same-wave race avoidance;
- Pattern A and Pattern B partial splitting;
- parameter/local copying, default initialization, return repair, multivalue block typing, and helper removal;
- direct, indirect, and reference tail-call repair, including EH-aware operand localization and hoisting from `try_table`;
- export/start/element/table/global function-reference survival;
- function/name/annotation remapping after compaction;
- bounded repeated work and plain-pass stop-point behavior.

There is no open v131 pass-owned transform-family gap. Remaining limitations are shared representation or debug-metadata boundaries, not missing inliner behavior:

- legacy `try_delegate` is not a first-class local instruction surface;
- expression-level code metadata, branch hints, and source-map offset repair are not modeled locally;
- copied callee local/label debug names are not synthesized into callers, although valid caller names survive and stale rewritten label maps are dropped;
- indirect/ref **callee recovery** is not part of Binaryen v131's chosen-action planner and remains optional future research.

## Role

`inlining` is the plain sibling of [`inlining-optimizing`](../inlining-optimizing/index.md). Both use the same module-level planner and body-copy engine. Plain mode stops after rewrite, repair, and dead-helper cleanup; it must not run the optimizing sibling's nested `precompute-propagate` plus default function pipeline.

## Algorithm

1. Build whole-module function summaries: size, references, roots, direct calls, loops, trivial-instruction class, policies, and type information.
2. Classify each defined function as full-inlineable, partial-inlineable, or uninlineable.
3. Plan reachable direct calls while avoiding self-recursion and same-wave inline-into/inline-from conflicts.
4. Check Binaryen's strict estimated combined binary-size ceiling for each chosen action.
5. Copy the callee into the caller:
   - evaluate operands in order and store them into fresh parameter locals;
   - append and remap callee locals;
   - initialize defaultable body locals on every inline execution;
   - rewrite `return` into the inlined result block;
   - preserve tail calls at tail sites;
   - lower nested tail calls at non-tail sites;
   - localize operands and hoist nested EH tail calls so exception catchability is unchanged.
6. Repair branch depths introduced by hoist wrappers, including branches to the implicit function label and `try_table` catch targets.
7. Remove only private helpers whose direct and reference uses are gone and which are not globally rooted.
8. Repeat within Binaryen's bounded-work policy.

## Profitability policy

The implemented order matches v131:

1. reject explicit no-full-inline policy;
2. honor toolchain Never/Always hints;
3. admit `size <= alwaysInlineMaxSize`;
4. admit one-reference, non-rooted functions within `oneCallerInlineMaxSize` (`-1` means unbounded);
5. admit shrinking trivial instructions in all optimization modes;
6. enforce `flexibleInlineMaxSize`;
7. require optimize level at least 3 and shrink level 0 for flexible cases;
8. admit may-grow trivial instructions;
9. otherwise require no direct calls and no loops unless loop inlining is enabled.

Indirect calls, `call_ref`, `return_call_indirect`, and `return_call_ref` do not count as direct-call recursion hazards in this policy, matching Binaryen's scanner.

## Public tuning flags

The CLI accepts Binaryen's long and short spellings, with either separate values or `=value` where applicable:

- `--always-inline-max-function-size`, `-aimfs`;
- `--one-caller-inline-max-function-size`, `-ocimfs`;
- `--flexible-inline-max-function-size`, `-fimfs`;
- `--inline-max-combined-binary-size`, `-imcbs`;
- `--inline-functions-with-loops`, `-ifwl`;
- `--partial-inlining-ifs`, `-pii`.

The same values flow through `CliParseResult`, JSON config options, `OptimizeOptions`, `HotPipelineOptions`, and the shared inliner entrypoint.

## Partial inlining

Partial splitting is enabled only when optimize level is at least 3, shrink level is 0, and `partialInliningIfs > 0`.

- Pattern A flips a leading simple `if (...) return` guard and outlines the heavy suffix.
- Pattern B outlines up to the configured number of leading guarded bodies and retains an optional simple final value.
- Simple conditions match v131's `LocalGet` / `GlobalGet` plus the complete represented Binaryen Unary family and `RefIsNull`; loads, ref casts, and GC conversions are not over-admitted.
- Result arms may exit through return, tail call, trap, throw, or another represented terminal-unreachable instruction.
- `no-full-inline` still allows splitting; `no-partial-inline` and `no-inline` suppress it.

## Evidence

Current focused validation:

- CLI parser: `54/54`;
- command package: `107/107`;
- inlining behavior tests: `120/120`;
- inlining white-box tests: `14/14`;
- full repository suite: `9452/9452`.

Official v131 GenValid closeout, using `_build/native/release/build/cmd/cmd.exe` and `.tmp/binaryen-version-131-bin/bin/wasm-opt`:

- plain: `.tmp/pass-fuzz-inlining-v131-closeout-10000` — `10000/10000` compared, `10000` normalized matches, zero mismatches or failures;
- optimizing: `.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000` — `10000/10000` compared, `10000` normalized matches, zero mismatches or failures.

Both runs used explicit `wasm-opt version 131 (version_131)` and reported zero command failures.

## Page map

- [`binaryen-strategy.md`](./binaryen-strategy.md): upstream phases and rationale.
- [`implementation-structure-and-tests.md`](./implementation-structure-and-tests.md): local owner/helper/test map.
- [`heuristics-splitting-and-plain-vs-optimizing.md`](./heuristics-splitting-and-plain-vs-optimizing.md): policy and sibling distinctions.
- [`compilation-hints-vs-no-inline-flags-and-clone-survival.md`](./compilation-hints-vs-no-inline-flags-and-clone-survival.md): separate metadata and policy channels.
- [`wat-shapes.md`](./wat-shapes.md): representative transform shapes.
- [`starshine-strategy.md`](./starshine-strategy.md): implementation-specific summary.
- [`starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md): signoff and reopening criteria.
