# `simplify-globals-optimizing` current-main refresh

_Date:_ 2026-05-18  
_Status:_ filed into living wiki pages

## Question

Refresh the upstream Binaryen `simplify-globals-optimizing` research before continuing Starshine implementation. The specific goal was to re-check official Binaryen sources on current `main`, answer the current open SGO questions, and identify focused Starshine slices that follow Binaryen without broad unsafe rewrites.

## Primary sources reviewed

Official Binaryen GitHub sources were checked on 2026-05-18. The `main` head observed through the GitHub commits API was:

- commit: `d3029d2b975488acdf9253eb2994a3fc55bd3549`
- committer date: `2026-05-15T22:34:18Z`
- commit page: <https://github.com/WebAssembly/binaryen/commit/d3029d2b975488acdf9253eb2994a3fc55bd3549>

Files pulled from official raw GitHub `main` for local comparison:

- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SimplifyGlobals.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/pass.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/effects.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/linear-execution.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/properties.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/utils.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/simplify-globals-read_only_to_write.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/simplify-globals-dominance.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/simplify-globals-gc.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/simplify-globals-non-init.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/simplify-globals-single_use.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/simplify-globals_func-effects.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/simplify-globals-nested.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/simplify-globals-offsets.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/simplify-globals-prefer_earlier.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/propagate-globals-globally.wast>

The focused diff against `version_129` found no SGO semantic drift in `SimplifyGlobals.cpp`, `pass.h`, `simplify-globals-read_only_to_write.wast`, or `simplify-globals_func-effects.wast`. The only `SimplifyGlobals.cpp` differences were comment typo fixes (`noticeable`, `anything`). `pass.cpp` had unrelated registration/doc-string additions outside SGO placement and SGO registration.

## Answers to the research focus questions

### How Binaryen computes `read-only-to-write`

`GlobalUseScanner` increments ordinary `read` on every concrete `GlobalGet` and ordinary `written` on every concrete `GlobalSet`. It separately increments `readOnlyToWrite` for two source-recognized families:

1. an `if` without `else` whose condition reads a global and whose true arm only writes that same global, and
2. a whole-function body exactly shaped as a two-child block: `if condition return` followed by write code.

The final removable-global test in `removeUnneededWrites()` is `info.read == info.readOnlyToWrite`, after excluding imported/exported globals. This is deliberately count-based and whole-module: any extra concrete read outside recognized safe sites prevents the read-only-to-write reason from making all writes removable.

### Actual-node structural checks vs effect summaries

Binaryen uses effects for safety but not as replacements for concrete syntax. The body must have exactly one written global effect and no remaining effects after clearing that write, but the matcher still scans for an actual `GlobalSet` for the written global. The condition must have a mutable-global-read effect for the written global, but the matcher still scans for an actual `GlobalGet`. Calls with computed global effects do not satisfy the structural matcher.

### Same-as-init write removal

`visitGlobalSet` marks `nonInitWritten` when the global is imported, the set value is not a constant expression, the initializer is not a constant expression, or the set and initializer literals differ. Later, `removeUnneededWrites()` removes all sets for private globals when `!info.nonInitWritten`; it replaces each set with `drop(value)` and marks the global immutable/unwritten.

The key implication for Starshine is that same-as-init is source-wide and literal-vector based over Binaryen constant expressions, not just a local `i32.const` peephole.

### Startup propagation vs runtime propagation

`propagateConstantsToGlobals()` walks globals in definition order, tracking constants known during instantiation and applying them to later global initializers, element offsets, and data offsets. This can use mutable globals because no runtime code has executed yet.

`propagateConstantsToCode()` is narrower. It starts with immutable non-imported constant-initialized globals and also tracks current constants created by constant `global.set`s in a cheap `LinearExecutionWalker` trace. Calls clear all current facts unless shallow effects prove only specific written globals; nonlinear control clears the map.

### Type/refinalization and replacement legality

