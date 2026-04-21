---
kind: concept
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md
  - ../../../../../src/passes/heap_store_optimization.mbt
  - ../../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./swap-safety-and-control-flow.md
  - ./wat-shapes.md
---

# Current Starshine `heap-store-optimization` strategy

This page is the local “what is actually implemented today?” companion to the upstream Binaryen strategy page.

## Short version

Current Starshine `src/passes/heap_store_optimization.mbt` follows the same **core idea** as Binaryen `version_129`:

- fold a `struct.set` back into a nearby fresh constructor when local visibility and effect ordering stay safe.

But the implementation shape is not a literal source port.

Binaryen uses:

- a CFG walker over AST basic blocks
- `EffectAnalyzer`
- `ShallowEffectAnalyzer`
- `LazyLocalGraph`

Current Starshine uses:

- HOT-region traversal and rewrite helpers
- per-node effect masks from the HOT analysis layer
- custom subtree predicates for trapless-readonly and reorderable shapes
- custom control-flow / owner-label reasoning
- extra cleanup to keep HOT lowering and writeback valid after the rewrite

So the local pass is best understood as:

- a HOT-IR generalization of the same narrow constructor/store-folding contract

not:

- a direct line-by-line port of Binaryen `HeapStoreOptimization.cpp`

## What Starshine already models well

## 1. The same core fold family

The in-tree pass still revolves around the same central optimization:

- `struct.set` into a fresh struct becomes an updated `struct.new`

It supports the two canonical entry shapes:

- tee-wrapped immediate form
- later `local.set` / `local.get` chain form

That is the real heart of the pass, and current Starshine models it directly.

## 2. Repeated subsequent-set chains

Like Binaryen, the local pass can absorb multiple later `struct.set`s into the same fresh constructor while the proof remains valid.

That is visible in tests such as:

- `folds consecutive struct.set roots on the same local`
- `reorders unrelated local.get field values within struct.new`

## 3. Default and descriptor constructor forms

Current Starshine explicitly supports more constructor spellings in-tree than the upstream public examples emphasize, including:

- `struct.new_default`
- `struct.new_desc`
- `struct.new_default_desc`

The pass has dedicated module-context helpers for:

- discovering struct fields
- checking whether default materialization is valid
- building explicit default child operands

That is a real local implementation difference worth keeping explicit.

## 4. HOT-region-safe prefix peeling and wrapper cleanup

The current local pass has a lot of machinery that exists because HOT IR and later writeback need more shape repair than upstream AST Binaryen does.

Examples include helpers for:

- trimming unreachable tails in moved values
- flattening block wrappers after peeling prefixes
- retargeting labels when flattening nested block wrappers
- preserving old field side effects with rewritten block/value shells

This is why the local test suite contains many shapes that sound more structural than the upstream dedicated test names, such as:

- `flattens swapped block roots before the folded local.set`
- `flattens nested if-tail wrappers inside folded values`
- `keeps the rewritten local.set valid after nop cleanup`

## 5. Wider reduced test coverage than the upstream dedicated lit file

The current repo test suite covers many source-local families beyond the upstream dedicated HSO lit test, including:

- memory/table/global read-only blockers
- nested block / if / loop wrappers
- raw-decoded ref-prefix shapes
- named-label preservation and raw-skip cases
- artifact replay via native `cmd`
- perf fast-skip behavior when there are no candidates

That does **not** automatically mean Starshine is fully upstream-parity complete.
But it does mean the local pass has already accumulated a lot of HOT-specific survival work.

## Important structural differences from Binaryen

## 1. Binaryen uses CFG basic blocks; Starshine walks HOT regions

Upstream Binaryen records only:

- `StructSet`
- `Block`

per CFG basic block.

Current Starshine recursively processes HOT regions for:

- `block`
- `loop`
- `if`
- `try`
- `try_table`

That means the local implementation can see and transform some wrapped shapes in a more region-native way, but it also means the proof structure is not the same as upstream.

