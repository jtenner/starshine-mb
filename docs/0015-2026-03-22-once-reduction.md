# OnceReduction

Status: research baseline for the next default optimize pipeline pass after `MemoryPacking`. In Starshine today, `OnceReduction` is scheduled but not implemented, so this document is both a Binaryen behavior audit and the implementation blueprint for the first real port.

## Scope

Document how Binaryen's `OnceReduction` pass works today on main, enumerate every material feature and conservative limitation visible in the source and upstream tests, provide source-faithful pseudocode, and map the work into Starshine-sized implementation slices.

## Why This Is The Next Pass

In Starshine's generated default optimize pipeline, the relevant pre-pass sequence is currently:

1. `DuplicateFunctionElimination`
2. `RemoveUnusedModuleElements`
3. `MemoryPacking`
4. `OnceReduction`

Local proof points:

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt) schedules `OptimizePass::OnceReduction` immediately after `MemoryPacking` when `opt_level >= 2`.
- [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt) asserts that ordering in the default optimize pipeline.

## Current Starshine State

Starshine currently has only the scheduling shell:

1. `OptimizePass::OnceReduction` exists in [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt).
2. The generated pipeline schedules it.
3. `make_entry_kind` still routes it through the generic module-wide no-op path instead of a dedicated runner.
4. The CLI pass description in [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt) is inaccurate for Binaryen semantics. Binaryen's pass is not a generic "used once" simplifier; it is specifically about removing redundant execution of provably run-once or annotated-idempotent functions.

So the local state is:

- real scheduling
- no real semantics
- no dedicated runner
- no parity tests

## Upstream Sources Used

Primary implementation source:

- Binaryen `src/passes/OnceReduction.cpp`
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/OnceReduction.cpp

Primary behavior tests:

- Binaryen `test/lit/passes/once-reduction.wast`
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/once-reduction.wast

## One-Sentence Summary

`OnceReduction` removes redundant direct calls and redundant monotonic guard writes once Binaryen proves that a function can only meaningfully execute once, either because it matches the exact once-global pattern or because it is annotated `@binaryen.idempotent`.

## The Real Model

Binaryen tracks "once-ness" through a monotonic-global abstraction:

- A candidate once-global starts at some unknown integer value.
- Every relevant reachable write to it must be a constant integer greater than zero.
- The global must never be observably read except for the single top-of-function guard read in the exact once-function pattern.
- Imported globals and exported globals are disqualified because external code can read or write them.

If those rules hold, then "global is nonzero" means "the once payload has already been entered at least once", which is strong enough to delete later direct calls that are dominated by that fact.

That is the key subtlety: the pass is about proving "entered once already", not "fully completed once already". That distinction is why the pass can remove some repeated calls but must stay conservative around wrapper loops and cross-function body cleanup.

## Exact Feature Inventory

### 1. Candidate once-global discovery

Binaryen seeds every global as a possible once-global only if:

- the global's value type is integer, and
- the global is not imported

Then it invalidates candidates as soon as it proves otherwise.

Source-faithful pseudocode:

```text
for each global in module.globals:
  onceGlobals[global] = global.type.is_integer && !global.is_imported

for each export in module.exports:
  if export.kind == global:
    onceGlobals[export.global] = false
```

Important observed behavior:

- Initial value does not matter. `0`, `42`, or `global.get $import` are all allowed.
- Only integer globals participate.
- Exported globals are rejected even if the export is the only visible external edge.

### 2. Global write monotonicity rule

A candidate once-global remains valid only if every relevant reachable integer write stores a constant value greater than zero.

Pseudocode:

```text
visit_global_set(name, value):
  if !value.type.is_integer:
    return

  if value is const && value.integer > 0:
    return

  onceGlobals[name] = false
```

Observed consequences:

- Writing `1`, `2`, `42`, or `1337` is fine.
- Writing `0` anywhere disqualifies the global.
- Writing a non-constant integer expression disqualifies the global.
- Unreachable-valued sets are ignored by this scanner step, but the exact once-pattern still separately requires the top guard-setting write to be reachable.

