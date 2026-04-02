---
kind: concept
status: supported
last_reviewed: 2026-04-10
sources:
  - ../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md
related:
  - ./index.md
  - ./starshine-hot-ir-strategy.md
  - ../../no-dwarf-default-optimize-path.md
---

# `simplify-locals` Binaryen Strategy

## Durable Conclusions

- Binaryen's `simplify-locals` family is a staged locals optimizer, not a single peephole.
- The main loop tracks pending `local.set` candidates on linear traces, replaces later `local.get`s with the producer value, and can upgrade multi-use producers to `local.tee` after the first stricter cycle.
- Pending candidates are invalidated conservatively with directional effect ordering plus extra barriers for nonlinear control, dangling `pop`, and values that may throw when crossing `try` or `try_table`.
- Structure-enabled modes can rewrite blocks, `if`s, and loops to return values directly, but only under guarded conditions such as the one-armed-defaultable rule and the `br_if` condition hazard check.
- After the sink fixpoint, Binaryen runs equivalent-copy cleanup and a final dead-set sweep that still removes redundant sets outside SSA-modeled reachable code.

## Mode And Pipeline Notes

- Binaryen exposes `simplify-locals`, `simplify-locals-nonesting`, `simplify-locals-notee`, `simplify-locals-nostructure`, and `simplify-locals-notee-nostructure`.
- On the no-DWARF optimize path, the no-structure variants run earlier than the full structure-enabled pass.
- That split matters: the earlier no-structure pass leaves some equivalent-copy cleanup and structure lifting for the later full pass.

## Source Status

- The archived research note is pinned to Binaryen commit `88a07e028cfb4aa68e7a94743646a0867b31c15b` as captured on 2026-04-01.
- The shared repo oracle for living Binaryen pass pages is now `version_129`.
- Refresh this page if upstream `SimplifyLocals.cpp`, `effects.h`, or the no-DWARF pass ordering changes materially from the archived note.

## Sources

- Archived research note: [`../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md`](../../../raw/research/0076-2026-04-01-simplify-locals-binaryen-research-plan.md)
- No-DWARF optimize path: [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
