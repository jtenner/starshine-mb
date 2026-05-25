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

# Inlining residual name and annotation repair gate (`[INL]006`)

## Scope

This docs/backlog slice audits `[INL]006`, the deferred residual name/annotation repair follow-up for Starshine's inlining family. It does not change optimizer behavior, tests, public API, or pass docs.

## Findings

No active repair implementation is warranted from the current evidence:

- Binaryen source research confirms that inline rewrite needs label/local/type repair, including label-collision avoidance and post-inline unique-name repair, but those are not the same as a current Starshine semantic correctness blocker.
- The current Starshine inlining subset already covers accepted direct-call and optimizing surfaces while intentionally dropping function-scoped local/label names after body rewrites instead of preserving stale or collision-prone debug maps.
- Tail-call and multi-result correctness subsets are covered by focused tests or remain separately represented by inlining behavior gaps; they are not evidence that debug/name repair should be implemented opportunistically.
- The active evidence set does not include a concrete user-facing debug-name requirement, annotation-collision bug, semantic mismatch, wasm validation failure, or pass-local performance/code-size issue caused by residual local/label name handling.

## Decision

Keep `[INL]006` closed as an evidence-gated future repair task. Reopen only with a concrete requirement or bug: user-visible debug-name preservation, annotation collision, semantic mismatch, wasm validation failure, or proven pass-local performance/code-size issue tied to residual names or annotations.

A reopened slice must add focused repair tests first, then either implement deterministic Binaryen-like local/label name reconstruction and broader annotation collision repair, or explicitly document the unsupported surface as rejected. It should not conflate debug/name repair with semantic tail-call, multi-result, or helper-removal correctness work.

## Validation

No optimizer behavior, tests, public API, or pass docs changed in this slice. `git diff --check` is sufficient commit validation.

## Remaining risks

This audit does not claim Binaryen-like debug/name fidelity. It only records that name/annotation repair is not currently an active correctness or performance blocker for the accepted Starshine inlining surfaces.
