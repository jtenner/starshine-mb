---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md
  - ../../../raw/research/0453-2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/research/0495-2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md
  - ../../../raw/binaryen/2026-04-25-local-cse-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../../raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md
  - ../../../raw/research/0464-2026-05-05-local-cse-port-readiness-and-validation.md
  - ../../../raw/research/0491-2026-05-05-local-cse-starshine-active-direct-pass-correction.md
  - ../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/local_cse.mbt
  - ../../../../../src/passes/local_cse_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/reorder_locals.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./basic-block-windows-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../flatten/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
---

# `local-cse` Implementation Structure And Tests

This page maps the Binaryen files and tests that define `local-cse`, then maps them to the exact current Starshine status. It is a read-along companion to the strategy and shape pages, not a second algorithm narrative.

## Source rule

Use Binaryen `version_129` as the tagged oracle and [`../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md) plus [`../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md`](../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md) as the latest freshness bridges. The 2026-05-05 recheck found no teaching-relevant current-`main` drift on the checked owner, scheduler, helper, and dedicated-test surfaces, and the 2026-05-06 note only refreshed local line anchors.

Primary upstream sources:

- `src/passes/LocalCSE.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalCSE.cpp>
- `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/ir/linear-execution.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- `src/ir/effects.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `src/ir/properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `src/ir/properties.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.cpp>
- `src/ir/intrinsics.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
- `src/ir/cost.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
- `test/lit/passes/local-cse.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-cse.wast>

## Upstream owner-file map

| File | What to read it for | Contract it proves |
| --- | --- | --- |
| `src/passes/LocalCSE.cpp` | Main pass implementation | Function-parallel pass declaration, candidate whole-tree hashing, exact equality checks, relevance/possibility filters, `Scanner` request collection, `Checker` invalidation, `Applier` temp-local materialization, and final rewrite mechanics. |
| `src/ir/linear-execution.h` | Window traversal helper | `local-cse` is window-local, not CFG-wide; adjacent-block connection explains the before-`if` / then-arm positive family without turning the pass into generic dominance-based CSE. |
| `src/ir/effects.h` | Effect invalidation semantics | Intervening writes/calls can kill an original, while trap differences are ignored for validation because the kept original still executes first. |
| `src/ir/properties.{h,cpp}` | Shallow generativity checks | Fresh-producing roots such as ordinary calls, `call_indirect`, `call_ref`, `struct.new`, `array.new*`, and continuation creation are rejected as reusable roots. |
| `src/ir/intrinsics.h` | Idempotent-call annotation helper | The narrow direct-call exception depends on callee annotations, not on arbitrary call-site guesses. |
| `src/ir/cost.h` | Profitability model | The pass skips tiny roots in speed mode and is stricter under shrink mode, which explains no-op shapes like repeated `global.get`. |
| `src/passes/pass.cpp` | Public registration and scheduler slots | Binaryen exposes `local-cse`, runs it in the ordinary late local-cleanup cluster, and adds the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` slot at high optimization levels. |
| `src/passes/opt-utils.h` | Nested optimizer reruns | `local-cse` can reappear through default function-optimization reruns after inlining-oriented transformations. |
| `test/lit/passes/local-cse.wast` | Concrete behavior examples | The dedicated lit file proves the most visible positive and negative families: arithmetic and load repeats, after-`if` and local-write barriers, nested-call negatives, switch-child ordering, and small-root no-ops. |

## `LocalCSE.cpp` read path

Read the owner file in this order:

1. Pass declaration.
   - Establishes function-parallel status and DWARF invalidation.
2. `HashedExpression`, `HEComparer`, and expression hashing/equality helpers.
   - Shows that matching is whole-tree equality with cached hash buckets, not arbitrary subtree extraction or textual matching.
3. Relevance and possibility filters.
   - Explains concrete-result gating, skipped local/constant roots, size/cost thresholds, shallow side-effect rejection, shallow generativity rejection, and idempotent-call handling.
4. `Scanner`.
   - Records first-occurrence originals, later repeat requests, current linear window state, and parent-over-child request cancellation.
5. `Checker`.
   - Rewalks the same windows, tracks active originals, compares effects, ignores trap differences for repeated roots, and deletes invalidated requests.
6. `Applier`.
   - Adds fresh temp locals, wraps originals in `local.tee`, replaces surviving repeats with `local.get`, and clears temp-local state across nonlinear windows.

The non-obvious teaching point is that the pass is deliberately three-stage. A future port that merges scan and rewrite too early can easily lose parent-over-child preference or fail to restore child opportunities after impossible effectful parents are rejected.

## Dedicated test-surface map

`test/lit/passes/local-cse.wast` is the main upstream behavior oracle for this dossier.

The important fixture families are:

- **Whole-tree arithmetic positives**: repeated nontrivial arithmetic roots become one original plus later `local.get`s.
- **Repeated-load positives**: loads may trap, but replacing later repeats preserves the first-trap behavior.
- **Control-window cases**: code before an `if` can feed the `then` arm through the helper's adjacent-window model, while code after the `if` is not treated as the same simple window.
- **Local-write barriers**: a `local.set` to a depended-on local invalidates the earlier original.
- **Nested-call negatives**: effectful or generative nested children keep larger parents from becoming candidates.
- **Switch-child ordering**: `br_table` / switch children must preserve operand order when one repeated child is replaced.
- **Tiny-root no-ops**: small expressions such as `global.get` remain unchanged mostly for profitability reasons.

Evidence caveat: the original source review did not identify dedicated standalone upstream lit fixtures that isolate idempotent-call positives or every GC-generative allocation negative. Starshine now carries local direct fixtures for the idempotent direct-call positive, the `call_indirect` and core-built `call_ref` repeated-root negatives, `struct.new` / `struct.new_default` generative negatives, and core-built `array.new` / `array.new_default` / `array.new_fixed` negatives for the WAT parser gap.

## Scheduler and rerun map

`pass.cpp` and `opt-utils.h` prove that `local-cse` is a cluster pass, not an isolated cleanup:

1. Aggressive prelude:
   - `flatten -> simplify-locals-notee-nostructure -> local-cse`
   - The middle locals-family pass removes some flatten-introduced noise before `local-cse` looks for repeated whole trees.
2. Ordinary late local-cleanup cluster:
   - `coalesce-locals -> local-cse -> simplify-locals`
   - Coalescing can expose clearer repeated local-fed trees; full simplify-locals then cleans up introduced temp-local traffic.
3. Nested cleanup reruns:
   - inlining-oriented helpers can rerun the default function optimization stack, so a faithful port should be stable when called repeatedly.

## Current Starshine file map

Starshine now implements `local-cse`. The relevant local files are implementation, scheduler, or prerequisite surfaces:

| Local file | Exact role today |
| --- | --- |
| `src/passes/local_cse.mbt` | Active Starshine owner file for direct `local-cse` execution, including the summary, descriptor, raw/module rewrite pipeline, nested adjacent-window support for straight-line block / `try_table` bodies, callee annotation lookup for the narrow idempotent direct-call exception, `return_call`, `return_call_indirect`, `return_call_ref`, and `throw_ref` operand modeling plus `br_on_null` fallthrough stack passthrough, `br_on_non_null` operand modeling, `br_on_cast` / `br_on_cast_fail` fallthrough stack modeling for Binaryen's continuation reuse shapes, `struct.set` / `array.set` / `array.fill` / `array.copy` / `array.init_data` / `array.init_elem` operand modeling for local-only reuse across GC writes, `memory.copy` / `memory.fill` / `memory.init`, `table.copy` / `table.fill` / `table.init` / `table.set`, and `global.set` operand modeling, side-effecting `table.grow` and `table.size` stack-result modeling without table-root reuse, and zero-operand `data.drop` / `elem.drop` side-effect modeling for local-only reuse across linear-memory/table/global/segment effects, module-pass entry, and main HotPass rewrite pipeline. |
| `src/passes/local_cse_test.mbt` | Direct registry and behavior tests for repeated trees, parent-over-child cancellation, load barriers, tiny-root `global.get` no-ops, `struct.new`, `struct.new_default`, and core `array.new` / `array.new_default` / `array.new_fixed` / `array.new_data` / `array.new_elem` generative-root no-ops, annotated idempotent direct-call reuse plus ordinary direct-call, `call_indirect`, and `call_ref` root no-ops, `return_call`, `return_call_indirect`, `return_call_ref`, and `throw_ref` unreachable-continuation reuse, `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` fallthrough-continuation reuse, `struct.set` / `array.set` / `array.fill` / `array.copy` / `array.init_data` / `array.init_elem` / `memory.copy` / `memory.fill` / `memory.init` / `table.copy` / `table.fill` / `table.init` / `table.set` / `table.grow` / `table.size` / `global.set` / `data.drop` / `elem.drop` local-only reuse, local-write window resets, Binaryen's before-`if` into `then`, before-block into straight-line block, and before-`try_table` into try-body positives, paired after-`if` / else-arm negatives, and before-loop into loop-body plus `br` / `br_table` / `return` / `throw` / top-level `unreachable` and `try_table` body unreachable boundary negatives. |
| `src/passes/optimize.mbt:253,437-449,456-472` | Registers `local-cse` as an active module pass and keeps the aggressive neighborhood gate closed. |
| `src/passes/pass_manager.mbt:8939-8943` | Module-pass dispatch routes `local-cse` to `local_cse_run_module_pass(...)`. |
| `src/passes/optimize_test.mbt:510-512,520-527,567-568` | Confirms `local-cse` stays in the active module-pass category on the regression surface, keeps the proven late preset order, and preserves the trace neighborhood proof. |
| `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33` | Canonical no-DWARF path records the late `coalesce-locals -> local-cse -> simplify-locals` neighborhood. |
| `src/passes/simplify_locals.mbt:70,176,4132` | Existing HOT local cleanup has sinkable/effect-conflict machinery and the full `simplify-locals` entry point, but it is the downstream cleanup neighbor rather than a CSE implementation. |
| `src/passes/reorder_locals.mbt:118,183,544` | Existing module pass shows local-use scanning, in-place local-index rewrite, and module-pass entry logic a future temp-localizing port will need to compose with. |
| `agent-todo.md` / `CHANGELOG.md` | The LCSE backlog slice has been pruned and the 2026-05-05 landing is recorded in the changelog. |

## What this page rules out

- Do not cite `simplify_locals.mbt` as if it implements `local-cse`. It sinks and cleans local traffic; it does not collect repeated whole-tree candidates and materialize a first original with temp-local reuse.
- Do not cite `reorder_locals.mbt` as if it implements `local-cse`. It rewrites local indices after sorting/removing unused locals; it does not do expression equality, effect validation, or temp-local insertion for repeated roots.
- Do not claim Starshine preset parity for the exact Binaryen slot yet. `flatten` and `simplify-locals-notee-nostructure` are still missing locally, so the exact ordered neighborhoods remain gated even though `local-cse` itself is implemented.

## Validation guidance for a future Starshine port

A faithful local port still needs neighborhood parity signoff with:

- focused WAT tests for each fixture family above,
- continued regression coverage for the before-`if` into `then`, simple before-block into straight-line block, before-`try_table` into try-body, `return_call` / `return_call_indirect` / `return_call_ref` / `throw_ref` unreachable-continuation reuse, `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` fallthrough-continuation reuse, and `struct.set` / `array.set` / `array.fill` / `array.copy` / `array.init_data` / `array.init_elem` / `memory.copy` / `memory.fill` / `memory.init` / `table.copy` / `table.fill` / `table.init` / `table.set` / `table.grow` / `table.size` / `global.set` / `data.drop` / `elem.drop` local-only reuse positives fixed after the 2026-06-04 audit,
- durable before-loop into loop body, `br`, `br_table`, `return`, `throw`, top-level `unreachable`, and `try_table` body unreachable boundary negative coverage,
- durable tiny-root no-op coverage for repeated `global.get`,
- continued source-derived tests for any additional GC-generative allocation variants beyond the covered `struct.new` / `struct.new_default` / `array.new` / `array.new_default` / `array.new_fixed` / `array.new_data` / `array.new_elem` roots,
- registry and explicit-pass CLI tests keeping `local-cse` active,
- repeated-pass/idempotence tests because Binaryen can rerun local cleanup,
- pass-targeted fuzz compare against `wasm-opt --local-cse`, and
- ordered no-DWARF artifact replay once `flatten` and `simplify-locals-notee-nostructure` are also locally representable enough for the surrounding cluster.

Until that evidence exists, keep the dossier explicit that `local-cse` is landed direct-pass behavior plus a still-gated ordered-neighborhood claim, not merely port planning.
