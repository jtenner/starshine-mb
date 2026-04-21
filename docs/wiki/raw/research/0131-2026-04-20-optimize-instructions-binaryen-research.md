# 0131 - `optimize-instructions` Binaryen research

## Status

- Date: 2026-04-20
- Type: One-off raw investigation
- Scope: deepen the currently shallow `optimize-instructions` pass docs using official Binaryen `version_129` sources, shipped tests, the repo's canonical no-DWARF scheduler note, the updated pass tracker, the local `optimize-instructions` implementation, the saved generated-artifact `-O4z` audit, and the current artifact-facing HOT-batch backlog slices that already depend on this pass.

## Why this pass

- `docs/wiki/binaryen/passes/tracker.md` had just promoted `optimize-instructions` to the top suggested next target after the `vacuum` dossier landed.
- Unlike the earlier unimplemented-pass campaign work, `optimize-instructions` is already **implemented** in Starshine, but only had a landing page.
- That made it the highest-value next deepening target because it is:
  - on the canonical no-DWARF `-O` / `-Os` path twice
  - present in the saved generated-artifact `-O4z` audit at top-level slots `16` and `44`
  - adjacent to `heap-store-optimization`, `precompute`, `rse`, and `vacuum`, which means it helps explain a whole late hot-pass cluster instead of one isolated pass
- The local backlog does not yet have a dedicated `#### OI - Optimize Instructions` slice, which is itself an important durable fact.
  - The relevant local planning surface today is the shared hot-batch work:
    - `agent-todo.md` -> `[HOT]001 - Post-SSA Hot-Pipeline Replay Hardening`
    - `agent-todo.md` -> `[HOT]002 - Native Parallel Hot-Batch Queue`
  - Both explicitly model a hot batch containing `vacuum -> optimize-instructions -> simplify-locals`.
- The canonical no-DWARF `-O` / `-Os` page shows `optimize-instructions` twice in the default function pipeline:
  - once early, after `remove-unused-brs`
  - once late, after the second `precompute` slot and just before late `heap-store-optimization`, `rse`, and the final `vacuum`
- The saved generated-artifact `-O4z` audit shows two top-level observed Binaryen slots for the pass:
  - slot `16`
  - slot `44`
- The saved Binaryen debug log shows the pass also matters inside nested optimizing reruns:
  - direct count of `running pass: optimize-instructions` lines in `.artifacts/o4z-wasm-opt-debug.log` is `36`
- The current in-tree Starshine implementation is much narrower than upstream Binaryen.
  - Starshine mostly covers exact integer, boolean, compare, and control-flow canonicalization over HOT IR.
  - Binaryen `version_129` `OptimizeInstructions.cpp` is a large function-parallel AST peephole pass that also covers bulk memory, call_ref/direct-call conversion, GC casts and null-check interactions, unshared GC atomics lowering, tuple extraction, descriptor-aware cast refinement, and trap-sensitive simplifications.

So this pass is especially easy to misunderstand:

- the name sounds like “small arithmetic peepholes”
- the current Starshine implementation also mostly looks like that
- but upstream Binaryen actually uses the pass as a broad **instruction-shape canonicalizer and trap-sensitive simplifier** across integer, float, memory, reference, GC, and control-flow forms

## Local source material

### Repo scheduler / backlog / audit sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/optimize-instructions/index.md`
- `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`
- `docs/wiki/raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`
- `docs/wiki/raw/research/0095-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-stack-underflow.md`
- `docs/wiki/raw/research/0100-2026-04-18-generated-o4z-optimize-instructions-slot44-func1818-stack-underflow.md`
- `docs/wiki/raw/research/0103-2026-04-18-generated-o4z-optimize-instructions-slot16-func652-carrier-guard.md`
- `docs/wiki/raw/research/0104-2026-04-18-generated-o4z-optimize-instructions-slot16-func1818-parent-exit-payload-guard.md`
- `docs/wiki/raw/research/0109-2026-04-18-generated-o4z-optimize-instructions-slot44-retired-by-replay-verification.md`
- `.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`
- `.artifacts/o4z-wasm-opt-debug.log`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `src/passes/optimize_test.mbt`

