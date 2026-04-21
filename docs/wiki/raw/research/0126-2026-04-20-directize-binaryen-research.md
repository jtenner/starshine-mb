# 0126 - `directize` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: document one currently unimplemented Binaryen late indirect-call cleanup pass in Starshine, using Binaryen `version_129` plus the saved generated-artifact audit to explain what `directize` actually does, how its table analysis works, which helper utilities it depends on, which IR / WAT shapes it rewrites or preserves, and what a future Starshine port must keep exact.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` still listed `directize` with wiki status `none` when this thread started.
- It is the top suggested next target after the newly-landed `string-gathering` and `reorder-globals` dossiers.
- It is the **last top-level pass** in the canonical no-DWARF `-O` / `-Os` tail.
- The saved generated-artifact `-O4z` audit records it as a real skipped top-level upstream slot:
  - slot `56`
- The saved Binaryen debug log shows it is a real but fairly small tail pass in that captured run:
  - approximately `0.0198565` seconds total around the `directize` stage, with a nested-pass log line appearing in Binaryen’s debug output even though `Directize.cpp` itself does not explicitly build a nested optimizer rerun.
- The backlog already tracks it as slice `DIR` in `agent-todo.md`.
- The pass name is easy to overread. A shallow mental model like “turn indirect calls into direct calls” misses several important realities:
  - in `version_129`, the pass only visits `call_indirect` / `return_call_indirect`, not `call_ref`
  - it needs whole-module table analysis first
  - it only handles constant indices directly, plus a very narrow `select`-between-known-targets shape
  - it may replace a call with `unreachable`, not only with a direct call
  - imported/exported/mutated tables are normally off-limits unless the special `directize-initial-contents-immutable` pass arg is set
  - “known trap”, “known call”, and “unknown” are three separate outcomes
  - it can refine result types and add locals, so it must repair IR typing afterwards

That combination makes `directize` a strong dossier target: it is short enough to read fully, but the actual contract is much more specific than the name suggests.

## Saved local source material

### Local Starshine / audit sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`

### Official Binaryen `version_129` sources

