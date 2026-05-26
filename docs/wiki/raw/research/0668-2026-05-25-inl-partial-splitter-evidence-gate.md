---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../agent-todo.md
  - ./0161-2026-04-21-inlining-binaryen-research.md
  - ./0391-2026-04-26-inlining-port-readiness.md
  - ./0557-2026-05-12-inlining-wiki-overhaul.md
---

# Inlining partial splitter evidence gate (`[INL]005`)

## Scope

This docs/backlog slice audits `[INL]005`, the deferred Pattern A / Pattern B partial-inlining splitter follow-up. It does not change optimizer behavior, tests, public API, or pass docs.

## Findings

No active implementation slice is warranted from the current evidence:

- Binaryen partial inlining is source-backed, but deliberately narrow: it is enabled only under the right optimization/shrink settings and `partialInliningIfs`, and it recognizes top-of-function Pattern A / Pattern B shapes rather than arbitrary CFG extraction.
- The port-readiness ladder already places split shapes after the direct-call copy/rewrite proof, callee-local remap, root preservation, non-optimizing suffix negative, return repair, tail-call shapes, and no-inline policy shapes.
- The current Starshine inlining subset is partial but functional for the accepted direct-call and optimizing surfaces. The latest inlining wiki evidence records remaining gaps without making partial splitting a v0.1.0 blocker.
- No reduced Pattern A/B fixture is currently cited in the backlog as causing a semantic mismatch, wasm validation failure, pass-local performance regression, downstream size win, or user-facing need for `no-partial-inline` behavior.

## Decision

Keep `[INL]005` closed as an evidence-gated future feature rather than an active implementation task. Reopen only with a concrete Pattern A or Pattern B fixture and an explicit reason to implement it now: semantic/validation correctness, clear pass-local performance or size benefit, downstream optimization win that offsets code growth, or user-facing `no-partial-inline` policy need.

A reopened slice must not implement generic splitting by analogy. It must start with focused Pattern A/B tests, preserve Binaryen's narrow syntactic/local-dependency gates, prove helper cleanup and no-partial-inline interaction, and compare direct `--pass inlining` / `--pass inlining-optimizing` on the reduced family.

## Validation

No optimizer behavior, tests, public API, or pass docs changed in this slice. `git diff --check` is sufficient commit validation.

## Remaining risks

This audit does not remove partial inlining from the long-term parity map. It only prevents the deferred splitter from being treated as active work without a concrete source-backed fixture and validation target.