### 3. Exact once-function pattern recognition

Binaryen recognizes only a very narrow source pattern, and only for functions with no params and no results:

```text
function foo() {
  if (global.get once) return;
  global.set once, POSITIVE_CONST;
  ...
}
```

The implementation requires:

1. function params == none
2. function results == none
3. body is a `Block`
4. block length >= 2
5. first item is `If`
6. `If.condition` is exactly `GlobalGet`
7. `If.then` is exactly `Return`
8. no `else`
9. second item is `GlobalSet`
10. set target matches the condition global
11. second-item set itself is not unreachable

Pseudocode:

```text
get_once_global(body):
  if body is not Block:
    return none
  if body.items.length < 2:
    return none

  iff = body.items[0]
  set = body.items[1]

  if iff is not If:
    return none
  if iff.condition is not GlobalGet(g):
    return none
  if iff.then is not Return:
    return none
  if iff.else exists:
    return none

  if set is not GlobalSet(g2, value):
    return none
  if g2 != g:
    return none
  if set.type == unreachable:
    return none

  return g
```

Observed non-features from tests:

- A leading `nop` before the `if` prevents recognition.
- A `nop` between the `if` and `global.set` prevents recognition.
- An `else` branch prevents recognition.
- Mismatched `global.get` / `global.set` names prevent recognition.
- A non-block body prevents recognition.
- A one-instruction body is too short.
- Generalized forms like `if (!once) { ... }` are not handled.
- Nested or inlined occurrences of the pattern are not searched for.

### 4. Guard-read exception and all other reads are disqualifying

Binaryen tracks all `global.get` reads seen while scanning a function. If the function matches the exact once pattern above, it subtracts exactly one read for the top guard. Any remaining read count for that global makes the global non-once.

Pseudocode:

```text
visit_global_get(name):
  readGlobals[name] += 1

visit_function(func):
  if func has no params and no results:
    g = get_once_global(func.body)
    if g exists:
      onceFuncGlobals[func] = g
      readGlobals[g] -= 1

  for each (global, count) in readGlobals:
    if count > 0:
      onceGlobals[global] = false
```

Observed consequences:

- Extra reads in callers disqualify the global.
- Extra reads inside the once function after the guard disqualify the global.
- Only the single recognized guard read is exempt.

### 5. A function is once only if its recognized global survives all invalidation

Pattern recognition alone is not enough. After the full scanner runs, Binaryen removes the once-function classification from any function whose guard global was later proven non-once.

Pseudocode:

```text
for each function -> onceGlobal in onceFuncGlobals:
  if onceGlobal exists and onceGlobals[onceGlobal] == false:
    onceFuncGlobals[function] = none
```

This is why a function can look like a once function locally but still not optimize if some other function reads or writes the global in a forbidden way.

### 6. `@binaryen.idempotent` support

Binaryen also treats annotated idempotent functions as once-like, but only in a restricted subset:

- no params
- no results
- not already recognized as a real once-global function

It assigns each such function a fake unique global name that is not an actual module global. That lets the rest of the pass use the exact same bookkeeping as for real once-globals.

Pseudocode:

```text
for each function:
  if function.params not empty:
    continue
  if function.results not empty:
    continue
  if onceFuncGlobals[function] already exists:
    continue
  if function has @binaryen.idempotent:
    fake = fresh_global_like_name(function.name)
    onceFuncGlobals[function] = fake
    onceGlobals[fake] = true
```

Important boundary:

- Fake globals exist only in analysis.
- Later body-cleanup optimizations that require a real guard global do not run for these fake-global functions.

### 7. Only direct `call` participates in the optimization

The optimizer phase looks only at:

- `GlobalSet`
- direct `Call`

It does not optimize:

- `ReturnCall`
- `CallIndirect`
- `CallRef`
- `ReturnCallIndirect`
- `ReturnCallRef`

