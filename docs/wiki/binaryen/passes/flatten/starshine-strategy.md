---
kind: concept
status: supported
last_reviewed: 2026-07-15
sources:
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-internal-output-recursive-ownership-impact.md
  - ../../../raw/binaryen/2026-07-15-flatten-version-130-nested-call-argument-impact.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-conditional-branch-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unreachable-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-add-unreachable-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unreachable-add-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-pure-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-pure-binary-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unbounded-add-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-add-two-multiplies-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-sub-two-multiplies-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-subtract-const-multiply-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-subtract-multiply-const-suffix-refresh.md
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
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-unary-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-trapping-drop-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-loop-table-call-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-try-table-call-argument-suffix-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-legacy-eh-repair-refresh.md
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
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-two-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-three-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-scalar-try-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-scalar-try-two-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-two-block-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-14-flatten-version-130-multivalue-try-block-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-if-table-tuple-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-two-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-three-block-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-multivalue-try-block-table-tuple-refresh.md
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
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../raw/research/0065-2026-03-24-ir2-execution-plan.md
  - ../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../local-cse/index.md
  - ../rereloop/index.md
  - ../i64-to-i32-lowering/index.md
  - ../simplify-locals-nonesting/index.md
  - ../souperify/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-ir-contract-and-preludes.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../local-cse/index.md
  - ../rereloop/index.md
  - ../i64-to-i32-lowering/index.md
  - ../simplify-locals-nonesting/index.md
  - ../souperify/index.md
---

# Starshine Strategy For `flatten`

