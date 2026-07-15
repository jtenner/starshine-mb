---
kind: entity
status: working
last_reviewed: 2026-07-15
sources:
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-internal-output-recursive-ownership-impact.md
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-nested-call-argument-impact.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-conditional-branch-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unreachable-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-drop-const-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-drop-const-unreachable-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unreachable-drop-const-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-add-unreachable-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unreachable-add-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-add-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-add-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-multiply-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-multiply-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-add-multiply-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-nontrapping-binary-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-nontrapping-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-root-sequence-with-trap-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-direct-root-sequence-with-unreachable-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-direct-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-call-argument-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-conversion-call-argument-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-constant-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-plus-constant-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-conversion-plus-constant-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-constant-argument-vector-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-one-rich-argument-vector-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-unary-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-binary-conversion-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-binary-argument-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-conversion-pair-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-rich-argument-vector-call-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-one-multiply-child-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-two-multiply-children-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-deeper-two-multiply-children-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-direct-drop-const-root-sequence-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-add-multiply-roots-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-multiply-add-roots-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-nested-add-multiply-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-nested-multiply-add-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-add-two-multiplies-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-sub-two-multiplies-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-subtract-const-multiply-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-subtract-multiply-const-suffix-refresh.md
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
- It now has an **internal active-partial** Starshine owner with a Flat IR classifier, scalar function-result materialization, reachable/unreachable tee lowering across region roots and operand positions, ordered scalar operand preludes, branch-free defaultable scalar `block`/`if` routing, branch-free defaultable independently produced multivalue `block`/`if`, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, and zero-input `loop` routing across payloadless backedges, branch-targeted independently scalar multivalue `if` arms with plain exits, scalar and exact independently scalar or tuple-made multivalue legacy `try` do/catch routing with plain carried try-label `br` exits and exact scalar try-label `br_if` direct-drop/unary/conversion/same-typed-binary false flow in either operand position and exact multivalue direct-drop, unary/conversion, or independently scalar / exclusively tuple-made same-typed-binary false flow plus exact scalar try-label `br_table` fanout through any complete strict direct-enclosure chain of matching block/if controls in structural order without a hardcoded count cap, and independently scalar multivalue fanout through the same arbitrary direct mixed order, including try-inside-if-inside-block, with exclusively tuple-made fanout admitted through the same arbitrary strict direct block/if order after separate exclusive-ownership, component, one-evaluation, and safe-deletion preflight without a hardcoded count cap, or one repeated try target behind an explicit catch-payload/exceptional-transfer prerequisite classifier, defaultable scalar branch-targeted `if` routing, zero-input and independently scalar or one exact tuple-made-entry inputful scalar-result `loop` routing with payloadless or independently scalar one- and multi-parameter `br`/`br_if` backedges, and plain scalar or independently scalar multivalue block-targeting `br`, including mixed fallthrough plus nested plain exits, scalar `br_if` routing including rich shared origins and the target/flow two-temp mismatch, same-vector multivalue block/if-targeting `br_if` routing with exact exclusive false-path spans, plus independently scalar `br_table` rich-origin and unique-target fanout for defaultable scalar block/if targets, exact repeated-label and nested multi-block multivalue targets, one- or multi-parameter loop entry channels, exact inputful multivalue loop plain branches and `br_if` channels with immediate direct-drop, same-typed binary with a simple right operand, unary, or conversion false flow from independently scalar or tuple-made payloads, one exact exclusive tuple-made loop result tail, per-arm independently scalar or exact separately owned tuple-made legacy-try tails with supported scalar component origins, and exact loop-plus-enclosing-block, loop-plus-repeated-if, and loop-plus-repeated-block table channels, exact scalar, independently scalar, and exclusively tuple-made terminal try-table fanout into one directly enclosing inputful loop with distinct entry/result channels and tuple ownership/deletion proof, plus same-arm nonterminal tables followed only by direct `Unreachable` roots, any positive number of exclusively owned distinct direct `drop(const)` roots, either exact two-root mixed order of direct `drop(const)` and direct `Unreachable`, either exact two-root mixed order of direct `drop(i32.add(const, const))` and direct `Unreachable`, any positive ordered sequence whose roots are independently owned direct `drop(const)`, direct `Unreachable`, or independently owned direct `drop(i32.add(const, const))`, `drop(i32.sub(const, const))`, `drop(i32.mul(const, const))`, `drop(i32.and(const, const))`, `drop(i32.clz(const))`, `drop(i64.extend_i32_s(const))`, or `drop(i32.div_s(const, const))`, or exact owned direct resultless calls with zero arguments, any positive vector of distinct scalar constants, exactly one audited binary, unary, or conversion argument plus any positive number of distinct scalar constants at arbitrary positions, or exactly two audited rich arguments from the admitted pair roster, with or without additional distinct scalar constants at arbitrary positions, or one exact scalar constant, `i32.add(const, const)`, `i32.div_s(const, const)`, `i32.clz(const)`, or `i64.extend_i32_s(const)` argument, or exact one- or two-multiply-child outer-add or outer-subtract drop trees with constant leaves, or one exact bounded outer add/subtract tree combining a matching two-multiply-child subtree and one direct constant; separately admitted single-root suffixes include exact `drop(i32.sub(const, const))`, any positive number of independently owned direct `drop(i32.mul(const, const))` roots, exact `drop(i32.and(const, const))`, exact `drop(i32.clz(const))`, exact `drop(i64.extend_i32_s(const))`, or exact `drop(i32.div_s(const, const))` root, plus exact owned direct void calls with zero arguments, any positive vector of distinct exclusively owned scalar constants, exactly one audited binary, unary, or conversion argument plus any positive number of distinct exclusively owned scalar constants at arbitrary positions, or exactly two audited rich arguments from the admitted pair roster, with or without additional distinct scalar constants at arbitrary positions, or one exclusively owned scalar constant, exact `i32.add(const, const)`, exact `i32.div_s(const, const)`, exact `i64.extend_i32_s(const)`, or exact `i32.clz(const)` argument through admitted try-table ancestries, and owner-local terminal placeholders for nested `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref`; structured suffix roots remain fail-closed because HOT cannot yet delete a control node and its owned label metadata together; the public registry remains `Removed` while broader correctness work continues.
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