That is a real parity detail, not an omission in this document.

### 8. Intrafunction optimization is dominance-based, not path-merge-based

For each function, Binaryen builds a CFG and dominator tree, then walks basic blocks in reverse postorder. Each block inherits the "known already written once-globals" set from only its immediate dominator.

Pseudocode:

```text
optimize_function(func):
  cfg = build_cfg(func)
  domTree = build_dominator_tree(cfg)

  onceWrittenPerBlock = array[block_count] of empty_set

  for block in reverse_postorder(cfg):
    if block is unreachable and block is not entry:
      continue

    if block has immediate_dominator parent:
      onceWritten = copy(onceWrittenPerBlock[parent])
    else:
      onceWritten = {}

    for expr in relevant_exprs(block):
      optimize expr against onceWritten

    onceWrittenPerBlock[block] = onceWritten

  newOnceGlobalsSetInFuncs[func] = onceWrittenPerBlock[entry]
```

Observed consequences:

- A second call in the same dominated region becomes `nop`.
- The pass handles straight-line code, nested `if`, loops, and try/catch CFGs.
- A call after an `if` merge is not removed unless dominance alone proves the call already happened on all paths.
- Unreachable blocks past the entry are skipped and left to later DCE.

This is intentionally conservative. The source even notes that intersecting predecessor information would do better.

### 9. Redundant once-global writes are removed too

The pass is not limited to calls. If a known once-global write happens after the same global is already known written, that write is also nopped.

Pseudocode:

```text
optimize_once(expr, global, onceWritten):
  if global already in onceWritten:
    nop(expr)
  else:
    insert global into onceWritten

for expr in block.exprs:
  if expr is GlobalSet(g, const_positive) and onceGlobals[g]:
    optimize_once(expr, g, onceWritten)
```

This shows up in tests where a later explicit `global.set $once, 1337` makes following calls redundant, and vice versa.

### 10. Redundant direct calls to once functions are removed

When the optimizer sees a direct call to a recognized once function, it treats the function's once-global as written by that instruction.

Pseudocode:

```text
if expr is Call(target, args):
  if onceFuncGlobals[target] exists:
    assert args is empty
    optimize_once(expr, onceFuncGlobals[target], onceWritten)
    continue
```

Important exactness:

- Binaryen asserts the call has no operands, which is guaranteed by the earlier "no params" restriction.
- The removed instruction is replaced with `nop`, not physically deleted.

### 11. Interprocedural propagation through non-once functions

For ordinary direct calls to non-once functions, the pass does not delete the call. Instead, it unions in the summary facts already known about the callee: which once-globals are definitely written by calling it.

Pseudocode:

```text
if expr is Call(target, args) and target is not once:
  for each g in onceGlobalsSetInFuncs[target]:
    onceWritten.insert(g)
```

This is what lets Binaryen prove cases like `A -> B -> C -> D -> once`.

### 12. The interprocedural facts are computed by fixed point

Binaryen seeds each once function's summary with its own once-global, then repeatedly reruns the local optimizer until the total number of "known written once-globals" across all functions stops increasing.

Pseudocode:

```text
foundOnce = false
for each function:
  onceGlobalsSetInFuncs[function] = {}
  if onceFuncGlobals[function] exists:
    insert onceFuncGlobals[function]
    foundOnce = true

if !foundOnce:
  return

lastTotal = 0
loop:
  for each function:
    newOnceGlobalsSetInFuncs[function] = {}

  optimize every function using onceGlobalsSetInFuncs

  onceGlobalsSetInFuncs = move(newOnceGlobalsSetInFuncs)

  currTotal = sum(size of each summary set)
  if currTotal > lastTotal:
    lastTotal = currTotal
    continue
  break
```

Why this works:

- Local optimization mutates bodies and discovers stronger caller facts at the same time.
- The monotone metric is the total count of known written once-globals.
- The pass stops when that metric no longer grows.

### 13. Summary facts are intentionally narrower than "all exits wrote it"

