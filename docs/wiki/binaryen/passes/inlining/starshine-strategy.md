---
kind: concept
status: supported
last_reviewed: 2026-07-19
sources:
  - ./index.md
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/inlining_wbtest.mbt
  - ../../../../../src/passes/no_inline.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-port-readiness-and-validation.md
  - ../inlining-optimizing/starshine-strategy.md
  - ../inline-main/starshine-strategy.md
---

# Starshine Strategy For `inlining`

## Current status

`inlining` is an active, supported module pass with no open Binaryen v131 pass-owned behavior gap. It shares its planner and rewrite engine with `inlining-optimizing` and `inline-main`, while preserving each public pass's distinct chooser and cleanup contract.

## Local owner map

- `src/passes/inlining.mbt`
  - whole-module summary and profitability;
  - partial splitter;
  - direct-call planner;
  - body-copy and local/type/control repair;
  - EH tail-call localization and hoisting;
  - helper removal and metadata remapping;
  - plain and optimizing entrypoints;
  - `inline-main` exact-target reuse.
- `src/passes/no_inline.mbt`
  - `no-inline`, `no-full-inline`, and `no-partial-inline` wildcard policy;
  - stable numeric names for stripped functions;
  - policy annotation copy/deduplication.
- `src/cli/cli.mbt` and `src/cmd/cmd.mbt`
  - Binaryen-compatible tuning flags, aliases, help, JSON config, merge precedence, and option propagation.
- `src/passes/optimize.mbt` and `src/passes/pass_manager.mbt`
  - active registry entries and module-pass dispatch.

## Implemented behavior

### Summary and eligibility

- direct-call and `ref.func` reference accounting;
- export/start/element/table/global roots;
- released v131 toolchain Always/Never hints;
- explicit no-full/no-partial policy separation;
- Binaryen's exact tiny, one-caller, trivial, flexible, loop, and shrink/speed ordering;
- generic trivial-instruction classification from HOT direct children, including `Shrinks` and `MayNotShrink`;
- direct-call-only recursion hazard tracking, so indirect/ref calls and their tail forms remain flexible-policy candidates;
- strict 2.5-bytes-per-expression combined-size estimate and strict configured ceiling.

### Partial splitting

- Pattern A leading-return guards;
- Pattern B multiple guarded bodies and optional final value;
- complete represented v131 Unary/`RefIsNull` simple-condition family;
- terminal result arms for returns, tail calls, traps, throws, and represented terminal-unreachable instructions;
- deterministic `byn-split-outlined-A$...` / `B$...` names;
- parameter forwarding, annotation copy, temporary-marker cleanup, and policy inheritance.

### Rewrite and repair

- operand evaluation into fresh parameter locals;
- copied body-local append/remap;
- per-execution initialization of numeric, vector, and nullable-reference locals;
- non-nullable local preservation without invalid zero synthesis;
- scalar and multivalue wrapper block types, including synthesized zero-param result types;
- callee `return` to wrapper-branch repair;
- nested direct/indirect/ref tail preservation at tail sites;
- nested direct/indirect/ref tail lowering at non-tail sites;
- EH-aware operand spills and call hoisting from `try_table`;
- table32/table64-aware indirect target spills;
- branch-depth repair for added hoist wrappers, all represented branch-on-* forms, branches to the function label, and `try_table` catch targets;
- reachable-call gating after unconditional terminators;
- bounded iteration and same-wave race guards.

### Removal and metadata

- private helper removal only after all represented uses disappear;
- function-index rewriting across module sections;
- function-name and function-annotation remapping;
- valid caller local-name preservation;
- untouched label-name preservation and rewritten label-map removal;
- outlined-helper annotation copy;
- plain mode remains free of the optimizing sibling's nested pipeline.

## Public options

The following Binaryen spellings are accepted and propagated end to end:

- `--always-inline-max-function-size` / `-aimfs`;
- `--one-caller-inline-max-function-size` / `-ocimfs`;
- `--flexible-inline-max-function-size` / `-fimfs`;
- `--inline-max-combined-binary-size` / `-imcbs`;
- `--inline-functions-with-loops` / `-ifwl`;
- `--partial-inlining-ifs` / `-pii`.

## Deliberate non-pass boundaries

These do not reopen direct inlining:

- legacy `try_delegate` representation;
- expression-level branch hints and other byte-offset code metadata;
- source-map offset repair;
- copied callee local/label debug-name synthesis;
- speculative indirect/ref callee recovery.

## Relationship to siblings

- `inlining`: profitability-driven whole-module direct inlining, then stop.
- `inlining-optimizing`: same direct engine, then touched-only `precompute-propagate` and the v131 default function pipeline.
- `inline-main`: exact `main` / `__original_main` chooser, no profitability, helper retained.

## Evidence and reopening criteria

Focused tests are `120/120`; white-box tests are `14/14`; full `moon test` is `9452/9452`. Plain and optimizing official-v131 GenValid closeout are each `10000/10000` normalized matches with no failures.

Reopen direct behavior only for a minimized semantic or validation failure, a source-backed missing v131 transform family, a proven size-losing Starshine divergence, or a pass-local performance regression. Shared nested-scheduler abstraction work remains tracked separately under `[O4Z-NESTED]001`.
