# Binaryen `de-nan` / `denan` research

Date: 2026-04-21
Status: source-backed upstream-only dossier seed
Pass: local registry `de-nan`, upstream public pass `denan`
Local registry status: `removed` in `src/passes/optimize.mbt`
Binaryen release reviewed: `version_129`
Current-main drift check: reviewed on 2026-04-21; `src/passes/DeNaN.cpp` differs from `main` only by a comment typo fix (`contant` -> `constant`), `pass.cpp` registration is unchanged, and `test/lit/passes/denan.wast` is byte-identical on `main`

## Why this note exists

The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only wave are already dossier-covered.
That meant this thread needed either:

- a clearly justified major-gap fallback inside an already-deep folder, or
- a new source-backed upstream-only registry expansion.

I chose the second path.

`de-nan` / `denan` is a good expansion target because:

- the local removed-pass registry in `src/passes/optimize.mbt` still explicitly names `de-nan`
- upstream `version_129` exposes a real public pass named `denan`
- the pass has a dedicated implementation file and a dedicated lit file
- it is easy for beginners to misunderstand as either constant folding, NaN canonicalization, or generic floating optimization, when it is actually runtime instrumentation
- it teaches a different kind of Binaryen pass contract than the optimization passes already covered here: a pass can deliberately add helper calls and helper functions to reduce nondeterminism instead of improving speed or size
- `agent-todo.md` currently has **no dedicated `de-nan` / `denan` slice**

## Executive summary

Binaryen `denan` instruments floating-point-producing wasm so that any NaN value that would otherwise flow onward is replaced with `0` at runtime.

The reviewed implementation does that in three layers:

1. **constant fixup**
   - if a `Const` is already a NaN, rewrite it directly to `0`
2. **entry sanitization of parameters**
   - at the start of each non-imported function, rewrite `f32`, `f64`, and `v128` params through helper calls
3. **expression-result sanitization**
   - for floating-point or SIMD expressions whose result is not just a structural fallthrough, wrap the expression in a helper call that returns the original value if it is not NaN and `0` otherwise

The pass is therefore **not**:

- a default no-DWARF optimize-path pass
- a code-size pass
- a speed pass
- a generic floating simplifier
- a NaN payload canonicalizer that preserves NaN-ness

Its actual contract is:

- **remove NaN nondeterminism by forcing NaN-producing flows to become zero-valued flows**

## Primary sources reviewed

### Core implementation

- `src/passes/DeNaN.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/denan.wast`

### Important helper dependencies

- `src/ir/names.h`
  - helper-function name collision avoidance via `Names::getValidFunctionName`
- `src/ir/properties.h`
  - `Properties::isResultFallthrough(...)` is the key guard that prevents repeated wrapping of structural pass-through nodes
- `src/wasm-builder.h`
  - helper-function construction and local/body rewrites
- `src/pass.h`
  - the pass is a `WalkerPass<ControlFlowWalker<...>>` and marks `addsEffects() = true`

## Public names and local naming split

This pass has a real naming split that the wiki should preserve explicitly.

- upstream public pass name in `pass.cpp`: `denan`
- local Starshine removed-registry name in `src/passes/optimize.mbt`: `de-nan`

So there are not two different Binaryen passes here.
The local spelling is just a registry alias.
A future Starshine port should probably accept the local spelling for continuity, but the dossier should keep the upstream public name visible because the official Binaryen CLI and test file use `denan`.

## What the pass sounds like versus what it actually does

### What the name can make people assume

A beginner might guess:

- make NaNs deterministic but still NaNs
- canonicalize one NaN payload to another NaN payload
- optimize away some floating weirdness
- rewrite only constants
- maybe run only while fuzzing, not as a real pass

### What the reviewed implementation actually does

It is much more direct:

- if an expression result has type `f32`, `f64`, or `v128`, Binaryen tries to ensure that result is **not NaN**
- NaN constants become zero constants immediately
- nonconstant producers are routed through helper calls
- function parameters of those types are sanitized on function entry
- helper functions are added after the walk so the pass does not instrument its own instrumentation

That means the real semantic promise is:

- after the pass, NaN values should not be *consumed* by later instructions in ordinary function code paths, because they are replaced by zero first

That is a stronger and more behavior-changing contract than “canonicalize NaNs.”

## Implementation structure