Binaryen stores only the entry block's accumulated set after the RPO walk:

```text
newOnceGlobalsSetInFuncs[func] = onceWrittenPerBlock[entry]
```

The source explicitly notes that intersecting exit blocks would be better. So the real current semantics are:

- summary facts are conservative
- summary facts are not a full all-path exit summary
- some removable calls are intentionally left for later passes

This is important for parity: a faithful port should copy this conservatism first, not "improve" it immediately.

### 14. Unreachable code is ignored during CFG optimization

If a block is unreachable and not the entry block, the optimizer skips it. This prevents assertions and avoids pretending unreachable code contributes definite facts.

Observed tested behavior:

- Calls after an explicit `unreachable` are not optimized by this pass.

### 15. Minimal once bodies are deleted completely

After the fixed point converges, Binaryen performs a separate cleanup pass over once functions with real globals.

If a recognized once body has exactly two top-level items:

1. the `if (global.get) return`
2. the `global.set`

then the entire body becomes `nop`.

Pseudocode:

```text
if body.items.length == 2:
  nop(body)
```

This overlaps with what `SimplifyGlobals` could later do, but Binaryen does it here immediately.

### 16. Single-call once wrappers can drop their own early-exit logic

If a once function with a real global has exactly three top-level items and the third item is a direct call to another once function, Binaryen may delete the first two early-exit lines from the wrapper.

Required shape:

1. top-level body is the exact once block
2. exactly one payload instruction
3. payload is exactly `call $other_once`

Pseudocode:

```text
if body.items.length == 3:
  payload = body.items[2]
  if payload is Call(target) and onceFuncGlobals[target] exists:
    if target not in removedExitLogic:
      nop(body.items[0])
      nop(body.items[1])
      removedExitLogic.insert(current_function)
```

Why it is valid:

- if wrapper already ran before, the callee once function will early-exit
- if wrapper never ran before, calling the callee still executes the needed once payload chain

### 17. Wrapper cleanup has a loop-safety guard

Binaryen tracks which functions already had their early-exit logic removed. It refuses to remove the logic from a wrapper if its payload calls a function already in that set.

That guard prevents creating infinite loops in cases like:

- `A` once-calls `B`
- `B` once-calls `A`

Observed tested behavior:

- In a two-function loop, Binaryen removes one side deterministically and keeps the other guarded.
- In more dangerous triple loops, Binaryen stays conservative and does not infer that "entered once" means "finished all downstream once payloads".

### 18. Wrapper cleanup is deterministic and order-sensitive

Binaryen iterates functions in module order during this final cleanup because the `removedExitLogic` guard depends on earlier choices.

A port should preserve deterministic order rather than iterating map keys.

### 19. Self-recursive once calls are removable

A once function calling itself after setting its own guard is turned into `nop`.

Reason:

- the recursive call immediately sees the guard set and exits

This is a special case of the normal local dominance logic, not a dedicated self-recursion rule.

### 20. Important non-features and conservative boundaries

Binaryen does not currently:

1. optimize once functions with params
2. optimize once functions with results
3. reuse stored results for idempotent/resultful calls
4. match generalized guard patterns beyond the exact top-level block shape
5. optimize `return_call`, `call_ref`, or indirect calls
6. use predecessor intersection at merges
7. compute richer callee summaries from exit-block intersections
8. run body cleanup on fake-global idempotent functions
9. infer that a once function's downstream once callees have fully completed just because their globals are set

Those are not bugs in this document. They are the current upstream semantics and matter for parity.

## Full Pass Pseudocode

This is the closest direct translation of current upstream behavior into structured pseudocode.

