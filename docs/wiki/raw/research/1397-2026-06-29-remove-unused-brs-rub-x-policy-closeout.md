# 1397 - remove-unused-brs RUB-X policy-surface closeout

Date: 2026-06-29

## Scope

This note closes `[O4Z-AUDIT-RUB-X]`, which asked whether strict as-good-or-better-than-Binaryen follow-up work should include Binaryen branch-hint metadata preservation and the `remove-unused-brs-never-unconditionalize` pass-option surface.

## Source-backed status

`[O4Z-AUDIT-RUB-N]` remains current after a source recheck.

Binaryen `version_130` treats these as real `remove-unused-brs` policy surfaces:

- `src/ir/branch-hints.h` provides branch-hint metadata helpers used by `RemoveUnusedBrs.cpp`: `copyTo`, `copyFlippedTo`, `applyAndTo`, `applyOrTo`, `flip`, and `clear`.
- The upstream lit files `remove-unused-brs_branch-hints.wast`, `remove-unused-brs_branch-hints-shrink.wast`, and `remove-unused-brs_branch-hints-unconditionalize.wast` prove both metadata movement and the `remove-unused-brs-never-unconditionalize` knob are part of Binaryen's observable contract.

Current Starshine does not yet have the local surfaces required to implement that contract safely:

- `src/lib/types.mbt` has `FuncAnnotation`, `FuncAnnotationAssoc`, and `FuncAnnotationSec`, but no expression-level branch-hint or code-metadata representation.
- `src/wast/parser.mbt` parses `(@...)` only as annotations attached to module fields, and `src/wast/lower_to_lib.mbt` lowers them only to function/import annotation associations.
- `docs/wiki/wast/code-metadata-and-function-annotations.md` explicitly says `metadata.code.branch_hint` is upstream/Core code metadata and not local expression-annotation support.
- Repo search still finds no `branch_hint`, `BranchHint`, or `metadata.code.branch_hint` implementation outside docs and the existing function-annotation tests.
- `src/cli/cli.mbt` accepts pass names and only special-cases a few value-bearing pass-like flags (`--dump`, `--extract-functions`, `--print-*`, and no-inline pattern flags). It has no `--pass-arg` parser or pass-option carrier.
- `src/passes/pass_manager.mbt` / `HotPipelineOptions` carry global optimization/trap/closed-world/shrink settings, not pass-specific arguments; `remove-unused-brs` receives no local `never-unconditionalize` option.

## Decision

Close RUB-X as a product-level representation/pass-option blocker, not as an optimization behavior implementation.

Do not add a superficial `remove-unused-brs`-only hint rewrite or a hidden flag. Without expression-level code metadata and pass-arg plumbing, a pass-local implementation could only invent metadata that cannot be parsed, round-tripped, remapped, or exposed consistently. That would be worse than the current explicit boundary.

The current Starshine behavior remains: `remove-unused-brs` performs its ordinary direct-pass condition-combining, selectification, restructuring, and set-if rewrites without branch-hint preservation and without a public `never-unconditionalize` mode.

## Reopening criteria

Reopen RUB policy-surface parity only after at least one of these prerequisites lands:

1. An expression-level code-metadata representation for branch hints, or a deliberate opaque code-metadata preservation policy that can attach metadata to instruction locations through rewrites.
2. Parser, printer, WAST lowering, binary decode/encode, and round-trip tests for `@metadata.code.branch_hint` / `metadata.code.branch_hint` attached to `if` and `br_if` instruction locations.
3. Pass-remap tests proving `remove-unused-brs` keeps hints on the correct rewritten expression for Binaryen-style `BranchHints::{copyTo, copyFlippedTo, applyAndTo, applyOrTo, flip, clear}` cases.
4. Public CLI/config/pass-manager plumbing for Binaryen-style pass arguments, including explicit tests for `remove-unused-brs-never-unconditionalize` on every RUB rewrite family that Binaryen gates with the option.
5. Dossier updates that distinguish Core/Binaryen branch-hint metadata support from Starshine's local function/import-only `FuncAnnotationSec` lane.

Until then, strict as-good-or-better RUB follow-up is complete for actionable optimizer transformations in `[O4Z-AUDIT-RUB-R]` through `[O4Z-AUDIT-RUB-X]`; branch-hint and never-unconditionalize parity remain visible, precise non-goals/blockers rather than hidden gaps.

## Validation

No behavior code was changed for RUB-X. This was a source/docs closeout slice. Consistency checks and focused validation still passed:

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt`: passed `220/220`.
- `git diff --check`: passed with no output.
- Stale-wording grep found no open `[O4Z-AUDIT-RUB-X]` checklist entry and no stale `RUB-N remains the only` wording in the RUB dossier after updates.