### Local Starshine implementation files

- `src/passes/optimize_instructions.mbt`
  - current summary: `Fold safe exact-instruction peepholes such as constant eqz, shift masks, and compare-to-zero patterns.`
  - large HOT-IR implementation centered on integer / boolean canonicalization and artifact-driven control-flow cleanup
- `src/passes/optimize_instructions_test.mbt`
  - extensive in-tree coverage for the currently implemented HOT-IR families
- `src/ir/hot_lower.mbt`
- `src/ir/hot_lower_test.mbt`
  - relevant because the saved generated-artifact slot `16` / `44` failures were ultimately retired by HOT-lowering / writeback guards, not by a newly reduced Binaryen peephole mismatch in the pass itself

## Official Binaryen `version_129` sources

### Main implementation and scheduler

- `src/passes/OptimizeInstructions.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OptimizeInstructions.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>

### Helper headers and utilities `OptimizeInstructions.cpp` depends on directly

- `src/ir/bits.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/bits.h>
- `src/ir/branch-hints.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h>
- `src/ir/drop.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h>
- `src/ir/effects.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- `src/ir/eh-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/eh-utils.h>
- `src/ir/gc-type-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h>
- `src/ir/literal-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/literal-utils.h>
- `src/ir/load-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/load-utils.h>
- `src/ir/localize.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/localize.h>
- `src/ir/manipulation.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
- `src/ir/properties.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- `src/ir/type-updating.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- `src/passes/call-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>

### Shipped test surface reviewed for this note

I reviewed the optimize-instructions lit surface directly and treated it as part of the real contract, not just nice-to-have examples.

The `version_129` optimize-instructions lit corpus contains `27` dedicated test files:

- `test/lit/passes/optimize-instructions-default.wast`
- `test/lit/passes/optimize-instructions-mvp.wast`
- `test/lit/passes/optimize-instructions-memory64.wast`
- `test/lit/passes/optimize-instructions-sign_ext.wast`
- `test/lit/passes/optimize-instructions-multivalue.wast`
- `test/lit/passes/optimize-instructions-atomics.wast`
- `test/lit/passes/optimize-instructions-bulk-memory.wast`
- `test/lit/passes/optimize-instructions-ignore-traps.wast`
- `test/lit/passes/optimize-instructions_idempotent.wast`
- `test/lit/passes/optimize-instructions_branch-hints-fold.wast`
- `test/lit/passes/optimize-instructions-call_ref.wast`
- `test/lit/passes/optimize-instructions-call_ref-roundtrip.wast`
- `test/lit/passes/optimize-instructions-exceptions.wast`
- `test/lit/passes/optimize-instructions-eh-legacy.wast`
- `test/lit/passes/optimize-instructions-iit-eh-legacy.wast`
- `test/lit/passes/optimize-instructions-gc.wast`
- `test/lit/passes/optimize-instructions-gc-atomics.wast`
- `test/lit/passes/optimize-instructions-gc-extern.wast`
- `test/lit/passes/optimize-instructions-gc-iit.wast`
- `test/lit/passes/optimize-instructions-gc-tnh.wast`
- `test/lit/passes/optimize-instructions-exact.wast`
- `test/lit/passes/optimize-instructions-all-casts.wast`
- `test/lit/passes/optimize-instructions-all-casts-exact.wast`
- `test/lit/passes/optimize-instructions-desc.wast`
- `test/lit/passes/optimize-instructions-nontrapping-float-to-int.wast`
- `test/lit/passes/optimize-instructions-strings.wast`
- `test/lit/passes/optimize-instructions-struct-rmw.wast`

Representative URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-default.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-call_ref.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-gc-tnh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-bulk-memory.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions-multivalue.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/optimize-instructions_branch-hints-fold.wast>

## Fast answer

