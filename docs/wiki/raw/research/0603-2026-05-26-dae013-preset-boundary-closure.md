# DAE013 preset boundary closure

Date: 2026-05-26

## Question

Should the active partial `dae-optimizing` pass be added to the public `optimize` / `shrink` presets for v0.1.0 now that `[DAE]002`, `[DAE]010`, and `[DAE]011` are closed?

## Finding

No. `[DAE]013` is closed by keeping `dae-optimizing` direct-pass-only for v0.1.0.

The direct pass has enough evidence for explicit requests:

- `[DAE]002` closed the guarded touched-function nested-cleanup scheduler boundary for the current partial port.
- `[DAE]010` refreshed direct fuzz signoff with no validation failures and only the known semantic-safe `gen-valid` raw-cleanup mismatch family.
- `[DAE]011` restored debug-artifact pass-local timing to the repo target after caller-filtering selected dropped-result rewriting.

That evidence does not justify widening public presets yet. The active `optimize` and `shrink` expansions in `src/passes/optimize.mbt` intentionally continue to skip `dae-optimizing`; they run the already signed-off late tail beginning at `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize`. Adding DAE ahead of that neighborhood would change the public default optimization surface while `[DAE]003` broader constant/unread-parameter generalization and `[DAE]004` broader dropped-result scheduling remain active implementation breadth.

## Decision

For v0.1.0, `dae-optimizing` remains available as a direct module pass under both `dae-optimizing` and `dead-argument-elimination-optimizing`, but it is not scheduled by public `optimize` or `shrink` presets. Future preset work should reopen from new ordered-prefix or artifact evidence that specifically proves default-preset safety and runtime, not merely from direct-pass signoff.

## Validation

This was a docs/backlog recovery slice only. No pass behavior changed, and no new fuzz mismatch classification was needed. Validation for the commit should use the repo quick gate (`moon info`, `moon fmt`, `moon test`).

## Files to sync

- `agent-todo.md`
- `docs/wiki/binaryen/passes/dae-optimizing/index.md`
- `docs/wiki/binaryen/passes/dae-optimizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/dae-optimizing/starshine-port-readiness-and-validation.md`
- `docs/wiki/log.md`