## 2026-07-15 internal output, ownership, proof-cache, and batch-mutation iterations

Three internal commits added resultless synthetic catch-all `Try` lowering, replaced six bounded call-argument recognizers with one recursive distinct one-use collector, admitted direct subtraction roots, and reused multi-root ownership results. On the three-probe detached-baseline matrix, the bridge shape was already Flat but unlowerable at baseline, while recursive and direct-subtract call suffixes moved from unchanged/non-Flat to changed/Flat. Current Starshine now lowers, encodes, validates, and executes all three probes.

The refreshed matched byte matrix totals `204` input bytes, `212` current Starshine direct bytes, `212` Starshine cleanup bytes, `275` Binaryen direct bytes, and `236` Binaryen cleanup bytes. The nonthrowing synthetic-try lowering removes the dead handler and retains only a target block where needed, making this narrow bridge/control/local family 63 bytes smaller direct and 24 bytes smaller after matched cleanup. All outputs validate and deterministic runtime results still match; this remains a measured narrow Starshine size win. Run-wide suffix/EH/terminal caches, duplicate-router removal, lightweight reachable ownership counts, and one-revision detached suffix deletion reduce the representative 120-function pass-only median from `3,682.5 us` to a current `970.5 us`, or `3.65x` Binaryen v130's `266.05 us`, still outside the `<=2x` target. Direct `i32.shl`, `i32.shr_s`, and `i32.shr_u` call roots share the recursive ownership proof, with `i32.rotl` retained as the private boundary. Typed `Catch`/`CatchAll` and `Rethrow`/`Delegate` retain distinct pre-mutation deferred outcomes, and structured suffix controls remain gated because batch node deletion does not remove owned label metadata. Full current evidence is in [`../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md`](../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md); the prior loss is retained historically in the earlier impact note.

