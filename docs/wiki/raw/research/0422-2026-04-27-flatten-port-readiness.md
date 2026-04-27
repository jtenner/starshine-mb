---
kind: research
status: supported
last_reviewed: 2026-04-27
sources:
  - ../binaryen/2026-04-27-flatten-port-readiness-primary-sources.md
  - ../binaryen/2026-04-25-flatten-current-main-implementation-test-map.md
  - ../binaryen/2026-04-23-flatten-primary-sources.md
  - ../../binaryen/passes/flatten/index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
related:
  - ../../binaryen/passes/flatten/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../binaryen/passes/flatten/binaryen-strategy.md
---

# `flatten` port-readiness follow-up

## Question

The `flatten` dossier already had a current-main implementation/test map, shape catalog, Binaryen strategy, and Starshine status page. The missing durable piece was the same implementation-readiness bridge that many neighboring pass dossiers now have: what exact sequence should a future Starshine port use, what local code surfaces prove the current hold point, and what validation lanes should block a parity claim?

## Source recheck

On 2026-04-27 I rechecked the official Binaryen current-main sources and tests captured in [`../binaryen/2026-04-27-flatten-port-readiness-primary-sources.md`](../binaryen/2026-04-27-flatten-port-readiness-primary-sources.md):

- `src/passes/Flatten.cpp`
- `src/ir/flat.h`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `test/lit/passes/flatten.wast`
- `test/lit/passes/flatten_all-features.wast`
- `test/lit/passes/flatten-eh-legacy.wast`

No teaching-relevant upstream drift was found from the 2026-04-25 current-main bridge. The important current facts remain:

- `flatten` enforces the formal Flat IR contract from `flat.h`.
- `preludes` and `breakTemps` remain the core implementation mechanisms.
- value-carrying `block` / `if` / `loop` / legacy `try` forms are erased through temp locals.
- reachable `local.tee` is lowered to set/get traffic.
- branch payloads are routed through target temps, with a special two-temp `br_if` mismatch family.
- `BrOn*` and `TryTable` remain hard unsupported families.
- EH nested-pop repair remains part of function-exit correctness.

## Local Starshine status

The local status is still a hold point, not an implementation:

- `src/passes/optimize.mbt:143-151` tracks `flatten` in the removed-name registry.
- `src/cli/cli_test.mbt:280-285` and `src/cli/cli_test.mbt:313-316` preserve explicit `--flatten` pass-token resolution.
- `src/passes/pass_manager.mbt` has no dispatcher case.
- `docs/0065-2026-03-24-ir2-execution-plan.md:39` and `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:47` keep older Batch 2 intent.
- `agent-todo.md` still has no dedicated active `flatten` slice.

## Durable conclusion

The best first Starshine page to add is a port-readiness / validation bridge rather than a second strategy correction.

The future port should start with a no-rewrite analyzer/verifier over the Flat IR contract, then land a narrow mutating slice, then expand toward branch payloads, EH, unsupported-family policy, and downstream aggressive-cluster replay. That bridge belongs beside the existing strategy, shapes, and implementation map so implementers do not mistake the current removed-name registry entry for a working pass.

## Open uncertainties

- Starshine does not yet have a committed local equivalent of Binaryen `flat.h`; a future port must decide whether to implement a verifier, a HOT/IR2 normal form, or an explicitly different invariant.
- Binaryen hard-fails on `BrOn*` and `TryTable`; Starshine must decide whether to match that behavior, pre-gate the pass, or intentionally no-op those shapes and document the divergence.
- The exact local EH repair substrate for legacy `catch` / `pop` is not identified in an active backlog slice yet.
