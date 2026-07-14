---
kind: entity
status: working
last_reviewed: 2026-07-14
sources:
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-conditional-branch-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unreachable-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-pure-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-pure-binary-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-trapping-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-call-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-call-argument-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-legacy-eh-repair-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-unreachable-return-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-terminal-throw-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-conditional-consumer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-terminal-tail-call-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-block-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-if-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-branch-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-entry-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-table-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-conditional-producer-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-conditional-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-loop-result-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-try-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-tuple-try-rich-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-try-tail-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-try-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-try-conditional-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-tuple-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-conditional-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-conditional-reversed-binary-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-three-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-scalar-try-two-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-two-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-two-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-three-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-three-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-three-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-four-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-four-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-four-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-five-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-five-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-five-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-six-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-six-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-six-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-seven-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-seven-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-seven-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-unbounded-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-ten-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-ten-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-ten-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-nine-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-nine-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-nine-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-eight-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-eight-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-eight-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-unsupported-policy-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-conditional-unary-convert-refresh.md
  - ../../../raw/binaryen/2026-07-11-flatten-current-main-and-local-status-recheck.md
  - ../../../raw/binaryen/2026-04-27-flatten-port-readiness-primary-sources.md
  - ../../../raw/research/0422-2026-04-27-flatten-port-readiness.md
  - ../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md
  - ../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0127-2026-04-20-flatten-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../raw/research/0065-2026-03-24-ir2-execution-plan.md
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-ir-contract-and-preludes.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../local-cse/index.md
  - ../tracker.md
---

# `flatten`

## Role

- `flatten` is an upstream Binaryen aggressive flat-IR preparation pass.
- It now has an **internal active-partial** Starshine owner with a Flat IR classifier, scalar function-result materialization, reachable/unreachable tee lowering across region roots and operand positions, ordered scalar operand preludes, branch-free defaultable scalar `block`/`if` routing, branch-free defaultable independently produced multivalue `block`/`if`, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, and zero-input `loop` routing across payloadless backedges, branch-targeted independently scalar multivalue `if` arms with plain exits, scalar and exact independently scalar or tuple-made multivalue legacy `try` do/catch routing with plain carried try-label `br` exits and exact scalar try-label `br_if` direct-drop/unary/conversion/same-typed-binary false flow in either operand position and exact multivalue direct-drop, unary/conversion, or independently scalar / exclusively tuple-made same-typed-binary false flow plus exact scalar try-label `br_table` fanout through any complete strict direct-enclosure chain of matching block/if controls in structural order without a hardcoded count cap, and independently scalar multivalue fanout through the same arbitrary direct mixed order, including try-inside-if-inside-block, with exclusively tuple-made fanout admitted through the same arbitrary strict direct block/if order after separate exclusive-ownership, component, one-evaluation, and safe-deletion preflight without a hardcoded count cap, or one repeated try target behind an explicit catch-payload/exceptional-transfer prerequisite classifier, defaultable scalar branch-targeted `if` routing, zero-input and independently scalar or one exact tuple-made-entry inputful scalar-result `loop` routing with payloadless or independently scalar one- and multi-parameter `br`/`br_if` backedges, and plain scalar or independently scalar multivalue block-targeting `br`, including mixed fallthrough plus nested plain exits, scalar `br_if` routing including rich shared origins and the target/flow two-temp mismatch, same-vector multivalue block/if-targeting `br_if` routing with exact exclusive false-path spans, plus independently scalar `br_table` rich-origin and unique-target fanout for defaultable scalar block/if targets, exact repeated-label and nested multi-block multivalue targets, one- or multi-parameter loop entry channels, exact inputful multivalue loop plain branches and `br_if` channels with immediate direct-drop, same-typed binary with a simple right operand, unary, or conversion false flow from independently scalar or tuple-made payloads, one exact exclusive tuple-made loop result tail, per-arm independently scalar or exact separately owned tuple-made legacy-try tails with supported scalar component origins, and exact loop-plus-enclosing-block, loop-plus-repeated-if, and loop-plus-repeated-block table channels, exact scalar, independently scalar, and exclusively tuple-made terminal try-table fanout into one directly enclosing inputful loop with distinct entry/result channels and tuple ownership/deletion proof, plus same-arm nonterminal tables followed only by direct `Unreachable` roots or one exclusively owned direct `drop(const)`, exact `drop(i32.add(const, const))`, exact `drop(i32.clz(const))`, or exact `drop(i32.div_s(const, const))` root, plus exact owned direct void calls with zero arguments or one exclusively owned scalar constant argument through admitted try-table ancestries, and owner-local terminal placeholders for nested `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref`; the public registry remains `Removed` while broader correctness work continues.
- In Binaryen `version_129`, it is **not** part of the canonical no-DWARF `-O` / `-Os` path used elsewhere in this repo.
- Instead, it appears only in the more aggressive `optimizeLevel >= 4` function pipeline, where it starts the trio:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`
- Its real job is not “generic flattening” or “merge blocks.”
- The real job is: rewrite Binaryen IR into the formal `Flat IR` shape from `src/ir/flat.h` by routing nested values and value-carrying control flow through temp locals and explicit preludes.

## Why it matters

- The dossier already explained the upstream Binaryen contract and later gained the now-standard owner-file / helper / lit-test / local-code map page that neighboring refreshed folders provide.
- The 2026-04-27 port-readiness and 2026-07-11 current-main/local-status rechecks found no teaching-relevant drift from the tagged `version_129` contract, so the latest work adds an implementation-readiness and validation bridge rather than rewriting the strategy as a correction.
- The saved generated-artifact `-O4z` audit still records `flatten` as a real skipped top-level upstream slot:
  - slot `9`
- The saved Binaryen debug log still shows it is bigger than a one-off top-level detail:
  - the top-level slot `9` run took about `1.67786` seconds
  - the full `-O4z` run executed `flatten` `18` total times because nested optimizing reruns reuse the default aggressive function pipeline
- The pass sits immediately before two already-documented neighbors whose purpose is easier to understand once flatten is clear:
  - `simplify-locals-notee-nostructure`
  - `local-cse`
- The current Starshine planning story is worth keeping explicit:
  - `src/passes/optimize.mbt:142-147` still tracks `flatten` in the removed-name registry
  - `src/cli/cli_test.mbt:305-309` and `src/cli/cli_test.mbt:340-342` still preserve the public `--flatten` spelling
  - `src/passes/pass_manager.mbt` has no active public `flatten` dispatcher case; helpers whose names contain `flatten` serve other passes and do not change this status
  - `../../../raw/research/0065-2026-03-24-ir2-execution-plan.md:69-70` and `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md:107-108` still place `flatten` at the front of the old removed-pass batch
  - `agent-todo.md` now carries `[O4Z-FLAT]001`, including the remaining control, branch-payload, EH, fuzzing, and scheduler work

The 2026-07-11 current-main/local-status recheck found no teaching-relevant upstream transform drift. It does, however, make the two local non-implementation boundaries explicit: the aggressive-neighborhood readiness predicate is intentionally false until all three passes are active, and text matches on `flatten` helper names do not prove pass registration. See Binaryen current-main [`Flatten.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Flatten.cpp) and local registry evidence in `src/passes/optimize.mbt`.

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
- In `version_130`, all four `BrOn*` variants are hard unsupported, and a direct `TryTable` probe aborts in the unhandled control-structure arm. Internal Starshine classifies these as `UpstreamHardUnsupported` before mutation but keeps public execution removed until a Binaryen-compatible rejection contract is wired.
- `Flatten.cpp` also still carries an open non-nullability TODO.
  - But the shipped tests show some non-null cases already work, so the limitation is selective, not absolute.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: scheduler placement, formal Flat IR meaning, the postorder prelude algorithm, control-value rewrites, branch-value temp routing, EH fixups, the reviewed release/source provenance, the retained current-main source bridges, and the current unsupported-instruction boundary.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Owner-file, helper-surface, official lit-test, scheduler, and current Starshine code-map page for `flatten`, including the `Flatten.cpp` / `flat.h` split, the tiny smoke test versus broad all-features and EH proof files, and the exact removed-registry / CLI-spelling / dispatcher-gap line ranges.
