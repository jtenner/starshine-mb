---
kind: research
status: current
last_reviewed: 2026-06-07
sources:
  - ../../../../agent-todo.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/late-pipeline-dispatch.md
  - ../../binaryen/passes/memory-packing/parity.md
  - ../../binaryen/passes/once-reduction/parity.md
  - ../../binaryen/passes/pick-load-signs/parity.md
  - ../../binaryen/passes/remove-unused-names/index.md
  - ../../binaryen/passes/remove-unused-module-elements/parity.md
  - ../../binaryen/passes/duplicate-function-elimination/parity.md
  - ../../binaryen/passes/global-refining/parity.md
  - ../../binaryen/passes/global-struct-inference/parity.md
  - ../../binaryen/passes/simplify-locals/parity.md
  - ../../binaryen/passes/local-cse/starshine-strategy.md
  - ../../binaryen/passes/code-folding/index.md
  - ../../../../.pi/skills/starshine-pass-implementation/SKILL.md
related:
  - ../../binaryen/no-dwarf-default-optimize-path.md
  - ../../binaryen/passes/late-pipeline-dispatch.md
  - ./0700-2026-06-03-memory-packing-o4z-audit.md
  - ./0701-2026-06-03-once-reduction-o4z-audit.md
  - ./0702-2026-06-03-pick-load-signs-o4z-audit.md
  - ./0703-2026-06-03-remove-unused-names-o4z-audit.md
  - ./0710-2026-06-04-local-cse-o4z-final-pass-audit.md
  - ./0712-2026-06-04-simplify-locals-o4z-pass-audit.md
  - ./0713-2026-06-04-code-folding-o4z-pass-audit.md
---

# O4z Behavior-Parity Inventory

## Question

Which pass audits can remain closed under a behavior-parity standard, and which previously audited or active passes still need Binaryen behavior implemented or explicitly reclassified?

## Behavior-parity rule used here

For this inventory, **Binaryen behavior parity** means Starshine implements the semantically relevant Binaryen transform families for the agreed scope, while preserving WebAssembly behavior and validation. It does **not** mean byte-for-byte wasm parity, raw WAT parity, exact helper-label shape parity, or identical local numbering.

A direct compare lane with zero raw mismatches is strong evidence, but it is not enough to close an audit when committed docs still say the pass is a narrow subset or list broad missing Binaryen families. Conversely, raw/text drift can be accepted only when the agent classification explains why the outputs are behavior-equivalent and the remaining difference is representation, cleanup, exact helper cost, or tool/oracle noise.

## Commands run for this inventory

- `bun scripts/pass-fuzz-compare.ts --list-passes`
  - listed 43 Starshine-supported direct compare pass names, including `strip-debug`.
- `wasm-opt --version`
  - local tool now reports `wasm-opt version 130 (version_130)`.
- `wasm-opt --help`
  - used only as a local pass-name surface check.

No pass compare lane was rerun for this inventory; the classifications below are based on committed pass docs, `agent-todo.md`, and the registry/preset code.

## Canonical preset behavior gap

The current `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` still uses the `version_129` no-DWARF path as the detailed pass-order baseline. The local `wasm-opt` binary now reports `version_130`, so a dedicated `version_130` path reread is needed before treating the exact counts below as the newest upstream contract. They are still useful as the currently documented baseline.

Against that documented baseline, Starshine's public `optimize` / `shrink` preset in `src/passes/optimize.mbt` has 39 top-level slots while the documented Binaryen no-DWARF path has 52. Count differences:

| Pass | Binaryen documented count | Starshine public preset count | Inventory classification |
| --- | ---: | ---: | --- |
| `duplicate-function-elimination` | 2 | 0 | scheduler behavior gap; direct pass exists but not placed like Binaryen |
| `remove-unused-module-elements` | 3 | 1 | scheduler behavior gap; direct pass is otherwise behavior-clean on current evidence |
| `vacuum` | 4 | 2 | scheduler behavior gap; direct pass still has an active audit |
| `reorder-locals` | 3 | 1 | scheduler behavior gap; direct pass still has an active audit |
| `coalesce-locals` | 2 | 1 | scheduler behavior gap; direct pass still has an active audit |
| `code-folding` | 1 | 0 | scheduler behavior gap; direct audit is now behavior-closed but not scheduled |
| `redundant-set-elimination` | 1 | 0 | scheduler behavior gap; active audit remains |
| `dae-optimizing` | 1 | 0 | scheduler/nested-rerun behavior gap; active audit remains |
| `inlining-optimizing` | 1 | 0 | scheduler/nested-rerun behavior gap; active audit remains |
| `duplicate-import-elimination` | 1 | 0 | scheduler behavior gap; active audit remains |
| `remove-unused-brs` | 3 | 4 | Starshine has one extra cleanup slot relative to the documented baseline; classify by neighborhood evidence, not output equality |