## 2026-07-15 branch-index and in-place-tail follow-up

Commits `c6181e26d` and `0a415161f` add one immutable pre-mutation label-to-branch-node index and replace one-for-one control-result tail splices with exact HOT region-root writes. Repeated/default `br_table` labels are recorded once, `label_used` comes from the same scan, scalar target admission no longer scans every live node, and scalar/multivalue block, if, loop, and legacy-try tails no longer rebuild the full sibling array merely to wrap one value in `local.set`.

Focused flatten remains `245/245`; private flatten is `146/146`; passes are `5,721/5,721`; the full suite is `9,181/9,181`; `moon info`, targeted formatting, and diff checks pass. No `.mbti`, public registry, dispatcher, CLI, compare/API, or preset surface changed. One same-session reconstructed candidate chain improved `1,197.5 -> 1,092.5 -> 1,030 us`, but the exact-shape code-2 sample remained about `3.9x` Binaryen. Typed EH, structured control-plus-owned-label deletion, broader parity, profile/four-lane signoff, and public wiring therefore remain open.

## 2026-07-15 suffix truncation and rewrite-proof boundary

Commits `13fe7b744` and `9acdac744` complete the next exact two-code internal iteration. The first adds `hot_region_truncate_suffix(...)`, whose red-first invariant proves that ordered suffix roots detach while the existing holder child span, prefix identity, storage count, and one revision advance are preserved; admitted terminal legacy-try tables now use it before exact batch tombstoning. The second makes scalar `br`, `br_if`, and `br_table` rewrite checks consume the immutable pre-mutation label branch index instead of rebuilding a live-node index after rewriting starts. Its red-first invariant proves that post-snapshot nodes cannot widen mutation-time admission.

The reconstructed 120-function candidate chain moved from clean `1f1a2dfd0` at `1,116.5 us` to code 1 at `1,053.5 us` (`5.64%`). Code 2 produced noisy slower samples and is classified as proof-boundary correctness/scan-removal rather than a measured speed win. Focused region editing is `4/4`, focused flatten `245/245`, private flatten `147/147`, passes `5,722/5,722`, and the full suite `9,183/9,183`; `moon info`, targeted formatting, and diff checks pass. The only `.mbti` addition is the HOT suffix-truncation API. Public registry, dispatcher, CLI, compare/API, and preset wiring remain absent. Performance is still at best `3.65x` Binaryen v130's `266.05 us`; typed EH, structured control-plus-owned-label deletion, broader parity, profile/four-lane signoff, and public admission remain open. See the [consolidated impact note](../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md).

## 2026-07-15 multivalue branch-index and table-vector follow-up

Commits `9aa7499e9` and `710cdc910` complete the next exact two-code internal iteration without widening the admitted semantic surface. Multivalue block/if target support now consumes the same immutable pre-mutation label-to-branch-node index as scalar routing, including recursive table-target checks and deferred-family admission. The first red-first invariant proves that a malformed branch allocated after the snapshot can fail an uncached proof without widening mutation-time routing. The second commit preflights and resolves each admitted `br_table` target's complete typed local vector once, then reuses those vectors for every payload lane; its invariant proves stable vector identity and no duplicate local allocation.

Private flatten is now `149/149`, focused flatten remains `245/245`, passes are `5,724/5,724`, the full suite is `9,185/9,185`, and `moon info`, targeted formatting, and diff checks pass. A 120-function multivalue branch fixture improved from a same-session `5,581.5 us` median to `5,099 us` (`8.64%`), while the table-vector fixture was noisy and did not establish a second speed win. No `.mbti` or public pass surface changed. The prior stable `970.5 us` candidate checkpoint remains `3.65x` Binaryen v130, so performance, typed EH, structured control-plus-owned-label deletion, broader behavior, the flatten GenValid aggregate, four-lane signoff, ordered-neighborhood proof, and public admission all remain open.

## 2026-07-15 legacy-try branch and ownership follow-up