```text
run_once_reduction(module):
  opt = new OptInfo()

  for global in module.globals:
    opt.onceGlobals[global] =
      global.value_type.is_integer &&
      !global.is_imported

  for func in module.functions:
    opt.onceFuncGlobals[func] = none

  for export in module.exports:
    if export.kind == global:
      opt.onceGlobals[export.global] = false

  scan_module_for_once_patterns(module, opt)

  for func in module.functions:
    g = opt.onceFuncGlobals[func]
    if g exists && opt.onceGlobals[g] == false:
      opt.onceFuncGlobals[func] = none

  for func in module.functions:
    if func.params not empty:
      continue
    if func.results not empty:
      continue
    if opt.onceFuncGlobals[func] exists:
      continue
    if func.has_annotation("binaryen.idempotent"):
      fake = fresh_global_like_name(func.name)
      opt.onceFuncGlobals[func] = fake
      opt.onceGlobals[fake] = true

  foundOnce = false
  for func in module.functions:
    opt.onceGlobalsSetInFuncs[func] = {}
    g = opt.onceFuncGlobals[func]
    if g exists:
      opt.onceGlobalsSetInFuncs[func].insert(g)
      foundOnce = true

  if !foundOnce:
    return module

  lastTotal = 0
  loop:
    for func in module.functions:
      opt.newOnceGlobalsSetInFuncs.try_insert(func, {})

    for func in module.functions in parallel:
      optimize_function(func, opt)

    opt.onceGlobalsSetInFuncs = move(opt.newOnceGlobalsSetInFuncs)

    currTotal = 0
    for (_, set) in opt.onceGlobalsSetInFuncs:
      currTotal += set.size

    if currTotal > lastTotal:
      lastTotal = currTotal
      continue loop

    break

  optimize_once_bodies(module, opt)
  return module

scan_module_for_once_patterns(module, opt):
  for func in module.functions in parallel:
    readGlobals = {}

    walk func body postorder:
      on GlobalGet(g):
        readGlobals[g] += 1

      on GlobalSet(g, value):
        if !value.type.is_integer:
          skip
        else if value is Const && value.integer > 0:
          skip
        else:
          opt.onceGlobals[g] = false

    if func.params empty && func.results empty:
      g = get_once_global(func.body)
      if g exists:
        opt.onceFuncGlobals[func] = g
        readGlobals[g] -= 1

    for (g, count) in readGlobals:
      if count > 0:
        opt.onceGlobals[g] = false

get_once_global(body):
  require exact block/if/global.get/return/global.set shape
  return global name or none

optimize_function(func, opt):
  cfg = build_cfg_with_relevant_exprs(func)
  if cfg.blocks.empty:
    return

  idom = compute_idoms(cfg)
  onceWrittenPerBlock = [ {} for each block ]

  for block in reverse_postorder(cfg):
    if block is unreachable and block != entry:
      continue

    if block has idom parent:
      onceWritten = copy(onceWrittenPerBlock[parent])
    else:
      onceWritten = {}

    for expr in block.relevant_exprs:
      optimizeOnce(global):
        inserted = onceWritten.insert(global)
        if !inserted:
          nop(expr)

      if expr is GlobalSet(g, const_positive) and opt.onceGlobals[g]:
        optimizeOnce(g)
      else if expr is Call(target, []):
        if opt.onceFuncGlobals[target] exists:
          optimizeOnce(opt.onceFuncGlobals[target])
        else:
          for g in opt.onceGlobalsSetInFuncs[target]:
            onceWritten.insert(g)

    onceWrittenPerBlock[block] = onceWritten

  opt.newOnceGlobalsSetInFuncs[func] = move(onceWrittenPerBlock[entry])

optimize_once_bodies(module, opt):
  removedExitLogic = {}

  for func in module.functions in deterministic module order:
    g = opt.onceFuncGlobals[func]
    if g missing:
      continue
    if module.has_no_real_global_named(g):
      continue

    body = func.body
    if body is not exact block:
      continue

    if body.items.length == 2:
      nop(body)
      continue

    if body.items.length != 3:
      continue

    payload = body.items[2]
    if payload is Call(target, []) &&
       opt.onceFuncGlobals[target] exists &&
       target not in removedExitLogic:
      nop(body.items[0])
      nop(body.items[1])
      removedExitLogic.insert(func)
```

