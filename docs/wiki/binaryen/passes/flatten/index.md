---
kind: entity
status: working
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-flatten-primary-sources.md
  - ../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md
  - ../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0127-2026-04-20-flatten-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../docs/0065-2026-03-24-ir2-execution-plan.md
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-ir-contract-and-preludes.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../local-cse/index.md
  - ../tracker.md
---

# `flatten`

## Role

- `flatten` is an upstream Binaryen aggressive flat-IR preparation pass.
- It is currently **unimplemented** in Starshine.
- In Binaryen `version_129`, it is **not** part of the canonical no-DWARF `-O` / `-Os` path used elsewhere in this repo.
- Instead, it appears only in the more aggressive `optimizeLevel >= 4` function pipeline, where it starts the trio:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`
- Its real job is not “generic flattening” or “merge blocks.”
- The real job is: rewrite Binaryen IR into the formal `Flat IR` shape from `src/ir/flat.h` by routing nested values and value-carrying control flow through temp locals and explicit preludes.

## Why it matters

- The dossier already explained the upstream Binaryen contract, but it still lacked the now-standard owner-file / helper / lit-test / local-code map page that neighboring refreshed folders provide.
- The 2026-04-25 current-main recheck found no teaching-relevant drift from the tagged `version_129` contract, so this run adds an implementation/test-map bridge rather than rewriting the strategy as a correction.
- The saved generated-artifact `-O4z` audit still records `flatten` as a real skipped top-level upstream slot:
  - slot `9`
- The saved Binaryen debug log still shows it is bigger than a one-off top-level detail:
  - the top-level slot `9` run took about `1.67786` seconds
  - the full `-O4z` run executed `flatten` `18` total times because nested optimizing reruns reuse the default aggressive function pipeline
- The pass sits immediately before two already-documented neighbors whose purpose is easier to understand once flatten is clear:
  - `simplify-locals-notee-nostructure`
  - `local-cse`
- The current Starshine planning story is worth keeping explicit:
  - `src/passes/optimize.mbt:144-151` still tracks `flatten` in the removed-name registry
  - `src/cli/cli_test.mbt:280-285` and `src/cli/cli_test.mbt:313-316` still preserve the public `--flatten` spelling
  - `src/passes/pass_manager.mbt` still has no active `flatten` dispatcher case
  - `docs/0065-2026-03-24-ir2-execution-plan.md:39` and `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:47` still place `flatten` at the front of the old removed-pass batch
  - `agent-todo.md` still has **no dedicated `flatten` slice today**, which is a real local planning gap rather than something to smooth over

## Beginner summary

A safe beginner mental model is:

- if a nested expression is too complicated for Flat IR,
- compute it earlier,
- store it in a temp local,
- and leave a `local.get` in the original place.

For control flow, that becomes:

- if a `block`, `if`, `loop`, or `try` used to *return* a value,
- make the control flow write that value into a temp local instead,
- and then read the temp later.

That is much closer to the real pass than “flatten removes nesting.”

## Current durable takeaways

- `flat.h` defines flattening precisely, not loosely.
- The main rules are:
  - most operands must become `local.get`, constant expression, `unreachable`, or `ref.as_non_null`
  - control-flow structures must stop carrying values
  - `local.tee` is disallowed
  - `local.set` cannot receive control flow directly
- `Flatten.cpp` implements this with two core maps:
  - `preludes`
    - code that must run immediately before an expression
  - `breakTemps`
    - temp locals keyed by branch target names for carried branch values
- The pass has explicit special logic for:
  - `Block`
  - `If`
  - `Loop`
  - legacy `Try`
  - `local.tee`
  - carried `br` / `br_if`
  - carried `switch` / `br_table`
- `If` temp typing uses least-upper-bound logic, not just exact arm type equality.
- Flatten can create blocks inside `catch`, so it must repair EH pop placement afterwards.
- In `version_129`, `flatten` hard-fails on `BrOn*` and `TryTable`.
- `Flatten.cpp` also still carries an open non-nullability TODO.
  - But the shipped tests show some non-null cases already work, so the limitation is selective, not absolute.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: scheduler placement, formal Flat IR meaning, the postorder prelude algorithm, control-value rewrites, branch-value temp routing, EH fixups, the reviewed release/source provenance, the 2026-04-25 no-drift current-main bridge, and the current unsupported-instruction boundary.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Owner-file, helper-surface, official lit-test, scheduler, and current Starshine code-map page for `flatten`, including the `Flatten.cpp` / `flat.h` split, the tiny smoke test versus broad all-features and EH proof files, and the exact removed-registry / CLI-spelling / dispatcher-gap line ranges.
- [`./flat-ir-contract-and-preludes.md`](./flat-ir-contract-and-preludes.md)
  Focused guide to the easiest part of the pass to misunderstand: what “flat” means exactly, how preludes migrate, why flatten creates so many locals, how named branch targets get temps, and why `unreachable` placeholders plus EH pop repair are part of the real contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for nested arithmetic, value-carrying `block` / `if` / `loop` / `try`, tee removal, `br_if` / switch value carriers, preserved simple-child families, and hard bailout shapes.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status/port map for `flatten`: removed-name registry tracking, preserved `--flatten` CLI spelling, Batch 2 planning surfaces, the still-missing active backlog slice, and the downstream dossier cluster a future local port would need to serve.

## Current maintenance rule

- Treat this folder as the canonical home for future `flatten` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass.
- Keep the strategy, implementation/test-map, and flat-IR/preludes pages in sync whenever new evidence changes the answer to any of these:
  - “what exact AST properties does Binaryen flatten enforce?”
  - “which owner/test/helper surfaces prove that behavior?”
  - “which feature shapes are still unsupported or only selectively supported?”

## Sources

- [`../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md`](../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md)
- [`../../../raw/binaryen/2026-04-23-flatten-primary-sources.md`](../../../raw/binaryen/2026-04-23-flatten-primary-sources.md)
- [`../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md`](../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md)
- [`../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md`](../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0127-2026-04-20-flatten-binaryen-research.md`](../../../raw/research/0127-2026-04-20-flatten-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../../../../docs/0065-2026-03-24-ir2-execution-plan.md`](../../../../../docs/0065-2026-03-24-ir2-execution-plan.md)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Official Binaryen sources and release surfaces are captured immutably in:
  - [`../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md`](../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md)
  - [`../../../raw/binaryen/2026-04-23-flatten-primary-sources.md`](../../../raw/binaryen/2026-04-23-flatten-primary-sources.md)