- [`./flat-ir-contract-and-preludes.md`](./flat-ir-contract-and-preludes.md)
  Focused guide to the easiest part of the pass to misunderstand: what “flat” means exactly, how preludes migrate, why flatten creates so many locals, how named branch targets get temps, and why `unreachable` placeholders plus EH pop repair are part of the real contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for nested arithmetic, value-carrying `block` / `if` / `loop` / `try`, tee removal, `br_if` / switch value carriers, preserved simple-child families, and hard bailout shapes.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact current Starshine status/port map for `flatten`: removed-name registry tracking, preserved `--flatten` CLI spelling, Batch 2 planning surfaces, the still-missing active backlog slice, and the downstream dossier cluster a future local port would need to serve.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Future implementation-readiness bridge: analyzer-first Flat IR classification, narrow first mutating slice, tee and branch-payload follow-ups, EH and unsupported-family gates, downstream cluster validation, and the criteria for moving `flatten` out of the removed-name registry.

## Current maintenance rule

- Treat this folder as the canonical home for future `flatten` research and port planning.
- Keep it explicitly marked **internal active-partial / public removed** until the direct pass surface is safe to register and dispatch.
- Keep the strategy, implementation/test-map, and flat-IR/preludes pages in sync whenever new evidence changes the answer to any of these:
  - “what exact AST properties does Binaryen flatten enforce?”
  - “which owner/test/helper surfaces prove that behavior?”
  - “which feature shapes are still unsupported or only selectively supported?”

## Sources

- Binaryen current-main [`Flatten.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Flatten.cpp)
- [`../../../raw/research/0422-2026-04-27-flatten-port-readiness.md`](../../../raw/research/0422-2026-04-27-flatten-port-readiness.md)
- [`../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md`](../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md)
- [`../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md`](../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0127-2026-04-20-flatten-binaryen-research.md`](../../../raw/research/0127-2026-04-20-flatten-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../../raw/research/0065-2026-03-24-ir2-execution-plan.md`](../../../raw/research/0065-2026-03-24-ir2-execution-plan.md)
- [`../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md) preserves the saved generated-artifact `-O4z` skipped-slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- Official Binaryen current-main [`Flatten.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Flatten.cpp), [`flat.h`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/flat.h), and the cited local registry sources support the current status.