## Correctness Constraints For A Starshine Port

The first Starshine implementation should preserve these exact constraints:

1. Restrict once-function recognition to the exact Binaryen top-level block shape.
2. Restrict optimization to direct calls with no params and no results.
3. Treat imported globals and exported globals as non-once immediately.
4. Require every relevant reachable integer write to a once-global to be a positive constant.
5. Reject any extra observable reads of the guard global.
6. Use dominance, not full path-merging dataflow, for the local rewrite.
7. Preserve the fixed-point structure for interprocedural propagation.
8. Preserve the conservative "entry-block summary" behavior before trying any stronger exit-summary variant.
9. Preserve the late body-cleanup ordering and loop guard.

If Starshine skips any of those for convenience, it will no longer be Binaryen-faithful.

## Performance Impact

Expected impact of a faithful first port:

- Compile-time cost: moderate. The pass builds CFG + idoms per function and iterates to a fixed point, but it only tracks a narrow set of expressions and a small monotone fact lattice.
- Code-size impact: positive in codebases with repeated init wrappers, JS glue helpers, or explicit once-guard functions.
- Runtime impact: positive when repeated direct calls to init wrappers can be deleted.

The main local compile-time risk is rebuilding or rewalking `typed instruction body` bodies too often if the implementation rewrites the entire module on every fixed-point round. That argues for keeping the analysis facts and mutation path narrowly scoped.

## Starshine Implementation Slices

These slices are ordered to match the current repository shape and to minimize overlap with the existing dirty optimizer work.

### Slice 1: Dedicated pass plumbing and naming correction

Files:

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt)
- [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt)
- [`src/cmd/cmd.mbt`](/home/jtenner/Projects/starshine-mb/src/cmd/cmd.mbt)

Work:

1. Add `run_once_reduction`.
2. Route `OptimizePass::OnceReduction` to that runner instead of `noop_module_wide_pass`.
3. Fix the CLI description so it describes run-once/idempotent call reduction accurately.
4. Add the small scheduler/runner tests first.

Reason for separate slice:

- It is tiny, isolated, and matches the current `run_memory_packing` staging pattern.

### Slice 2: Module indexing and exact once-pattern analysis

Files:

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt)
- new [`src/optimization/once_reduction_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/once_reduction_wbtest.mbt)

Work:

1. Add helpers to enumerate imported/defined globals, exports, function type signatures, and code bodies.
2. Add exact once-pattern recognizer over function bodies.
3. Add global read/write scanning and candidate invalidation.
4. Add idempotent annotation lookup if Starshine already carries that annotation surface; otherwise explicitly scope this slice to real once-globals first and document the annotation gap in `agent-todo.md`.

Why this should stay separate:

- The exact-shape recognizer and invalidation rules are the highest-risk correctness surface.
- This slice can be tested without any CFG rewriting yet.

Required red tests:

1. exact positive match
2. leading `nop` reject
3. `nop` between guard and set reject
4. `else` reject
5. mismatched get/set reject
6. extra read reject
7. zero write reject
8. non-constant write reject
9. imported global reject
10. exported global reject

### Slice 3: Narrow CFG + dominance infrastructure for `OnceReduction`

Files:

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt)
- possibly a new local helper file if `optimization.mbt` gets too crowded
- [`src/ir/cfg.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/cfg.mbt) only if the helper can be generalized cleanly without stepping on other work

Work:

1. Build a pass-local CFG view for function bodies that records only relevant expressions:
   - once-global `global.set`
   - direct `call`
2. Reuse the existing dominance algorithm shape where possible.
3. Skip unreachable non-entry blocks exactly like Binaryen.

Recommendation:

- Do not force a broad `src/ir/cfg.mbt` refactor in the first port.
- `OnceReduction` needs Wasm-AST-aware block contents and rewrite handles, not just the typed IR block graph used elsewhere.
- A small pass-local CFG helper inside the optimization package is lower-risk for parity.

