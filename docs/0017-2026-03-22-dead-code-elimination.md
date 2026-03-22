# DeadCodeElimination

Status: research baseline for the next default optimize pipeline pass after `OnceReduction`. In Starshine today, `DeadCodeElimination` is scheduled in the first function-local optimize stage, but it still routes through the generic no-op runner. This document is the Binaryen behavior audit plus the migration plan for a real Starshine port.

## Scope

Document how Binaryen's `DeadCodeElimination` pass works on main, enumerate every material behavior visible in the source and upstream tests, spell out source-faithful pseudocode, and break the port into checkpointable Starshine slices.

## Why This Is The Next Pass

In Starshine's generated default optimize pipeline, the first function-local stage begins immediately after the no-DWARF prepasses:

1. `DuplicateFunctionElimination`
2. `RemoveUnusedModuleElements`
3. `MemoryPacking`
4. `OnceReduction`
5. `DeadCodeElimination`

Local proof points:

- [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt#L106) asserts that `pipeline[4]` contains `OptimizePass::DeadCodeElimination`.
- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt#L9613) inserts `DeadCodeElimination` as the first pass in the default function-local optimization group.

Important nuance:

- This is the next individual pass.
- It is not a standalone pipeline segment in Starshine today; it is the first entry inside a grouped function-local stage.

## Current Starshine State

Starshine currently has scheduling but no semantics:

1. `OptimizePass::DeadCodeElimination` exists.
2. It is classified as `FuncLocal`.
3. The default optimize pipeline schedules it.
4. [`make_entry_kind`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt#L9449) still routes it through the generic `noop_func_local_pass`.
5. There is no dedicated runner, no whitebox parity suite, and no integration coverage for its behavior.

So the local state is:

- real scheduling
- no real rewrite logic
- no local type-updating helper for DCE
- no upstream-parity tests

## Upstream Sources Used

Primary implementation source:

- Binaryen `src/passes/DeadCodeElimination.cpp`
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadCodeElimination.cpp

Primary behavior tests:

- Binaryen `test/lit/passes/dce_all-features.wast`
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dce_all-features.wast
- Binaryen `test/lit/passes/dce_vacuum_remove-unused-names.wast`
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dce_vacuum_remove-unused-names.wast
- Binaryen `test/lit/passes/dce-eh.wast`
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dce-eh.wast
- Binaryen `test/lit/passes/dce-stack-switching.wast`
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dce-stack-switching.wast

High-level pass catalog entry:

- Binaryen `README.md`
  - https://github.com/WebAssembly/binaryen/blob/main/README.md

## One-Sentence Summary

`DeadCodeElimination` removes unreachable code inside function bodies by propagating `unreachable` through parent expressions, preserving only the side effects that still occur before control traps or exits, and synchronously updating enclosing control-flow types so the rewritten IR stays valid.

## The Real Model

This is not global DCE and it is not constant folding.

Binaryen's pass is much narrower and more structural:

1. Walk each function in post-order.
2. Detect expressions that are already unreachable because one child is unreachable or because earlier control flow made later code dead.
3. Rewrite those expressions into the minimal side-effect-preserving form:
   - `unreachable` if nothing before the trap/exit matters,
   - `drop(...) ; unreachable` if earlier child evaluation had side effects or observable execution,
   - a `block` of preserved effects followed by `unreachable` if multiple evaluations must remain.
4. Trim trailing instructions in a block after the first unreachable instruction.
5. Update enclosing block / if / try / try_table types immediately when dead child removal means they no longer need a concrete value type.

The core invariant is:

- Preserve everything that still executes before control becomes unreachable.
- Remove everything that is proven not to execute.
- Keep types synchronized while rewriting, not only after the fact.

## Top-Level Skeleton

Binaryen's real pass shape is small:

```text
run_on_function(func):
  typeUpdater.walk(func.body)
  walk_post_order(func.body)

  if saw_pop && inserted_new_blocks:
    fix_eh_block_nested_pops(func)
```

The entire pass hangs off three mechanisms:

1. post-order rewriting
2. a synchronous type/break updater
3. a small set of control-flow-specific rewrites

## Exact Feature Inventory

### 1. Function-parallel pass shape

Binaryen marks the pass as function-parallel.

Implication:

- The pass is purely per-function.
- There is no cross-function state.
- Starshine should also implement this as a function-local pass with no module-global analysis.

Pseudocode:

```text
for each function in module in parallel:
  dce_function(function)
```

### 2. No non-nullable-local fixup requirement

Binaryen explicitly says dead-code removal can only help validation, so the generic non-nullable-local fixup hook is not required.

Important nuance from tests:

- The pass still must avoid leaving stale local uses behind after removing a defining `local.tee` path.
- That is handled by correct dead-child elimination and type updates, not by a post-pass "local fixup" stage.

### 3. Post-order rewriting is essential

Binaryen rewrites parents only after children are already typed and simplified.

Why that matters:

- Parent reachability depends on child types.
- Parent type changes can only be decided after child loss is known.
- This is why a pre-order or one-shot top-down pass is the wrong model.

Pseudocode:

```text
walk_post(expr):
  for child in expr.children:
    walk_post(child)
  rewrite(expr)
```

### 4. Generic non-control-flow rule: unreachable child poisons the parent

For any expression that is not a control-flow structure, Binaryen checks:

1. Is the expression itself `unreachable`?
2. Does it have at least one child with `unreachable` type?

If yes, the parent is dead code induced by that child.

This covers:

- unary ops
- binary ops
- selects
- loads
- stores
- local/global sets
- calls
- call_indirect
- string ops
- most non-control-flow IR nodes

Pseudocode:

```text
rewrite_non_control_flow(expr):
  if expr.type != unreachable:
    return expr

  if no child.type == unreachable:
    return expr

  kept = []
  after_unreachable = false

  for child in expr.children in evaluation_order:
    if after_unreachable:
      note_recursive_removal(child)
      continue

    if child.type == unreachable:
      kept.push(child)
      after_unreachable = true
    else:
      kept.push(drop(child))

  if kept.length == 1:
    return kept[0]
  return block(kept)
```

### 5. Evaluation order is preserved exactly

The child scan is in actual child-evaluation order. That means:

- reachable children before the first unreachable child stay, wrapped in `drop`
- the first unreachable child stays as-is
- all later children are removed entirely

That one rule explains nearly all operator-specific behavior in the tests.

Examples:

1. `i32.add(unreachable, x)` becomes `unreachable`
2. `i32.add(x, unreachable)` becomes `block(drop(x), unreachable)`
3. `store(addr, unreachable)` becomes `block(drop(addr), unreachable)`
4. `store(unreachable, value)` becomes `unreachable`
5. `select(a, b, unreachable)` becomes `block(drop(a), drop(b), unreachable)`
6. `call(f, a, unreachable, b)` becomes `block(drop(a), unreachable)`

This is the most important implementation detail to port correctly.

### 6. Single-child collapse

If the preserved list contains only one expression, Binaryen replaces the parent directly with that expression instead of wrapping it in a block.

That avoids extra structure in simple cases like:

- `local.set x (unreachable)` -> `unreachable`
- `i32.eqz(unreachable)` -> `unreachable`

Pseudocode:

```text
if kept.length == 1:
  replace parent with kept[0]
else:
  replace parent with block(kept)
```

### 7. Block tail truncation after the first unreachable instruction

For a `Block`, Binaryen scans the instruction list and truncates everything after the first item with `unreachable` type.

This handles:

- code after `unreachable`
- code after `return`
- code after `br`
- code after `br_table`
- code after a rewritten parent that is now unreachable

Pseudocode:

```text
rewrite_block(block):
  first = index_of_first(item.type == unreachable)
  if first exists:
    note_recursive_removal(all items after first)
    block.list = block.list[0:first + 1]

    if block.list == [unreachable]:
      return unreachable
```

### 8. Block concrete type is removed when no longer needed

After truncation, Binaryen may change a concrete-typed block to `unreachable` if:

1. the block still has a concrete type,
2. its final instruction is `unreachable`,
3. and no remaining break targets require the block's value type.

This is not just cleanup. It is necessary for correctness after dead breaks are removed.

Pseudocode:

```text
if block.type.isConcrete() &&
   block.last.type == unreachable &&
   !typeUpdater.hasBreaks(block):
  typeUpdater.changeType(block, unreachable)
```

Observed effect:

- blocks with formerly necessary result types can become typeless/unreachable once dead breaks disappear
- blocks with still-live breaks must keep their value types

### 9. `If`: unreachable condition replaces the entire `if`

If the `if` condition itself is unreachable:

- both arms are recursively noted as removed
- the whole `if` is replaced by the condition

That preserves any side effects before the condition trapped and drops everything that would never execute.

Pseudocode:

```text
if if_.condition.type == unreachable:
  note_recursive_removal(if_.then)
  note_recursive_removal(if_.else if present)
  return if_.condition
```

### 10. `If`: both arms unreachable make the `if` unreachable

If both arms are unreachable and the `if` currently has a concrete type, Binaryen changes the `if` type to `unreachable`.

Important nuance:

- This is a type change only.
- It does not replace the whole `if`.
- The condition remains because it still executes.

Pseudocode:

```text
if if_.type != unreachable &&
   if_.has_else &&
   if_.then.type == unreachable &&
   if_.else.type == unreachable:
  typeUpdater.changeType(if_, unreachable)
```

### 11. `Loop`: replace with body only when body was entirely eliminated

Binaryen does not do general loop simplification here.

The only loop-specific rewrite is:

- if the loop body itself is now the literal `unreachable`, replace the loop with that body

Pseudocode:

```text
if loop.body is unreachable:
  return loop.body
```

This is intentionally conservative.

### 12. `Try`: body and all catches unreachable make `try` unreachable

For EH `try`, Binaryen changes the `try` type to `unreachable` when:

1. the `try` has a concrete result type,
2. the `do` body is unreachable,
3. every catch body is unreachable

If any catch remains reachable, the `try` may still complete normally through that catch, so it cannot be made unreachable.

Pseudocode:

```text
all_catches_unreachable = all(catch.type == unreachable)

if try.type != unreachable &&
   try.body.type == unreachable &&
   all_catches_unreachable:
  typeUpdater.changeType(try, unreachable)
```

### 13. `TryTable`: only the body determines normal completion

For `try_table`, Binaryen uses a different rule:

- `try_table` can finish normally only if its body can finish normally

So if the body becomes unreachable and the `try_table` currently has a concrete type, its type changes to unreachable.

Pseudocode:

```text
if try_table.type != unreachable &&
   try_table.body.type == unreachable:
  typeUpdater.changeType(try_table, unreachable)
```

This distinction matters and is explicitly covered in upstream tests.

### 14. Synchronous type updating is not optional

Binaryen relies on `TypeUpdater` during the rewrite, not just after it.

The pass uses it to:

1. note node replacements,
2. note recursive removals of dead subtrees,
3. test whether a block still has live breaks,
4. change node types immediately

Why this matters:

- DCE can remove a break, which changes whether an enclosing block needs a concrete result type.
- That can immediately affect the validity of a parent node.
- Waiting until a later refinalization pass is too late for several upstream test cases.

Required local abstraction:

```text
typeUpdater.noteReplacement(old, new)
typeUpdater.noteRecursiveRemoval(deadSubtree)
typeUpdater.hasBreaks(blockLike)
typeUpdater.changeType(expr, newType)
```

### 15. DCE must not over-refinalize unrelated reference types

The GC/reference tests show a sharp boundary:

- DCE is allowed to propagate `unreachable`
- DCE is not allowed to opportunistically refinalize other types just because it now could

Examples from tests:

- `ref.cast` cases must remain valid nullable/non-nullable combinations
- `try` result types must not be over-tightened except where unreachable propagation requires it

That means the Starshine port must not "retype everything after every edit".

### 16. Branch-value and enclosing-type interactions are first-class behavior

Upstream tests exercise many branch-value edge cases:

- `br` whose value is itself unreachable
- `br_if` with unreachable value or condition
- `br_table` with unreachable index/value interactions
- dead branch removal changing whether an enclosing block still has a value

The pass is not branch-specific in the source file because the generic child rule plus synchronous type updates handle most of it.

But the port must validate all of these categories explicitly because they are where type bugs show up.

### 17. Calls and indirect calls use the generic child-preservation rule

`call` and `call_indirect` are not treated specially in the source.

Observed behavior from upstream tests:

- reachable arguments before the first unreachable arg are preserved as `drop`
- later arguments are removed
- the call itself disappears
- the final expression becomes `unreachable` or `block(drop..., unreachable)`

Pseudocode:

```text
call(arg0, arg1, arg2)
where arg1 is first unreachable

=> block(
     drop(arg0),
     arg1
   )
```

### 18. Loads, stores, unary ops, binary ops, and `select` all use the same rule

The upstream all-features test proves that no operator-specific reasoning is needed for the basic cases.

Behavior summary:

- unary op with unreachable input -> unreachable
- binary op with unreachable left -> unreachable
- binary op with unreachable right -> `drop(left); unreachable`
- load with unreachable address -> unreachable
- store with unreachable address -> unreachable
- store with reachable address and unreachable value -> `drop(address); unreachable`
- `select` with unreachable condition -> drop both values, then unreachable
- `select` with unreachable second value -> drop first value, then unreachable

That is all a consequence of evaluation-order preservation.

### 19. `local.set` and `global.set` become unreachable when their value does

Setters are also just non-control-flow expressions here.

So:

- `local.set x (unreachable)` -> `unreachable`
- `global.set g (unreachable)` -> `unreachable`

This is explicitly important in tests where an enclosing `if` becomes unreachable and that unreachability must propagate through the set, not stop there.

### 20. Dead code after already-unreachable function prefixes is removed aggressively

If a function body starts with `unreachable`, the trailing body disappears. Upstream tests cover this through raw unreachable instructions and through expressions that become unreachable after rewriting.

That means a correct port must treat:

- original unreachable code
- newly-created unreachable code

the same way once it reaches the enclosing block pass.

### 21. EH-specific `Pop` fixup after inserting blocks

Binaryen tracks two per-function booleans:

- `hasPop`
- `addedBlock`

If a function contains `pop` and DCE inserted any new blocks, it runs:

```text
EHUtils::handleBlockNestedPops(func, module)
```

Why:

- DCE can introduce new blocks while rewriting dead children
- nested block structure can change where `pop` instructions live
- EH validation needs a post-fixup for that case

This is a real feature, not a cleanup detail.

### 22. Stack-switching handlers require control-flow-aware value preservation

The stack-switching test proves an important invariant:

- do not blindly drop a block result value if control can branch to that block from a handler edge

Observed cases:

- `resume`
- `resume_throw`

The practical takeaway for Starshine:

- the type/break updater must understand these constructs well enough that DCE does not erase a value that is still required by a handler path

### 23. `br_on_non_null` and `br_on_cast_fail` with unreachable inputs must stay safe

The GC branch tests show another subtlety:

- an unreachable branch input may not have a meaningful heap type
- DCE must not assume it can inspect or reconstruct a more precise heap type in that case

So the port must avoid any implementation that depends on reading refined heap-type information from already-unreachable values.

### 24. String/`local.tee` cases are validation-sensitive

The string tests prove that DCE must handle dead `local.tee` producers carefully.

What can go wrong:

- if the pass removes the tee-producing expression incorrectly
- but leaves later code using the local
- the function becomes invalid

So the correct behavior is:

- once the string op becomes unreachable because one child is unreachable,
- preserve only the evaluations before the first unreachable child,
- drop everything after,
- let enclosing block truncation remove later local uses

### 25. The pass intentionally composes with `Vacuum` and `RemoveUnusedNames`, but does not subsume them

The `dce_vacuum_remove-unused-names.wast` test shows Binaryen often runs:

```text
--dce --vacuum --remove-unused-names
```

That does not mean DCE itself performs those optimizations.

DCE's job ends at:

- propagate unreachable,
- preserve pre-unreachable side effects,
- trim dead tails,
- synchronize types.

Anything like:

- removing leftover `drop(nop)` shapes,
- flattening silly blocks further,
- stripping unused local names,

belongs to later passes.

## What The Pass Does Not Do

These non-features are important for a faithful port:

1. It does not remove unused functions, globals, tables, or data segments.
2. It does not fold constant conditions in general.
3. It does not do effect analysis beyond structural reachability.
4. It does not require a full function refinalization pass.
5. It does not try to be a general CFG simplifier.
6. It does not replace `Vacuum`, `RemoveUnusedBrs`, or `RemoveUnusedNames`.

## Operational Pseudocode For A Starshine Port

The clean local model is:

```text
run_dead_code_elimination_on_func(func):
  ctx = DeadCodeCtx::seed(func.body)
  body = walk_texpr_post(func.body, ctx)

  if ctx.has_pop && ctx.added_block:
    body = fix_block_nested_pops(body)

  return func.with_body(body)
```

Where the walk does:

```text
rewrite_expr(expr, ctx):
  rewrite children first

  if expr is Block:
    truncate after first unreachable item
    note removed tails in ctx
    maybe collapse single unreachable child
    maybe set block.type = unreachable if no live breaks remain
    return expr

  if expr is If:
    if condition is unreachable:
      note children removed
      return condition
    if both arms unreachable and if has concrete type:
      mark if unreachable
    return expr

  if expr is Loop:
    if body is literal unreachable:
      return body
    return expr

  if expr is Try:
    if body unreachable and all catches unreachable and try has concrete type:
      mark try unreachable
    return expr

  if expr is TryTable:
    if body unreachable and try_table has concrete type:
      mark try_table unreachable
    return expr

  if expr is not control-flow:
    if expr.type == unreachable and any child.type == unreachable:
      return preserve_prefix_effects_then_unreachable(expr.children)
    return expr
```

And the state must keep:

```text
DeadCodeCtx {
  break_uses : map[label_id -> live_break_count]
  replacements : map[old_node -> new_node]
  has_pop : bool
  added_block : bool
}
```

Starshine may not need Binaryen's exact `TypeUpdater` API, but it does need the same semantic services.

## Required Starshine Support Abstractions

The port will be much cleaner if it introduces a tiny DCE-specific support layer instead of burying all type bookkeeping inside the walker.

Minimum required helpers:

1. `dce_note_recursive_removal(texpr_or_tinstr)`
2. `dce_note_replacement(old_id, new_id)`
3. `dce_block_has_live_breaks(label_id)`
4. `dce_change_instr_type(instr, new_type)`
5. `dce_preserve_prefix_effects_then_unreachable(children)`
6. `dce_truncate_block_after_first_unreachable(instrs)`
7. `dce_fix_block_nested_pops(func)` or a conservative local equivalent

Without those helpers the implementation will likely become brittle and impossible to checkpoint safely.

## Migration Plan In Checkpointable Slices

### Slice 1. Pass plumbing and parity harness

Goal:

- Replace the `noop_func_local_pass` entry with a real `run_dead_code_elimination` runner shell.

Local files:

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt)
- new DCE tests in `src/optimization`
- possibly [`src/optimization/imports.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/imports.mbt)

Work:

1. Add a dedicated runner symbol.
2. Dispatch `OptimizePass::DeadCodeElimination` to it in `make_entry_kind`.
3. Add pipeline-plumbing tests proving the pass is no longer routed through the no-op shell.
4. Add one empty-function smoke test.

Checkpoint:

- pass is wired
- no behavior change yet
- tests prove dedicated dispatch exists

### Slice 2. Generic non-control-flow unreachable-child rewrite

Goal:

- Implement the core `preserve prefix effects, then unreachable` rule for non-control-flow typed instructions.

Work:

1. Walk children in evaluation order.
2. Detect the first unreachable child.
3. Wrap earlier surviving children in `drop`.
4. Remove later children recursively.
5. Return either a single child or a new `block`.

Initial operator coverage target:

- unary
- binary
- load
- store
- local/global set
- `select`
- direct call
- indirect call

Tests to port first:

- right-unreachable binary case
- store address vs value unreachable cases
- select condition/value ordering cases
- call and call_indirect argument ordering cases

Checkpoint:

- upstream ordering-sensitive child behavior matches on a focused whitebox suite

### Slice 3. Block tail truncation and single-unreachable collapse

Goal:

- Make enclosing blocks trim dead tails after the first unreachable item.

Work:

1. Detect the first unreachable instruction in block order.
2. Remove trailing instructions.
3. Note recursive removal of removed tails.
4. Collapse blocks of the form `[unreachable]` to the single child.

Tests:

- code after `return`
- code after `br`
- code after rewritten unreachable expression
- trivial `unreachable`-prefix function case

Checkpoint:

- dead tails disappear correctly
- later instructions are not accidentally preserved

### Slice 4. Live-break tracking and synchronous block type updates

Goal:

- Add the minimal local `TypeUpdater` equivalent needed for DCE.

Work:

1. Track which blocks / loops / try-like constructs still have live incoming breaks.
2. Update that information when dead subtrees are removed.
3. Allow DCE to mark a concrete block as `unreachable` when no live breaks remain and the tail is unreachable.

Tests:

- typed block becomes unnecessary after dead branch removal
- typed block remains necessary when a live break still exists
- branch-value regression cases from upstream

Checkpoint:

- no post-pass refinalization is required for the tested block cases

### Slice 5. `If` handling

Goal:

- Port the two `if`-specific rules exactly.

Work:

1. If condition unreachable: replace whole `if` with condition and note arm removal.
2. If both arms unreachable and type concrete: mark `if` unreachable.

Tests:

- unreachable condition case
- both-arms-unreachable case
- ancestor type-change regressions from upstream

Checkpoint:

- `if` cases match Binaryen structurally on the focused fixtures

### Slice 6. `Loop` handling

Goal:

- Port the conservative loop rule only.

Work:

1. Detect when loop body is the literal unreachable node after child rewriting.
2. Replace the loop with the body.
3. Leave all other loops alone.

Tests:

- fully unreachable loop body
- branch-back loop that must remain

Checkpoint:

- loop behavior matches the upstream covered cases without over-simplifying

### Slice 7. EH `try` and `try_table` handling

Goal:

- Port the control-flow-specific unreachable propagation for EH nodes.

Work:

1. `Try`: change type to unreachable only when body and all catches are unreachable.
2. `TryTable`: change type to unreachable when body is unreachable.
3. Add a post-pass nested-pop fixup strategy for functions containing `pop` if blocks were inserted.

Tests:

- upstream `dce-eh.wast` reachability matrix
- at least one local `pop` / inserted-block regression

Checkpoint:

- EH output validates
- try vs try_table distinction is locked in tests

### Slice 8. Branch-value and ancestor-propagation stress cases

Goal:

- Port the hard type-propagation regressions that prove the local updater is good enough.

Work:

1. Add the upstream branch-value fixtures:
   - unreachable `br` values
   - unreachable `br_if`
   - `br_table` cases
   - ancestor block type changes
2. Add focused regression fixtures where child loss changes ancestor break usage.

Checkpoint:

- all known "refinalize too late" cases pass locally

### Slice 9. GC, reference, and string-sensitive cases

Goal:

- Prove the DCE port is safe for the feature-rich typed IR surface Starshine already exposes.

Work:

1. Port `br_on_non_null` and `br_on_cast_fail` unreachable-input tests.
2. Port `ref.cast` no-over-refinalize test.
3. Port `try` reference-result no-over-refinalize test.
4. Port the `string.new_wtf16_array` / `local.tee` regressions.

Current status:

- `docs/0041-2026-03-22-dead-code-elimination-gc-branch-ops.md`,
  `docs/0042-2026-03-22-dead-code-elimination-ref-cast.md`,
  `docs/0043-2026-03-22-dead-code-elimination-unary-ref-tests.md`, and
  `docs/0044-2026-03-22-dead-code-elimination-ref-get-desc.md` land the GC
  branch and unary rewrites.
- `docs/0046-2026-03-22-dead-code-elimination-nested-try-table-coverage.md`
  closes the separate nested concrete ref-result `try_table` coverage question
  that stayed open after the EH rewrite slice.
- `docs/0047-2026-03-22-dead-code-elimination-typed-surface-blockers.md`
  records that the remaining string-sensitive and EH `pop` follow-ups are
  blocked in this repo today because the typed IR does not yet expose string
  operators or EH `try` / `pop`.
- Remaining actionable work in this lane is therefore grouped-pipeline
  interaction coverage for the already-landed `TTryTable` / GC rewrite set.

Checkpoint:

- DCE propagates unreachability without inventing unrelated type refinements

### Slice 10. Stack-switching coverage

Goal:

- Prove DCE does not drop values still needed by handler-based control flow.

Work:

1. Port `resume` and `resume_throw` fixtures from `dce-stack-switching.wast`.
2. Confirm handler-target block results survive DCE where required.

Checkpoint:

- stack-switching fixtures validate and match upstream behavior

### Slice 11. Pipeline enablement and interaction validation

Goal:

- Turn the port on in the real optimize pipeline with enough confidence that follow-on passes see good output.

Work:

1. Enable the real runner in the default grouped function-local stage.
2. Add pipeline tests proving the pass still sits before `RemoveUnusedNames`, `RemoveUnusedBrs`, and `Vacuum`.
3. Run local comparisons with:
   - DCE alone
   - DCE + Vacuum
   - default grouped function stage

Checkpoint:

- standalone DCE tests pass
- grouped-pipeline tests pass
- interaction output is stable enough for the next pass work

## Validation Plan

1. Add focused whitebox tests in `src/optimization` for each rule category before implementing that slice.
2. Port the upstream lit fixtures in small groups instead of one giant snapshot.
3. After each slice, run:
   - `moon test src/optimization --target native`
   - `moon test src/cmd --target native` if pipeline plumbing changed
4. After EH / GC slices, validate rewritten outputs explicitly where possible.
5. After final enablement, compare Starshine against Binaryen on:
   - upstream-inspired focused DCE fixtures
   - `examples/modules/*.wat`
   - the grouped default optimize function stage

## Correctness Constraints

1. Preserve child evaluation order exactly.
2. Never erase side effects that execute before the first unreachable child.
3. Never keep code that is proven not to execute after the first unreachable child or block item.
4. Update enclosing block / if / try / try_table types synchronously enough that the rewritten IR stays valid.
5. Do not over-refinalize unrelated GC/reference types.
6. Keep EH `pop` handling correct when inserting new blocks.
7. Keep stack-switching handler-result behavior intact.
8. Keep the port function-local and parallel-friendly.

## Performance Impact

Expected wins:

1. Smaller function bodies before `Vacuum`, `RemoveUnusedBrs`, and `RemoveUnusedNames`.
2. Better cleanup of dead tails created by earlier passes like `OnceReduction`.
3. Better input quality for later local simplification passes.

Expected costs:

1. A real type/break updater is more complex than the pass source initially suggests.
2. EH / GC / stack-switching regressions will dominate validation effort.

This is still a high-value pass because it is the first cleanup pass in the main function-local stage, so later grouped passes benefit from its output.

## Open Questions

1. Should Starshine build a tiny DCE-specific type updater, or factor out a reusable typed control-flow updater for later local passes too?
2. Is there already enough local EH block/pop infrastructure to mirror Binaryen's nested-pop fixup, or does that need its own prep slice?
3. Should the first landed version deliberately exclude stack-switching fixtures behind a temporary feature gate, or is full-feature parity required immediately for this pass?

Current blocker note:

- In the current repo state, typed `TTry` / `pop` nodes and typed string
  operators are not exposed in the local IR surface, so those follow-ups cannot
  be ported directly until the underlying instruction surface exists.