Binaryen `optimize-instructions` is not just “constant folding for instructions.”

A better fast answer is:

- it is a large function-parallel post-walk peephole pass
- it canonicalizes instruction shapes first so later matches become easier
- it uses bit-width reasoning, fallthrough reasoning, effect analysis, type refinement, and feature gates to rewrite many small patterns safely
- it reaches far beyond plain arithmetic:
  - integer/float peepholes
  - boolean and compare normalization
  - `if` / `select` ternary hoisting and folding
  - load/store and memory-copy/fill simplification
  - `call_ref` directization opportunities
  - GC null-check, cast, RMW, cmpxchg, array, and descriptor rewrites
  - tuple extraction simplification
- when a rewrite changes types, it postpones repair until a function-level `ReFinalize`
- after all that, it runs a tiny final cleanup walk and then an EH pop-fixup helper

So the real contract is:

- **canonicalize first, then exploit that canonical form across many instruction families**

not:

- “just fold a couple of math ops.”

## Registered surface and scheduler placement

### Registered public surface

`pass.cpp` registers:

- `optimize-instructions`
  - description: `optimizes instruction combinations`

`passes.h` exports:

- `createOptimizeInstructionsPass()`

### Canonical no-DWARF scheduler placement

In `version_129` `pass.cpp`, the default function optimization path inserts `optimize-instructions` twice in the no-DWARF `-O` / `-Os` pipeline:

1. early cleanup cluster
   - after `remove-unused-brs`
   - before `heap-store-optimization`, `pick-load-signs`, and `precompute` / `precompute-propagate`
2. late cleanup cluster
   - after late `precompute` / `precompute-propagate`
   - before late `heap-store-optimization`, `rse`, and the final `vacuum`

That placement matters because the pass is deliberately used in two different moods:

- early canonicalization before several other simplifiers and local passes
- late canonicalization after structural cleanup has exposed new small patterns

### Nested reruns still matter

`opt-utils.h` shows that `optimizeAfterInlining(...)` prepends `precompute-propagate` and then reruns `addDefaultFunctionOptimizationPasses()` on touched functions.

That means `optimize-instructions` also appears inside nested optimizing reruns under later whole-module passes.

The saved generated-artifact `-O4z` debug log reflects that:

- top-level observed slots: `16`, `44`
- total `running pass: optimize-instructions` lines: `36`

So the real scheduler meaning is not “just those two visible top-level slots.”

## Pass options and mode switches that actually matter

`OptimizeInstructions.cpp` is full of mode-sensitive behavior. The main ones are:

- `fastMath`
  - enables some float canonicalizations that would otherwise preserve stricter signed-zero behavior
- `ignoreImplicitTraps`
- `trapsNeverHappen`
  - unlock many trap-sensitive rewrites, especially around null checks, memory.copy/fill zero-size drops, and cast removal
- `optimizeLevel` / `shrinkLevel`
  - influence profitability-sensitive transforms such as conditionalization and some bulk-memory lowerings
- `targetJS`
  - disables at least one rotate-based rewrite that is awkward for JS lowering
- pass arg `optimize-instructions-never-fold-or-reorder`
  - disables folding and reordering so branch-hint fuzzing does not create bogus metadata execution order

This is an important beginner warning:

- many rewrite families are **mode-dependent**
- describing the pass as one unconditional rule set is inaccurate

## Actual implementation structure

## Phase 1: function shell, local scan, main walk, optional refinalize, tiny final cleanup

The pass class is:

- `OptimizeInstructions : WalkerPass<PostWalker<OptimizeInstructions>>`
- `isFunctionParallel() == true`

The whole function pipeline inside `doWalkFunction()` is:

1. cache option flags
2. run `LocalScanner`
3. do the main post-order walk
4. if any rewrite changed a type, run `ReFinalize().walkFunctionInModule(...)`
5. run `FinalOptimizer`
6. run `EHUtils::handleBlockNestedPops(...)`

That shell already tells us a lot.

### What `LocalScanner` contributes