## 2. Binaryen uses `LazyLocalGraph` only on control-flow values; Starshine uses custom subtree analysis

Upstream Binaryen's hardest safety check is:

- can moving the `local.set` forward expose bad `local.get`s?

It answers that with `LazyLocalGraph::canMoveSet(...)`.

Current Starshine answers the same *kind* of question with custom HOT helpers such as:

- subtree/region touches-local predicates
- branch-owner escape checks
- subtree-may-skip-local-set predicates
- reorderability predicates over HOT effect masks

So the local proof is aiming at the same semantic barrier, but it is not using the same exact helper stack.

## 3. Starshine currently cares a lot about writeback-valid shapes

Several local helpers exist mainly to avoid generating invalid or awkward lowered output after a successful fold, for example:

- trimming unreachable tails in value wrappers
- flattening single-root block wrappers
- retargeting labels when flattening nested block roots

That is a local HOT/writeback reality, not a direct upstream Binaryen concern.

## 4. The local pass is still narrow in *goal*, even when broad in *shape handling*

Even though Starshine handles more wrapper families and constructor spellings, the pass is still not claiming broader semantic scope than Binaryen.

It is still fundamentally about:

- folding `struct.set` into nearby `struct.new`

It is **not** currently claiming:

- generic heap dead-store elimination
- load forwarding
- array-store folding as the main contract

That narrow-goal correction must stay explicit locally too.

## Current honest parity state

## Top-level generated-artifact audit

The saved generated-artifact `-O4z` audit recorded exact equality for the two top-level HSO slots:

- slot `17`
- slot `45`

with:

- `wasmEqual = true`
- `normalizedWatEqual = true`
- `normalizedWatTextEqual = true`

But the same summary also says:

- `starshinePassSkippedRaw = true`

for both slots.

So the honest reading is:

- the current fast-skip path preserved exact artifact behavior there
- this is good regression evidence, but not proof that every upstream rewrite family is already exercised on that artifact

## Native artifact replay coverage exists in-tree

`src/cmd/cmd_wbtest.mbt` contains a native regression ensuring:

- `run_cmd_with_adapter validates heap-store-optimization on debug artifact`

That is important because it proves the current implementation can at least run and validate cleanly on the checked-in large artifact.

## There is no dedicated `HSO` backlog slice in `agent-todo.md`

That is unusual compared to passes like `DCE`, `PC`, or `H2L`.

The relevant local planning surface is currently indirect:

- shared post-SSA cleanup-prefix references that include HSO
- the existing pass-specific test corpus
- the tracker priority note that this dossier was needed to clarify pass scope

So this page should be treated as the current local strategy note until a dedicated `HSO` slice exists.

## Fast-skip behavior is part of the local strategy

`src/passes/perf_test.mbt` has explicit tests showing the current implementation can skip raw lifting when:

- a function has no HSO candidates at all
- a struct allocation cannot feed a later `struct.set`

That matters on large artifacts.

It means the local implementation strategy is not only about the rewrite itself.
It is also about making “no candidate here” cheap.

## What a future local refactor must preserve

If Starshine rewrites this pass again, keep these durable local lessons:

- preserve the narrow pass goal: fresh-struct `struct.set` folding, not generic heap DSE
- preserve the fast-skip path when no candidates exist
- keep target-local safety, effect ordering, and control-flow skip reasoning explicit
- keep default and descriptor constructor handling honest
- keep writeback-valid wrapper cleanup as part of the implementation, not as an afterthought
- keep generated-artifact equality evidence labeled honestly when a slot succeeded by fast-skip instead of by exercising the full rewrite surface

## Best current mental model

Upstream Binaryen tells us **what the pass means**.
Current Starshine tells us **what a HOT-IR implementation needs in order to survive real writeback and artifact replay**.

Both matter.

But when those two stories disagree, treat Binaryen `version_129` as the semantic oracle and treat the local file as the current implementation strategy that still needs to keep proving itself against that oracle.
