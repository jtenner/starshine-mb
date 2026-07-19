---
kind: concept
status: supported
last_reviewed: 2026-07-19
sources:
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/Inlining.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/NoInline.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_131/src/passes/opt-utils.h
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/inlining_wbtest.mbt
  - ../../../../../src/passes/no_inline.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-strategy.md
  - ../inlining-optimizing/implementation-structure-and-tests.md
  - ../inline-main/implementation-structure-and-tests.md
---

# `inlining`: implementation structure and tests

## Upstream owner map

Binaryen v131 keeps the family in `src/passes/Inlining.cpp`:

- `FunctionInfoScanner`: refs, size, direct calls, loops, legacy try-delegate, roots, trivial class, toolchain hint;
- `FunctionSplitter`: Pattern A/B detection and outlined helper creation;
- `Planner`: reachable direct `call` / `return_call` actions;
- `Updater`: local remap, returns, nested tail calls, EH localization;
- `doCodeInlining`: callsite surgery and copied-body insertion;
- `updateAfterInlining`: labels, refinalization, nondefaultable locals;
- `Inlining::iteration`: conflict selection, filtered rewrite/cleanup, helper removal;
- `InlineMainPass`: exact wrapper special case.

`src/passes/NoInline.cpp` owns full/partial policy flags. `src/passes/opt-utils.h` defines the optimizing suffix.

## Starshine owner map

### `src/passes/inlining.mbt`

Main clusters:

- module/type/index helpers;
- size and root scanning;
- HOT-backed trivial-instruction classification;
- toolchain/no-inline policy merge;
- Pattern A/B recognition and splitting;
- full-inline summary construction;
- callsite body copy and local initialization;
- nested tail-call operand typing and hoisting;
- branch/catch target depth repair;
- function removal and section remapping;
- touched-only optimizing cleanup;
- active `inline-main` exact-target chooser.

### `src/passes/no_inline.mbt`

- wildcard policy matching for named and stripped functions;
- marker deduplication;
- no-match behavior;
- clone/copy policy preservation.

### Registry and CLI

- `src/passes/optimize.mbt`: active module-pass descriptors;
- `src/passes/pass_manager.mbt`: plain/optimizing/inline-main dispatch and option forwarding;
- `src/cli/cli.mbt`: Binaryen long/short tuning aliases;
- `src/cmd/cmd.mbt`: config, help, option construction, and repro hints;
- `scripts/lib/pass-fuzz-compare-task.ts`: compare-pass admission for all three public names.

## Focused test map

`src/passes/inlining_test.mbt` covers:

- active registry/dispatch and plain-vs-optimizing stop points;
- exact `inline-main` positives and no-op families;
- no-inline policy channels and metadata remapping;
- toolchain Never/Always hints;
- tiny, one-caller, shrinking-trivial, may-grow-trivial, flexible, loop, and combined-size decisions;
- scalar, memory, table, SIMD, GC, direct-call, indirect/ref-call, constant, skipped-param, and duplicate-operand trivial families;
- nullable/nonnullable local initialization;
- scalar/multivalue result blocks and type synthesis;
- direct/indirect/ref tail preservation and non-tail lowering;
- `try_table` callsite and nested-callee hoisting;
- operand evaluation inside the original EH region;
- roots, recursive waves, cycles, helper deletion, and optimizing cleanup;
- Pattern A/B, terminal traps, returned values, and policy separation;
- exact nested pipeline order and touched filtering.

`src/passes/inlining_wbtest.mbt` covers internal invariants:

- combined-size arithmetic;
- graph/dead-suffix preservation helpers;
- GC wrapper classification fallback;
- Binaryen Unary condition classification;
- table64 indirect tail operand typing;
- branch/function/catch depth shifts introduced by hoist wrappers.

CLI/command tests cover parsing, aliases, invalid values, JSON config, help text, end-to-end option propagation, and option construction.

## V131 fixture-family accounting

| Upstream family | Starshine accounting |
| --- | --- |
| `O3_inlining*`, loop/flexible-size fixtures | configurable O3, shrink, loop, and flexible thresholds |
| `inlining-const-args`, `inlining-trivial-calls-*`, `inlining-trivial-instructions` | HOT-derived `Shrinks` / `MayNotShrink`, including constants, skipped/repeated operands, direct calls, SIMD, GC, memory, and table operations |
| `inlining-max-combined-size` | strict combined-size rail, configurable limit, Binaryen byte estimate, and iteration-start caller sizing |
| `inlining-unreachable` | reachable-call gating, unreachable copied bodies, terminal Pattern B arms, validation tests |
| `inlining-gc`, `inlining_all-features` | nullable/nonnullable locals, GC types/ops, roots, multivalue blocks |
| `inlining_memory64` | copied memory instructions retain lifted memory32/memory64 typing; table64 tail spills use i64 addresses |
| `inlining_tnh` | trapping callees remain eligible independently of trap-mode policy and propagate unreachability |
| `inlining_enable-tail-call` | direct/indirect/ref tail sites, non-tail lowering, EH localization/hoisting, table64 spills, branch-depth repair |
| `inlining-eh-legacy` | modern represented `try_table` behavior is covered; legacy `try_delegate` remains a shared input-representation boundary |
| `inlining_splitting*` | Pattern A/B, guard limits, final values, terminal traps, policies; branch-hint payload changes remain expression-metadata substrate work |
| `toolchain-inlining`, `inline-hints*`, `no-inline*` | separate toolchain, metadata, no/full/partial policy channels and clone survival |
| `inlining-optimizing*`, vacuum/OI cleanup fixtures | exact represented touched nested order, cleanup behavior, trace, validation fallback |
| `skip-pass-inlining` | nested pass skipping is global pass-runner substrate; the inlining roster is explicit and independently tested |
| Binaryen.js inlining options | equivalent Starshine CLI/config/repro controls are wired end to end; Binaryen's JS/C embedding API is not a Starshine public surface |
| `inline-main` | active exact-name chooser, ordinary/tail/EH-tail rewrite, no-op families, helper retention |
| `inlining_source-maps` | source-map offset repair is shared metadata/binary substrate work; it is not silently claimed by the pass |

## Validation snapshot

- inlining black-box: `120/120`;
- inlining white-box: `14/14`;
- CLI: `54/54`;
- command: `107/107`;
- full suite: `9452/9452`;
- plain official-v131 GenValid: `10000/10000` normalized matches;
- optimizing official-v131 GenValid: `10000/10000` normalized matches.

## Shared boundaries

Expression-level branch hints, source maps, copied callee debug names, and legacy `try_delegate` are shared representation/metadata concerns. They are not missing direct-inliner transform families.