Before the main peepholes run, Binaryen scans locals to infer two compact facts per local:

- `maxBits`
- `signExtBits`

Those facts come from:

- the local type for params
- `Properties::getFallthrough(...)` on local-set values
- `Bits::getMaxBits(...)`
- `Properties::getSignExtValue(...)`
- sign-relevant signed loads

This is one of the major things the pass name hides.

A lot of the “small” rewrites are really powered by a lightweight per-function data summary about locals.

### What `replaceCurrent()` really does

`replaceCurrent()` is not a one-shot mutation helper.

It intentionally loops on the same node until no further local rewrite fires, while avoiding recursive re-entry.

That means the pass is designed to:

- canonicalize something
- then immediately exploit the new shape
- then maybe exploit the next new shape

Many of the compact-looking rule families rely on that local fixpoint behavior.

## Phase 2: canonicalization is a first-class strategy, not a tiny helper

Before most binary peepholes, `visitBinary()` calls `shouldCanonicalize()` and then `canonicalize()`.

That canonicalization does several important things:

- move constants to the right when legal
- prefer `x + (-C)` over `x - C` in many integer cases
- prefer comparisons to `0` over `-1` or `1`
- prefer comparisons to signed min/max or unsigned max in certain edge cases
- prefer `LocalGet` on the right in commutative forms
- sort otherwise-equal commutative children by node id / opcode / local index
- reverse relational operators when operands are swapped

This is why the pass can have so many specific-looking pattern matches later without exploding combinatorially.

It is not matching every possible spelling of a shape.

It first tries to make many shapes look alike.

## Phase 3: integer / float / bit-width peepholes are the biggest single family

The biggest central visitor is `visitBinary()`.

Important rewrite families there include:

- arithmetic normalization
  - `(0 - x) + y -> y - x`
  - `x + (0 - y) -> x - y`
  - `x + (-C) -> x - C`
  - `-x * -y -> x * y`
  - `-x * y -> -(x * y)` in limited integer cases
- boolean and compare rewriting
  - `(eqz (x - y)) -> x == y`
  - compare-to-zero canonicalization
  - unsigned and signed edge-constant compare simplifications
  - relational rewrites like `x - y == 0 -> x == y`
- shift and rotate cleanup
  - mask the shift amount to the effective bit-width
  - remove shift-by-zero
  - simplify `x <<>> (y & 31|63)` to `x <<>> y`
  - turn multiply/div/rem by powers of two into `shl`, `shr_u`, or `and`
  - combine nested shifts / rotates with constants
- sign-extension synthesis and removal
  - detect almost-sign-extend patterns
  - replace suitable shift pairs with `extend8_s`, `extend16_s`, `extend32_s`
  - drop redundant sign extends when the child is already sufficiently sign-extended
  - sometimes replace sign-ext comparisons with cheaper zero-extend forms
- bit-knowledge simplifications
  - if `Bits::getMaxBits(...)` proves a value can only use certain bits, remove redundant masks or prove comparisons true/false
  - if a value can only have zero bits, replace it with a literal zero via `replaceZeroBitsWithZero()`
- float rewrites gated by safety or `fastMath`
  - normalize negations
  - simplify multiply/divide by `1` or `-1`
  - power-of-two float division to multiplication by the inverse power-of-two
  - roundtrip simplifications for integer->float->integer conversions and redundant rounding ops
- deduplication
  - `neg(neg(x)) -> x`
  - repeated `abs`, `ceil`, `floor`, etc. collapse
  - repeated xor/and/or/rem patterns collapse when children match and ordering is safe

This family is broad, but there is still a clear theme:

- the pass prefers **canonical forms that later passes or later local patterns can keep simplifying**

not just minimal local byte count in isolation.

## Phase 4: boolean context, `if`, and `select` are treated specially

A lot of “instruction” optimization here is actually about control-shaped boolean plumbing.

### `optimizeBoolean(...)`

Binaryen has a dedicated helper for values flowing into boolean contexts.