### Slice 4: Local rewrite engine plus fixed-point propagation

Files:

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt)
- new [`src/optimization/once_reduction_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/once_reduction_wbtest.mbt)

Work:

1. Implement local `nop` rewriting for redundant direct calls and redundant once-global sets.
2. Seed `onceGlobalsSetInFuncs`.
3. Iterate until the total fact count stops growing.
4. Preserve the conservative entry-block summary behavior first.

Required red tests:

1. straight-line duplicate call removal
2. dominated nested-if removal
3. merge-point non-removal
4. loop cases from upstream
5. unreachable tail ignored
6. interprocedural `A -> B -> C -> once`
7. non-once wrapper not optimized in reverse order

### Slice 5: Late once-body cleanup

Files:

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt)
- new [`src/optimization/once_reduction_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/once_reduction_wbtest.mbt)

Work:

1. Implement empty-body cleanup for two-item once bodies.
2. Implement single-call wrapper cleanup for three-item bodies.
3. Preserve deterministic order and `removedExitLogic`.
4. Add self-loop and two-function-loop coverage.
5. Add the dangerous triple-loop regression so Starshine preserves Binaryen's conservatism.

This should be separate because:

- It mutates once functions themselves after the main fixed point.
- It is easy to accidentally overgeneralize and become unsound.

### Slice 6: Idempotent parity or explicit deferral

Files:

- [`src/optimization/optimization.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization.mbt)
- maybe annotation-carrying code if Starshine exposes Binaryen-style function annotations already
- [`agent-todo.md`](/home/jtenner/Projects/starshine-mb/agent-todo.md) if deferring

Decision point:

- If Starshine already preserves Binaryen annotation metadata through parse/decode/lowering, land idempotent support here.
- If not, keep the first production slice limited to real once-globals and record idempotent parity as the remaining blocker.

The important thing is to be explicit. A half-implicit "annotation maybe later" port will be hard to reason about.

## Validation Plan

The first signoff gate should be:

1. whitebox tests in new [`src/optimization/once_reduction_wbtest.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/once_reduction_wbtest.mbt) mirroring the upstream `once-reduction.wast` feature buckets
2. pipeline plumbing tests in [`src/optimization/optimization_test.mbt`](/home/jtenner/Projects/starshine-mb/src/optimization/optimization_test.mbt)
3. generated CLI/pipeline tests only if pass descriptions or expansion plumbing change
4. final repo gate: `moon info && moon fmt`, then `moon test`

Test buckets that matter most for parity:

1. exact-shape recognition and all disqualifiers
2. repeated calls in straight-line, branch, loop, and unreachable shapes
3. interprocedural propagation across non-once helpers
4. wrapper cleanup and loop safety
5. imported/exported global guardrails
6. params/results non-support
7. nonzero-initial and nonzero-later-write acceptance

## Open Questions

1. Does Starshine already retain Binaryen-compatible idempotent function annotations anywhere in the pipeline, or is that metadata currently absent?
2. Should the first port operate only on `typed function` bodies and bail on raw `Func`, or should it normalize raw `Expr` to `typed instruction body` up front?
3. Is there enough reusable AST-to-CFG machinery locally to share code with [`src/ir/cfg.mbt`](/home/jtenner/Projects/starshine-mb/src/ir/cfg.mbt), or is a pass-local CFG builder cleaner for the first faithful slice?
4. Do we want the first Starshine version to preserve Binaryen's exact conservative entry-block summary behavior, or intentionally diverge with a stronger exit-intersection summary? For parity, the answer should be "preserve it first".

## Bottom Line

The safe Starshine port is not a generic call deduplicator. It is a very specific monotonic-global and direct-call analysis with exact-shape matching, dominance-based local deletion, fixed-point propagation of "definitely sets these once-globals", and a final narrowly-scoped cleanup of trivial once wrappers. Porting that exact behavior first is the shortest path to Binaryen parity and the lowest-risk foundation for any later generalization.
