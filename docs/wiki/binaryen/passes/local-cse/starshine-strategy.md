---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md
  - ../../../raw/research/0453-2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/research/0495-2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/research/0533-2026-05-06-local-cse-direct-revalidation.md
  - ../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md
  - ../../../raw/research/0464-2026-05-05-local-cse-port-readiness-and-validation.md
  - ../../../raw/research/0491-2026-05-05-local-cse-starshine-active-direct-pass-correction.md
  - ../../../raw/binaryen/2026-04-25-local-cse-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/local_cse.mbt
  - ../../../../../src/passes/local_cse_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../flatten/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
  - ../reorder-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./basic-block-windows-and-barriers.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../flatten/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
  - ../reorder-locals/index.md
---

# Starshine Strategy For `local-cse`

Use this page together with the tagged raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md), the 2026-05-05 current-main recheck in [`../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md), the 2026-05-06 line-anchor refresh in [`../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md`](../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md), the 2026-06-04 `version_130` / current-main refresh in [`../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md`](../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md), the 2026-06-04 audit note in [`../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md`](../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md), the source/test map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md), and the implementation-readiness bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that track the pass, and the concrete neighboring implementation areas future preset-slot work will need.

## The honest current status

`local-cse` is now implemented in Starshine with a dedicated owner file, tests, registry entry, dispatcher route, fuzz-harness support, and direct debug-artifact self-optimize evidence.

The 2026-05-06 refreshed direct-pass lane is green: `.tmp/pass-fuzz-local-cse` reported 6759/10000 compared cases, 6759 normalized matches, 0 mismatches, and 20 known Binaryen empty-recursion-group command failures. The 2026-06-04 O4z audit lane stayed semantically green on generated inputs (`998` normalized matches, `0` mismatches, and `2` known Binaryen empty-recursion-group command failures) and sampled Starshine pass-local time on `tests/node/dist/starshine-debug-wasi.wasm` at about `63-67 ms` versus Binaryen's `109-110 ms` debug pass time.

The 2026-06-04 audit found direct adjacent-window parity gaps and coverage-positive state/effect cases: Binaryen can reuse a repeated tree computed before an `if` inside the `then` arm, before a straight-line block inside that block body, before a `try_table` inside the try body, across `return_call` / `return_call_indirect` / `return_call_ref` / `throw_ref` into unreachable continuation code, across `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` into fallthrough continuation code, and across `struct.set` / `array.set` / `array.fill` / `array.copy` / `array.init_data` / `array.init_elem` / `memory.copy` / `memory.fill` / `memory.init` / `memory.grow` / `memory.size` / `table.get` / `table.copy` / `table.fill` / `table.init` / `table.set` / `table.grow` / `table.size` / `global.set` / `data.drop` / `elem.drop` for local-only repeated expressions. Starshine now covers and implements those narrow raw/module positives while preserving after-`if`, else-arm, loop, `br`, `br_table`, plain return, plain throw, top-level `unreachable`, and `try_table` body hard-terminator boundary negatives.

The active local strategy is still deliberately slot-honest:

- keep the upstream pass spelling active in the registry surface
- schedule the proven late `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` cleanup neighborhood in public `optimize` / `shrink`
- keep the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood gated until `flatten` lands
- grow the implementation from same-window temp-localizing reuse without recasting it as a whole-function GVN pass
- keep `ref.as_non_null`, reference conversions, and descriptor reads grouped with `ref.test`, `ref.cast`, descriptor, and other reference/nullability reasoning as documented conservative deferrals unless a separate safe root model is approved
- keep `i31.get_s` / `i31.get_u` as narrow scalar accessor roots while leaving `ref.i31` root CSE deferred until non-null temp-local materialization has a safe typed story
- keep repeated `struct.get` / `array.get` roots, including packed signed/unsigned accessors, as a documented heap-read deferral, not a shortcut into heap GVN
- keep linear atomic operations and packed shared-GC atomic accessors grouped with shared-GC atomics as documented conservative boundaries rather than adding atomic or memory GVN
- keep SIMD load, load-splat/load-zero, load-extend, lane-load, and store/lane-store local-only roots grouped with the existing SIMD pure-root deferral unless a separate vector load/store memory-state model is approved
- keep `string.const` roots unmaterialized unless a separate string/reference temp-local safety story is approved
- keep the before-`if` / then-arm, before-block / straight-line block, before-`try_table` / try-body, `return_call` / `return_call_indirect` / `return_call_ref` / `throw_ref` unreachable-continuation positives, `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` fallthrough-continuation positives, `struct.set` / `array.set` / `array.fill` / `array.copy` / `array.init_data` / `array.init_elem` / `memory.copy` / `memory.fill` / `memory.init` / `memory.grow` / `memory.size` / `table.get` / `table.copy` / `table.fill` / `table.init` / `table.set` / `table.grow` / `table.size` / `global.set` / `data.drop` / `elem.drop` local-only reuse positives, try-body hard-terminator negative, annotated idempotent direct-call positive, and ordinary direct-call plus `call_indirect` and `call_ref` root negative coverage green while hardening the remaining control-boundary and GC/generative-root surfaces one focused slice at a time

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active pass implementation and tests
  - `src/passes/local_cse.mbt:1-18,543-559,809-816`
  - `src/passes/local_cse_test.mbt`
    - covers registry, same-window arithmetic, parent-over-child, load/store and local-write barriers, before-`if` / then-arm reuse, before-block / straight-line block reuse, before-`try_table` / try-body reuse, `return_call` / `return_call_indirect` / `return_call_ref` / `throw_ref` unreachable-continuation reuse, `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` fallthrough-continuation reuse, `struct.set` / `array.set` / `array.fill` / `array.copy` local-only reuse, try-body hard-terminator clearing, annotated idempotent direct-call reuse, ordinary direct-call, `call_indirect`, and `call_ref` root no-ops, after-`if` and else-arm negatives, before-loop into loop-body, `br`/`br_table`, return-boundary, unreachable-boundary, tiny-root `global.get` no-op, and repeated `struct.new` / `struct.new_default` / descriptor `struct.new_desc` / `struct.new_default_desc` / core `array.new` / `array.new_default` / `array.new_fixed` / `array.new_data` / `array.new_elem` generative-root coverage, `string.const` no-op coverage, `ref.as_non_null` nullability-root and reference-conversion deferral coverage, and i31 coverage split between `i31.get_s` / `i31.get_u` reuse and `ref.i31` non-null-temp deferral, plus struct/array heap-read and packed heap-read root deferral coverage, and descriptor allocation root deferral coverage, linear atomic boundary coverage, SIMD load-root boundary coverage, and SIMD lane-load-root boundary coverage
- active registry and dispatcher surface
  - `src/passes/optimize.mbt:253,437-449,456-472`
    - `local-cse` is registered as an active module pass and scheduled in the proven late local-cleanup preset neighborhood
  - `src/passes/pass_manager.mbt:8939-8943`
    - routes `local-cse` through `local_cse_run_module_pass(...)`
  - `src/passes/optimize_test.mbt:510-512,520-527,567-568`
    - keeps `local-cse` in the active module-pass category, locks the late preset order, and keeps the aggressive neighborhood gated
- completed backlog and release note
  - `agent-todo.md`
    - the LCSE implementation slice has been pruned
  - `CHANGELOG.md`
    - records the 2026-05-05 `local-cse` landing
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33`
    - the late-cluster slot where `local-cse` belongs after `coalesce-locals` and before full `simplify-locals`
- exact neighboring local implementation files already worth reading
  - `src/passes/simplify_locals.mbt:70`, `src/passes/simplify_locals.mbt:176`, `src/passes/simplify_locals.mbt:4132`
    - sinkable-local state, sinkable/effect conflict checks, and the active full `simplify-locals` entry point
  - `src/passes/reorder_locals.mbt:118`, `src/passes/reorder_locals.mbt:183`, `src/passes/reorder_locals.mbt:544`
    - local-use scanning, in-place local-index rewriting, and module-pass entry logic
- exact current regression and replay surfaces worth following
  - `src/cmd/cmd_wbtest.mbt:7564-7619`
    - `test "run_cmd_with_adapter print-func sees simplify-locals remove debug artifact Func 71 const fanout webs"`
    - the `--dead-code-elimination --vacuum --optimize-instructions --simplify-locals` artifact replay lane
- exact neighboring living dossiers that define the future slot and local landing zone
  - [`../flatten/index.md`](../flatten/index.md)
  - [`../simplify-locals-notee-nostructure/index.md`](../simplify-locals-notee-nostructure/index.md)
  - [`../coalesce-locals/index.md`](../coalesce-locals/index.md)
  - [`../simplify-locals/index.md`](../simplify-locals/index.md)
  - [`../reorder-locals/index.md`](../reorder-locals/index.md)

That code-and-doc map is the main practical addition in this dossier: readers can now jump directly from the upstream algorithm to the exact local status, proof-surface map, and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `local-cse` is active but deliberately scoped.

### 1. The name is active, not merely tracked

`src/passes/optimize.mbt` registers the upstream spelling `local-cse` as an active module pass, and `src/passes/pass_manager.mbt` dispatches it through `local_cse_run_module_pass(...)`.
That means:

- direct `--local-cse` requests execute instead of rejecting as removed
- the pass participates in public presets through the proven late local-cleanup neighborhood
- the completed LCSE backlog slice has moved to `CHANGELOG.md`

### 2. The landed work is a direct parity slice

The implementation covers same-window temp-localizing reuse for repeated local arithmetic trees, preserves barrier resets for local writes and non-idempotent calls in the raw path, and is protected by direct pass tests plus fuzz/self-optimize evidence. It also implements Binaryen's adjacent before-`if` into `then`, before-block into straight-line block, before-`try_table` into try-body and try-body hard-terminator clearing, `return_call` / `return_call_indirect` / `return_call_ref` / `throw_ref` unreachable-continuation reuse, `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` fallthrough-continuation reuse, `struct.set` / `array.set` / `array.fill` / `array.copy` local-only reuse, and annotated idempotent direct-call reuse windows while keeping ordinary direct-call, `call_indirect`, and `call_ref` roots unmaterialized.
The docs should keep that slice connected to the exact Binaryen contract:

- repeated **whole-tree** reuse, not arbitrary subtree extraction
- limited linear windows, not whole-function GVN
- temp-local materialization, not silent value merging
- explicit slot dependence on neighboring passes

### 3. The scheduler slot is already documented, and the missing neighbors matter

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already places `local-cse` in the ordinary late local-cleanup cluster.
The upstream source also places it in the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` prelude.

That matters because `local-cse` is not meant to run in isolation.
Upstream Binaryen expects other passes to expose the right shapes first:

- `flatten` turns nested near-miss trees into local-fed whole-tree candidates
- `simplify-locals-notee-nostructure` removes some flatten-introduced noise before the early aggressive `local-cse` run
- `coalesce-locals` simplifies later local traffic before the ordinary late run
- full `simplify-locals` cleans up the temp-local traffic `local-cse` leaves behind

Current Starshine has the direct `local-cse` transform, the late consumer (`simplify-locals`), and enough late-neighbor proof to schedule `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` in public presets. The aggressive early `flatten -> simplify-locals-notee-nostructure -> local-cse` slot remains gated because `flatten` is still unavailable.

## The right future Starshine implementation shape

The current implementation should continue to be taught as a **late local-tree reuse pass with temp locals**, not as an isolated generic optimizer.

Why:

- Binaryen runs it in deliberate neighbor clusters, not alone
- the upstream pass is centered on whole-tree equality plus small linear windows
- Starshine already has nearby local-traffic and effect-conflict machinery in `simplify-locals`
- Starshine already has a module-side local-index rewrite pass in `reorder-locals`
- the missing early and late neighbors explain why exact slot parity remains blocked today

So the local strategy should be thought of as:

1. identify a HOT-level representation of the real upstream families
   - repeated arithmetic and load trees
   - local-fed whole-tree repeats after cleanup
   - controlled temp-local insertion points for originals and repeats
2. preserve the same conservative boundaries locally
   - whole-tree-only matching
   - first-occurrence originals
   - parent-over-child request cancellation
   - linear-window resets around non-linear control
   - effect and generativity invalidation
   - profitability thresholds
3. compose it with the surrounding local cleanup ecosystem
   - early `flatten -> simplify-locals-notee-nostructure -> local-cse` once those neighbors exist
   - ordinary `coalesce-locals -> local-cse -> simplify-locals`
   - local-index and CLI proof surfaces already maintained in-tree

In other words, the direct pass should keep growing inside a cleanup ecosystem that partly exists already.

## The most important local dependency map

### Upstream `local-cse` depends on early shape exposure

See [`../flatten/index.md`](../flatten/index.md) and [`../simplify-locals-notee-nostructure/index.md`](../simplify-locals-notee-nostructure/index.md).

Why it matters locally:

- Binaryen's aggressive slot is not just `flatten -> local-cse`
- the small `simplify-locals-notee-nostructure` cleanup in between is part of the real contract because flatten introduces local traffic that would otherwise obscure repeated whole trees

A future Starshine port should preserve that lesson instead of treating flatten as optional decoration.

### The ordinary late run depends on prior local-slot cleanup

See [`../coalesce-locals/index.md`](../coalesce-locals/index.md).

Why:

- Binaryen runs `local-cse` after `coalesce-locals`
- simpler local-slot usage can make repeated local-fed trees easier to recognize and cheaper to materialize

So a future Starshine implementation should treat `coalesce-locals` as a real feeder, not an unrelated neighbor.

### Existing Starshine `simplify-locals` code is the nearest landed local reasoning surface

See [`../simplify-locals/index.md`](../simplify-locals/index.md), `src/passes/simplify_locals.mbt`, and `src/passes/pass_manager_wbtest.mbt`.

Why:

- `simplify_locals_new_sinkables(...)` and `simplify_locals_sinkables_may_conflict(...)` already encode a real local effect/conflict story in HOT form
- the current raw simplify-locals tests already exercise local traffic, overwrite barriers, and condition-boundary cases that are close to the kinds of safety questions a future `local-cse` port will face
- full `simplify-locals` is also the immediate cleanup consumer after the ordinary late `local-cse` slot

So the current local implementation map for `local-cse` continues to include these neighboring cleanup files alongside the dedicated owner file.

### Existing Starshine `reorder-locals` code is the nearest landed local-index rewrite surface

See [`../reorder-locals/index.md`](../reorder-locals/index.md) and `src/passes/reorder_locals.mbt`.

Why:

- a future `local-cse` port will have to materialize temp locals honestly
- Starshine already has a module pass that scans local users and rewrites local indices in one canonical place
- `rl_scan_instruction(...)`, `rl_rewrite_instrs_in_place(...)`, and `reorder_locals_run_module_pass(...)` give future contributors an in-repo model for local-index rewrites and local metadata stability work

That does not make `reorder-locals` an implementation of `local-cse`, but it does make it an important local read-along file.

## What Starshine still does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- exact public preset parity for the upstream `flatten -> simplify-locals-notee-nostructure -> local-cse` neighborhood
- exact public preset parity for the upstream `coalesce-locals -> local-cse -> simplify-locals` neighborhood
- a locally representable version of every prerequisite neighboring slot needed to make those ordered claims oracle-proven end to end

So the current repo status is best summarized as:

- direct `local-cse` transform landed
- direct tests and registry/dispatcher wiring landed
- backlog tracked and pruned
- scheduler slot documented
- neighboring local cleanup and rewrite files already exist
- public preset scheduling for the exact upstream neighborhoods remains gated

## Validation plan for the ordered-neighborhood claim

The direct pass already exists, so the remaining validation ladder is about exact upstream neighborhood parity.

1. Keep the landed direct tests green
   - same-block repeated arithmetic trees
   - repeated load positives
   - parent-over-child cancellation cases
   - before-`if` / then-arm reuse plus after-`if` and else-arm negatives
   - before-`try_table` / try-body, before-block / straight-line block, `return_call` / `return_call_indirect` / `return_call_ref` / `throw_ref` unreachable-continuation positives, the `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` fallthrough-continuation positives, and the `struct.set` / `array.set` / `array.fill` / `array.copy` / `array.init_data` / `array.init_elem` / `memory.copy` / `memory.fill` / `memory.init` / `memory.grow` / `memory.size` / `table.get` / `table.copy` / `table.fill` / `table.init` / `table.set` / `table.grow` / `table.size` / `global.set` / `data.drop` / `elem.drop` local-only reuse positives
   - before-loop into loop-body, `br`/`br_table`, return-boundary, throw-boundary, top-level unreachable-boundary, and try-body hard-terminator negatives
   - local-write invalidation
   - tiny-root profitability no-op cases
   - repeated `struct.new` generative-root negative
   - add remaining hard control-boundary negatives and additional GC/generative-root negatives only as focused source-backed slices; repeated `call_indirect` and `call_ref` roots already have direct no-reuse coverage
2. Keep the registry and CLI proof honest
   - `local-cse` stays an active module pass
   - explicit `--local-cse` execution keeps working
   - the surrounding aggressive neighborhood gate stays false while the prerequisite neighbors are incomplete
3. Keep pass-targeted parity and replay evidence green
   - `wasm-opt --local-cse` compare-pass replay
   - direct artifact replay on the no-DWARF lane
4. Only then claim exact ordered-neighborhood parity
   - `flatten -> simplify-locals-notee-nostructure -> local-cse`
   - `coalesce-locals -> local-cse -> simplify-locals`

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact surrounding code surfaces.

## Bottom line

Current Starshine `local-cse` strategy is an active direct pass plus a guarded neighborhood/preset parity bridge:

- the upstream spelling is intentionally preserved in `src/passes/optimize.mbt`
- the direct implementation, tests, and dispatcher wiring are already landed
- the backlog already treats the remaining ordered-neighborhood work as the real parity slice under `LCSE`
- the canonical early and late slots are already documented in the no-DWARF optimizer notes
- the surrounding implementation files already exist and define the practical landing zone for future neighborhood work, especially `simplify_locals.mbt`, `reorder_locals.mbt`, `pass_manager_wbtest.mbt`, and `cmd_wbtest.mbt`
- the docs now keep two important honesty rules explicit: no exact preset-slot claim should be made before the missing upstream-neighbor equivalents land locally, and no direct window-model parity claim should be made until the before-`if` / then-arm gap is covered test-first

So the right mental model today is not “nothing exists locally.”
It is:

- **direct transform landed**
- **direct status clear**
- **exact preset claim still gated**
- **neighbor map clear**
- **parity proof still pending for the ordered slots**
