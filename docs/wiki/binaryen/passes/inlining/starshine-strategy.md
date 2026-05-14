---
kind: concept
status: working
last_reviewed: 2026-05-14
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

Current status is **direct-surface signed off but not universal Binaryen inliner parity**. Former `[INL]001` is accepted for the current supported optimizing direct surface, `[INL]007` is accepted for the current supported plain direct surface, deferred unsupported direct-inliner breadth now lives under `[INL]003`, `[INL]005`, and `[INL]006`, and `[INL]002` remains active for the optimizing sibling's exact nested scheduler.

## Exact local code map

- [`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt)
  - `inlining_summary()` and `inlining_optimizing_summary()` define public help text.
  - `inlining_run_module_pass(...)` is the shared entrypoint.
  - `inl_build_function_infos(...)` builds the current simplified summary.
  - `inl_rewrite_all_calls(...)` runs direct-call rewrite.
  - `inl_make_inline_replacement(...)` appends/remaps callee locals and builds wrapper-block replacement.
  - `inl_remove_dead_inlined_helpers(...)` removes private helpers and rewrites function indices.
  - `inl_run_nested_cleanup(...)` is used only when `optimize=true`.
- [`src/passes/no_inline.mbt`](../../../../../src/passes/no_inline.mbt)
  - implements the first local no-inline policy surface for `no-inline=<pattern>`, `no-full-inline=<pattern>`, and `no-partial-inline=<pattern>`.
  - stores matched policy in internal function annotations and exposes policy flags to the inliner.
- [`src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
  - lowers WAT function identifiers into structured function names so no-inline wildcard policy can match text inputs.
- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - registers `inlining`, `inlining-optimizing`, and the three `no-inline*` policy passes as module passes.
  - public `optimize` / `shrink` presets still omit the Binaryen late `INL` slot.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - dispatches plain `inlining` with `optimize=false`.
  - dispatches `inlining-optimizing` with `optimize=true` and trace.
- [`src/passes/inlining_test.mbt`](../../../../../src/passes/inlining_test.mbt)
  - focused public-pipeline coverage for the current subset.
- [`agent-todo.md`](../../../../../agent-todo.md)
  - `[INL]002` tracks exact nested useful-pass replay for the optimizing sibling.
  - `[INL]003`, `[INL]005`, and `[INL]006` track deferred unsupported direct-inliner breadth; `[INL]007` records accepted plain direct signoff.

## Implemented subset

The current plain pass handles:

- tiny no-param private helpers;
- one-use private helpers;
- narrow shrinking-trivial two-parameter binary wrappers, three-parameter `select` wrappers, and parameter-passthrough memory/table/SIMD operation wrappers (`i32.store`, `i64.store`, `f32.store`, `f64.store`, `i32.store8`, `i32.store16`, `i64.store8`, `i64.store16`, `i64.store32`, `v128.store`, `v128.store8_lane`, `v128.store16_lane`, `v128.store32_lane`, `v128.store64_lane`, supported SIMD two-/three-parameter wrappers, `table.set`, `table.grow`, `memory.fill`, `memory.copy`, `memory.init`, `table.fill`, `table.copy`, and `table.init`);
- direct `call` and narrow direct `return_call` sites;
- callee param/body-local appending into the caller;
- local-index remapping inside the copied body;
- simple callee `return` to wrapper-block branch rewriting;
- iterative waves after same-wave race guards expose later calls;
- helper deletion only when refs disappear and no root is found;
- function-index rewrites across exports/start/elements/tables/globals/code/data where represented by the local module APIs;
- plain helper deletion without optimizing-only retain counts;
- narrow no-call unreachable value-block cleanup matching Binaryen plain `--inlining`;
- exact-`unreachable` helper retention prediction for the optimizing path;
- name-section wildcard policy marking for `no-inline`, `no-full-inline`, and `no-partial-inline`, including names lowered from defined/imported WAT identifiers, with the direct inliner honoring full-inline suppression, function annotation/name remapping preserving policy and later name matching across helper compaction, and local/label name maps dropped after inlining body rewrites until full repair exists.

## Strategy constraints

### Keep plain mode plain

Do not add broad cleanup behavior to `inlining` only because it helps a test. Plain mode is allowed to leave debris. The only current plain cleanup is the narrow unreachable value-block pruning observed in Binaryen's own `--inlining` no-call path; broader cleanup belongs to `inlining-optimizing` or later explicit passes.

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

- Full Binaryen heuristic classes beyond the narrow parameter-passthrough binary, `select`, and memory/table/SIMD operation `Shrinks` subsets: remaining `Shrinks`, `MayNotShrink`, flexible size, loop policy, optimize/shrink-level sensitivity.
- partial-inlining-specific `no-inline*` behavior after the splitter lands.
- Pattern A / Pattern B partial inlining and helper cleanup.
- Exact nested `return_call*` and `return_call`-inside-`try` handling.
- Multi-result result-block support.
- Full label/name collision avoidance and post-inline uniquification.
- Nondefaultable-local repair and Binaryen-like refinalization behavior.
- Exact Binaryen iteration/action filtering and size-growth guard.

## Relationship to `inlining-optimizing`

Plain `inlining` and `inlining-optimizing` should share all core rewrite work. The optimizing sibling adds:

- touched-function tracking obligations;
- `precompute-propagate` prepend;
- default function-pipeline rerun on exactly touched functions;
- late-tail scheduler significance in the no-DWARF path.

Current Starshine has only an approximation of that optimizing suffix. Plain signoff therefore relies on its own direct lanes, not optimizing evidence.

## Bottom line

The correct local mental model is:

- **active partial module pass**;
- **shared direct-call inliner core**;
- **plain mode stops after rewrite/helper cleanup plus the narrow no-call unreachable value-block cleanup**;
- **plain `[INL]007` direct surface accepted with locals-only representation drift**;
- **not universal Binaryen-inliner parity complete**;
- **INL backlog remains active for `[INL]002`, `[INL]003`, `[INL]005`, and `[INL]006`; `[INL]004` is accepted for the current no-inline policy surface, including direct name-section policy marking, annotation/function-name compaction remapping, stale local-name dropping, and a shared policy-copy helper for future clone/copy transforms**.
