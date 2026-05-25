---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../agent-todo.md
  - ../../log.md
---

# Self-optimize compare normalization symmetry gate (`[TOOL]001`)

## Scope

This docs/backlog slice audits `[TOOL]001`, the self-optimize compare normalization symmetry follow-up for harmless raw/debug-only outer-block drift. It does not change compare tooling, optimizer behavior, tests, public API, or pass docs.

## Findings

No active tooling change is warranted from the current evidence:

- The backlog already classifies the tracked residual as not a Starshine optimizer bug and not needed for v0.1.0.
- The desired behavior is narrow: stop the exact artifact helper from reporting a harmless raw/debug-only outer-block drift where Binaryen raw `--debug` kept an outer block that symmetric normalization would remove.
- Existing wiki log history shows the self-optimize compare helper has already received many targeted canonical-function fallback improvements for pass-specific representation drift. That history argues for keeping new canonicalization rules evidence-driven and tightly scoped.
- There is no current release gate, failing pass signoff, or active exact artifact workflow blocked solely by `defined=200 abs=217` transparent unused-label void-block drift.

## Decision

Close `[TOOL]001` as an evidence-gated tooling follow-up. Reopen only if an active exact artifact workflow or release QA gate is blocked by this exact raw/debug-only outer-block drift.

If reopened, prefer symmetric Binaryen normalization through the same strip-debug path before canonical-function comparison while preserving `binaryen.raw.wasm`. A canonical-function fallback that ignores transparent unused-label void block wrappers is acceptable only if tests prove it does not hide meaningful branch-target, label, result-type, or side-effect differences.

## Validation

No compare tooling, optimizer behavior, tests, public API, or pass docs changed in this slice. `git diff --check` is sufficient commit validation.

## Remaining risks

This does not solve all self-optimize compare noise. It only retires the currently tracked open-ended normalization task until a concrete exact-artifact workflow needs it.
