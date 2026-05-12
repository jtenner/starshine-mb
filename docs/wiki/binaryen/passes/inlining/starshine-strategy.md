---
kind: concept
status: working
last_reviewed: 2026-05-12
sources:
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/binaryen/2026-04-26-inlining-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
  - ../../../../../CHANGELOG.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../inlining-optimizing/starshine-strategy.md
  - ../inline-main/index.md
---

# Starshine Strategy For `inlining`

## Current status

`inlining` is a **partial active module pass** in Starshine.

This supersedes older April text that described it as boundary-only and unimplemented. The local owner is [`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt), shared with `inlining-optimizing`.

Current behavior:

- direct public pass name `inlining` is accepted;
- registry category is module pass;
- module dispatcher invokes `inlining_run_module_pass(... optimize=false ...)`;
- same implementation file also powers `inlining-optimizing` with `optimize=true`;
- plain mode does not emit or run the optimizing nested-cleanup approximation.

Current status is **not signed off**. `[INL]001` remains active because rewrite/heuristic parity is incomplete, and `[INL]002` remains active for the optimizing sibling's exact nested scheduler.

## Exact local code map

- [`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt)
  - `inlining_summary()` and `inlining_optimizing_summary()` define public help text.
  - `inlining_run_module_pass(...)` is the shared entrypoint.
  - `inl_build_function_infos(...)` builds the current simplified summary.
  - `inl_rewrite_all_calls(...)` runs direct-call rewrite.
  - `inl_make_inline_replacement(...)` appends/remaps callee locals and builds wrapper-block replacement.
  - `inl_remove_dead_inlined_helpers(...)` removes private helpers and rewrites function indices.
  - `inl_run_nested_cleanup(...)` is used only when `optimize=true`.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - registers `inlining` and `inlining-optimizing` as module passes.
  - public `optimize` / `shrink` presets still omit the Binaryen late `INL` slot.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - dispatches plain `inlining` with `optimize=false`.
  - dispatches `inlining-optimizing` with `optimize=true` and trace.
- [`src/passes/inlining_test.mbt`](../../../../../src/passes/inlining_test.mbt)
  - focused public-pipeline coverage for the current subset.
- [`agent-todo.md`](../../../../../agent-todo.md)
  - `[INL]001` tracks heuristics/rewrite/touched-function set.
  - `[INL]002` tracks exact nested useful-pass replay for the optimizing sibling.

## Implemented subset

The current plain pass handles:

- tiny no-param private helpers;
- one-use private helpers;
- direct `call` and narrow direct `return_call` sites;
- callee param/body-local appending into the caller;
- local-index remapping inside the copied body;
- simple callee `return` to wrapper-block branch rewriting;
- iterative waves after same-wave race guards expose later calls;
- helper deletion only when refs disappear and no root is found;
- function-index rewrites across exports/start/elements/tables/globals/code/data where represented by the local module APIs;
- exact-`unreachable` helper retention prediction shared with the optimizing path.

## Strategy constraints

### Keep plain mode plain

Do not add cleanup behavior to `inlining` only because it helps a test. Plain mode is allowed to leave debris. Cleanup belongs to `inlining-optimizing` or later explicit passes.

### Preserve the shared-engine design

The same local code should serve `inlining`, `inlining-optimizing`, and eventually `inline-main`-style low-level helper reuse. Avoid growing a second body-copy engine.

### Keep root survival separate from deletion

Starshine already distinguishes inlining from helper removal. Future work should preserve that separation as no-inline flags, partial helpers, element/table uses, and annotations become richer.

### Prefer conservative skip over invalid rewrite

Missing repair surfaces should skip rather than emit invalid wasm:

- nested `return_call*` in copied bodies;
- multi-result wrapper blocks;
- nondefaultable locals;
- label collisions;
- `try` / EH-sensitive hoisting;
- partial split helpers.

## Main gaps

- Full Binaryen heuristic classes: `Shrinks`, `MayNotShrink`, flexible size, loop policy, optimize/shrink-level sensitivity.
- `no-inline*` policy flags and clone-survival behavior.
- Pattern A / Pattern B partial inlining and helper cleanup.
- Exact nested `return_call*` and `return_call`-inside-`try` handling.
- Multi-result result-block support.
- Full label/name collision avoidance and post-inline uniquification.
- Nondefaultable-local repair and Binaryen-like refinalization behavior.
- Exact Binaryen iteration/action filtering and size-growth guard.
- Direct standard `--pass inlining` 10k parity evidence.

## Relationship to `inlining-optimizing`

Plain `inlining` and `inlining-optimizing` should share all core rewrite work. The optimizing sibling adds:

- touched-function tracking obligations;
- `precompute-propagate` prepend;
- default function-pipeline rerun on exactly touched functions;
- late-tail scheduler significance in the no-DWARF path.

Current Starshine has only an approximation of that optimizing suffix, so do not use optimizing evidence as plain signoff.

## Bottom line

The correct local mental model is:

- **active partial module pass**;
- **shared direct-call inliner core**;
- **plain mode stops after rewrite/helper cleanup**;
- **not Binaryen-parity complete**;
- **INL backlog remains active**.