Important examples:

- `eqz(eqz(x)) -> x` in boolean context
- invertible relational operators can be flipped under `eqz`
- `x != 0` in boolean context can become `x`
- some `% power-of-two` patterns become masked tests
- sign-extended values can be rewritten to cheaper zero-extended forms when only truthiness matters
- the helper recurses into result-producing `block`, `if`, `select`, and `try` forms in some cases

### `visitIf(...)`

Upstream `OptimizeInstructions.cpp` does **not** do generic constant-if folding here.

That is a very important distinction for this repo, because current Starshine does perform explicit constant-if folding in its HOT pass.

Binaryen `visitIf()` mainly does:

- optimize the condition in boolean context
- if the condition is `eqz` and there is an `else`, flip the arms and call `BranchHints::flip(...)`
- fold identical arms when safe and when `neverFold` is not active
- call `optimizeTernary(...)`

So the Binaryen story is:

- `if` optimization here is mostly about boolean normalization and duplicated-arm hoisting/folding
- generic constant-branch selection belongs more naturally to `precompute`

### `optimizeSelect(...)` and `optimizeTernary(...)`

This is one of the easiest parts of the pass to underestimate.

The pass has a serious amount of logic for two-arm value forms:

- constant-condition select simplification
- `x ? x : 0` / `x ? 0 : x` style rewrites
- boolean `select` simplification into `and` / `or`
- flipping select arms to remove `eqz`
- folding identical select arms when effect ordering allows it
- hoisting identical unary shells or other shallow-equal one-child wrappers out of `if` / `select`
- careful restrictions on:
  - child type compatibility
  - side effects for `select`
  - control-flow-structure arms
  - whether select arms can still be emitted legally

A future port must preserve the fact that this is **not** a generic CFG simplifier.

It is a careful local rewrite on ternary-shaped expressions.

## Phase 5: memory and bulk-memory shapes are part of the real pass

The source and tests make it clear that memory handling is part of the pass contract.

Important families:

- `optimizeMemoryAccess(...)`
  - fold constant address factors into the load/store offset when it does not overflow
  - distinguish memory32 vs memory64 rules
- `optimizeStoredValue(...)`
  - truncate stored constants to the written byte width
  - remove redundant masks on narrow stores
  - remove some sign-extension work that the narrower store will already discard
  - rewrite some reinterpret-store pairs into stores of the original representation type
- `optimizeMemoryCopy(...)`
  - under IIT/TNH, `memory.copy(x, x, sz)` can collapse to dropped arguments
  - constant-size `memory.copy` may lower to one load plus one store for sizes `1`, `2`, `4`, `8`, and some `16`-byte SIMD cases
- `optimizeMemoryFill(...)`
  - zero-size under IIT/TNH can drop the destination and value
  - small constant sizes can lower to store8/store16/store32/store64 or SIMD store patterns
  - size `1` can lower directly to `store8`

This is one of the places where the public name really undersells the pass.

## Phase 6: reference / GC / cast / `call_ref` logic is a huge part of `version_129`

For beginner-to-intermediate readers, this was the biggest surprise in the source review.

A very large slice of `OptimizeInstructions.cpp` is devoted to reference-typed and GC-specific rewrites.

Important families include:

- `skipNonNullCast(...)`
  - remove or move `ref.as_non_null` when a later operation already traps on null and effect ordering allows it
- `skipCast(...)`
  - in TNH mode, strip reference casts when the surrounding operation only cares about the value and the remaining type is still valid
- `trapOnNull(...)`
  - optimize expressions under the assumption that if a null would flow out to a null-trapping operation, then the operation will trap anyway
  - in TNH mode this can delete null-producing arms of `if` / `select`
- `visitRefEq(...)`
  - use heap-type intersection logic, cast skipping, null canonicalization, and equal-input detection
