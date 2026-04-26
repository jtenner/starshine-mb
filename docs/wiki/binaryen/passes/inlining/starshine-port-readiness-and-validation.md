---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-inlining-current-main-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../../../raw/research/0391-2026-04-26-inlining-port-readiness.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining-optimizing/index.md
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining-optimizing/index.md
  - ../inline-main/index.md
  - ../monomorphize/index.md
  - ../duplicate-function-elimination/index.md
---

# Starshine Port Readiness And Validation For `inlining`

Use this page as the bridge between Binaryen's source-backed whole-module inliner and Starshine's current boundary-only status.

## Current status in one sentence

Starshine currently knows the pass name and rejects active `inlining` requests as boundary-only, but it has no `src/passes/inlining.mbt` owner file, no module-pass dispatcher case, and no direct-call body-copy rewrite machinery for this pass yet.

Relevant local code locations:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - `pass_registry_boundary_only_names()` includes `"inlining"` and `"inlining-optimizing"`.
  - `run_hot_pipeline_expand_passes(...)` rejects `BoundaryOnly` entries with an explicit not-implemented-in-hot-pipeline error.
  - `optimize_preset_passes(...)` and `shrink_preset_passes(...)` currently contain only the active Starshine hot/module subset, not `inlining`.
- There is no `src/passes/inlining.mbt` file today.

## Why this cannot start as a HOT peephole

Binaryen `inlining` is a module-level function-boundary transform:

- the planner needs whole-module callee summaries;
- roots such as exports, start functions, `ref.func`, tables, and surviving references affect deletion separately from callsite replacement;
- the rewrite copies a callee body into a caller and repairs locals, labels, returns, tail-call forms, and expression types;
- private-helper deletion is a module-topology update;
- the plain pass must stop before the optimizing sibling's nested cleanup suffix.

That makes a local HOT-only peephole misleading even if the first reduced test only contains one caller and one callee.

## Minimum viable Starshine slice

A safe first implementation slice should be deliberately smaller than Binaryen's full pass:

1. Add an explicit module-pass landing zone for `inlining` without changing the public boundary-only behavior until tests pin the dispatch semantics.
2. Build a whole-module summary for defined functions:
   - direct-call count,
   - direct callers,
   - export/start roots,
   - `ref.func` or element/table roots,
   - local count and result type.
3. Select only one positive shape:
   - private defined callee,
   - exactly one direct `call`,
   - no `return_call`,
   - no split-inlining,
   - no `try_delegate`,
   - defaultable locals only,
   - callee body small enough to fit the always-inline threshold.
4. Rewrite the call by copying the callee body into the caller with fresh caller locals for callee params and locals.
5. Preserve side-effect order by evaluating call operands into the fresh params before the copied body.
6. Delete the callee only if the post-rewrite summary proves no root and no remaining use.
7. Prove plain `inlining` stops there: no nested `precompute-propagate`, no default useful-pass rerun, and no implicit `inlining-optimizing` behavior.

## First before/after shape

Before:

```wat
(func $add1 (param $x i32) (result i32)
  (i32.add (local.get $x) (i32.const 1))
)

(func $caller (param $y i32) (result i32)
  (call $add1 (local.get $y))
)
```

After, conceptually:

```wat
(func $caller (param $y i32) (result i32)
  (local $inl_x i32)
  (local.set $inl_x (local.get $y))
  (i32.add (local.get $inl_x) (i32.const 1))
)
```

Caveat: exact printed WAT may use wrapper blocks or temporary locals. The invariant is semantic: the call boundary is gone, argument evaluation order is preserved, and the callee frame's locals are not aliased with caller locals.

## Negative tests that must land with the first slice

The first slice should refuse or preserve all of these:

- exported callee deletion;
- start-function deletion;
- `ref.func` / element-segment use deletion;
- indirect `call_ref` or table-call inlining;
- `return_call` until tail-call repair is explicit;
- nondefaultable callee locals until local-initialization repair is explicit;
- `try_delegate` bodies;
- no-inline flagged functions;
- any case where the result only matches Binaryen after `inlining-optimizing`'s cleanup suffix.

## Expansion order after the first slice

| Slice | Add | Required proof |
| --- | --- | --- |
| 1 | Direct one-use private callee | Call boundary disappears; private dead helper is removed only when unrooted |
| 2 | Root survival | Exported/start/ref.func/tabled helpers can inline into direct callers but remain declared |
| 3 | Return repair | Early returns become structured exits from the inlined body |
| 4 | Label repair | Copied labels cannot collide with caller labels; branch targets stay valid |
| 5 | Nondefaultable locals | No fake zeroing for nondefaultable locals; validation remains strict |
| 6 | `return_call` | Tail-call semantics are preserved or conservatively skipped |
| 7 | No-inline policy | `no-inline`, `no-full-inline`, and `no-partial-inline` flags are honored |
| 8 | Split inlining | Only Binaryen's narrow top-of-function conditional split patterns are added |
| 9 | Plain-vs-optimizing split | Shared machinery powers both siblings while preserving different stop points |

## Binaryen oracle comparison plan

Once a Starshine module-pass lane can run `inlining`, compare against Binaryen in this order:

1. dedicated `inlining-trivial-instructions.wast`-style tiny wrappers;
2. `inlining-trivial-calls-1.wast` direct-call families;
3. `inlining-unreachable.wast` type/unreachable repair;
4. `inlining-gc.wast` reference-typed and nondefaultable-local edge cases;
5. `no-inline.wast` and `no-inline-monomorphize-inlining.wast` policy surfaces;
6. `inlining_splitting_basics.wast` and `inlining_splitting.wast` only after split support lands;
7. neighborhood replay with `inline-main`, `monomorphize`, `duplicate-function-elimination`, and `inlining-optimizing`.

Use the pass-targeted harness when available, for example a future equivalent of:

```text
bun scripts/pass-fuzz-compare.ts --pass inlining ...
```

Keep exact normalization expectations separate for plain `inlining` and `inlining-optimizing` because the latter intentionally runs additional cleanup.

## Open implementation decisions

- Whether the first real landing zone is a standalone module-pass dispatcher or a broader boundary-pass scheduler.
- Whether direct-call summaries should be built from the existing `@lib.Module` representation first or from a future richer function graph.
- How much shared machinery to build before exposing either public sibling: plain `inlining`, `inlining-optimizing`, and `inline-main` should not grow three incompatible body-copy engines.
- How to represent copied labels and fresh locals in a way that is friendly to later binary and WAT roundtrips.

## Cross-links

- [`./binaryen-strategy.md`](./binaryen-strategy.md) explains the upstream phases.
- [`./wat-shapes.md`](./wat-shapes.md) catalogs transformed and preserved WAT shapes.
- [`./heuristics-splitting-and-plain-vs-optimizing.md`](./heuristics-splitting-and-plain-vs-optimizing.md) covers the heuristics and sibling split.
- [`./compilation-hints-vs-no-inline-flags-and-clone-survival.md`](./compilation-hints-vs-no-inline-flags-and-clone-survival.md) covers no-inline flags and metadata caveats.
- [`./starshine-strategy.md`](./starshine-strategy.md) records the current Starshine boundary-only status.
- [`../inlining-optimizing/index.md`](../inlining-optimizing/index.md) is the public sibling with the nested cleanup suffix.