Immutable copy-chain canonicalization rewrites only when the earliest ancestor global's declared type exactly matches the current `global.get` type. Binaryen still has a TODO for more refined replacements requiring refinalization.

Constant replacement into function code is different: if the replacement expression type differs from the old node type, `ConstantGlobalApplier` sets `refinalize = true` and runs `ReFinalize()` on the changed function before the optimizing nested cleanup.

### Iteration / fixed point behavior

The pass runs `while (iteration())`. Each iteration does `analyze()`, `foldSingleUses()`, `removeUnneededWrites()`, `preferEarlierImports()`, `propagateConstantsToGlobals()`, and `propagateConstantsToCode()`. Only `removeUnneededWrites()` requests another full iteration, and only when the removable reason was all reads being read-only-to-write. The source comment ties this to nested self-guard families where removing inner writes erases effects that blocked an outer match.

### Optimizing wrapper / nested default-function rerun

`simplify-globals-optimizing` is the same shared `SimplifyGlobals` engine with `optimize = true`. When `ConstantGlobalApplier` replaces a `global.get`, or `GlobalSetRemover` replaces a `global.set` with `drop(value)`, the changed function gets a nested `PassRunner(getPassRunner())`, then `addDefaultFunctionOptimizationPasses()`, then `runOnFunction(curr)`.

This remains different from DAE/inlining optimizing siblings: no `precompute-propagate` prefix is added here.

### Most important official-test gaps for Starshine

The current Starshine subset has strong coverage for many literal/adjacent/block-yielded self-guard families, but the official tests still point to gaps worth slicing carefully:

- generic side-effect-free condition expressions beyond `eqz` and `eq`/`ne` compare-const shapes;
- `read-only-to-write` conditions with side effects that are safe because the global value does not steer those effects, such as the `select` / `local.tee` / `i32.load` positive in `simplify-globals-read_only_to_write.wast`;
- flow-sensitive negatives where the global value does steer a call, `local.tee`, or another side effect;
- broader same-as-init constant-expression equivalence;
- exact Binaryen `LinearExecutionWalker` adjacency behavior from `simplify-globals-dominance.wast`, especially the dominated-then positive and else-path TODO negative;
- GC refinalization cases from `simplify-globals-gc.wast`, where function-code constant replacement may change reference precision and require type repair.

## Starshine-focused slice recommendations

Prefer these next, in order, because they are source-backed and can be tested narrowly:

1. Add negative guard tests around the already broadened read-only-to-write helpers: wrong target global, non-constant set operand, `if` with `else`, top-level trailing code after `if return; set`, and condition values that flow into side effects. These protect correctness before more widening.
2. Add a very narrow generic-pure-condition self-guard slice: a single concrete `global.get $g` flowing through side-effect-free integer operators before an adjacent no-else `if` whose body is one same-global constant set. This follows Binaryen's generic condition contract without implementing full `FlowScanner` yet.
3. Only after that, consider the official safe-side-effect condition positive, but keep it separate because it requires value-flow reasoning rather than just a pure-expression whitelist.
4. Treat broader same-as-init and GC/refinalization as separate slices; both require stronger constant-expression/type machinery than the existing single-const and exact-type gates.
5. Revisit the SGO nested cleanup large-module / touched-set guard with artifact/performance evidence; the upstream wrapper has no analogous touched-count skip, but Starshine should remove it only with a safe performant replacement.

## Durable wiki updates made

- Updated the `simplify-globals-optimizing` landing, Binaryen strategy, linear-trace/read-only-to-write, Starshine strategy, and Starshine port-readiness pages with a 2026-05-18 current-main no-drift note and sharper slice guidance.
- Updated `docs/wiki/index.md` and `docs/wiki/log.md` with this refresh.

## Uncertainties and non-claims

- The current-main head can move after this note. The observed commit above is the exact anchor for this refresh.
- The raw source fetch was a focused SGO recheck, not a full Binaryen release audit.
- The recommended Starshine slices are implementation guidance, not proof that the current local IR helpers are sufficient without new safety checks.