- `visitRefCast(...)` / `visitRefTest(...)`
  - use `GCTypeUtils::evaluateCastCheck(...)`
  - tighten cast types
  - materialize known success/failure/null outcomes
  - preserve exactness or descriptor information when removing a cast would lose useful information
  - use `Properties::getMostRefinedFallthrough(...)` plus tee-based reconstruction when the best propagated fallthrough value is more refined than the syntactic child
- `visitCallRef(...)`
  - `call_ref(ref.func ...) -> direct call`
  - `call_ref(table.get ...) -> call_indirect`
  - if the fallthrough target is a `ref.func`, rewrite to a direct call while preserving target-side effects and operand order, possibly using a temp local for the final operand
  - if the target is a suitable select of known direct targets, use `CallUtils::convertToDirectCalls(...)` to lower to an `if` over direct calls / return_calls
- `visitStructGet/Set/RMW/Cmpxchg` and array counterparts
  - remove redundant non-null checks
  - simplify default constructors and default-initialized arrays
  - relax acquire-release field ops on unshared heaps to unordered
  - optimize or lower unshared GC RMW/cmpxchg shapes to ordinary get/set logic
  - deliberately avoid optimizing seqcst shared RMWs in unsafe ways
- `visitTupleExtract(...)`
  - `tuple.extract(tuple.make(...))` becomes direct lane extraction via a tee and dropped-child reconstruction

The real `version_129` pass is therefore deeply entangled with modern reference and GC semantics.

## Phase 7: tiny final cleanup and EH repair are real, not incidental

After the main visitor:

- `FinalOptimizer` does a small last normalization step, notably around final add/sub spelling and signed-LEB-friendly constants
- `EHUtils::handleBlockNestedPops(...)` repairs pop nesting that some rewrites can temporarily invalidate

This is important because it means the pass is not “just a single walk and done.”

The implementation explicitly expects some rewrites to need:

- deferred type repair
- deferred EH cleanup

## Key helper and analysis dependencies

The pass is not a heavy CFG analysis pass, but it does depend on a large helper surface.

The most important dependencies to preserve are:

- `Bits`
  - max bits, min bits, effective shifts, power-of-two reasoning, masked-bit reasoning
- `Properties`
  - fallthroughs, sign-extension recognition, boolean emission, generative-value checks, control-flow-structure identification, arm-emittability checks, most-refined fallthrough selection
- `EffectAnalyzer` and `ShallowEffectAnalyzer`
  - reordering safety, trap movement safety, deduplication safety, select folding safety
- `Intrinsics`
  - idempotent call annotations for equal-input reasoning
- `GCTypeUtils`
  - cast-check result lattice and field queries
- `ChildLocalizer`
  - preserve effect order when deleting or moving operands but keeping one value alive
- `BranchHints::flip`
  - update metadata when a condition is inverted by swapping `if` arms
- `ReFinalize`
  - repair types after rewrites that intentionally change them
- `EHUtils::handleBlockNestedPops`
  - clean up exception-pop nesting after structural rewrites
- `CallUtils::convertToDirectCalls`
  - whole-target-shape lowering for some `call_ref` cases

So a faithful future port needs more than a bag of peephole patterns.

It also needs the helper substrate those patterns assume.

## What the pass does **not** do

Important negative facts from the source review:

- it is not a constant-everything folder; `precompute` still owns broader compile-time evaluation
- it is not a liveness or CFG pass
- it does not generally perform arbitrary code motion; reordering is local and heavily effect-gated
- it does not freely remove casts just because TNH mode exists; exactness, descriptors, and downstream optimization value still matter
- it does not optimize every bulk-memory or RMW size/state combination; many transforms are deliberately narrow
- it does not generically fold control-flow structures with multiple-child shells in `optimizeTernary`; the hoisting logic is intentionally shallow and constrained
- it does not try to handle every shared-memory atomic case; seqcst shared GC RMW/cmpxchg is explicitly protected
- it does not own later tiny-structure cleanup by itself; `vacuum`, `rse`, `remove-unused-brs`, and `merge-blocks` still matter around it

## Easy misunderstandings to avoid