Commits `e39faf79e` and `e64428dc1` complete the next exact two-code internal iteration without widening behavior. Multivalue legacy-try label support now consumes the immutable pre-mutation branch population, and multivalue legacy-try plus loop conditional-flow proofs reuse exact lightweight reachable ownership counts instead of allocating full node-use/use-def structures. The two red-first invariants lock both mutation-time proof populations.

Private flatten is `151/151`, focused flatten `245/245`, passes `5,726/5,726`, and the full suite `9,187/9,187`; `moon info`, targeted formatting, and diff checks pass. A 120-function tuple-made legacy-try `br_if` fixture with 256 extra roots improved `16,524.5 -> 16,167 -> 6,724.5 us`, a `59.31%` total reduction. No `.mbti` or public pass surface changed. The prior stable representative checkpoint remains `970.5 us` (`3.65x` Binaryen v130), so all public-readiness blockers remain open.

## 2026-07-15 region-tail ownership and loop-branch follow-up

Commits `3d0acb44e` and `19fa4eda8` complete the next exact two-code internal iteration without widening behavior. Exact multivalue `TupleMake` region tails now prove exclusive ownership from the immutable reachable-use counts plus the already-known tail root/slot instead of allocating full use-site arrays. The complete inputful-loop support and rewrite chain now consumes the immutable per-label branch population and the same pre-mutation counts for multivalue `br_if` and tuple-flow proof. Both red-first invariants prove that post-snapshot uses or branches can fail uncached checks without widening mutation-time admission.

Private flatten is `153/153`, focused flatten `245/245`, passes `5,728/5,728`, and the full suite `9,189/9,189`; `moon info`, targeted formatting, and diff checks pass. The 120-function two-lane tuple-tail fixture improved `6,569 -> 4,144.5 us` (`36.91%`), and the exact inputful-loop `br_if` fixture improved `8,344 -> 6,870 us` (`17.67%`). The reconstructed representative terminal-table fixture was noisy (`2,953.5 -> 3,038.5 us` with overlapping ranges), so the stable `970.5 us` / `3.65x` checkpoint remains the durable gate result. No `.mbti` or public pass surface changed; typed EH, structured control-plus-label deletion, broader parity, the flatten GenValid aggregate, four-lane signoff, ordered-neighborhood proof, and public admission remain open.

## 2026-07-15 loop-entry and scalar-try ownership follow-up

Commits `3a88b5bd6` and `5c0235d71` remove two more full node-use/use-site builds without widening behavior. Exact tuple-made inputful-loop entries now use the immutable reachable counts plus the structurally known entry slots and reversed body-prefix drops. Exact scalar legacy-try `br_if` false flow uses the same snapshot plus the known branch/adjacent-consumer shape. Both red-first invariants prove post-snapshot extra uses fail uncached without widening mutation-time proof.

Private flatten is `155/155`, focused flatten `245/245`, passes `5,730/5,730`, and the full suite `9,191/9,191`; `moon info`, targeted formatting, owner-hash verification, and diff checks pass. Targeted 120-function fixtures with 256 extra roots improved `10,895.5 -> 4,506 us` (`58.64%`) for tuple loop entries and `8,867.5 -> 4,214.5 us` (`52.47%`) for scalar try flow. The stable representative remains `970.5 us` / `3.65x` Binaryen, so public readiness is unchanged and all wiring stays absent.

## 2026-07-15 tuple branch and conditional-flow proof follow-up

Commits `24ca31723` and `32690a37d` remove flatten's last two full tuple use-site allocation paths without widening behavior. Tuple-made plain branch/table payloads now use the immutable reachable count plus structurally known payload slots. Tuple-made block/if `br_if` flow still needs an exact false-flow location, so admission performs one bounded reachable locator, caches the exact tuple/parent/start result by branch id, and rewrite requires that pre-mutation cache.