- `src/passes/Directize.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `src/passes/call-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
- `src/ir/table-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
- `src/ir/table-utils.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
- `src/ir/type-updating.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- `test/lit/passes/directize_all-features.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>
- `test/lit/passes/directize-gc.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast>
- `test/lit/passes/directize-wasm64.wast`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast>

## Fast answer

Binaryen’s `directize` pass is a late indirect-call cleanup pass that tries to replace some `call_indirect` sites with either:

- a direct `call` / `return_call`, or
- a statically known trap represented as `unreachable` (while still preserving argument side effects), or
- for a narrow `select` shape, an `if` whose arms are direct calls and/or `unreachable`.

The actual `version_129` contract is:

1. analyze tables module-wide with `TableUtils::computeTableInfo(...)`
2. skip the pass entirely if no table has entry-level information worth using
3. walk functions in parallel
4. only inspect `CallIndirect` nodes
5. directize a call only when the target index is a constant, or a `select` whose two arms each resolve to either a known target or a known trap
6. preserve the original indirect call if the target remains unknown
7. run `ReFinalize()` on touched functions because rewriting can change result types and introduce new locals

The most durable source-derived facts are:

- `directize` is the final top-level pass in the no-DWARF default optimize tail.
- `pass.cpp` explicitly says it may enable more `inlining` / `dae` opportunities, but that you need `--converge` to come back and exploit them.
- In `version_129`, the implementation only visits `call_indirect` / `return_call_indirect`.
  - It does **not** directly optimize `call_ref`.
- Constant target indices use a three-way result:
  - `Known(target function)`
  - `Trap`
  - `Unknown`
- Imported, exported, or mutated tables are conservatively treated as modifiable.
- The optional `--pass-arg=directize-initial-contents-immutable` mode loosens that by allowing optimization from the known initial table contents even when the table may later grow or otherwise change.
- Flat table inference is deliberately conservative:
  - all relevant element-segment offsets must be constants
  - the segment element type must be function-typed
  - overflow or obviously-invalid layout makes the whole table unsuitable for entry-level optimization
- Type compatibility uses `HeapType::isSubType(...)`, not exact signature-name equality.
  - That is why GC subtype cases can directize successfully.
- A bad target can become `unreachable`, and Binaryen intentionally keeps child side effects instead of dropping them silently.
- `select` handling is narrow:
  - both arms must resolve to something non-unknown
  - operands are stored to fresh locals once
  - the rewritten shape is an `if`, not a fancier merged call expression
- `call-utils.h` has TODOs for nested selects and mixed known/unknown arms, so those are deliberate current limitations, not omissions in the test prose.

## Where it appears in the scheduler

## Registered pass surface

`pass.cpp` registers:

- `directize`
  - description: “turns indirect calls into direct ones”

`passes.h` declares:

- `createDirectizePass()`

There is no public `directize-always` or similarly named helper variant in `version_129`.

## Late-tail placement

In the canonical no-DWARF default optimize path used in this repo, the post-pass tail is:

- `dae-optimizing`
- `inlining-optimizing`
- `duplicate-function-elimination`
- `duplicate-import-elimination`
- `simplify-globals-optimizing`
- `remove-unused-module-elements`
- `string-gathering`
- `reorder-globals`
- `directize`

The most important scheduler comment is in `pass.cpp` right above this tail ending:

- `reorder-globals` is run after optional `string-gathering`
- then `directize` runs
- and the source comment says this may allow more `inlining` / `dae` opportunities, but you need `--converge` for that

That gives the most useful beginner summary of scheduler meaning:

- `directize` is intentionally *late*
- it sees the already-cleaned table/global/module surface
- and Binaryen knows it can unlock more work, but the ordinary one-pass preset stops there unless convergence is requested

That last point matters a lot for a future Starshine scheduler. Modeling only the top-level order is not enough if a future preset adds a `converge` mode.

## Saved generated-artifact `-O4z` audit

The saved ordered replay records:

- slot `56`: `directize`

The saved Binaryen debug log records the tail as:

- `string-gathering`
- `reorder-globals`
- `directize`

with the `directize` section taking roughly `0.0198565` seconds in that captured run.

I did not find source evidence that `Directize.cpp` itself explicitly launches a nested optimize-after-directize cleanup pass. The debug log does show a nested-pass line during `directize`, but I am treating any explanation of that internal logging detail as uncertain unless further Binaryen runner internals are audited.

## Actual implementation structure

## 1. `run(Module*)` is tiny and mostly about preconditions

`Directize` itself is a small module pass wrapper.

Its top-level flow is:

1. if the module has no tables, return
2. read the optional pass arg `directize-initial-contents-immutable`
3. compute `TableUtils::TableInfoMap`
4. check if any table reports `canOptimizeByEntry()`
5. if none do, return
6. otherwise run a function-parallel `FunctionDirectizer`

That means the pass spends its interesting logic in two places:

- module-wide table analysis
- per-function `call_indirect` rewriting

## 2. Module-wide table analysis is the real gatekeeper

`Directize.cpp` relies on `TableUtils::computeTableInfo(...)`.

That helper computes, for each table:

- `mayBeModified`
- `initialContentsImmutable`
- `flatTable`

and then exposes one very important predicate:

- `canOptimizeByEntry()`

A table is usable for directization by entry only when:

- either it cannot be modified at all, **or** Binaryen was told the initial contents are immutable,
- and Binaryen successfully flattened the table contents to a known index-to-function map.

This is the first big beginner correction:

- `directize` is not “see constant index, emit direct call”
- it is “see constant index **and** have entry-level table knowledge that makes the result sound”

## 3. `FlatTable` is deliberately conservative

`FlatTable` is built from the module’s table segments.

Binaryen only considers a table flat / directly inspectable when all relevant segments meet narrow conditions:

- the segment offset is a constant expression
- the segment element type is function-typed
- the computed segment range does not overflow or extend past `table.initial`

If any relevant segment fails those checks, `flatTable.valid` becomes false and entry-level directization is disabled for that table.

Important practical consequences:

- non-constant segment offsets are a bailout
- obviously-invalid segment layout is a bailout
- non-function element typing is a bailout
- Binaryen does not try a clever partial proof here

This is why some tests that *look* like they should imply a trap are intentionally left alone: the table analysis refuses to pretend it understands a table layout it could not flatten safely.

## 4. `mayBeModified` is broader than just `table.set`

`computeTableInfo(...)` marks a table modifiable if any of the following is true:

- the table is imported
- the table is exported
- a `table.set` exists in any function body
- a `table.fill` exists in any function body
- a `table.copy` writes into that table in any function body
- a `table.init` writes into that table in any function body

This matters because beginners often expect only explicit `table.set` to block directization.

Binaryen is broader:

- if runtime code can overwrite table entries, it assumes an observed initial slot might stop being reliable

One caveat:

- I found shipped lit tests for `table.set`, `table.fill`, and `table.init`
- I did **not** find a dedicated `directize` lit test that isolates the `table.copy` barrier, even though the source clearly models it

So `table.copy` is a direct source fact, but not one I found explicitly mirrored in the shipped directize test trio.

## 5. `initialContentsImmutable` is weaker than “table never changes”

`table-utils.h` makes a subtle distinction that is essential for this pass.

`initialContentsImmutable` means:

- the initial table contents are not overwritten
- but later growth or appended entries may still happen

This is weaker than `!mayBeModified`.

That is why imported/exported/mutated tables can still become partially optimizable under:

- `--pass-arg=directize-initial-contents-immutable`

The pass can then trust known initial slots, but it still must remain conservative about entries that are outside the known initial flattened content.

That distinction is one of the easiest things to miss if you only skim the tests.

## 6. Function rewriting is parallel and visits only `CallIndirect`

`FunctionDirectizer` is a `WalkerPass<PostWalker<...>>` with:

- `isFunctionParallel() -> true`

and it implements only:

- `visitCallIndirect(CallIndirect* curr)`

That yields two important facts:

- the pass is function-parallel once the table facts are precomputed
- the pass does **not** visit `CallRef`

So in `version_129`, `directize` really means:

- directize constant-table `call_indirect` sites
- including the tail-call form represented by `CallIndirect` with `isReturn = true`

The pass name sounds broader than the current implementation surface.

## 7. Constant target indices go through a three-way classifier

For a constant target, `getTargetInfo(...)` returns one of:

- `Known{name}`
- `Trap{}`
- `Unknown{}`

The classification rules are:

### `Unknown`

- target expression is not a constant
- or index is beyond the flattened known-prefix size and the table may still be modified / appended later

### `Trap`

- constant index names a known-null hole inside the known flattened range
- or names a function whose type is not a subtype of the `call_indirect` heap type
- or is out of bounds for a table that cannot later change in a way that would make that index valid

### `Known`

- constant index lands on a known function name
- and that function type is a subtype of the indirect call type

This is the second major beginner correction:

- `directize` is not binary success/failure
- it has a useful middle category where the answer is “we still do not know enough, preserve the indirect call”

## 8. Type compatibility uses subtyping, not exact equality

When a constant index lands on a function, Binaryen checks:

- `HeapType::isSubType(func->type.getHeapType(), original->heapType)`

So the condition is not:

- “the declared types are textually identical”

It is:

- “the concrete target function type is a subtype of the expected indirect-call heap type”

That is exactly why the GC lit tests matter.

`directize-gc.wast` shows:

- supertype call to subtype target can directize
- incompatible subtype/supertype direction becomes a known trap
- direct calls may expose a more refined result type than the original indirect-call site had, which then requires IR repair

## 9. Known traps become `unreachable`, but child effects are preserved

If `getTargetInfo(...)` says a constant target is a definite trap, `Directize.cpp` does **not** just delete the whole call.

Instead it replaces the site with:

- dropped children as needed
- followed by `unreachable`

The source comment explains the policy:

- Binaryen is allowed to replace one trap with another during optimization, but not to remove the trapping behavior entirely by default

The tests make this very concrete:

- a bad constant index can become `unreachable`
- but a side-effectful argument like `local.tee` is still evaluated and then dropped first

So a future port must preserve:

- side-effect retention
- trap preservation
- and the fact that the result may type as `unreachable`, which can require later type repair

## 10. Known direct targets become `call` / `return_call`

If the target is known-good, `makeDirectCall(...)` builds:

- `call $target ...`
- or `return_call $target ...`

using the target function’s actual result type and the original `isReturn` flag.

That means `return_call_indirect` can become `return_call`, not merely an ordinary `call`.

The directized call can also refine the result type if the target function’s type is more specific than the original indirect-call type.

That refinement is intentional, but it is why the pass tracks `changedTypes`.

## 11. `select` target rewriting is narrow but important

If the target is not a constant, `Directize.cpp` tries one more helper:

- `CallUtils::convertToDirectCalls(...)`

That helper only handles a very specific shape:

- the indirect target is a `select`
- the select itself is not `unreachable`
- both arms classify as either `Known` or `Trap`
- none of the call operands are `unreachable`

If those conditions hold, Binaryen rewrites the call into:

1. fresh locals storing each original operand once
2. an `if` on the select condition
3. one branch per arm, each containing either a direct call or `unreachable`

The helper deliberately bails out when:

- either arm is `Unknown`
- the select type is already `unreachable`
- any operand is `unreachable`

The helper comments also contain two important TODO-style limits:

- nested selects / more than two targets are not supported here
- mixed known-plus-unknown cases are not yet lowered to a partial directization shape

So the real implementation is:

- “tiny, safe select-to-if lowering for two-arm known/trap targets”

not:

- “general indirect-call target simplification”

## 12. Added locals and refined results require `ReFinalize()`

`CallUtils::convertToDirectCalls(...)` may add locals.
`makeDirectCall(...)` may refine a result type.
A trap replacement may turn a formerly reachable expression into `unreachable`.

`FunctionDirectizer` therefore tracks `changedTypes` and, after walking the function, runs:

- `ReFinalize().walkFunctionInModule(func, getModule())`

`type-updating.h` explicitly documents this pattern as one of the standard ways to repair IR typing after batch edits.

This matters for two subtle reasons:

- new locals can be non-nullable and require proper final local typing in the surrounding function
- a rewritten direct call can have a more specific result type than the original `call_indirect`

The GC tests demonstrate both of those ideas in real shapes.

## What the shipped tests actually prove

## `directize_all-features.wast`

This large test is the main behavior map.
It proves all of the following:

- a constant in-range target can become a direct call
- explicit table operands are handled
- multiple tables are handled
- table-edge indices like `0` and the last initialized index are handled
- imported tables are not optimized in normal mode, but can be optimized in immutable-initial-contents mode
- exported tables are treated similarly
- non-constant element-segment offsets disable the flat-table reasoning path
- a non-constant call index is not optimized
- a known bad index can become `unreachable`
- a missing/null slot inside the known range can become `unreachable`
- a wrong-type target can become `unreachable`
- `return_call_indirect` can become `return_call`
- `select` between two constant targets can become an `if` with two direct calls
- `select` with trap arms can become an `if` with `unreachable` branches
- `select` with unknown arms is left alone
- unreachable conditions / arms / operands intentionally disable the optimization
- a non-nullable reference argument can be stored in a non-nullable fresh local in the lowered `if` form
- `table.set`, `table.fill`, and `table.init` all block optimization in normal mode but allow known-initial-slot optimization in immutable mode
- invalid or weirdly out-of-bounds element layouts are handled conservatively as no-ops instead of crashing the pass

## `directize-gc.wast`

This test proves the subtype story:

- calling a subtype with a supertype expectation can directize
- the reverse direction can become a known trap
- directization can expose a more refined result type and therefore require IR type repair

This is a very important guard against a naive exact-signature-only port.

## `directize-wasm64.wast`

This test proves the index logic is not accidentally 32-bit-truncated.

The important case is:

- `i64.const 4294967297`

In a wasm64 table, Binaryen must treat that as the real large index, not the low 32 bits.
The test expects a trap rewrite, not a mistaken direct call to the slot at `1`.

## Important nuance from the tests: hole vs beyond-known-prefix

The most interesting immutable imported-table test is the non-contiguous one.

Binaryen’s behavior there is:

- holes **inside** the flattened known prefix become known traps
- but an index **beyond** the flattened known prefix remains unknown on a mutable/imported table, even in immutable mode, because later appends may still make that index valid

In the shipped example:

- indices `0` and `2` become `unreachable`
- indices `1` and `3` become direct calls
- index `4` remains indirect

That is a subtle but very real contract. The pass does **not** equate “inside table.initial” with “known forever.”

## Analysis and helper dependencies

`directize` depends directly on:

- `TableUtils::computeTableInfo(...)`
- `TableUtils::TableInfo::canOptimizeByEntry()`
- `CallUtils::convertToDirectCalls(...)`
- `HeapType::isSubType(...)`
- `Builder`
- `ReFinalize`
- `type-updating.h`’s “repair types after edits” contract

It also depends indirectly on table-analysis helpers inside `TableUtils`:

- constant segment offsets
- function-typed segment contents
- mutation scanning for `table.set` / `table.fill` / `table.copy` / `table.init`

It notably does **not** depend on:

- `Effects`
- liveness
- CFG reasoning
- branch analyses
- whole-program escape analysis
- nested optimize-after-directize reruns in `Directize.cpp` itself
- arbitrary constant propagation beyond literal constants and a tiny `select` shape

So this is not a heavy dataflow pass. It is a small, table-facts-driven late canonicalization pass.

## Pass interactions and scheduler meaning

## After late module/global cleanup

Because `directize` runs after:

- `duplicate-import-elimination`
- `simplify-globals-optimizing`
- late `remove-unused-module-elements`
- optional `string-gathering`
- `reorder-globals`

it sees the cleaned-up late module state.

Practical meaning:

- dead global/module clutter has already been reduced
- string global gathering and global layout are already settled
- directization is one of the last chances to simplify function bodies before the preset stops

## Before more boundary work only in `--converge`

The strongest source-level interaction note is the `pass.cpp` comment:

- directization may enable more inlining / DAE / related work
- but you need `--converge` to loop back and exploit it

That means a future Starshine port must be careful not to tell a misleading story like:

- “directize is the last pass so its effects do not matter much”

Binaryen explicitly expects it can matter.
It is just deliberately placed at the end of the ordinary one-shot tail.

## Relation to `reorder-globals`

The source shows scheduler adjacency, but I did **not** find a stronger direct code-level dependence where `Directize.cpp` cares about global order specifically.

So the strongest honest claim is:

- `reorder-globals` finishes late global layout first
- `directize` then performs the final indirect-call cleanup step on the already-settled module

Anything stronger would be inference, not a direct source claim.

## Easy misunderstandings to avoid

- It is **not** a general “all indirect calls become direct calls” pass.
  - In `version_129`, it only visits `CallIndirect`.
- It is **not** a `call_ref` optimizer.
- It is **not** a general constant-propagation pass.
  - It only understands literal constant indices and a tiny `select` pattern.
- It is **not** purely local.
  - It depends on module-wide table facts first.
- It is **not** limited to known direct calls.
  - Some sites become `unreachable` instead.
- It is **not** safe to optimize imported/exported/mutated tables in normal mode.
- It is **not** exact-signature-only.
  - GC subtype compatibility matters.
- It is **not** guaranteed to leave types unchanged.
  - Result refinement and fresh locals can force refinalization.
- It is **not** proof that later optimizing reruns happen automatically.
  - The default pipeline stops here unless `--converge` is used.

## What a future Starshine port must preserve

## Core parity checklist

A faithful port should preserve all of these:

- final-tail placement after `reorder-globals`
- the `--converge` implication that later optimization opportunities may be exposed here
- the module-wide table-info prepass
- the distinction between:
  - immutable initial contents
  - fully unmodifiable tables
- fast no-op exits when there are no tables or no entry-optimizable tables
- the fact that only `call_indirect` / `return_call_indirect` are handled today
- constant-target classification into `Known` / `Trap` / `Unknown`
- subtype-based target compatibility checks
- trap-to-`unreachable` replacement with side-effect preservation
- `select`-target lowering only for the narrow current supported shape
- fresh-local materialization for duplicated operands in the `select` rewrite
- post-rewrite refinalization when types changed
- wasm64-correct full-width index handling
- conservative bailouts for non-flat or not-well-understood table layouts

## Table-specific parity checklist

A faithful port should also preserve:

- imported tables count as modifiable
- exported tables count as modifiable
- `table.set`, `table.fill`, `table.copy`, and `table.init` count as mutation barriers
- flat-table inference only from constant-offset, function-typed element segments
- holes inside the known flattened prefix are definite traps
- indices beyond the known flattened prefix on mutable tables remain unknown
- invalid / overflowing / nonsensical segment layout disables optimization instead of inventing a stronger answer

## Representation-specific Starshine note

Binaryen can cheaply replace `call_indirect` with direct calls because its IR already names direct call targets symbolically.
A future Starshine port may need to preserve additional local invariants around:

- table index immediates
- direct-call target representation
- result-type repair
- fresh locals introduced by select-lowering

The exact mechanical rewrite surface is Starshine-specific, but the externally visible semantics must match the Binaryen behavior above.

## Open questions and uncertainty

- I found no explicit directize lit case for the `table.copy` mutation barrier, even though `table-utils.cpp` models it directly.
- I did not find a code comment in `Directize.cpp` explaining a stronger relation to `reorder-globals` than simple scheduler adjacency.
- `call-utils.h` is generic enough to talk about indirect-call lowering patterns more broadly, but `Directize.cpp` currently uses it only for `CallIndirect`; I am therefore treating any broader “Binaryen directizes call_ref too” claim as false for `version_129`.
- The saved Binaryen debug log prints a nested-pass line during the directize stage. I did not audit runner internals deeply enough to explain that line with confidence, so I am not treating it as evidence of a directize-specific nested cleanup contract.

## Bottom line

If I had to compress the source contract into one beginner-friendly sentence, it would be:

- Binaryen’s `directize` pass is a late table-facts-driven cleanup that turns some constant-index `call_indirect` sites into direct calls, some into preserved-effect traps, and a few `select`-target cases into `if`-over-direct-calls, while staying conservative whenever table mutation or layout knowledge is incomplete.

That is a much better mental model than:

- “replace indirect calls with direct ones when the index is constant.”

## Sources

### Local sources

- `src/passes/optimize.mbt`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`

### Official Binaryen `version_129` sources

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