Use this page together with the retained 2026-07-11 current-main/status recheck in Binaryen current-main [`Flatten.cpp`](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Flatten.cpp), the direct tagged `version_129` URLs in [`./binaryen-strategy.md`](./binaryen-strategy.md), and the local owner/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`flatten` is now **internal active-partial** in Starshine.
`src/passes/flatten.mbt` owns a Flat IR classifier plus scalar body-result materialization, reachable/unreachable tee lowering across function roots, structured-region roots, and ordinary operand positions, ordered scalar operand preludes, branch-free defaultable scalar `block`/`if` result routing, branch-free defaultable independently produced multivalue `block`/`if`, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, and zero-input `loop` result routing across payloadless backedges through exclusive consumer spans, branch-targeted independently scalar multivalue `if` arms with plain exits, scalar and exact independently scalar or tuple-made multivalue legacy `try` do/catch routing with plain carried try-label `br` exits and exact scalar try-label `br_if` direct-drop/unary/conversion/same-typed-binary false flow in either operand position and exact multivalue direct-drop, unary/conversion, or independently scalar / exclusively tuple-made same-typed-binary false flow plus exact scalar try-label `br_table` fanout through any complete strict direct-enclosure chain of matching block/if controls in structural order without a hardcoded count cap, and independently scalar multivalue fanout through the same arbitrary direct mixed order, including try-inside-if-inside-block, with exclusively tuple-made fanout admitted through the same arbitrary strict direct block/if order after separate exclusive-ownership, component, one-evaluation, and safe-deletion preflight without a hardcoded count cap, or one repeated try target behind an explicit catch-payload/exceptional-transfer prerequisite classifier, defaultable scalar branch-targeted `if` routing, zero-input and independently scalar or one exact tuple-made-entry inputful scalar-result `loop` routing with payloadless or independently scalar one- and multi-parameter `br`/`br_if` backedges, and plain scalar or independently scalar multivalue block-targeting `br`, including mixed fallthrough plus nested plain exits, scalar `br_if` routing through typed temps, same-vector multivalue block/if-targeting `br_if` routing across exact exclusive false-path spans, plus independently scalar `br_table` rich-origin and unique-target fanout for defaultable scalar block/if targets, exact repeated-label and nested multi-block multivalue targets, one- or multi-parameter loop entry channels, exact inputful multivalue loop plain branches and `br_if` channels with immediate direct-drop, same-typed binary with a simple right operand, unary, or conversion false flow from independently scalar or tuple-made payloads, one exact exclusive tuple-made loop result tail, per-arm independently scalar or exact separately owned tuple-made legacy-try tails with supported scalar component origins, and exact loop-plus-enclosing-block, loop-plus-repeated-if, and loop-plus-repeated-block table channels, with focused coverage in `src/passes/flatten_test.mbt`. Same-type `br_if` preserves the not-taken flow through one shared `local.get`; the target/flow-type mismatch uses a second flow temp and one target copy; rich ordinary scalar payloads are evaluated once before the condition and shared across chained false-path uses; `br_table` evaluates rich ordinary payloads once before its selector, copies to deduplicated target temps, and removes the dead terminal origin. Nested terminal `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref` operands now become owner-region effects plus `unreachable` placeholders, with child payload/argument work preserved before the terminal, later sibling work preserved afterwards, already-rooted effects deduplicated, and unsupported root value-controls not scalar-materialized. Branch-free multivalue blocks and ifs plus zero-input multivalue loops with payloadless backedges and independently scalar defaultable tails now write a typed label-local vector, erase the control result, and replace one exclusive repeated HOT consumer span with ordered local reads. Branch-free scalar legacy tries now write exact do/catch tails into one shared typed local. Branch-free multivalue legacy tries write per-arm exact independently scalar tails or separately owned exact tuple-made tails with supported scalar component origins into one shared typed vector when one exclusive repeated consumer or region-tail span owns the results. `flatten_eh_repair_requirement(...)` separates missing typed catch-payload tracking from exceptional-transfer repair before mutation. Functions with legacy `Catch`/`CatchAll`, `rethrow`, or `delegate` nodes remain whole-function fail-closed until Binaryen-equivalent payload representation and nested-pop repair land. Same-vector multivalue `br_if` now writes independently scalar payloads once into the shared target vector, replaces one contiguous exclusive false-path tail with matching reads, and preserves the condition. Exact multivalue `br_table` writes each independently scalar component once before selector work, deduplicates repeated labels, and copies the vector once into every admitted nested block target. Inner target results may feed an enclosing target only through one exclusive ordered repeated-control region tail. Exact inputful multivalue loops may share table fanout with an enclosing block when fallthrough tails are independently scalar, or with one repeated exclusive block/if-result tail; staged payload, loop-entry, nested-control-result, enclosing-target, and loop-result vectors stay distinct. Broader mixed-control fanout plus nested or nonexclusive conditional multivalue loop control remain gated. Remaining richer tuple-made loop conditional consumers and mixed table loop backedges, mismatched or ambiguously shared multivalue conditionals, broader multivalue table payloads, broader inputful or backedge multivalue loop results, branch-targeted multivalue loop controls, and broader legacy-try/EH shapes remain open behind conservative gates. Branch-targeted ifs now share one temp across fallthrough arms and carried `br`/`br_if` flow after preflighting every label use; nondefaultable branch payloads remain whole-function fail-closed. Inputful loops capture each independently scalar defaultable entry once in order, redirect body uses through typed locals, and clear the parameter prefix. Scalar results route separately; admitted plain-branch, exact immediate direct-drop, scalar-binary, unary, or conversion false-flow conditional, and table-backed multivalue-result families use a separate ordered result vector. Payloadless zero-input and independently scalar defaultable one- or multi-parameter `br`/`br_if` backedges now reuse typed entry locals while preserving payload order, one evaluation, and conditional false-path flow; one- or multi-parameter loop tables stage payload vectors once and copy them into entry locals. Exact inputful multivalue loop-plus-block fanout also routes independently scalar or one exact exclusive tuple-made fallthrough result tail through distinct locals, while nondefaultable and multivalue single-producer table backedges fail closed. The terminal legacy-try table ancestry preflight now builds direct structural parent links once and walks the exact target chain outward, eliminating the prior approximately quadratic repeated-candidate scan while preserving skipped-ancestry rejection and exact direct-order extraction; the warm three-block-plus-thirty-two-if focused fixture measured 0.187s. The exact terminal legacy-try table roster now also includes scalar and independently scalar payloads whose complete strict direct ancestry reaches one inputful loop: table payload types must equal loop inputs, existing loop entry/backedge/result preflight must pass, all lanes must be defaultable, and loop-entry locals remain distinct from try/control result locals. One exclusively owned repeated-HOT-`TupleMake` payload now admits the same loop ancestry after separate exact-use, ordered component, type/defaultability, loop-backedge, one-evaluation, and safe-deletion preflight. Supported scalar and multivalue legacy-try tables may also have a same-arm suffix consisting only of direct `Unreachable` roots; those detached roots are removed during table routing so the existing terminal result proof remains unchanged, while non-`Unreachable` suffixes remain gated except for any positive number of exclusively owned distinct direct `drop(const)` roots, either exact two-root mixed order of direct `drop(const)` and direct `Unreachable`, either exact two-root mixed order of direct `drop(i32.add(const, const))` and direct `Unreachable`, any positive ordered sequence whose roots are independently owned direct `drop(const)`, direct `Unreachable`, or independently owned direct `drop(i32.add(const, const))`, `drop(i32.sub(const, const))`, `drop(i32.mul(const, const))`, `drop(i32.and(const, const))`, `drop(i32.clz(const))`, `drop(i64.extend_i32_s(const))`, or `drop(i32.div_s(const, const))`, or exact owned direct resultless calls with zero arguments, any positive vector of distinct scalar constants, exactly one audited binary, unary, or conversion argument plus any positive number of distinct scalar constants at arbitrary positions, or exactly two audited rich arguments from the admitted pair roster, with or without additional distinct scalar constants at arbitrary positions, or one exact scalar constant, `i32.add(const, const)`, `i32.div_s(const, const)`, `i32.clz(const)`, or `i64.extend_i32_s(const)` argument, or exact one- or two-multiply-child outer-add or outer-subtract drop trees with constant leaves, or one exact bounded outer add/subtract tree combining a matching two-multiply-child subtree and one direct constant; separately admitted single-root suffixes include `drop(i32.sub(const, const))`, any positive number of independently owned direct `drop(i32.mul(const, const))` roots, `drop(i32.and(const, const))`, `drop(i32.clz(const))`, `drop(i64.extend_i32_s(const))`, or `drop(i32.div_s(const, const))` root; the complete two-, three-, four-, or six-node subtree is detached and deleted before terminal routing. Exact owned direct resultless call roots are admitted with either zero arguments, any positive vector of distinct exclusively owned scalar constants, exactly one audited binary, unary, or conversion argument plus any positive number of distinct exclusively owned scalar constants at arbitrary positions, or exactly two audited rich arguments from the admitted pair roster, with or without additional distinct scalar constants at arbitrary positions, or one exclusively owned scalar constant, exact `i32.add(const, const)`, exact `i32.div_s(const, const)`, exact `i64.extend_i32_s(const)`, or exact `i32.clz(const)` argument, including through the existing direct inputful-loop ancestry. Shared, nested, effectful, other-opcode, or repeated-descendant arguments, same-opcode binary pairs or three-or-more rich arguments, repeated/shared two-argument children, result-carrying calls, and indirect/reference calls remain gated. Multiple-root sequences containing alternate unary/conversion opcodes, deeper, shared, or other richer call arguments, another opcode, a deeper tree, or another rich recognizer remain gated. Structured suffix roots also remain gated: every HOT control owns label metadata, the verifier requires a live matching owner, and the public mutation API cannot remove the detached control and label together without leaving an invalid owner or a live orphan. The registry and dispatcher intentionally remain public-removed until broader families are safe.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is registry tracking plus batch planning:

- keep the upstream pass spelling tracked in the removed-name registry
- keep the public CLI spelling stable
- keep the pass in the IR2 execution-order documents as a deliberate next-wave port target
- keep the downstream dossier cluster honest about which later passes depend on a flattened world
- keep the active `[O4Z-FLAT]001` backlog aligned with the internal implementation and remaining public-closeout gates

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page. For the recommended implementation slices and validation gates, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Exact local code and doc map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - `src/passes/optimize.mbt:144-151`
    - `pass_registry_removed_names()` includes `"flatten"`
- public CLI spelling stability
  - `src/cli/cli_test.mbt:305-309`
    - `resolve_pass_flags omits trap-mode toggles from scheduled pass list`
    - this still preserves the explicit `--flatten` spelling even though trap-mode toggles are omitted
  - `src/cli/cli_test.mbt:340-342`
    - `resolve_pass_flags ignores -O level flags for preset pass expansion`
    - this still preserves explicit `--flatten` alongside an `-O` flag
- dispatcher gap
  - `src/passes/pass_manager.mbt`
    - no active `flatten` match exists today
- current batch intent
  - `../../../raw/research/0065-2026-03-24-ir2-execution-plan.md:69-70`
    - `flatten` still leads the preferred Batch 2 implementation order
  - `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md:107-108`
    - `flatten` still sits in Batch 2 removed-until-implemented planning