This is a preset-level behavior inventory, not a request to immediately widen the public preset. Existing repo policy still applies: prove direct pass behavior first, then ordered neighborhoods, then preset scheduling.

## Previously audited / removed pass classification

| Pass / prior audit | Current evidence summary | Behavior-parity classification | Backlog action |
| --- | --- | --- | --- |
| `memory-packing` / `[O4Z-AUDIT-MP]` | Direct lanes are green on comparable cases and the saved active-segment artifact slot is green. The parity page still says the official passive-segment and segment-user half is missing: `memory.init` rewrites, `memory.fill` insertion, `data.drop` expansion, lazy drop-state globals, imported-memory `zeroFilledMemory`, GC data-referrer boundaries, and max-segment limiting. | **Documented Binaryen behavior gap.** This audit should not stay removed if full pass behavior parity is the release value. | Reopen as active behavior-parity implementation/audit work. |
| `once-reduction` / `[O4Z-AUDIT-OR]` | Direct keep-going lane is green. Docs still list imported idempotent calls, broader CFG/dominator precision, try/merge/cycle breadth, and a local `ReturnCall` divergence as open questions outside the local subset. | **Documented Binaryen behavior gap.** Direct fuzz green does not close the source-surface gap. | Reopen as active behavior-parity implementation/audit work. |
| `pick-load-signs` / `[O4Z-AUDIT-PLS]` | Direct 9975/10000 lane is green. The only explicit scope divergence is that Starshine recognizes i64 families beyond upstream's i32-focused helper surface. | **No known behavior discrepancy for closure.** The broader i64 rewrite is a local semantic-preserving expansion / output-scope watchpoint, not currently a Binaryen-missing behavior gap. | Keep removed unless a new strict-upstream-equivalence or semantic mismatch appears. |
| `remove-unused-names` / `[O4Z-AUDIT-RUN]` | Direct 9975/10000 lane is green and raw rewrite performance was improved. The audit note and landing page still say actual O4z mode returns an intentional no-op for this pass, so O4z misses same-type wrapper collapse and loop demotion. | **Preset/O4z behavior gap.** Direct explicit pass parity is not enough to claim scheduled O4z behavior parity. | Reopen as an O4z guard-narrowing or explicit accepted-non-goal slice. |
| `remove-unused-module-elements` / `[O4Z-AUDIT-RUME]` | Current page classifies the major semantic keep/drop/remap gaps as fixed and direct 9972/10000 compare as zero semantic mismatches; remaining failures are parser/tool or coverage-hardening. | **No known behavior discrepancy for direct pass.** Scheduler placement is still part of preset behavior, not direct RUME semantics. | Keep direct audit removed; track missing repeated preset slots under preset behavior. |
| `duplicate-function-elimination` / `[O4Z-AUDIT-DFE]` | Direct 9975/10000 lane is green after hash/rewrite coverage. Docs still say Starshine is one-iteration, Binaryen has stronger optimize/shrink iteration and two top-level slots, and local extra cleanup is bundled with DFE. | **Documented behavior/scheduler gap.** Core direct merge behavior is good, but overall Binaryen DFE behavior is not fully represented. | Reopen direct/scheduler behavior-parity work. |
| `global-refining` / `[O4Z-AUDIT-GR]` | Saved slot and focused boundary tests are green. The parity page still calls out a missing explicit GC feature gate and additional descriptor/stringref initializer/public-type fixture surfaces. | **Behavior watchpoint.** Smaller than MP/OR/GSI, but not clean enough to silently treat as no known discrepancy until the GC-gate and initializer surfaces are classified or fixed. | Reopen a focused confirm/fix slice or explicitly prove these are non-observable local-representation differences. |
| `global-struct-inference` / `[O4Z-AUDIT-GSI]` | Direct 9975/10000 lanes are green for the documented Starshine subset. The parity page says the full official contract is much broader: sibling `gsi-desc-cast`, broader open/closed-world reasoning, unbounded/large-module un-nesting, carriers, larger decision trees, Binaryen-style refinalization, and more atomic/aggregate surfaces. | **Documented Binaryen behavior gap.** The prior signoff is a subset signoff, not full behavior parity. | Reopen as active behavior-parity implementation/audit work. |
| `simplify-locals` / `[O4Z-AUDIT-SL]` | 2026-06-04 O4z closeout has zero direct and generated late-neighborhood mismatches. Remaining exact artifact carrier/value-shape drift is classified as representation/canonicalization/performance frontier, with raw thresholds tracked under `[AUDIT002-F/G]` and `[WALL]001`. | **No known direct behavior discrepancy for closure.** | Keep removed; do not let raw-threshold coverage masquerade as behavior parity. |
| `local-cse` / `[O4Z-AUDIT-LCSE]` | 2026-06-07 closeout and follow-ups implemented previously rejected Binaryen-positive behavior gaps. Final docs classify remaining items as semantic-safe representation, Binaryen no-op/tool-blocked, or explicit non-CSE roots. | **No known behavior discrepancy after reopening work.** | Keep removed; reopen only with a new Binaryen-positive source probe or mismatch. |
| `code-folding` / `[O4Z-AUDIT-CF]` | 100000-case direct lane left only agent-classified semantic-safe cleanup/representation mismatches; later slices closed non-EH movement, EH classification, fixpoint, profitability, and timing. Exact helper-cost/text-shape differences are documented as future non-semantic work. | **No known direct behavior discrepancy for v0.1.0 direct pass.** Scheduler slot is still a preset gap. | Mark as behavior-closed, but track scheduling separately. |
| `strip-debug` / `[JSON-AS]008` | Registry and tests show `strip-debug` is now an active module pass; the older backlog text that says it is not implemented is stale. | **Implementation status stale, not a behavior gap.** Preset placement and artifact metrics remain open. | Update backlog to say implemented-direct, schedule/artifact follow-up open. |