## 1. The pass is a control-flow walker that mutates expressions in place

The pass type is:

- `WalkerPass<ControlFlowWalker<DeNaN, UnifiedExpressionVisitor<DeNaN>>>`

That matters because the pass wants to visit expression results in normal control-flow order and replace current nodes in place.
It is not a whole-module analysis pass and it is not a separate CFG-building pass.

The pass also overrides:

- `bool addsEffects() override { return true; }`

That is an important contract detail.
The pass adds helper **calls**, so it must honestly report that it introduces effects.
A future Starshine port must preserve that classification and not pretend this is a pure tree rewrite.

## 2. Three helper names are reserved up front

Before the actual walk, `doWalkModule(...)` chooses fresh helper names:

- `deNan32`
- `deNan64`
- `deNan128`

using `Names::getValidFunctionName(*module, root)`.

That means:

- existing user-defined functions with those names are allowed
- Binaryen will auto-suffix fresh helper names to avoid collisions
- the dedicated lit file explicitly checks this behavior with a second module that already defines `$deNan32` and `$deNan64`

This is a real part of the public contract, not just implementation trivia.

## 3. The pass rewrites expression results, but skips two important families

`visitExpression(Expression* expr)` first rejects two cases:

### Case A: `local.get`

The pass does **not** instrument `local.get`.
The source comment explains why:

- if it instrumented `local.get`, rerunning the pass would break its own helper bodies and other inserted flows

This is the first big idempotence boundary.
It does not make the whole pass fully idempotent, but it prevents the most obvious self-instrumentation explosion.

### Case B: result-fallthrough nodes

The pass also skips nodes where `Properties::isResultFallthrough(expr)` is true.
In `properties.h`, that includes structural nodes such as:

- `local.set`
- `block`
- `if`
- `loop`
- `try`
- `try_table`
- `select`
- `break`

The key idea is:

- if the node's result is just a child result flowing through unchanged, Binaryen expects that child to have already been sanitized
- wrapping the structural shell again would double-instrument the same value path

This is one of the most important non-obvious rules in the whole pass.
Without it, `denan` would add many redundant nested helper calls around ordinary structured expressions.

## 4. Type-based rewrite surface

After those guards, the rewrite surface is small and entirely type-driven.

### `f32`

- if the expression is a NaN constant: replace with `f32.const 0`
- otherwise if it is nonconstant: replace with `(call $deNan32 expr)`

### `f64`

- if the expression is a NaN constant: replace with `f64.const 0`
- otherwise if it is nonconstant: replace with `(call $deNan64 expr)`

### `v128`

- if the expression is a constant that may contain any NaN lane: replace with all-zero `v128`
- otherwise if it is nonconstant: replace with `(call $deNan128 expr)`

### everything else

- untouched

So the pass's actual IR surface is not “all floating operations.”
It is:

- **all expression results whose type is `f32`, `f64`, or `v128`, except for the explicit skip families**

That includes calls, unary ops, binary ops, and many other producers implicitly.

## 5. Constant handling is compile-time, because some contexts cannot contain calls

A very important source comment says constant folding here is useful for places like global initializers, where calls are illegal.

This explains the following replacement rule:

- if the chosen replacement is a `Const`, Binaryen can use it anywhere
- if the chosen replacement is a `Call`, Binaryen only installs it when `getFunction()` is available
- otherwise it prints a warning that it cannot de-NaN outside function context

So the pass has a real context boundary:

- **module-level floating constants can be de-NaNed only when the fixup can be expressed as another constant**
- nonconstant module-level expressions cannot be forced through helper calls here

The shipped lit file covers the positive half by showing `(global (mut f32) (f32.const nan))` becoming `(f32.const 0)`.

## 6. Function-parameter sanitization is a separate phase

`visitFunction(Function* func)` does extra work after expression walking:

- skip imported functions completely
- inspect each parameter local
- for every `f32`, `f64`, or `v128` parameter, emit:
  - `local.set param (call $deNanXX (local.get param))`
- prepend those fixups to the function body

That means the pass does **not** rely only on uses inside the body to sanitize incoming parameters.
It eagerly repairs them at function entry.

This is easy to miss if you only read the high-level pass description.
The pass is both:

- expression-result instrumentation, and
- ABI-entry sanitization for floating/vector params

