---
kind: entity
status: supported
starshine_status: active
last_reviewed: 2026-09-02
sources:
  - ../../release-horizon-and-oracles.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/directize.mbt
  - ../../../../../src/passes/directize_test.mbt
  - ../../../../../src/passes/directize_wbtest.mbt
  - ../../../../../src/passes_perf_long/directize_perf_test.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../late-pipeline-dispatch.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./table-info-and-immutability.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../reorder-globals/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `directize`

## Binaryen v131 status

Default direct-pass Binaryen v131 parity is **closed and renewed on 2026-07-30**. Starshine classifies full-width table32/table64 constant targets using sparse element facts plus declared table defaults: segment or `ref.func` targets become direct calls, absent-initializer holes and non-growable out-of-range indexes become traps, explicit non-`ref.func` initializers (including explicit `ref.null`), imported defaults, and `global.get` defaults remain unknown, and element segments override defaults. Select lowering covers known/trap arms and multivalue results; legacy-EH traversal covers protected bodies, typed catches, catch-all, delegates, and `try_table`. Optional `directize-initial-contents-immutable` pass-arg support remains separate.

## Role

- `directize` is an upstream Binaryen late boundary / module-shaped indirect-call cleanup pass.
- Starshine now has an active explicit `directize` module pass with direct Binaryen oracle parity evidence for the default pass behavior.
- In Binaryen `version_129`, it is the **last top-level pass** in the canonical no-DWARF optimize tail.
- Its job is to replace some `call_indirect` / `return_call_indirect` sites with either:
  - a direct `call` / `return_call`, or
  - a known trap represented as `unreachable`, or
  - for a narrow `select` target shape, an `if` whose arms are direct calls and/or `unreachable`.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase ends with:
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`
  - `string-gathering`
  - `reorder-globals`
  - `directize`
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - slot `56`
- The saved Binaryen debug log shows it is real, but small, in that captured run:
  - about `0.0198565` seconds total around the directize stage
- The backlog already tracks it as slice `DIR` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- `pass.cpp` explicitly says this final rewrite can enable more `inlining` / `dae` opportunities, but that you need `--converge` to come back and exploit them.

That makes `directize` a very important late-tail dossier even though the implementation file is short.

## Beginner summary

A safe beginner mental model is:

- Binaryen first asks whether it really understands a table’s current entry layout,
- then asks whether a specific indirect-call target is definitely one function, definitely a trap, or still unknown,
- and only then rewrites the call.

That is much closer to the real pass than either:

- “constant index means direct call”, or
- “the pass rewrites every kind of indirect call”, or
- “imported tables can never be optimized”.

## Current durable takeaways

- Binaryen `version_131` is the released oracle; older v129/current-main notes remain historical provenance for the segment-driven contract and `table.copy` mutation barrier.
- V131 extends constant-index classification to table initial values: `ref.func` defaults can directize, null/default holes can prove traps on defined tables, imported-table defaults remain unknown, and `global.get` defaults remain unknown.
- `directize` is a **late table-facts-driven call rewrite pass**, not a generic constant-propagation pass.
- The refreshed dossier has a compact owner/test map across `Directize.cpp`, `call-utils.h`, `table-utils.{h,cpp}`, `type-updating.h`, the older directize fixtures, and v131's new `directize_init.wast` default-initializer coverage.
- The retained 2026-04-26 repo-authored port-readiness digest is research note 0380; it does not change the upstream algorithm, but it names the first Starshine slices as table facts, target classification, constant rewrites, `select` lowering, and late-tail scheduling.
- In v131, the main implementation lives in `src/passes/Directize.cpp`.
- It computes module-wide table facts first with `TableUtils::computeTableInfo(...)`.
- It only visits `CallIndirect` nodes.
  - That includes the tail-call form via `isReturn`, but it does **not** mean `call_ref` is handled here.
- Tables are only entry-optimizable when Binaryen can flatten the relevant element-segment contents and trust the needed entries.
- Imported, exported, and runtime-written tables are conservatively treated as modifiable.
- The optional `--pass-arg=directize-initial-contents-immutable` mode loosens that by allowing optimization from known initial contents even when later growth or mutation may still happen.
- Constant targets classify into three answers:
  - known direct callee
  - known trap
  - unknown
- Known traps become `unreachable`, but child side effects are preserved.
- A narrow `select`-between-known-targets shape lowers to an `if` with fresh locals for the operands.
- Type compatibility uses subtype checking, not just exact signature-name equality.
- Rewrites can refine result types and add locals, so `ReFinalize()` is part of the real contract.

## Current repo caveat

- The current Starshine pass registry exposes `directize` as an active module pass in `src/passes/optimize.mbt`, implemented by `src/passes/directize.mbt`.
- The implementation preserves the boundary-shaped table-analysis requirement by computing module-wide table facts before rewriting function bodies.
- It rewrites compatible constant-index `call_indirect` / `return_call_indirect` sites through non-imported, non-exported, non-mutated tables with known active `ref.func` / function-index elements.
- It classifies known holes, out-of-range targets, and wrong-type targets as traps and rewrites them to `unreachable` when the table facts prove the trap.
- It lowers known/known, known/trap, and trap/trap constant-index `select` shapes to typed `if` expressions with direct-call or trapping arms and fresh locals preserving operand evaluation, including multivalue results.
- The September 2 renewal is in [`./fuzzing.md`](./fuzzing.md): regular explicit-v131 GenValid is `10000/10000` canonical-equal. Dedicated `directize-all` is `559` canonical-equal plus `9441` explicitly retained canonically smaller outputs, with zero larger outputs or validation/property/generator/command failures. The count partitions exactly: `273` wrong-type and `286` multivalue-select cases generate no callee `nop` and compare equal; every other dedicated case contains one or two inert callee `nop`s that Starshine omits while preserving the same Directize rewrite. The older 100,000-case, wasm-smith, and random-all matrix remains the broader released-behavior evidence.
- Directize now performs an exact recursive admission scan before function context construction and producer analysis. A function enters the rewrite path only when an indirect call targets an entry-optimizable table and its immediate sibling target is the table-width constant or `select` spelling that the implementation can consume. Dynamic loads, locals, arithmetic, calls through nonoptimizable tables, and unsupported nested spellings remain untouched without entering the expensive rewrite/provenance path; nested block, loop, `if`, legacy-EH, and `try_table` regions are still visited.
- The native benchmark file [`../../../../../src/passes_perf_long/directize_perf_test.mbt`](../../../../../src/passes_perf_long/directize_perf_test.mbt) retains the 256-call depth-64 trigger-bearing select lane, now `12.37ms +/- 137.51us`, and adds a fail-closed 2,048-function dynamic-target breadth lane. The latter constructs and validates the reusable fixture outside `it.bench(...)`, requires exact module equality plus preserved `call_indirect`, disables only repeated final-module validation, and measures `156.93us +/- 1.76us` on x86_64 AMD Ryzen 7 8845HS with MoonBit `0.1.20260713`.
- `[P0-WALL-DIRECTIZE]` is closed on the canonical 4,977,401-byte artifact. All 2,261 indirect calls across 261 functions target table 1 through dynamic loads, so none can exercise the implemented constant/select rewrite. Clean HEAD entered the impossible-candidate rewrite path and exceeded 120 seconds; the final candidate measures `689.065ms` no-trace command and `49.177ms` pass-local versus Binaryen v131 `563.773ms` / `36.192ms` (`1.222x` / `1.359x`), clearing the fixed `<=1.106s` command target by `416.935ms`. Starshine raw output is unchanged at SHA-256 `4acd06537e4466bc372a73c2e37da46f1cd94c3baca1fd62c1aa5fe76b944721`; harness canonicalization is byte-identical to Binaryen's 5,300,041-byte output at SHA-256 `4a9c3279a6fb409fbf9eaf68f714141aacfd8d6d9ddacd098f29afe4bbefe583`.
- The accepted public `optimize` / `shrink` late-tail suffix now includes `simplify-globals-optimizing -> remove-unused-module-elements -> string-gathering -> reorder-globals -> directize` via [research note 0572](../late-pipeline-dispatch.md), and the direct five-pass neighborhood proof remains in [research note 0571](../late-pipeline-dispatch.md). The remaining caveat is the optional `directize-initial-contents-immutable` pass-arg behavior, which Starshine does not expose yet. The inner `string-gathering -> reorder-globals -> directize` triple itself still has a current-head replay recorded in [research note 0549](../reorder-globals/index.md).

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: scheduler placement, pass arg surface, module-wide table analysis, constant-vs-trap-vs-unknown classification, select-lowering, and the real “what this is not” facts.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Compact source-confirmed owner/test map for `directize`: what `Directize.cpp`, `call-utils.h`, `table-utils.{h,cpp}`, `type-updating.h`, `pass.cpp`, `passes.h`, and the three shipped lit files each prove about the real pass contract.
- [`./table-info-and-immutability.md`](./table-info-and-immutability.md)
  Focused guide to `TableUtils`, flat-table construction, mutation barriers, the `initial-contents-immutable` mode, hole-vs-out-of-range behavior, and the main table-analysis corner cases a future port must preserve.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after WAT shape catalog for direct-call positives, trap/unreachable rewrites, `select` lowering, mutation and flat-table bailouts, wasm64 width correctness, and GC subtype behavior.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Dedicated Starshine status-and-port-map page covering the active module-pass implementation, direct oracle evidence, canonical no-DWARF tail slot, and the exact neighboring local dossiers the completed tail slot must compose with.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness and validation bridge for Starshine work: local parser / IR / binary / validator / HOT prerequisite map, implemented default-pass status, reduced-test families, Binaryen oracle evidence, accepted public late-tail suffix, and remaining pass-arg / broader-widening caveats.

## Current maintenance rule

- Treat this folder as the canonical home for future `directize` research and port planning.
- Keep the direct oracle evidence current when changing table facts, trap rewriting, select lowering, or type compatibility.
- Keep the strategy page and the table-info page in sync whenever new evidence changes the answer to either:
  - “when does Binaryen know enough to directize?” or
  - “when does Binaryen intentionally leave the indirect call alone?”

## Sources

- research note 0521
- [research note 0571](../late-pipeline-dispatch.md)
- [research note 0572](../late-pipeline-dispatch.md)
- research note 0476
- research note 0380
- research note 0350
- research note 0126
- research note 0209
- research note 0265
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [research note 0093](../late-pipeline-dispatch.md) preserves the saved generated-artifact `-O4z` skipped-slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast>
