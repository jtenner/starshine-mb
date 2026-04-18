---
kind: entity
status: working
last_reviewed: 2026-04-13
sources:
  - ../../../raw/research/0070-2026-03-27-remove-unused-brs-binaryen-comparison.md
  - ../../../raw/research/0071-2026-03-28-remove-unused-brs-hot-lift-shapes.md
  - ../../../raw/research/0076-2026-04-10-remove-unused-brs-br-table-carried-wrapper-parity.md
  - ../../../raw/research/0077-2026-04-10-remove-unused-brs-large-result-br-table-noop-skip.md
  - ../../../raw/research/0078-2026-04-10-remove-unused-brs-false-prefix-guard-raw-skip.md
  - ../../../raw/research/0079-2026-04-10-remove-unused-brs-mid-unique-tee-floor.md
  - ../../../raw/research/0079-2026-04-11-pass-fuzz-health-round-two.md
  - ../../../raw/research/0080-2026-04-10-remove-unused-brs-large-brtable-hot-skip.md
  - ../../../raw/research/0081-2026-04-10-remove-unused-brs-large-value-if-branch-raw-skip.md
  - ../../../raw/research/0082-2026-04-10-remove-unused-brs-large-tagged-result-prefix-hot-skip.md
  - ../../../raw/research/0083-2026-04-10-remove-unused-brs-large-typed-brtable-encoder-raw-skip.md
  - ../../../raw/research/0084-2026-04-10-remove-unused-brs-brtable-one-arm-payload-parity.md
  - ../../../raw/research/0085-2026-04-10-remove-unused-brs-drop-heavy-local-set-floor.md
  - ../../../raw/research/0086-2026-04-13-remove-unused-brs-medium-branchy-hot-skip.md
  - ../../../raw/research/0087-2026-04-13-remove-unused-brs-call-heavy-mixed-if-mesh-hot-skip.md
  - ../../../raw/research/0088-2026-04-13-remove-unused-brs-localset-heavy-value-if-mesh-hot-skip.md
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_mutate.mbt
  - ../../../../../src/passes/remove_unused_brs.mbt
  - ../../../../../src/passes/remove_unused_brs_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
related:
  - ./pattern-catalog.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./tail-and-return-cleanups.md
  - ./select-and-condition-rewrites.md
  - ./branch-exit-and-payload-rewrites.md
  - ./carried-guards-and-result-blocks.md
  - ./returned-ladder-hot-shapes.md
  - ./visit-order-and-bailouts.md
  - ./parity.md
  - ../../no-dwarf-default-optimize-path.md
---

# `remove-unused-brs`

## Role

- `remove-unused-brs` is an active HOT pass in Starshine's Binaryen namespace.
- It is the main branch-structure cleanup pass for:
  - removing terminal `br` / `return` traffic that already flows to the surrounding continuation
  - rewriting branch-shaped `if` structures into `br_if`, `select`, `br_table`, or simpler payload forms
  - collapsing carried-wrapper shapes that only exist to shuttle branch payload values through result blocks
  - preserving Binaryen-compatible shapes where an earlier-looking cleanup would actually move Starshine away from the oracle

## Current Summary

