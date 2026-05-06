---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-strip-toolchain-annotations-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-strip-toolchain-annotations-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md
  - ../../../raw/research/0504-2026-05-06-strip-toolchain-annotations-current-main-recheck.md
  - ../../../raw/research/0394-2026-04-26-strip-toolchain-annotations-port-readiness.md
  - ../../../raw/research/0324-2026-04-24-strip-toolchain-annotations-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/wast/module_wast_tests.mbt
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/duplicate_import_elimination.mbt
  - ../../../../../src/passes/remove_unused_module_elements.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../duplicate-function-elimination/index.md
  - ../tracker.md
---

# Starshine strategy for `strip-toolchain-annotations`

## Current local status

Starshine currently has **no `strip-toolchain-annotations` implementation**.
This page is therefore a status and future-port map, not a description of a shipped transform.

The exact local status is:

- `src/passes/optimize.mbt` has no `strip-toolchain-annotations` entry in `pass_registry_boundary_only_names()` or `pass_registry_removed_names()`.
- `src/passes/optimize.mbt` has no active `HotPass` or `ModulePass` entry for it in `pass_registry_entries()`.
- `run_hot_pipeline_expand_passes(...)` reports unknown names as `unknown pass flag ...`, so an explicit `strip-toolchain-annotations` request currently fails as unknown rather than boundary-only or removed.
- `agent-todo.md` has no dedicated backlog slice for the pass.

That means Starshine's present strategy is **non-adoption plus documentation**.
The wiki tracks the upstream pass because Binaryen exposes it publicly and because the late-pass chronology had already mentioned it without a canonical dossier.
The 2026-05-06 current-main recheck keeps that status unchanged, and the earlier port-readiness note documents a safe future module-pass subset in [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md).

## Exact local code locations to read first

- `src/passes/optimize.mbt:127-143`
  - current boundary-only and removed name lists; `strip-toolchain-annotations` is absent from both.
- `src/passes/optimize.mbt:156-267`
  - current active hot/module/preset registry construction; no `strip-toolchain-annotations` entry exists.
- `src/passes/optimize.mbt:317-320`
  - boundary-only and removed names are materialized into the lookup table.
- `src/passes/optimize.mbt:525`
  - request expansion and rejection behavior; unknown names fail before the boundary-only / removed guards.
- `src/lib/types.mbt:348`
  - local `FuncAnnotationSec` in-memory structure, with the surrounding `FuncAnnotation` / `FuncAnnotationAssoc` records immediately above it.
- `src/lib/types.mbt:8105-8108`
  - constructor for local function-annotation sections.
- `src/wast/parser.mbt:779-784`
  - WAT annotation parsing and attachment, currently limited to functions and function imports.
- `src/wast/lower_to_lib.mbt:2916-2917` and `src/wast/lower_to_lib.mbt:3016-3017`
  - creation of `FuncAnnotationAssoc` entries for annotated function imports and definitions.
- `src/wast/lower_to_lib.mbt:3502`
  - lowering of the accumulated WAT annotations into `@lib.FuncAnnotationSec`.
- `src/wast/module_wast_tests.mbt:78-98`
  - roundtrip test that preserves `@binaryen.js.called`, `@binaryen.idempotent`, and `@metadata.code.inline` in WAT parsing/printing.
- `src/passes/duplicate_function_elimination.mbt:23-31` and `src/passes/duplicate_function_elimination.mbt:2663-2693`
  - DFE annotation lookup plus remap helpers show there is already local code that depends on annotation indices when function indices change.
- `src/passes/duplicate_function_elimination.mbt:3034-3072`
  - DFE equivalence and hashing include annotations, which shows annotations are observable to at least one local pass today.
- `src/passes/duplicate_import_elimination.mbt:309-332` and `src/passes/remove_unused_module_elements.mbt:1944-1966`
  - additional module passes that remap annotation indices when import/function spaces change.

## Why there is no straightforward HOT-IR port today

Binaryen's pass works over Binaryen's function-level annotations and per-expression `codeAnnotations`.
Starshine's currently visible local support is narrower and shaped differently:

- WAT syntax can parse and print annotations.
- Lowering creates a module-level `FuncAnnotationSec` for functions and function imports.
- The local binary encoder/decoder scan in this run did not expose a direct `func_annotation_sec` binary custom-section path, so binary parity must be source-confirmed before promising it.
- The HOT IR does not expose a general per-expression code-annotation wrapper that matches Binaryen's `codeAnnotations` map.

So the first Starshine decision is not how to fold annotations in HOT IR; it is what annotation surface the pass should own.

## If Starshine ever ports it

A useful first local port should probably start as a **module pass** over `FuncAnnotationSec`, not as a normal HOT peephole.
That first slice can strip `binaryen.removable.if.unused`, `binaryen.idempotent`, and `binaryen.js.called` from function/import annotation entries while preserving `metadata.code.inline` and unknown annotations.
A faithful Binaryen parity port is broader: it must also model per-expression `codeAnnotations` or explicitly document that Starshine does not support that surface.

Minimum acceptance criteria:

- choose a public status deliberately: active module pass, boundary-only compatibility entry, removed compatibility entry, or continued unknown-name rejection;
- define exactly which local annotation storage is in scope (`FuncAnnotationSec`, future expression annotations, binary custom sections, or some combination);
- remove only the Binaryen-owned toolchain annotation names/bits;
- preserve `metadata.code.inline` and other non-toolchain metadata;
- update DFE annotation hashing/equivalence expectations if the new pass can run before DFE;
- keep the pass out of optimize/shrink presets unless a separate user-facing reason exists;
- add direct tests for `binaryen.removable.if.unused`, `binaryen.idempotent`, `binaryen.js.called`, preserved `metadata.code.inline`, mixed removed/preserved entries, and empty-entry cleanup.

## Non-goals today

- Do not mark the pass as implemented just because Starshine can parse some Binaryen annotations.
- Do not treat this pass as generic custom-section stripping.
- Do not conflate this pass with the local extra name-section stripping inside [`duplicate-function-elimination`](../duplicate-function-elimination/index.md).
- Do not add it to the optimize or shrink preset without a product decision; Binaryen frames it as a cleanup after toolchain-specific annotations are no longer useful, not as an ordinary optimizing transform.
