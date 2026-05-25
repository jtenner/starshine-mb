---
kind: research-note
status: completed
created: 2026-05-25
sources:
  - ../../../../agent-todo.md
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/simplify_globals_optimizing_test.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md
  - ./0573-2026-05-19-sgo-v010-signoff.md
  - ./0639-2026-05-25-sgo-nested-cleanup-wrapper-frontier.md
---

# SGO nested cleanup scheduler deferral audit (`[SGO]004`)

## Scope

This docs/backlog slice audits `[SGO]004`, the nested cleanup runtime and exact-scheduler experiment follow-up. It does not change optimizer behavior, nested cleanup scheduling, tests, public API, or pass docs.

## Findings

No behavior or runtime experiment is warranted from the current evidence:

- The accepted v0.1.0 SGO signoff recorded direct artifact validity, smaller Starshine output than Binaryen on the direct artifact, pass-local runtime inside the 2x floor, and direct 10k SGO fuzz with zero normalized mismatches or Starshine validation failures.
- The current SGO nested cleanup runner already uses the Binaryen-style `prefix=default` lane, not the inlining/DAE `precompute-propagate` prefix.
- Remaining nested cleanup costs are visible but not currently blocking: the 0573 trace recorded `detail:sgo:nested-total=86.104ms` and the largest nested wrapper as `vacuum=45.538ms`, while still meeting the accepted direct pass-local runtime floor.
- The 0639 wrapper frontier identified safety filters for large touched functions and value-block/control structures. Those filters should not be lifted opportunistically; a future change needs a minimal verifier reproduction and a fix in the correct layer.
- There is no current semantic mismatch, wasm validation failure, artifact/code-size target, or measured SGO-specific wall-time owner that justifies an exact-scheduler experiment or nested-wrapper optimization now.

## Decision

Close `[SGO]004` as an evidence-gated deferred follow-up rather than an active backlog item. Reopen only with one of these concrete triggers:

- a semantic mismatch or validation failure caused by the current nested cleanup scheduler;
- a targeted artifact/code-size case that the omitted exact Binaryen nested default-function slots would improve;
- a measured SGO-specific wall-time owner showing nested cleanup wrapper overhead as the bottleneck;
- a minimal verifier reproduction for the current large-function or value-block/control filters.

A future reopened slice must keep correctness first, preserve direct SGO fuzz parity, and document whether it changes scheduling policy, HOT lift/lower safety, or a nested cleanup pass implementation.

## Validation

No optimizer behavior, tests, public API, or pass docs changed in this slice. `git diff --check` is sufficient commit validation.

## Remaining risks

This does not prove the current nested cleanup scheduler is identical to Binaryen. It only records that the known differences are not currently blocking and should be driven by fresh evidence instead of open-ended experimentation.