## 7. Nested `merge-blocks` cleanup is part of the real contract

If parameter fixups were added, the pass wraps the body in a block and then immediately runs a nested pass runner containing:

- `merge-blocks`

The source comment says this is to avoid adding an unnecessary block.

So `merge-blocks` is not just a nearby unrelated optimization here.
It is an explicit nested cleanup step inside `denan` itself.
A future port must preserve that or replicate the same normalization another way.

## 8. Helper functions are added only after the walk

After the traversal finishes, `doWalkModule(...)` appends helper functions:

- `deNan32`
- `deNan64`
- `deNan128` only when SIMD is enabled

The source comment explains why the helpers are added after the walk:

- so they are not instrumented themselves

That is the second major self-interference boundary.

## Helper function contract

## Scalar helpers: `f32` and `f64`

For scalar types the helper body is conceptually:

```wat
(if (result f*)
  (f*.eq (local.get 0) (local.get 0))
  (local.get 0)
  (f*.const 0)
)
```

That works because NaN is the floating value that is not equal to itself.
So:

- true => not NaN => return original value
- false => NaN => return zero

This preserves all non-NaN values exactly and collapses all NaN values to zero.

## SIMD helper: `v128`

The SIMD helper is the most subtle part of the pass.

The comments explain two distinct ideas.

### Idea A: check only as `f32x4`

Binaryen notes that the f32 NaN bit-pattern condition is a superset of the f64 one, because:

- it checks fewer exponent bits
- and it checks more lanes

So checking the vector as four `f32` lanes is sufficient to catch any possible f32 or f64 NaN interpretation that matters for this instrumentation purpose.

### Idea B: do **not** use vector equality directly

The obvious vector compare would produce all-ones lanes on equality.
But those bit patterns themselves look like NaN patterns.
So if the pass were rerun, that helper implementation would interfere with itself.

To avoid that, Binaryen:

- extracts each f32 lane
- compares each scalar lane to itself with `EqFloat32`
- ANDs the resulting i32 booleans together

So the helper condition is scalarized lane-by-lane instead of using `EqVecF32x4` directly.

That is one of the most interesting “easy to miss” details in the whole file.

## Constant `v128` detection

For constant vectors the helper is not used.
Instead `hasNaNLane(Const* c)`:

- computes `value.eqF32x4(value)`
- then `allTrueI32x4()`
- and returns whether the result is not all-true

If any lane fails self-equality under the f32-lane interpretation, Binaryen replaces the constant with an all-zero vector literal.

## Important positive shapes

## Positive shape 1: NaN global initializer constant

```wat
(global (mut f32) (f32.const nan))
```

becomes:

```wat
(global (mut f32) (f32.const 0))
```

Why it works:

- constant-only rewrite is legal outside function context

## Positive shape 2: floating call result

```wat
(func (param f32) (result f32)
  (call $foo32 (local.get 0))
)
```

gets both:

- entry fixup for the param, and
- wrapping of the `call` result through `$deNan32`

## Positive shape 3: floating unary producer

```wat
(drop (f32.abs (local.get $f)))
```

becomes:

```wat
(drop (call $deNan32 (f32.abs (local.get $f))))
```

because the producer is nonconstant and returns `f32`.

## Positive shape 4: local.set of floating producer

```wat
(local.set $f (f32.abs (local.get $f)))
```

becomes:

```wat
(local.set $f (call $deNan32 (f32.abs (local.get $f))))
```

The parent `local.set` itself is a fallthrough node and is not wrapped again.
Only its value child is repaired.

## Positive shape 5: NaN constants inside function bodies

```wat
(drop (f64.const nan))
```

becomes simply:

```wat
(drop (f64.const 0))
```

No helper call is needed.

## Important preserved or bailout shapes

## Preserved shape 1: raw `local.get`

```wat
(drop (local.get $f))
```

stays as a `local.get` use.
The pass relies on earlier entry sanitization or defining-expression sanitization, not on wrapping every read.

## Preserved shape 2: pure tee/get ladders that only pass a result through

The shipped test shows repeated `local.tee` layers around `local.get $x` staying unchanged except for the function-entry param fixup.
That proves the combination of:

- skip `local.get`
- skip result-fallthrough nodes

is intentionally preserving pass-through structure.

## Preserved shape 3: select shells

