---
kind: concept
status: supported
last_reviewed: 2026-05-14
sources:
  - ../../../raw/binaryen/2026-04-26-inlining-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../../../raw/research/0557-2026-05-12-inlining-wiki-overhaul.md
  - ../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md
  - ../../../raw/research/0226-2026-04-21-inlining-inline-hints-and-no-inline-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining-optimizing/index.md
---

# `inlining`: heuristics, splitting, and plain-vs-optimizing

This page focuses on the parts of the inliner that future agents most often overcompress.

## The wrong one-line summary

> Inline every small function.

That misses the real contract. Binaryen instead asks:

- Is the callee defined, reachable from a direct callsite, and non-recursive in this action?
- Does the callee have roots or reference uses that force boundary survival?
- Does the body fit one of several layered profitability families?
- Would splitting a narrow top-of-function conditional region create a better inline unit?
- Can copied locals, labels, returns, tail calls, and types be repaired safely?
- Should the pass stop now (`inlining`) or run filtered nested cleanup (`inlining-optimizing`)?

## 1. Plain and optimizing are different public contracts

Both public names share the same upstream engine.

| Public pass | Shared scan/plan/rewrite | Dead-helper cleanup | Nested useful-pass rerun |
| --- | --- | --- | --- |
| `inlining` | yes | yes | no |
| `inlining-optimizing` | yes | yes | yes |

The optimizing suffix is not a log label. It means: prepend `precompute-propagate`, then rerun Binaryen's default function optimization pipeline on changed functions.

Current Starshine mirrors that split at the entrypoint level: plain `inlining` calls `inlining_run_module_pass(... optimize=false ...)`, while `inlining-optimizing` calls the same function with `optimize=true`. The optimizing cleanup is still an approximation, so the public split exists locally but is not parity-complete.

## 2. Direct-call planning stays the source-backed baseline

The reviewed `version_129` chosen-action surface is reachable direct `call` / `return_call`.

Keep these facts separate:

- `ref.func` increments refs and can keep a callee boundary alive.
- `call_ref` / `call_indirect` forms can exist in copied code and affect repair/conservatism.
- The actual action planner is not a broad indirect/ref-call inliner in the reviewed release.

This distinction is important for Starshine: the current direct-call subset is aligned with the safe first surface, even though many other Binaryen rules are still missing.

## 3. “One use” is broader than “one direct caller”

The one-caller heuristic uses counted uses plus root status. A function can have one direct call and still be non-disposable because it is:

- exported;
- the start function;
- referenced by `ref.func` or element/table-like initialization;
- used by another surviving callsite after filtering.

Binaryen can therefore inline into one caller but keep the declaration.

## 4. Trivial wrappers are special

### `Shrinks`

A single non-control instruction whose operands are exactly the params in order and exactly once. Inlining provably shrinks the call boundary.

### `MayNotShrink`

Still tiny, but constants, repeated/skipped params, or extra scaffolding can grow code. Binaryen accepts this mainly under heavier speed focus.

### `NotTrivial`

Everything else.

Starshine currently does not model these classes exactly. It has a much smaller tiny/one-use eligibility rule plus narrow `[INL]003` `Shrinks` subsets: two-parameter stack bodies of the form `local.get 0`, `local.get 1`, then a whitelisted binary numeric/ref operator; three-parameter stack bodies of the form `local.get 0`, `local.get 1`, `local.get 2`, then `select`; and two-parameter stack bodies of the form `local.get 0`, `local.get 1`, then one of `i32.store`, `i64.store`, `f32.store`, `f64.store`, `i32.store8`, `i32.store16`, `i64.store8`, `i64.store16`, or `i64.store32`, can inline even when multi-use.

## 5. `try_delegate`, loops, and calls are policy gates