## Active pass audits that still need behavior work or closeout evidence

These are the active release-gating audit names in `agent-todo.md` after applying the behavior-parity rule. The scope text in `agent-todo.md` remains the detailed implementation checklist.

| Group | Passes |
| --- | --- |
| Reopened removed audits with documented behavior gaps | `memory-packing`, `once-reduction`, `remove-unused-names` in O4z mode, `duplicate-function-elimination`, `global-refining`, `global-struct-inference` |
| Existing active hot/function audits | `ssa-nomerge`, `dead-code-elimination`, `remove-unused-brs`, `optimize-instructions`, `heap-store-optimization`, `precompute`, `code-pushing`, `tuple-optimization`, `simplify-locals-nostructure`, `vacuum`, `heap2local`, `optimize-casts` |
| Existing active module/local audits | `reorder-locals`, `local-subtyping`, `coalesce-locals`, `merge-blocks`, `redundant-set-elimination`, `dae-optimizing`, `inlining-optimizing`, `duplicate-import-elimination`, `simplify-globals-optimizing`, `string-gathering`, `reorder-globals`, `directize` |
| Direct behavior closed but preset placement still missing | `code-folding`, `remove-unused-module-elements`, `duplicate-function-elimination` direct surface, plus repeated `vacuum`, `reorder-locals`, and `coalesce-locals` slots after their direct audits close |
| Boundary-only / removed registry entries | The registry still explicitly rejects many upstream names as boundary-only or removed, including `flatten`, `precompute-propagate`, `remove-unused-types`, `gufa*`, `type-*`, `reorder-functions*`, `reorder-types`, `const-hoisting`, `dataflow-optimization`, and `loop-invariant-code-motion`. These are outside the current active no-DWARF subset unless the release target changes, but they are unimplemented if the goal becomes full Binaryen pass-catalog behavior. |

## Actionable backlog changes from this inventory

1. Treat `agent-todo.md` audits as behavior-parity work, not output-parity work.
2. Reopen MP, OR, RUN/O4z, DFE, GR, and GSI as active behavior slices or explicitly mark their gaps as accepted non-goals with user approval.
3. Add a preset behavior slice for the documented 52-slot Binaryen baseline versus Starshine's current 39-slot public preset before widening `optimize` / `shrink`.
4. Update the pass implementation skill so future agents cannot close/remove a pass audit while docs still admit broad missing Binaryen behavior.
5. Correct stale `strip-debug` backlog wording: the direct module pass exists; the remaining work is preset/artifact signoff.
6. Record that the local `wasm-opt` binary now reports `version_130`; the no-DWARF order page needs a dedicated `version_130` reread before new exact path claims.