The dedicated lit file shows a floating-result `select` body remaining structurally as `select` after entry sanitization.
That is because `select` is a result-fallthrough node in `properties.h`.

This is a good beginner example of “the pass repairs producers, not every structural shell.”

## Preserved shape 4: imported functions

Imported functions are skipped by `visitFunction`.
So no entry fixups are inserted there.

## Preserved shape 5: nonfloating types

`i32`, `i64`, refs, and so on are not in scope unless they appear inside the helper logic itself.

## Important interactions

## Interaction with `merge-blocks`

This is a direct nested dependency, not just a pipeline neighbor.
Parameter fixups create a wrapper block, and `denan` immediately runs nested `merge-blocks` to simplify that structural noise.

## Interaction with reruns / idempotence

The pass has several anti-self-interference measures:

- skip `local.get`
- skip result-fallthrough nodes
- add helper funcs only after the walk
- avoid vector-equality instrumentation in the `v128` helper itself

Even so, the safest documented reading is still:

- **do not teach this as a fully idempotent normalization pass**
- teach it as a carefully guarded one-shot instrumentation pass

That caution is an inference from the implementation style and comments.

## Interaction with validation constraints

The module-context guard around nonfunction rewrites is essential.
A future port must preserve the fact that:

- calls cannot appear in global initializers
- therefore only constant rewrites are legal there

## Interaction with fuzzing

The top-of-file comment explicitly frames the pass as useful when fuzzing between VMs that differ on wasm NaN nondeterminism.
So this pass belongs conceptually closer to:

- determinization / instrumentation

than to:

- default optimization scheduling

That explains why it is absent from the repo's no-DWARF default optimize-path page.

## What is easiest to misunderstand

1. **`denan` does not preserve NaNs in canonical form.**
   - It replaces them with zero.
2. **It is not just a constant rewrite pass.**
   - It wraps general floating producers in helper calls.
3. **It is not “wrap every float-typed node.”**
   - `local.get` and result-fallthrough nodes are deliberately skipped.
4. **The entry-param fixup phase is part of the main contract.**
   - It is not just a helper convenience.
5. **The SIMD path is not a trivial vector compare.**
   - It scalarizes lane checks deliberately to avoid self-interference.
6. **Nested `merge-blocks` is part of the shipped behavior.**
   - It is not a hypothetical future cleanup step.
7. **This is not a parity target for the current no-DWARF optimize path.**
   - It is an explicit optional upstream-only pass.

## Future Starshine port invariants

A future Starshine implementation should preserve at least these rules:

- accept the local `de-nan` name, but document the upstream `denan` alias explicitly
- report that the pass adds effects
- sanitize non-imported floating/vector params on function entry
- sanitize floating/vector expression results, but skip `local.get`
- preserve the result-fallthrough boundary instead of wrapping structural shells redundantly
- allow constant-only repair in global initializers, but never insert helper calls there
- generate fresh helper function names collision-safely
- add helper functions after the walk to avoid self-instrumentation
- preserve the special `v128` helper logic and its no-vector-eq self-interference trick
- preserve the nested cleanup of wrapper blocks

## Open questions and uncertainty

### High-confidence facts

These are directly grounded in reviewed source or tests:

- pass name split: local `de-nan` vs upstream `denan`
- entry-param fixup behavior
- `local.get` skip
- result-fallthrough skip
- scalar helper shape
- SIMD helper lane-extraction strategy
- imported-function skip
- global-constant-only repair boundary
- nested `merge-blocks`

### Inferences

These are reasoned from the source, but not stated as explicit upstream prose policy:

- the pass should be taught as a one-shot instrumentation pass rather than a general rerunnable normalization pass
- the chosen anti-self-interference guards are specifically designed to make fuzzing-oriented repeated use safer, even though the source does not promise complete idempotence
- the best teaching position for this pass in the local wiki is beside instrumentation / determinization surfaces, not beside default optimization scheduling docs

## Short beginner summary

If you need one accurate sentence, use this:

- Binaryen `denan` rewrites floating and SIMD value flows so NaNs become zeros, using constant fixups, function-entry param sanitization, and helper calls around nonconstant producers.

## Sources

- `src/passes/optimize.mbt`
- `agent-todo.md`
- Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeNaN.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/names.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/denan.wast>
- Current-main freshness check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/DeNaN.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/denan.wast>
