---
kind: concept
status: supported
last_reviewed: 2026-07-14
sources:
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-conditional-branch-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-loop-break-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-if-table-refresh.md
  - ../../../raw/binaryen/2026-07-13-flatten-version-130-mixed-loop-block-table-refresh.md
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
`src/passes/flatten.mbt` owns a Flat IR classifier plus scalar body-result materialization, reachable/unreachable tee lowering across function roots, structured-region roots, and ordinary operand positions, ordered scalar operand preludes, branch-free defaultable scalar `block`/`if` result routing, branch-free defaultable independently produced multivalue `block`/`if`, one exact exclusive tuple-made multivalue block tail, if-arm tail, plain block/if-targeting `br` payload, repeated-target `br_table` payload, or exact block/if-targeting `br_if` flow, and zero-input `loop` result routing across payloadless backedges through exclusive consumer spans, branch-targeted independently scalar multivalue `if` arms with plain exits, scalar and exact independently scalar or tuple-made multivalue legacy `try` do/catch routing with plain carried try-label `br` exits and exact scalar try-label `br_if` direct-drop/unary/conversion/same-typed-binary false flow in either operand position and exact multivalue direct-drop, unary/conversion, or independently scalar / exclusively tuple-made same-typed-binary false flow plus exact scalar try-label `br_table` fanout through either a strict direct-enclosure block chain of any proven length or zero or more such blocks followed by one or more directly enclosing matching value `if`s, with all ifs outermost and no hardcoded count cap, and independently scalar multivalue fanout through the same blocks-before-ifs strict direct-enclosure roster without a hardcoded control-count cap, with exclusively tuple-made fanout admitted through the same unbounded strict direct-enclosure block chain, or any strict directly enclosing matching block chain (including zero blocks) followed by one, two, three, four, five, six, or seven directly enclosing matching value `if`s, or exactly eight directly enclosing matching value `if`s preceded by zero or one directly enclosing matching block, or one repeated try target behind an explicit catch-payload/exceptional-transfer prerequisite classifier, defaultable scalar branch-targeted `if` routing, zero-input and independently scalar or one exact tuple-made-entry inputful scalar-result `loop` routing with payloadless or independently scalar one- and multi-parameter `br`/`br_if` backedges, and plain scalar or independently scalar multivalue block-targeting `br`, including mixed fallthrough plus nested plain exits, scalar `br_if` routing through typed temps, same-vector multivalue block/if-targeting `br_if` routing across exact exclusive false-path spans, plus independently scalar `br_table` rich-origin and unique-target fanout for defaultable scalar block/if targets, exact repeated-label and nested multi-block multivalue targets, one- or multi-parameter loop entry channels, exact inputful multivalue loop plain branches and `br_if` channels with immediate direct-drop, same-typed binary with a simple right operand, unary, or conversion false flow from independently scalar or tuple-made payloads, one exact exclusive tuple-made loop result tail, per-arm independently scalar or exact separately owned tuple-made legacy-try tails with supported scalar component origins, and exact loop-plus-enclosing-block, loop-plus-repeated-if, and loop-plus-repeated-block table channels, with focused coverage in `src/passes/flatten_test.mbt`. Same-type `br_if` preserves the not-taken flow through one shared `local.get`; the target/flow-type mismatch uses a second flow temp and one target copy; rich ordinary scalar payloads are evaluated once before the condition and shared across chained false-path uses; `br_table` evaluates rich ordinary payloads once before its selector, copies to deduplicated target temps, and removes the dead terminal origin. Nested terminal `br`/`br_table`/`return`/`return_call`/`return_call_indirect`/`return_call_ref`/`throw`/`throw_ref` operands now become owner-region effects plus `unreachable` placeholders, with child payload/argument work preserved before the terminal, later sibling work preserved afterwards, already-rooted effects deduplicated, and unsupported root value-controls not scalar-materialized. Branch-free multivalue blocks and ifs plus zero-input multivalue loops with payloadless backedges and independently scalar defaultable tails now write a typed label-local vector, erase the control result, and replace one exclusive repeated HOT consumer span with ordered local reads. Branch-free scalar legacy tries now write exact do/catch tails into one shared typed local. Branch-free multivalue legacy tries write per-arm exact independently scalar tails or separately owned exact tuple-made tails with supported scalar component origins into one shared typed vector when one exclusive repeated consumer or region-tail span owns the results. `flatten_eh_repair_requirement(...)` separates missing typed catch-payload tracking from exceptional-transfer repair before mutation. Functions with legacy `Catch`/`CatchAll`, `rethrow`, or `delegate` nodes remain whole-function fail-closed until Binaryen-equivalent payload representation and nested-pop repair land. Same-vector multivalue `br_if` now writes independently scalar payloads once into the shared target vector, replaces one contiguous exclusive false-path tail with matching reads, and preserves the condition. Exact multivalue `br_table` writes each independently scalar component once before selector work, deduplicates repeated labels, and copies the vector once into every admitted nested block target. Inner target results may feed an enclosing target only through one exclusive ordered repeated-control region tail. Exact inputful multivalue loops may share table fanout with an enclosing block when fallthrough tails are independently scalar, or with one repeated exclusive block/if-result tail; staged payload, loop-entry, nested-control-result, enclosing-target, and loop-result vectors stay distinct. Broader mixed-control fanout plus nested or nonexclusive conditional multivalue loop control remain gated. Remaining richer tuple-made loop conditional consumers and mixed table loop backedges, mismatched or ambiguously shared multivalue conditionals, broader multivalue table payloads, broader inputful or backedge multivalue loop results, branch-targeted multivalue loop controls, and broader legacy-try/EH shapes remain open behind conservative gates. Branch-targeted ifs now share one temp across fallthrough arms and carried `br`/`br_if` flow after preflighting every label use; nondefaultable branch payloads remain whole-function fail-closed. Inputful loops capture each independently scalar defaultable entry once in order, redirect body uses through typed locals, and clear the parameter prefix. Scalar results route separately; admitted plain-branch, exact immediate direct-drop, scalar-binary, unary, or conversion false-flow conditional, and table-backed multivalue-result families use a separate ordered result vector. Payloadless zero-input and independently scalar defaultable one- or multi-parameter `br`/`br_if` backedges now reuse typed entry locals while preserving payload order, one evaluation, and conditional false-path flow; one- or multi-parameter loop tables stage payload vectors once and copy them into entry locals. Exact inputful multivalue loop-plus-block fanout also routes independently scalar or one exact exclusive tuple-made fallthrough result tail through distinct locals, while nondefaultable and multivalue single-producer table backedges fail closed. The registry and dispatcher intentionally remain public-removed until broader families are safe.

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
