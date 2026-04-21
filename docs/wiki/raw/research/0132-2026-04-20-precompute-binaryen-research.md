# 0132 - `precompute` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: deepen the currently shallow `precompute` pass docs using official Binaryen `version_129` sources, shipped tests, the repo's canonical no-DWARF scheduler note, the updated pass tracker, the local `precompute` implementation, the saved generated-artifact `-O4z` audit, and the active `PC` backlog slices in `agent-todo.md`.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` had just promoted `precompute` to the top suggested next target after the `optimize-instructions` dossier landed.
- `precompute` is already **implemented** in Starshine, but only had a landing page.
- It is one of the easiest passes to misread from the name alone.
  - The public description sounds like simple constant folding.
  - The local Starshine implementation is intentionally much narrower than upstream Binaryen.
  - Upstream Binaryen `version_129` actually uses a small interpreter, a local-flow propagation pass, a partial-select precompute phase, and a GC identity cache.
- It matters directly to both major scheduler stories this repo keeps returning to:
  - the canonical no-DWARF `-O` / `-Os` path uses `precompute` in **two** visible top-level function slots
  - the saved generated-artifact `-O4z` audit saw `precompute-propagate` in the analogous aggressive slots `19` and `43`
- The local backlog already has dedicated pass slices:
  - `agent-todo.md` -> `[PC]001 - Constant Folding Surface`
  - `agent-todo.md` -> `[PC]002 - Early/Late Slot Regression and Artifact Parity`
- The saved generated-artifact slot-19 invalid-output witness from `0096` was already retired by `0105`, which means the main open work here is now documentation depth, parity breadth, and runtime honesty rather than an unresolved hard-corruption blocker.

## Local source material

### Repo scheduler / backlog / audit sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/precompute/index.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `docs/wiki/raw/research/0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md`
- `docs/wiki/raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `src/passes/optimize_test.mbt`

### Local Starshine implementation files

- `src/passes/precompute.mbt`
  - current summary: `Fold exact constant integer expressions that are trap-free and stable across the top-level precompute slots.`
  - actual current scope: exact i32/i64 unary/binary folding, immutable-global replacement, constant-`if` picking, some root dead-drop / `nop` cleanup, and artifact-driven writeback safety hardening
- `src/passes/precompute_test.mbt`
  - current in-tree coverage for the implemented HOT subset and the retired slot-19 regression families

## Official Binaryen `version_129` sources

### Main implementation and scheduler

- `src/passes/Precompute.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
  - especially:
    - `PrecomputingExpressionRunner`: `#L94-L292`
    - pass shell and first walk: `#L294-L340`
    - `visitExpression`: `#L342-L505`
    - `visitBlock`: `#L507-L572`
    - partial-precompute collection and application: `#L574-L844`
    - propagation logic: `#L896-L1057`
    - constant-emission gate: `#L1059-L1121`
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - registration: `#L377-L383`
  - default function pipeline placement: `#L655-L740`
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - nested `optimizeAfterInlining` helper prepending `precompute-propagate`

### Helper headers the pass directly depends on