- active backlog truth
  - `agent-todo.md`
    - `[O4Z-FLAT]001` tracks implementation, public wiring, direct closeout, and aggressive-neighborhood proof
- exact neighboring living dossiers that define the future landing zone
  - [`../simplify-locals-notee-nostructure/index.md`](../simplify-locals-notee-nostructure/index.md)
  - [`../local-cse/index.md`](../local-cse/index.md)
  - [`../rereloop/index.md`](../rereloop/index.md)
  - [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md)
  - [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md)
  - [`../souperify/index.md`](../souperify/index.md)

That code-and-doc map is the main practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and the future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `flatten` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt:144-151` keeps the upstream spelling `flatten` in `pass_registry_removed_names()`.
That means:

- the project still treats `flatten` as a real known pass
- the name is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and batch-planning work instead of silently falling out of scope

That remains the right public behavior for an internal active-partial parity pass.

### 2. The CLI spelling is intentionally stable

`src/cli/cli_test.mbt:305-309` and `src/cli/cli_test.mbt:340-342` still exercise the explicit `--flatten` spelling in pass-flag resolution tests.
That matters for two reasons:

- docs and future parity commands can keep using the upstream pass spelling consistently
- once a real implementation lands, the public spelling does not need a second documentation migration first

### 3. The repo now has an active implementation slice

The repo still has real planning intent for `flatten`:

- `../../../raw/research/0065-2026-03-24-ir2-execution-plan.md` still puts it first in the next-wave Batch 2 order
- `../../../raw/research/0063-2026-03-24-pass-port-batches-and-registry-map.md` still records it as a Batch 2 removed pass

But the active backlog surface is intentionally less mature:

- `agent-todo.md` now has `[O4Z-FLAT]001` with deliverables and exit criteria

The active slice is intentionally broader than the landed first steps and keeps all public-wiring and parity blockers visible.

## The right future Starshine implementation shape

The current docs strongly suggest that a future local `flatten` port should be taught as a **cluster-root structural normalizer**, not as just another cleanup pass.

Why:

- upstream Binaryen `flatten` defines a formal Flat IR contract rather than a vague simplification pass
- several later upstream passes depend on that flattened world rather than replacing it
- the neighboring Starshine dossiers already rely on explaining those downstream relationships precisely

So the local strategy should be thought of as:

1. decide how Starshine will represent the equivalent of Binaryen's flattened world
   - either a dedicated HOT/IR2 normalization layer that captures the same contract
   - or an explicitly documented divergence if Starshine chooses a different structural representation
2. preserve the real upstream responsibilities
   - temp-local routing for value-producing children
   - elimination of value-carrying control flow
   - elimination of `local.tee`
   - explicit carried-branch payload channels
   - a documented policy for unsupported `BrOn*` / `TryTable` families
3. wire the port into the right downstream cluster rather than landing it as an isolated pass
   - `simplify-locals-notee-nostructure`
   - `local-cse`
   - `rereloop`
   - other flatness-sensitive downstream consumers

In other words, the future port needs to create a structural world that later passes can rely on, not merely remove some nesting opportunistically.

## The most important local dependency map

### `flatten` is the structural root for the aggressive local-cleanup cluster

See [`../simplify-locals-notee-nostructure/index.md`](../simplify-locals-notee-nostructure/index.md) and [`../local-cse/index.md`](../local-cse/index.md).

Why it matters locally:

- the upstream aggressive cluster is `flatten -> simplify-locals-notee-nostructure -> local-cse`
- `flatten` creates the world those later passes expect
- the later passes are not substitutes for `flatten`

A future Starshine port should preserve that relationship instead of treating the cluster as three unrelated ideas.

### `rereloop` depends on flattened input rather than replacing flattening

See [`../rereloop/index.md`](../rereloop/index.md).

Why:

- `rereloop` operates on the already-flattened/control-explicit world
- the relationship is “flatten first, then rebuild structure where useful,” not “rereloop instead of flatten”

That is an important planning boundary for future local design.

### `i64-to-i32-lowering` is another downstream consumer of the flattened world

See [`../i64-to-i32-lowering/index.md`](../i64-to-i32-lowering/index.md).

Why:

- the upstream dossier already records flattened input as a real prerequisite
- that makes `flatten` part of a larger aggressive structural pipeline story, not just a locals-cleanup curiosity

### The broader flatness-sensitive family already exists in the wiki

See [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md) and [`../souperify/index.md`](../souperify/index.md).

Why:

- both dossiers already depend on teaching what the flattened world means
- a future Starshine `flatten` port would therefore affect more than one immediate neighbor folder

That is another reason to document the pass as a structural root rather than a one-off cleanup.

## Latest measured movement and blocker

The 2026-07-15 internal sequence added a narrow output bridge for resultless synthetic catch-all `Try`, replaced bounded call-tree recognizers with recursive exclusive ownership, reused recognized suffix results, added exact terminal-table proof caching plus duplicate-router removal, then replaced the suffix-only full use-def snapshot with lightweight reachable ownership counts and batched exact detached-node tombstoning. Recursive and direct-subtract call probes moved from deferred to Flat, lowerable output; the existing branch-free try probe moved from Flat-but-unlowerable to valid encoded wasm, and the current unsigned-shift probe uses the same complete ownership route.

This clears the old blanket Starshine output-measurement blocker only for the synthetic catch-all subset. Nonthrowing-body proof removes dead handler scaffolding and keeps a block only for a live try-label channel. On the matched three-probe matrix, current Starshine is `212` bytes both direct and after cleanup, versus Binaryen's `275` direct and `236` cleanup bytes; the narrow bridge/control/local family remains a measured size win. Lightweight reachable counts preserve exact pre-mutation one-use ownership without allocating full use sites, and exact detached suffix vectors now tombstone with one HOT revision invalidation after region detachment. The representative pass-only median is `970.5 us`, still `3.65x` Binaryen's `266.05 us`; final phase medians are `53.5 us` classify, `67.5 us` state, `245.5 us` admission, `590.5 us` rewrite, and `5.5 us` result handling. Direct `i32.shl`, `i32.shr_s`, and `i32.shr_u` call roots share the complete recursive ownership proof, while `i32.rotl` remains the private boundary. Typed EH remains fail-closed rather than repaired. Public removed status, absent profile/four-lane matrix, structured control-plus-label deletion, broader behavior, and performance remain explicit blockers. See [`../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md`](../../../raw/binaryen/2026-07-15-flatten-version-130-nonthrowing-bridge-suffix-cache-impact.md).

The following two-code iteration attacks the newly measured admission and rewrite costs without widening behavior. `c6181e26d` indexes exact branch users once per label and derives label-used facts from the same immutable scan; `0a415161f` replaces one-for-one scalar and multivalue control-result tails in place rather than rebuilding all region siblings. One reconstructed same-session chain improved from `1,197.5 us` to `1,092.5 us` and then `1,030 us`; exact-shape code-2 samples were `1,033.5 us` and `1,047 us`, still around `3.9x` Binaryen.

The current two-code iteration continues that structural work. `13fe7b744` adds exact HOT region-suffix truncation and uses it to detach admitted terminal-table debris without rebuilding the holder span; its reconstructed candidate median improved from clean `1f1a2dfd0` at `1,116.5 us` to `1,053.5 us` (`5.64%`). `9acdac744` keeps scalar rewrite-time branch proof on the pre-mutation index for `br`, `br_if`, and `br_table`; its timing was noisy and slower, so the durable claim is failure-atomic proof reuse rather than a speed win. Current validation is focused region editing `4/4`, focused flatten `245/245`, private `147/147`, passes `5,722/5,722`, and full `9,183/9,183`.

The next two-code iteration extends the same boundary to multivalue routing. `9aa7499e9` removes the whole-live-node multivalue target scan by threading the exact pre-mutation label branch index through admission, recursive table support, and mutation-time routing; its target-heavy fixture improved `5,581.5 -> 5,099 us` (`8.64%`) in one same-session ordering. `710cdc910` resolves each admitted table target's typed local vector once after complete preflight and reuses it for every payload lane; repeated-resolution timings were noisy and are not classified as a win. Validation is focused flatten `245/245`, private `149/149`, passes `5,724/5,724`, and full `9,185/9,185`. The earlier `970.5 us` stable candidate checkpoint remains the best committed sample, still `3.65x` Binaryen and outside the `<=2x` gate.

The latest two-code iteration applies those proof rules to multivalue legacy tries and conditional ownership. `e39faf79e` makes legacy-try label support consume the immutable branch index. `e64428dc1` replaces full node-use/use-def construction in legacy-try and loop `br_if` flow proof with lightweight reachable counts and an explicit rewrite-only snapshot boundary. The targeted 120-function legacy-try fixture improves `16,524.5 -> 6,724.5 us` (`59.31%`), with focused flatten `245/245`, private `151/151`, passes `5,726/5,726`, and full `9,187/9,187`. The stable representative checkpoint remains `3.65x` Binaryen, so public readiness is unchanged.

The next two-code iteration removes the remaining full use-site allocation for exact multivalue region-tail tuples and the remaining full live-node branch scans in the inputful-loop support chain. `3d0acb44e` reuses the frozen reachable count when the exact tail root/slot is already known; `19fa4eda8` reuses the frozen per-label branch population and count snapshot for loop backedges and multivalue `br_if` flow during admission and rewrite. Targeted fixtures improve `36.91%` and `17.67%`; validation reaches focused `245/245`, private `153/153`, passes `5,728/5,728`, and full `9,189/9,189`. The representative fixture remains noisy and the stable result remains `3.65x` Binaryen, so public readiness is unchanged.

The current two-code iteration removes two more full use-site builds. `3a88b5bd6` proves exact tuple-made inputful-loop entry ownership from the frozen reachable count plus the known entry slots and reversed body-prefix drops. `5c0235d71` proves exact scalar legacy-try `br_if` payload/consumer ownership from the same snapshot. Targeted fixtures improve `58.64%` and `52.47%`; validation reaches focused `245/245`, private `155/155`, passes `5,730/5,730`, and full `9,191/9,191`. The stable representative remains `3.65x` Binaryen, so public readiness and public-removed status are unchanged.

The tuple ownership/site-allocation iteration uses `24ca31723` to prove tuple-made plain branch/table payload ownership from the frozen reachable count plus known branch slots. `32690a37d` replaces the final full node-use/use-site build with one admission-time reachable locator for generic tuple-made block/if `br_if`, caching exact positive or negative flow sites behind the rewrite boundary. Targeted fixtures improve `13,697 -> 5,238 us` (`61.76%`) and `12,764.5 -> 5,578.5 us` (`56.30%`).

The latest two-code iteration extends exact-site caching to ordinary flow. `ae096a883` caches distinct non-tuple multivalue block/if `br_if` parent/start results before mutation. `b87464d25` snapshots scalar false-flow parent populations and permits only same-parent slot shifts plus same-state chained replacements; new parents are never discovered after rewrite starts. Validation reaches focused `245/245`, private `159/159`, passes `5,734/5,734`, and full `9,195/9,195`. The distinct fixture moves `30 -> 28 ms`; scalar moves `22 -> 23 ms` and is correctness-only. The stable representative remains an unrequalified `970.5 us` / `3.65x` Binaryen, so public readiness and public-removed status are unchanged.

The latest two-code iteration reduces rewrite-state allocation breadth without changing behavior. `e165fde1c` sparsifies conditional-flow and chained-replacement proof; `476848f9d` sparsifies suffix, terminal-table, and scalar-try proof. Fifteen node-sized arrays become seven exact entry vectors, while the same pre-mutation identities and post-boundary failure rules remain mandatory. Validation reaches private `161/161`, focused `245/245`, passes `5,736/5,736`, and full `9,197/9,197`. Reconstructed timing does not establish public performance readiness, and no `.mbti`, registry, dispatcher, CLI, compare/API, generator, or preset surface changes.

The latest two-code iteration narrows recursive rewrite overhead and sequence bookkeeping without changing behavior. `7801166ac` recognizes that payload-bearing `br_if` and `br_table` return from dedicated rewrite arms, so generic postorder dispatch now calls only the carried plain-`br` router. `18101a947` uses the immutable reachable-count snapshot to retain holder/node identity only for roots with multiple pre-mutation owners; an explicit snapshot node limit rejects ids allocated during rewrite. The second slice's initial implementation exposed five focused out-of-range failures before that boundary was added.

A high-resolution native-release pass-only path was recovered in the existing long-performance package with temporary sources preserved under `.tmp`. The 1,200-function root-heavy fixture improved `57,498 -> 52,402 us` after code 1 (`8.86%`) and measured `52,534.5 us` after code 2. The reconstructed representative measured `1,177 -> 1,176 -> 1,171.5 us`, so shared-root sparsity is classified as allocation-footprint work rather than a timing win. Validation reaches private `163/163`, focused `245/245`, passes `5,738/5,738`, and full `9,199/9,199`. The original native gate harness is still unrecovered, the durable result remains `970.5 us` / `3.65x` Binaryen, and no `.mbti` or public surface changed.

The latest exact two-code iteration narrows table-local construction and freezes one more run-wide support decision without widening behavior. `81cfb9619` reuses the resolved target vector when all table labels deduplicate to one target, removing one staging local and one local-copy pair per lane while preserving payload-before-selector order; a focused encoded module shrinks `51 -> 47` bytes. Multi-target fanout remains Binaryen-shaped. `dda2bdfe3` caches exact inputful-loop support before mutation and refuses an absent rewrite-time entry. Its targeted native fixture is timing-flat (`2,589 -> 2,584 us`), and reconstructed representative samples overlap the `1,128.5 us` pre-iteration baseline.

Validation reaches private `165/165`, focused `245/245`, passes `5,740/5,740`, and full `9,201/9,201`. The pinned v130 owner hash is unchanged. No `.mbti`, registry, dispatcher, CLI, compare/API, generator, or preset surface changes. The durable `970.5 us` / `3.65x` gate and all typed-EH, structured-label, broader-parity, aggregate, signoff, neighborhood, and public-readiness blockers remain open.

The latest exact two-code iteration removes two more run-wide scan costs without widening behavior. `6a74918d6` appends branch users to the immutable per-label index in constant time by exploiting monotonic HOT node order; repeated labels from one table remain deduplicated, and later branch nodes remain ordered. `1acb9bc14` records loop, legacy-try, and payload-bearing branch candidate rosters in that same scan and reuses them for deferred-family admission.

Validation reaches private `167/167`, focused `245/245`, passes `5,742/5,742`, and full `9,203/9,203`. The branch-dense benchmark improves `13.72%`, the root-heavy benchmark improves `6.45%` with a faster rerun, and the representative reconstruction moves directionally `1,111.5 -> 1,066 us`. These are measured internal scan reductions, not a requalification of the lost gate harness. No `.mbti`, registry, dispatcher, CLI, compare/API, generator, preset, or semantic family changes; the durable `970.5 us` / `3.65x` gate and every public-readiness blocker remain open.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- public registry, dispatcher, CLI execution, or compare-harness admission for `flatten`
- close mismatched/shared multivalue `br_if`, broader mixed/nonexclusive multivalue `br_table`, legacy-EH repair/transfer, and unsupported-family behavior
- a pass-specific GenValid profile or four-lane direct closeout
- aggressive preset scheduling or neighborhood proof

So the current repo status is best summarized as:

- name tracked
- CLI spelling tracked
- batch intent tracked
- internal transform active-partial
- remaining correctness and signoff slices tracked

## Validation plan for the eventual port

The detailed validation ladder now lives in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

The short version is:

1. prove a no-rewrite Flat IR classifier first;
2. land simple spill, function-body return wrapping, and value-carrying `block` / `if` rewrites before broader families;
3. add `local.tee`, `br`, `br_if`, and `br_table` payload channels with explicit two-temp `br_if` mismatch coverage;
4. gate parity on legacy `try` / EH pop repair and an explicit `BrOn*` / `TryTable` policy;
5. only then run downstream cluster lanes such as `flatten -> simplify-locals-notee-nostructure -> local-cse`, `flatten -> rereloop`, and `flatten -> i64-to-i32-lowering`.

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the real downstream contracts already documented in this repo.

## Bottom line

Current Starshine `flatten` strategy is honest registry tracking plus batch planning:

- the upstream spelling is intentionally preserved in `src/passes/optimize.mbt`
- the public `--flatten` spelling is intentionally preserved in `src/cli/cli_test.mbt`
- the IR2 execution-plan docs still place the pass at the front of the next removed-pass batch
- the active `[O4Z-FLAT]001` backlog records the remaining correctness, public wiring, comparison, timing, and neighborhood gates
- the surrounding living dossiers already define the practical landing zone for a future port because they explain which later passes depend on the flattened world

So the right mental model today is not “nothing exists locally.”
It is:

- **first internal transform slices landed**
- **clear tracked public-removed status**
- **clear public spelling**
- **clear future cluster**
- **clear active backlog for the remaining implementation and signoff work**
