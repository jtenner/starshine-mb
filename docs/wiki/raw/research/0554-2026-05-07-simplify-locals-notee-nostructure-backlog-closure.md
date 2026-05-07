---
kind: research
status: done
last_reviewed: 2026-05-07
sources:
  - ../../../agent-todo.md
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/index.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/starshine-strategy.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/local-cse/starshine-strategy.md
  - ../../../src/passes/optimize.mbt
  - ../../../src/passes/optimize_test.mbt
related:
  - ../../binaryen/passes/simplify-locals-notee-nostructure/index.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/starshine-strategy.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/starshine-port-readiness-and-validation.md
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/local-cse/starshine-strategy.md
---

# 2026-05-07 `simplify-locals-notee-nostructure` backlog closure

## Question

Does active backlog slice `[SLNNS]003` still describe live `v0.1.0` no-DWARF optimize-path work, or has it become a mixed-scope reminder for a future aggressive `flatten` neighborhood?

## Findings

1. The current `v0.1.0` parity target does **not** include `simplify-locals-notee-nostructure`.
   - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` records the canonical no-DWARF `-O` / `-Os` function pipeline, and that pathway uses `tuple-optimization -> simplify-locals-nostructure -> ... -> local-cse -> simplify-locals`.
   - The `simplify-locals-notee-nostructure` dossier and the `flatten` dossier both state that `simplify-locals-notee-nostructure` appears only in Binaryen's more aggressive `optimizeLevel >= 4` prelude: `flatten -> simplify-locals-notee-nostructure -> local-cse`.
2. The direct Starshine pass plus the omission gate are already landed.
   - `src/passes/optimize.mbt` keeps `simplify-locals-notee-nostructure` as an active direct hot pass while leaving `optimize` / `shrink` unchanged.
   - `src/passes/optimize_test.mbt` already locks the current boundary: `simplify-locals-notee-nostructure exact neighborhood waits for flatten`.
   - The living dossier pages already describe the pass as active direct with green direct Binaryen parity evidence.
3. The only remaining work is not a standalone `SLNNS` deliverable inside the current release target.
   - The missing neighborhood is shared aggressive-path work that depends first on `flatten`, which is still unimplemented/removed locally.
   - `local-cse` already documents the same early `flatten -> simplify-locals-notee-nostructure -> local-cse` slot as gated on `flatten` rather than on additional direct `SLNNS` behavior work.
   - That means `[SLNNS]003` had become a stale mixed-scope item: the direct-pass and preset-omission part is already complete, while the remaining aggressive-neighborhood replay belongs to future `flatten` / aggressive scheduler work rather than the active no-DWARF optimize-path queue.

## Conclusion

Close `[SLNNS]003`.

Keep the living `simplify-locals-notee-nostructure` pages explicit about two facts:

- the direct pass is landed and remains explicit-only today;
- future replay of `flatten -> simplify-locals-notee-nostructure -> local-cse` should reopen as a new aggressive-path / `flatten` task, not stay in the active `v0.1.0` no-DWARF backlog.