- The pass runs in three modeled top-level slots inside both `optimize` and `shrink`.
- It has two execution layers:
  - a raw pre-lift fast path in [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - the HOT fixpoint in [`../../../../../src/passes/remove_unused_brs.mbt`](../../../../../src/passes/remove_unused_brs.mbt)
- The implementation is already much broader than "trailing branch stripping", and the old early `br_table` continuation-wrapper artifact gap is now fixed in-source.
- The raw layer now also skips the large one-result `br_table` dispatch ladders that were dominating no-op artifact cost after the continuation-wrapper slice.
- The raw layer now also skips the later large typed `br_table` encoder family that was still lifting as `Func 1482` even though RUB left it unchanged.
- The raw layer now also skips the later tiny-local value-`if` / branch ladder family that was still lifting as `Func 828` even though RUB left it unchanged.
- The raw layer now also skips the later large-local drop-heavy branch ladder family that was still lifting as `Func 145` even though RUB left it unchanged.
- The raw structured-return skip now ignores reduced false prefix-guard families that the real HOT result-prefix matcher cannot rewrite anyway.
- The raw layer now also has two more Binaryen-shaped cost filters:
  - very large void-`if` / return families can now bail before lift on cheap raw shape counts instead of always waiting for the lifted `large-void-if-return-ladder-noop` door
  - medium-size unchanged control ladders with heavy local traffic can now bail before lift once the raw counts show RUB is unlikely to find a profitable rewrite
- The unique loop/select raw skip now also covers the measured sixteen-tee mid-band ladder family, but that slice only reclassifies `Func 1171`.
- The direct one-arm payload branch rewrite now also has a negative parity guard in `br_table` functions:
  - the reduced `Func 3771` family proves Binaryen keeps that `if` conservative
  - the landed guard piggybacks on the existing branch-payload scan instead of paying a second whole-function walk
- The hot layer now also skips the large lifted `br_table` / return family that was still paying full traversal after lift:
  - `Func 1058` / `parse__opcode__instruction`
  - `Func 1150` / `wt__lower__module`
- The hot layer now also skips the later tagged result-prefix family that only triggered repeated `rub-result-prefix reject=inner-op` discovery before exiting unchanged:
  - `Func 356` / `dfe__try__rewrite__instruction__type__idxs`
- The hot layer now also skips the later medium branchy block-ladder family that still paid lift plus a full HOT walk before exiting unchanged:
  - `Func 144` / `parse__env__overlay`
  - `Func 301` / `dfe__iteration.inner`
  - `Func 353` / `dfe__rewrite__module__type__idxs.inner`
  - `Func 1512` / `Elem.Encode.encode`
  - `Func 1547` / `NameSec.Encode.encode`
  - `Func 1859` / `validate__ref__func__declarations__in__module.inner`
  - `Func 1867` / `validate__name__sec`
- The hot layer now also skips the later call-heavy mixed-if mesh family that still paid lift plus a full HOT walk before exiting unchanged:
  - `Func 408` / `run__hot__pipeline__func`
  - `Func 413` / `run__hot__pipeline__raw__rewrite__instrs`
  - `Func 739` / `hot__lower__impl__emit__instruction`
  - `Func 832` / `hot__lift__impl__build__exact__node`
  - `Func 902` / `cfg__builder__process__block`
  - `Func 1022` / `spec__check__command`
  - `Func 1448` / `SubType.Decode.decode`
  - `Func 1815` / `validate__typecheck__if`
- The hot layer now also skips the later localset-heavy value-if mesh family that still paid lift plus a full HOT walk before exiting unchanged:
  - `Func 837` / `hot__lift__impl__build__direct__node`
  - `Func 3021` / `encoding::utf8::decode.inner`
  - `Func 3120` / `parse__number`
  - `Func 3130` / `parse__decimal__from__view`
  - `Func 3134` / `parse__int64.inner`
- A later `2026-04-13` perf audit also removes several pass-internal costs without widening semantics:
  - HOT liveness now uses a hybrid `deleted_nodes` fast path for large free lists
  - the six lifted ladder-skip classifiers share one precomputed summary
  - each fixpoint cycle computes `label_refs`, `branch_payload_children`, and `has_br_table` in one scan
  - visitation now threads root-site and single-arm-`nop` context instead of re-finding those facts with extra whole-function walks
  - detached cleanup is bounded and several hot rewrites now use push-style array assembly
- A newer upstream trunk note is now recorded too: the Chromium-hosted Binaryen mirror shows a 2026-02-27 `RemoveUnusedBrs` change that rewrites branches-to-traps directly to traps. That is a behavior change newer than this repo's older `version_129` Binaryen oracle, so treat it as tracked upstream drift rather than as already-ported Starshine behavior.
- It is still an in-progress parity pass because the explicit debug-artifact compare remains noisy after those fixes:
  - the saved compare still diverges in normalized WAT
  - the first inspected remaining hunk `func $384` still traces as `changed=false`, so some early noise is not RUB mutation at all
  - the later interleaved three-pair self-opt replay improves the RUB lane again from `431.7387 ms` baseline to `402.0653 ms` current for the localset-heavy value-if mesh hot-skip slice alone
  - the current trace now retires a further five unchanged canonical functions under `skip-hot reason=localset-heavy-value-if-mesh-noop`
  - the next runtime work should keep shrinking the still-open unchanged-walk families led by `Func 497` / `Func 1168` / `Func 229` / `Func 990` / `Func 883` / `Func 1213`

## Page Map

- [`./pattern-catalog.md`](./pattern-catalog.md)
  Exhaustive inventory of every rewrite family, cleanup helper, and skip surface currently modeled by the pass.
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Upstream `RemoveUnusedBrs` phase structure, why Binaryen defers late shape work, and which parts of that strategy still matter for Starshine.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  The current in-tree Starshine architecture: raw pre-lift shortcutting, HOT traversal, fixpoint cycles, caches, and structural guards.
- [`./tail-and-return-cleanups.md`](./tail-and-return-cleanups.md)
  Detailed notes for terminal `br` / `return` stripping, return-context cleanup, tail-exit stripping, tail-return voidification, and trailing `nop` trimming.
- [`./select-and-condition-rewrites.md`](./select-and-condition-rewrites.md)
  Detailed notes for value-`if` to `select`, nested condition folding, `br_table` ladder formation, and one-sided stack-tail selection.
- [`./branch-exit-and-payload-rewrites.md`](./branch-exit-and-payload-rewrites.md)
  Detailed notes for block-local `br_if` formation, local-set arm rewrites, branch-exit `if` cleanup, payload-branch rewrites, and block-if flattening.
- [`./carried-guards-and-result-blocks.md`](./carried-guards-and-result-blocks.md)
  Detailed notes for the carried-guard/result-block families that dominate the current artifact parity work.
- [`./returned-ladder-hot-shapes.md`](./returned-ladder-hot-shapes.md)
  HOT-lift shape guide for returned ladders, holder blocks, explicit `Return` nodes, and the reason printed WAT is not enough here.
- [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md)
  The pass's execution model, seen-mask logic, raw/hot skip rules, mutation bounds, and performance-control heuristics.
- [`./parity.md`](./parity.md)
  Current signoff status, coverage surface, known remaining artifact gaps, and the next reductions that actually matter.

## Current Maintenance Rule

- When newer non-GitHub upstream evidence changes `RemoveUnusedBrs` behavior without renaming the pass, record that drift here and in [`./parity.md`](./parity.md) instead of silently folding it into the older `version_129`-backed algorithm notes.
- Treat this folder as the canonical home for all future `remove-unused-brs` work.
- New RUB research should land here instead of being left only in `agent-todo.md`, one-off parity notes, or commit messages.
- Any new rewrite should update:
  - [`./pattern-catalog.md`](./pattern-catalog.md)
  - the detailed family page that owns the pattern
  - [`./parity.md`](./parity.md) if the current artifact state or active blocker changes
- Any new performance guard should also update [`./visit-order-and-bailouts.md`](./visit-order-and-bailouts.md) if it changes where the pass now fails fast.