- `try_delegate` blocks full inlining in the reviewed contract.
- Loops are not invalid syntax, but default policy avoids loop-containing flexible inlines unless `allowFunctionsWithLoops` is enabled.
- Calls in the callee matter because flexible cases generally require no calls.
- Tail-call-containing callees require special conservatism/repair.

These are not parser limitations; they are optimizer policy and safety gates.

## 6. Full inlining is not the only action

If a callee is not fully inlineable, Binaryen may try partial inlining under the right settings.

That does not mean copying a random half of a CFG. It means splitting the function into a smaller inlineable helper plus an outlined remainder, then using ordinary full inlining on the smaller unit.

## 7. Partial Pattern A: guard then heavy work

Source shape:

```wat
(func $f (param $x i32)
  (if (local.get $x)
    (then (return)))
  (call $heavy))
```

Binaryen can inline the cheap early guard and outline the heavier later work. Constants at callsites may then kill the guard entirely.

## 8. Partial Pattern B: short top-level `if` ladder

Pattern B is a small ladder, not arbitrary nested branching:

- a short run of top-level `if`s;
- simple conditions only;
- no else arms;
- bodies are unreachable or none-typed without returns;
- optional final item is simple;
- locals written in the `if` bodies are not read by the final item.

That final local-dependency gate prevents splitting from changing a guarded write's relationship to the later value.

## 9. “Simple” is intentionally tiny

The splitter's simple-expression budget accepts only very small shapes such as:

- `local.get`;
- `global.get`;
- unary wrappers around simple expressions;
- `ref.is_null` around simple expressions.

A guard that calls an arbitrary condition helper is not simple.

## 10. No-inline policy is separate from inline-hint metadata

Binaryen preserves `@metadata.code.inline` bytes, but the practical `Inlining.cpp` policy checks `Function::noFullInline` and `Function::noPartialInline`. The separate `no-inline*` pass family sets those flags.

See [`./compilation-hints-vs-no-inline-flags-and-clone-survival.md`](./compilation-hints-vs-no-inline-flags-and-clone-survival.md) for the detailed source map.

Current Starshine status: the first `no-inline*` policy surface is modeled through name-section wildcard marking and internal function annotations, WAT function identifiers now populate that name lookup for defined and imported functions, full-inline suppression is honored by the direct inliner, annotation/function-name remapping preserves policy and later matching across helper compaction, stale local names are dropped after inlining rewrites, and `no_inline_copy_policy_annotations(...)` is available for future clone/copy transforms. `[INL]004` is accepted for this current policy surface; partial-inlining-specific no-inline behavior moves with `[INL]005`.

## 11. Iteration has race guards

Binaryen discovers many opportunities but filters them to avoid bad same-wave interactions:

- do not inline a function elsewhere in the same iteration if it was inlined into;
- bound repeated operations per function name;
- bound total iterations;
- enforce a combined-size limit.

Starshine now has bounded iterative waves, which fixes the broad “same-wave guard exposes a later call” family, but it does not yet reproduce the full Binaryen action-order/filtering model.

## 12. Plain `inlining` must leave cleanup debris

Plain `inlining` may leave wrapper blocks, local sets, redundant constants, and dead-looking local traffic. That is expected. If a local test only matches Binaryen after running the optimizing nested cleanup suffix, it is not a proof of plain `inlining` parity.

## Good future-agent checklist

When a would-be inline does or does not happen, ask:

1. Is the callsite a reachable direct `call` / `return_call`?
2. Is the callee defined and not the same function?
3. Is it rooted by export/start/ref.func/element/table use?
4. Is it tiny, one-use, shrinking-trivial, or flexible-profitable?
5. Does it contain `try_delegate`, loops, calls, or tail-call shapes that change policy?
6. Does no-inline policy block full or partial inlining?
7. Would partial Pattern A/B be required first?
8. Would the result require tail-call, nondefaultable-local, label, or multi-result repair that the current Starshine subset lacks?
9. Are you testing plain `inlining` or `inlining-optimizing`?