- `src/ir/local-graph.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- `src/ir/iteration.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/iteration.h>
- `src/ir/literal-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/literal-utils.h>
- `src/ir/manipulation.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
- `src/ir/properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `src/ir/utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- `src/wasm-interpreter.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>

### Shipped test surface reviewed for this note

The `version_129` lit corpus contains `17` dedicated `precompute*` pass tests under `test/lit/passes/`:

- `precompute-desc.wast`
- `precompute-effects.wast`
- `precompute-gc-atomics-rmw.wast`
- `precompute-gc-atomics.wast`
- `precompute-gc-immutable.wast`
- `precompute-gc-loop.wast`
- `precompute-gc-multibyte.wast`
- `precompute-gc.wast`
- `precompute-partial.wast`
- `precompute-propagate-partial.wast`
- `precompute-propagate_all-features.wast`
- `precompute-ref-func.wast`
- `precompute-relaxed.wast`
- `precompute-stack-switching.wast`
- `precompute-strings.wast`
- `precompute_all-features.wast`
- `precompute_coalesce-locals_vacuum.wast`

Representative URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-effects.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-partial.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc-immutable.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc-atomics.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-strings.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-ref-func.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-relaxed.wast>

## Fast answer

Binaryen `precompute` is not just “constant folding.”

A better beginner summary is:

- Binaryen speculatively **executes** an expression with a restricted interpreter,
- checks whether the result is concrete and safely re-emittable,
- preserves side-effectful local/global writes when needed,
- optionally pushes constant knowledge through locals in a worklist-style propagation phase,
- and at higher optimize levels also partially pushes parent operations into `select` arms.

So the real contract is closer to:

- **small compile-time execution plus conservative replacement and optional local propagation**

not:

- “replace `1 + 2` with `3` and stop there.”

## Public names and scheduler placement

## Registered public surface

`pass.cpp` registers two related public pass names:

- `precompute`
  - public description: `computes compile-time evaluatable expressions`
- `precompute-propagate`
  - public description: `computes compile-time evaluatable expressions and propagates them through locals`

That name split matters.

The repo's living pages and Starshine registry currently use `precompute` as the umbrella label, but upstream Binaryen really exposes **two modes**:

1. plain precompute
2. precompute plus local propagation

## Canonical no-DWARF top-level slots

In `version_129` `pass.cpp`, the default function optimization path inserts a precompute-family slot twice:

1. early, after `pick-load-signs`
2. late, after the second `merge-blocks`

However, which of the two public names Binaryen actually runs depends on optimization settings:

- if `optimizeLevel >= 3` **or** `shrinkLevel >= 2`, Binaryen uses `precompute-propagate`
- otherwise, it uses plain `precompute`

That means:

- the repo's canonical no-DWARF `-O` / `-Os` path for `version_129` and the MoonBit debug artifact uses **plain `precompute`** in both top-level slots, because `-O` / `-Os` here means `optimizeLevel=2`, `shrinkLevel=1`
- the saved generated-artifact `-O4z` audit saw **`precompute-propagate`** in those analogous aggressive slots, because that setting crosses the threshold

So both names matter for this repo:

- `precompute` matters for honest no-DWARF parity
- `precompute-propagate` matters for aggressive-size and nested-rerun parity

## Nested reruns matter too

`opt-utils.h` shows that the shared “after inlining” cleanup helper prepends `precompute-propagate` and then reruns the normal default function passes.

That means `precompute-propagate` is not just a top-level aggressive-mode variant.
It is also part of the nested cleanup contract after optimizing boundary passes like inlining.

The local saved `-O4z` debug log confirms how common that becomes in practice:

- `.artifacts/o4z-wasm-opt-debug.log` contains `53` `running pass: precompute-propagate` lines
- the saved ordered audit only exposes two top-level slots, so the rest come from later nested reruns and converging cleanup clusters

## Actual implementation structure

## 1. A specialized expression runner is the heart of the pass

The center of the file is `PrecomputingExpressionRunner`, which subclasses `ConstantExpressionRunner`.

That inherits a lot of important behavior from the generic interpreter layer in `wasm-interpreter.h`:

- `Flow` values can represent:
  - concrete results
  - breaks / returns
  - `NONCONSTANT_FLOW`
  - suspend flow
- the runner can be told either:
  - just evaluate (`DEFAULT`)
  - or evaluate while preserving side effects (`PRESERVE_SIDEEFFECTS`)
- the generic constant runner already knows some constant-expression semantics for locals, globals, branches, tuple values, and many instruction families

`PrecomputingExpressionRunner` adds the pass-specific pieces the generic constant runner cannot know on its own:

- `getValues`
  - concrete values learned later by the propagation phase for specific `local.get`s
- `heapValues`
  - a cache mapping heap-allocating expressions to canonical `GCData` identities

That cache is one of the most important non-obvious details in the whole pass.

## 2. Heap identity is tracked, not just scalar equality

The file's `HeapValues` comments are worth taking literally.

Binaryen is not satisfied with only knowing that two GC allocations have equal field contents.
It wants to know when two references are actually the **same allocation identity**.

That is why it caches each allocation expression's `GCData` object and returns a literal pointing at that same canonical heap object when the same source allocation expression is evaluated again.

Why this matters:

- `ref.eq` depends on identity, not on structural equality
- propagation may reevaluate set expressions multiple times
- loops and merges can make the same source expression represent different runtime allocations on different iterations or control-flow paths

The pass handles that conservatively:

- if a merge means a local may refer to more than one allocation, it gives up on inferring a single value
- if a cached heap allocation had effects, the runner reevaluates the expression to reproduce those effects, but still reuses the canonical identity object only if the reevaluation stayed constant

That is why the shipped GC tests spend so much time on:

- equal vs unequal `ref.eq`
- loop-carried refs
- immutable vs mutable fields
- global-held nested immutable objects
- escape / mutation boundaries

## 3. The runner deliberately limits depth and loop iterations

`PrecomputingExpressionRunner` uses very small hard limits:

- `MAX_DEPTH = 50`
- `MAX_LOOP_ITERATIONS = 1`

The source comments explain both.

Depth is capped because:

- deeply nested expressions are unlikely to be the best precompute target all at once
- smaller inner pieces are likely to simplify first
- low depth also avoids platform-native stack-budget differences

Loop iterations are capped because:

- a precomputed replacement must preserve the same side effects
- if a loop would need more than one iteration before becoming concrete, then there must usually be a side-effect story the pass cannot safely compress into one constant replacement

That detail helps explain an easy beginner confusion:

- the pass is willing to *execute* loops in the interpreter
- but only very conservatively

This is why direct loop roots are skipped as rewrite roots in the walker, yet enclosing blocks can still sometimes collapse if the loop's overall flow is immediately known.

## 4. The runner carves out GC, string, and atomic special cases itself

`PrecomputingExpressionRunner` overrides generic behavior for a lot of post-MVP instructions.

Important rules in `version_129`:

- `struct.new`, `array.new`, `array.new_fixed`
  - allowed through `getGCAllocation(...)`, which also maintains identity cache state
- `struct.set`, `array.set`, `array.copy`, `array.store`, GC RMWs, GC cmpxchg
  - all immediately become `NONCONSTANT_FLOW`
- `struct.get` and `array.get`
  - only allowed when the reference is non-null / reachable enough to reason about **and** the accessed field/element is immutable
- `array.len`
  - allowed, because length is immutable
- `array.load`
  - explicitly not precomputed in `version_129`
- `string.new_wtf16_array`
  - only handled for the WTF-16-array op, and only when the child is an immediate array allocation-like expression
- `string.encode_wtf16_array`
  - always treated as nonconstant because it writes into the array
- GC atomic ordering matters:
  - unordered gets can be precomputed
  - seqcst gets cannot, because synchronization itself is observable
  - acqrel gets can only be precomputed on **unshared** heaps

That whole cluster is the easiest place to underestimate the pass.
It is doing real semantic filtering, not just syntax matches.

## 5. The main AST walk is a post-walk replacement pass

The pass shell is:

- `WalkerPass<PostWalker<Precompute, UnifiedExpressionVisitor<Precompute>>>`
- function-parallel

The per-function flow in `doWalkFunction()` is:

1. decide whether partial precompute is enabled (`optimizeLevel >= 2`)
2. run the main post-walk once
3. run the partial-precompute phase
4. if this is the propagate variant:
   - compute local propagation facts
   - if anything propagated, run the main post-walk again
5. after all expression work, refinalize the function in `visitFunction()`

That makes the real phase model:

- **main compile-time execution pass**
- **optional parent-into-select-arm partial precompute**
- **optional local propagation plus second walk**
- **type repair**

## 6. `visitExpression()` is the core replacement algorithm

`visitExpression()` skips a bunch of obvious or awkward cases up front:

- already-constant expressions
- `nop`
- `local.set`
- `global.set`
- `return`
- `loop`
- unconditional `br`

Then it runs the interpreter with `replaceExpression = false`.
That means:

- it is allowed to evaluate local/global sets in order to understand the result value
- but if replacement does happen later, the pass must manually preserve any such writes that mattered

The algorithm is:

1. speculate by interpreting the expression
2. if it throws `NonconstantException`, give up
3. if the resulting value cannot be emitted as a constant, give up
4. if the result is `NONCONSTANT_FLOW`, consider partial precompute instead
5. if the flow suspends, give up
6. otherwise build the replacement:
   - literal constant expression
   - `br`
   - `return`
   - or `nop` if nothing remains
7. if there were effectful local/global writes during speculation, keep the needed children alive as dropped expressions where possible
8. replace the node

The child-retention logic is especially important.

If the speculative evaluation only succeeded because it walked through `local.set` or `global.set`, Binaryen does **not** simply erase those writes.
Instead it tries to preserve the relevant child expressions by:

- scanning children with `EffectAnalyzer`
- keeping children that write locals or globals
- wrapping kept children in `drop`
- appending the final constant value if one exists

But it is careful about where this is safe.

It bails out when:

- the original expression is `block`, `if`, or `try`
  - because some children may not execute, and the pass does not track that precisely enough here
- the flow breaks / returns and child-retention would require precise ordering against transferred control flow

This is one of the strongest durable lessons from the file:

- precompute replacement is not just “we proved the answer, so erase the original expression”
- it is “we proved the answer and can also preserve the subset of writes whose continued execution matters”

## 7. Blocks get a special performance bailout

`visitBlock()` is mostly just `visitExpression()` with one extra guard.

Binaryen explicitly refuses to keep trying to precompute “tower of blocks” shapes like nested switch lowering:

```wat
(block
  (block
    (block
      (br_table ...)))
```

If a block's first child is still a block when the visitor reaches it, that is a strong sign that a nested block already failed to simplify, and retrying every parent block would create quadratic wasted work.

So Binaryen bails early there.

Important beginner nuance:

- this is a **performance** bailout, not a semantic statement that outer blocks can never simplify
- if the inner block *did* collapse first, the outer one may still simplify later

## 8. Partial precompute is a separate algorithm, not a tiny side case

When ordinary replacement fails with `NONCONSTANT_FLOW`, Binaryen may still do something clever at optimize levels `>= 2`.

The supported target today is a narrow but important family:

- a `select` whose two arms are already constant-expression-like
- and whose parent stack above it might become constant if you plug each arm in separately

The source's own motivating example is:

```wat
(i32.eqz
  (select
    (i32.const 42)
    (i32.const 1337)
    (local.get $cond)))
```

The pass can apply the outer `i32.eqz` separately to each arm and rebuild:

```wat
(select
  (i32.const 0)
  (i32.const 0)
  (local.get $cond))
```

But the implementation is more general than just one parent.

It walks **up** the expression stack from the select through successive parents, trying:

- parent applied to left arm and right arm
- then maybe parent+grandparent together
- then maybe more of the stack together

Why the “whole path” retries matter:

The source comments give a key GC example where:

- an inner `struct.get` alone lands on an interior pointer that cannot be re-emitted as a constant
- but `struct.get(struct.get(select ...))` together lands back on a global-rooted outer object that *can* be simplified to a scalar result

So the partial-precompute phase is really:

- **speculative upward context pushing into select arms**

not:

- “constant-fold a select if both arms are constants.”

## 9. Partial precompute uses a temporary heap cache on purpose

This is subtle enough to deserve its own bullet.

When partial precompute speculatively evaluates a parent with the select replaced by one arm and then the other, it uses a **temporary** `HeapValues` cache instead of the pass-global one.

The shipped `precompute-propagate-partial.wast` explains why.

A partial speculative execution might avoid a trap in one arm, and if that speculative heap result were cached globally, later normal evaluation could incorrectly think a trapping expression was safe and removable.

So Binaryen isolates heap caching during partial speculative attempts.

That is not an implementation footnote.
It is part of the correctness contract.

## 10. The propagate variant is a real lazy LocalGraph worklist pass

If `propagate` is enabled, the pass does much more than just “replace some local.gets with constants.”

`propagateLocals()` uses `LazyLocalGraph` to derive three kinds of relationships:

- which sets can reach a get
- which gets are influenced by a set
- which sets are influenced by a get

The algorithm is roughly:

1. lazily discover constant `local.set` values
   - using `Properties::getFallthrough(...)` to look through wrappers like tees and similar fallthrough shells
2. only keep a propagated value if its concrete type is a valid subtype of the full set expression's type
   - important for casty reference flows where the fallthrough child type is too specific or otherwise invalid to substitute directly
3. a `local.get` becomes constant only if **all** reaching sets agree on the same concrete value
   - params make the get nonconstant
   - a missing set for a var means the zero/default entry value
   - nondefaultable vars in this situation cause a conservative bailout
4. use a worklist of newly constant gets/sets to propagate further influence through the local graph
5. if anything propagated, rerun the main post-walk once to exploit the new `getValues`

The worklist is small and intentionally single-hit:

- gets and sets only enter it when first proven constant
- there is no full fixed-point loop rebuilding `LazyLocalGraph`
- the source explicitly says rarer second-order opportunities are left for later runs of the pass or for `--converge`

So the pass is clever, but still intentionally bounded.

## 11. Emitability is a major boundary, especially for refs

`canEmitConstantFor(...)` is one of the most useful “what this pass really means” helpers.

Binaryen can only replace a computed value if it knows how to emit that value back into Binaryen IR / WAT as a valid constant expression.

In `version_129` that means:

- numeric values: yes
- null refs: yes (`ref.null`)
- function refs: yes (`ref.func`)
- strings: yes, but only when the literal is valid UTF-16 for `string.const`
- other GC refs: **no**

That boundary explains a lot of surprising source and test behavior.

For example:

- the pass may know a `struct.get` or `array.get` leads to some immutable nested object
- but if the result is a non-null GC reference that is not a function or string constant, the pass still may not replace the whole expression directly
- it may still benefit propagation or later outer simplifications, but direct re-emission is blocked

This is why some tests say things like:

- “we can precompute the first `struct.get`, but there is no constant expression we can emit for it, so we do nothing”

That is not inconsistency.
It is a deliberate emitability boundary.

## Important WAT / IR shape families

## Plain scalar folds

The easy positive families do exist:

- integer arithmetic and comparisons
- SIMD constants in deterministic ops
- tuple extraction into constant tuple-making shells
- immutable `global.get` users
- constant `if` / `block` / `br_if` style flows when the interpreter can compute the result

But those are just the entry point.

## Local/global-write retention

Important positive-but-conservative families from `precompute-effects.wast`:

- `i32.add(local.tee ..., local.get ...)`
  - can become a constant **if the tee is kept alive** as a dropped child
- nested blocks containing `local.set` or `global.set`
  - may reduce to a block of drops plus the final value

Important negative family:

- control structures with conditionally executed effectful children (`if`, `try`, some `block` / `br` stories)
  - often bail because simple child retention would change execution order or retain too much / too little

## Constant-if / break / loop flow

The pass can collapse whole-flow stories like:

- trivial constant-armed `if`
- blocks whose inner control transfers make the overall result statically known
- loops whose only meaningful outcome is an immediately known branch to an outer block

But it does **not** optimize direct loop roots as a generic standalone rewrite target.
The win usually happens when the enclosing `block` becomes precomputable.

## Partial select families

At optimize levels `>= 2`, Binaryen can push parent operations into `select` arms when both arms are constant-expression-like.

Good families from `precompute-partial.wast` include:

- boolean wrappers like `i32.eqz(select(...))`
- binary ops where one side is a constant and the select is the other child
- deeper parent-stack cases where a whole chain of parents applied separately to each arm becomes constant

Negative families include:

- arm expressions that are not constant-expression-like enough
- selects that are the entire function body
- parent stack entries with non-concrete or tuple types
- control-flow parents

## Immutable-GC read families

This is the biggest non-obvious positive cluster.

Binaryen can propagate through:

- immutable struct fields
- immutable array elements
- `array.len`
- nested immutable objects inside immutable objects
- immutable global-held nested objects
- some descriptor-related immutable data
- reference identity comparisons when the pass can prove both sides are the same or different allocation

But it refuses mutable equivalents.

That gives the core rule:

- **immutability plus known allocation identity unlocks GC precompute**

while these negative families remain preserved:

- mutable fields
- mutable arrays for `array.get`
- incoming params whose allocation identity is unknown
- escape / mutation boundaries
- merge points where two distinct allocation identities can reach the same get

## GC atomic-order families

The GC atomic tests make the ordering contract very explicit.

Positive families:

- unordered `struct.get` / `array.get`
- acquire-release `struct.atomic.get` / `array.atomic.get` on **unshared** heaps

Negative families:

- seqcst atomic gets, even on unshared heaps, because the synchronization is part of observable behavior
- acquire-release atomic gets on **shared** heaps
- GC RMW / cmpxchg ops, because they both read and write heap state

## String families

`precompute-strings.wast` shows that `version_129` precompute already covers a substantial string surface:

- `string.eq`
- `string.concat`
- `string.measure_wtf16`
- `stringview_wtf16.get_codeunit`
- some `stringview_wtf16.slice`
- `string.new_wtf16_array` when the array allocation is the immediate child and the result is representable as a `string.const`

Important negative / preserved families:

- `string.encode_wtf16_array`
  - preserved because it mutates the array
- `string.new_wtf16_array` with too-indirect array provenance
  - currently not optimized
- slices that would produce invalid UTF-16 constant material
  - kept as slice operations instead of emitted as `string.const`

## Reference and control oddities

The test corpus also guards tricky shapes involving:

- `ref.func` constant reuse
- nested `br` values with different ref heap types
- `ref.cast` oddities around null versus incompatible non-null values
- stack-switching instructions (`cont.new`, `cont.bind`, `resume`, `resume_throw`, `switch`)
  - these stay preserved rather than being “interpreted away”
- relaxed SIMD
  - preserved because of nondeterminism

That cluster is a good reminder that the pass is not “optimize everything constant-looking.”
It is “optimize what the evaluator and re-emission logic can make deterministic and safe.”

## What the pass sounds like versus what it actually does

What the name suggests:

- a small constant-folder

What `version_129` actually implements:

- a function-parallel post-walk pass with:
  - a small compile-time interpreter
  - local/global-write retention logic
  - a block-specific quadratic-work bailout
  - higher-level partial-select precompute
  - optional lazy-LocalGraph constant propagation
  - GC identity caching
  - restricted constant re-emission
  - final refinalization

That gap between the name and the implementation is the main reason this dossier was worth writing.

## Helper dependencies that matter semantically

## `ConstantExpressionRunner` / `Flow` / `Literals`

These are not just convenience helpers.
They define what “compile-time evaluatable” means in practice:

- concrete values
- transferred control flow
- suspend flow
- nonconstant failure
- optional side-effect preservation

## `Properties`

Important uses in this pass:

- `isConstantExpression(...)`
  - cheap early skip for already-constant nodes
- `isValidConstantExpression(...)`
  - gate for whether partial-select arms are promising enough
- `isControlFlowStructure(...)`
  - blocks partial-precompute climbs into unsafe parent shapes
- `getFallthrough(...)`
  - lets propagation look through fallthrough wrappers when learning local-set values

## `LazyLocalGraph`

This is what makes `precompute-propagate` a real propagation pass rather than a purely local peephole.

It provides:

- reaching-set queries for gets
- influence edges from sets to gets and gets to sets
- on-demand computation instead of full eager graph building

## `EffectAnalyzer`

Used narrowly but critically in child retention.

It decides which children must stay because they write locals or globals.
Without that, `replaceExpression = false` speculative evaluation would erase semantic writes.

## `ExpressionStackWalker` / child-pointer lookup

These power the partial-precompute phase.

They let the pass walk up from a `select`, temporarily substitute one arm and then the other into a parent stack, and rebuild the expression tree safely.

## `ReFinalize`

The pass ends with function refinalization because break removal and expression replacement can change types, including local nullability and branch/result typing.

The `remove-set` GC test in particular shows why this matters:

- precomputing control flow can eliminate the only set to a local
- later unreachable code may still mention the local
- Binaryen repairs the local typing so the function remains valid even if the validator ignores unreachability precision there

## Scheduler and pass interactions

## Early slot meaning

In the ordinary no-DWARF pipeline, early `precompute` sits after:

- `optimize-instructions`
- `heap-store-optimization`
- `pick-load-signs`

and before:

- `code-pushing`
- `tuple-optimization`
- the simplify-locals cluster

That early slot is about:

- folding exact scalar work exposed by earlier canonicalization
- shrinking simple control/result shells before tuple/local cleanup
- possibly simplifying side-effect-free expression trees into constants early enough for later local passes to benefit

## Late slot meaning

The late slot comes after:

- `merge-blocks`
- another `remove-unused-brs`
- another `remove-unused-names`
- another `merge-blocks`

and before:

- late `optimize-instructions`
- late `heap-store-optimization`
- `rse`
- final `vacuum`

That late slot is about:

- exploiting simpler control/value shapes exposed by the local-cleanup passes
- cleaning up exact remnants before final redundancy elimination and garbage pruning

## Nested optimizing reruns

The biggest interaction to remember is:

- `optimizeAfterInlining(...)` prepends `precompute-propagate`

So even if the top-level preset only uses plain `precompute`, later boundary passes can still reintroduce the stronger propagation variant on touched functions.

This is exactly why the saved `-O4z` debug log shows far more `precompute-propagate` executions than the visible top-level slots.

## Current Starshine gap versus upstream

The current in-tree Starshine pass is intentionally much smaller.

Today it covers mainly:

- exact i32/i64 scalar folds
- exact compare folds
- immutable scalar global replacement
- constant `if` arm picking
- some dead-drop and `nop` cleanup around rewritten roots
- artifact-driven validation and writeback hardening

Major upstream Binaryen surfaces still missing locally include:

- the distinct `precompute-propagate` mode and its `LazyLocalGraph` worklist algorithm
- the general compile-time interpreter model used by `ConstantExpressionRunner`
- child-retention logic for local/global writes during replacement
- partial precompute through `select` parent stacks
- heap-identity-aware GC reasoning
- immutable-GC field / array propagation
- string constant / slice / compare support
- tuple constant emission
- SIMD precompute and relaxed-SIMD no-fold boundaries
- atomic-order-sensitive GC get handling
- stack-switching and descriptor-sensitive boundary behavior

That difference is large enough that the old landing page's short summary was no longer honest.

## Durable takeaways for a future Starshine port

A future honest Starshine port must preserve at least these contracts:

1. **Mode split matters**
   - plain `precompute` and `precompute-propagate` are not just aliases
2. **Compile-time execution is bounded and semantic**
   - depth limit, loop-iteration limit, suspend handling, break/return flow all matter
3. **Writes cannot disappear accidentally**
   - if speculative evaluation walked through local/global writes, replacement must preserve the needed children or bail out
4. **Heap identity matters, not just field equality**
   - especially for `ref.eq`, immutable nested data, and loop/merge behavior
5. **Emitability is a real boundary**
   - proving a value is known is not enough; the pass must also be able to re-emit it as valid IR
6. **Partial select precompute is part of the real pass**
   - it is not optional trivia; it is a distinct algorithm Binaryen relies on at optimize levels `>= 2`
7. **Propagation uses real local-flow reasoning**
   - the worklist / reaching-set agreement model is part of the pass, not a later unrelated optimization
8. **Refinalization is required**
   - type repair after control/value rewriting is part of the pass contract

## Uncertainty and drift notes

- This note treats Binaryen `version_129` as the source oracle for real pass behavior.
- The existing landing page already records later trunk drift from 2025-08 and 2026-03 around child retention, GC writes, GC atomics, and multibyte array loads.
- I did not fully re-audit current trunk `Precompute.cpp` beyond those already-linked official upstream drift notes, so any comparison against `main` should be labeled as newer-than-`version_129` behavior, not silently merged into the `version_129` contract.
- In particular, this note keeps the `version_129` `array.load` no-fold fact as a tagged oracle statement, not a claim that newer trunk still behaves identically.

## Bottom line

Binaryen `precompute` in `version_129` is a layered compile-time execution pass:

- interpret an expression conservatively
- replace it only if the result is concrete and re-emittable
- keep needed local/global writes alive when possible
- optionally push parent computation into `select` arms
- optionally propagate constants through locals with `LazyLocalGraph`
- refinalize at the end

That is much richer than the name suggests, and much broader than the current Starshine HOT subset.