Private flatten is `157/157`, focused flatten `245/245`, passes `5,732/5,732`, and the full suite `9,193/9,193`; `moon info`, targeted formatting, owner-hash verification, and diff checks pass. Targeted 120-function fixtures with 256 extra roots improved `13,697 -> 5,238 us` (`61.76%`) for tuple branch payloads and `12,764.5 -> 5,578.5 us` (`56.30%`) for tuple block `br_if`. No full node-use/use-site builder remains in `src/passes/flatten.mbt`. The stable public gate remains the unrequalified `970.5 us` / `3.65x` Binaryen checkpoint, so public wiring stays absent and all correctness/signoff blockers remain open.

## 2026-07-15 distinct and scalar conditional-site proof follow-up

Commits `ae096a883` and `b87464d25` remove the remaining whole-function rewrite-time flow discovery for ordinary block/if `br_if` without widening behavior. Distinct non-tuple multivalue flow caches the exact positive or negative contiguous parent/start during admission. Scalar flow snapshots the exact parent population, re-resolves only expected slot shifts inside those parents after prelude insertion, and records chained replacement identity in the same rewrite state; a use introduced under a new post-snapshot parent is not rewritten.

Private flatten is `159/159`, focused flatten `245/245`, passes `5,734/5,734`, and the full suite `9,195/9,195`; `moon info`, targeted formatting, owner-hash verification, and diff checks pass. The distinct 600-function fixture moved `30 -> 28 ms`, while the scalar fixture moved `22 -> 23 ms` and is classified as correctness-only. No semantic family, `.mbti`, or public pass surface changed. The durable public gate remains the unrequalified `970.5 us` / `3.65x` Binaryen checkpoint, so all public wiring stays absent.

## 2026-07-15 sparse proof-cache follow-up

Commits `e165fde1c` and `476848f9d` replace fifteen node-sized conditional-flow, dead-suffix, terminal-table, and scalar-try cache arrays with seven sparse entry vectors keyed only by admitted branch, value, table, or try owners. The exact pre-mutation proof boundary is unchanged: positive and negative conditional decisions stay frozen, scalar parent populations still tolerate only expected same-parent slot shifts, terminal decisions retain region/label/arity/mixed-target identity, and a missing cache after mutation starts still fails closed.

The two red-first invariants prove that functions with 256 unrelated nodes begin with zero entries and allocate only for inspected owners. Private flatten is `161/161`, focused flatten `245/245`, passes `5,736/5,736`, the full suite `9,197/9,197`, and `moon info` is green with 11 existing warnings. A reconstructed 1,200-function version of the documented three-family representative mix moved from a scaled `1,900 us` to `1,800 us` per 120 after code 1, then measured `1,900 us` on both sides of code 2; the node-heavy code-2 fixture moved `8,200 -> 8,300 us`. These overlapping coarse samples do not requalify the durable `970.5 us` / `3.65x` gate. No semantic family, `.mbti`, or public pass surface changed, so all public wiring remains absent.

## 2026-07-15 postorder-routing and shared-root follow-up

Commits `7801166ac` and `18101a947` complete the next exact two-code internal iteration without widening behavior. The first replaces three generic postorder router attempts on every recursively visited node with one exact carried-`br` dispatch; payload-bearing `br_if` and `br_table` remain in their dedicated arms. The second retains sequence-root holder/node identity only for roots whose immutable pre-mutation reachable use count is greater than one, and rejects rewrite-created ids beyond that frozen population. Its first implementation exposed five focused out-of-range failures before the explicit snapshot node limit restored the boundary.

A repeatable high-resolution native-release pass-only path was recovered through the existing `passes_perf_long` package with temporary benchmark sources preserved under `.tmp`. A 1,200-function fixture with 256 unrelated roots plus one carried branch improved from a `57,498 us` median at `be140ee73` to `52,402 us` after code 1 (`8.86%`); code 2 measured `52,534.5 us`. The reconstructed 120-function three-family representative measured `1,177 -> 1,176 -> 1,171.5 us`, with overlapping ranges. These results establish one targeted traversal win and one allocation-footprint reduction, but they do not reproduce or replace the durable `970.5 us` / `3.65x` public gate.