### 1. “This is just arithmetic peepholes.”

False.

Arithmetic peepholes are a big part of the file, but so are:

- boolean/control canonicalization
- memory and bulk-memory lowering
- `call_ref`
- GC casts/null checks
- struct/array atomics and constructors
- tuple extraction

### 2. “The pass is basically constant folding.”

False.

`precompute` is the main constant evaluator.

`optimize-instructions` is more about:

- canonicalizing shapes
- simplifying local instruction families
- exposing later opportunities
- preserving or exploiting trap/type facts

### 3. “If Starshine folds a constant `if`, that matches Binaryen optimize-instructions.”

Not necessarily.

Upstream `visitIf()` in `version_129` does not implement a generic constant-if picker. That shape is much closer to `precompute` territory.

### 4. “TNH means casts and null checks can just disappear.”

Only partially.

The source goes out of its way to explain why removing casts can throw away useful type information, especially for exactness, descriptors, and downstream GUFA-like reasoning.

### 5. “This pass only matters in its two top-level pipeline slots.”

False.

Nested optimizing reruns make it show up repeatedly inside real optimize runs.

## Starshine-preservation takeaways

The most important future-port facts to preserve are:

- the pass is a **function-parallel post-walk** with a local rewrite loop, not a one-shot single-pattern mutator
- canonicalization is part of the algorithm, not just cleanup style
- local bit-width and sign-extension knowledge from a pre-scan is central to many rewrites
- the control-flow side is mostly about boolean normalization and ternary hoisting/folding, not generic constant-if folding
- trap-sensitive rewrites must preserve sibling ordering and type validity
- GC/cast logic depends on real helper utilities, not just syntax checks
- `call_ref` optimization is a real pass responsibility in upstream `version_129`
- when rewrites change types, refinalization is mandatory
- EH pop nesting cleanup is part of the real postcondition

The biggest current Starshine gap is not a tiny missing arithmetic identity.

It is the much broader upstream surface around:

- cast reasoning
- trap-on-null logic
- `call_ref`
- bulk memory
- GC RMW/cmpxchg
- tuple extraction
- helper-driven type and EH repair

## Relation to the saved generated-artifact `-O4z` failures

The saved ordered generated-artifact audit originally showed this pass failing at slots `16` and `44`.

Those failures are now retired.

The durable conclusion from `0095`, `0100`, `0103`, `0104`, and `0109` is:

- the live corruption family is no longer an open `optimize-instructions` blocker
- the observed failures were resolved by HOT-lowering / writeback guards that prevented invalid carried-result wrapper packing
- that means the remaining work for this pass is documentation depth, parity breadth, and runtime honesty, not a still-open hard corruption witness

This is also a useful warning when reading the local implementation:

- some current Starshine test coverage around `optimize-instructions` is actually guarding the **writeback boundary around the pass**, not proving full parity with Binaryen `OptimizeInstructions.cpp`

## Open questions / uncertainty

- I did not attempt to enumerate every last arithmetic peephole in the 5.8k-line source file. The living docs should focus on the major stable families and the helper structure that makes the pass work.
- The broad shape categories above are directly grounded in the source and tests. When I describe the pass as “instruction-shape canonicalizer and trap-sensitive simplifier,” that wording is an inference from the implementation structure rather than a phrase used verbatim by upstream.
- I did not do a fresh trunk-drift audit beyond using `version_129` as the source oracle. That is intentional: the repo's current Binaryen parity contract for pass research is still `version_129`.

## Bottom line

Binaryen `optimize-instructions` is one of the biggest “small-sounding” passes in the pipeline.

The safest mental model is:

- a broad canonicalization-and-peephole pass for instruction-shaped expressions,
- driven by bit facts, fallthrough facts, effect ordering, and feature gates,
- with important control-flow, memory, `call_ref`, GC, and cast sub-stories,
- and with refinalization / EH repair as part of the actual contract.

That is the story the living wiki should teach, and the story a future honest Starshine parity plan must preserve.