Private flatten is `163/163`, focused flatten `245/245`, passes `5,738/5,738`, the full suite `9,199/9,199`, and `moon info` remains green with 11 existing warnings. No `.mbti` or public registry, dispatcher, CLI, compare/API, generator, or preset surface changed. Typed EH, structured control-plus-owned-label deletion, broader parity, the flatten GenValid aggregate, four-lane signoff, ordered-neighborhood proof, performance readiness, and public admission remain open.

## 2026-07-15 single-target table and loop-support follow-up

Commits `81cfb9619` and `dda2bdfe3` complete the next exact two-code internal iteration. The first reuses the exact resolved target-local vector as the staging vector when a `br_table`'s repeated/default labels deduplicate to one target. Multi-target fanout still allocates a separate staging vector and copies to every unique target. The red-first invariant proves the one-target path allocates no extra staging locals while the multi-target path remains distinct. Existing scalar, tuple, loop, legacy-try, suffix, and placeholder expectations now lock the smaller shape. A focused encoded probe shrank from `51` to `47` bytes; the reconstructed representative samples were `1,128.5 us` baseline, `1,087 us` after code 1, and later `1,136` / `1,122 us`, so the durable claim is the measured 4-byte size and local/operation-count win rather than a stable timing win.

The second commit caches each inspected inputful-loop support result in `FlattenRewriteState`, reuses only that exact admission result after mutation starts, and fails closed if no entry exists. Its red-first invariant proves a post-snapshot malformed backedge can make an uncached proof fail without changing the cached rewrite decision. A 600-function native-release inputful-loop fixture was timing-flat at `2,589 -> 2,584 us`. Private flatten is `165/165`, focused flatten `245/245`, passes `5,740/5,740`, the full suite `9,201/9,201`, and `moon info` is green with 11 existing warnings. No `.mbti` or public registry, dispatcher, CLI execution, compare/API, generator, or preset surface changed. The durable `970.5 us` / `3.65x` performance gate, typed EH, structured control-plus-owned-label deletion, broader parity, flatten aggregate, four-lane signoff, ordered-neighborhood proof, and public admission remain open.

## 2026-07-15 branch append and admission-roster follow-up

Commits `6a74918d6` and `1acb9bc14` complete the next exact two-code internal iteration without widening behavior. The branch index now uses the monotonic HOT node order to deduplicate only repeated targets from the current branch node, avoiding a scan of every prior user of that label. The same immutable node scan also records exact loop, legacy-try, and payload-bearing branch admission rosters, so admission no longer performs three whole-live-node scans.

The branch-dense native-release fixture improved `17,065 -> 14,723 us` (`13.72%`). The root-heavy fixture improved `54,596 -> 51,076.5 us` (`6.45%`) with a `49,953.5 us` rerun, and the reconstructed representative moved directionally `1,111.5 -> 1,066 us`. Private flatten is `167/167`, focused flatten `245/245`, passes `5,742/5,742`, the full suite `9,203/9,203`, and `moon info` remains green with 11 existing warnings. No semantic family, `.mbti`, or public surface changed. The durable `970.5 us` / `3.65x` gate and all typed-EH, structured-label deletion, broader-parity, aggregate, signoff, neighborhood, and public-readiness blockers remain open.

## Current maintenance rule

- Treat this folder as the canonical home for future `flatten` research and port planning.
- Keep it explicitly marked **internal active-partial / public removed** until the direct pass surface is safe to register and dispatch.
- Keep the strategy, implementation/test-map, and flat-IR/preludes pages in sync whenever new evidence changes the answer to any of these:
  - “what exact AST properties does Binaryen flatten enforce?”
  - “which owner/test/helper surfaces prove that behavior?”
  - “which feature shapes are still unsupported or only selectively supported?”

## Sources

- [`../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md`](../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md)
- [`../../../raw/binaryen/2026-07-15-flatten-version-130-internal-output-recursive-ownership-impact.md`](../../../raw/binaryen/2026-07-15-flatten-version-130-internal-output-recursive-ownership-impact.md)
- [`../../../raw/binaryen/2026-04-27-flatten-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-flatten-port-readiness-primary-sources.md)
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
