---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-05-de-nan-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md
  - ../../../raw/research/0478-2026-05-05-de-nan-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-de-nan-current-main-line-anchor-refresh.md
  - ../../../raw/research/0512-2026-05-06-de-nan-current-main-line-anchor-refresh.md
  - ../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeNaN.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/names.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-builder.h
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./helper-functions-fallthrough-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# Binaryen strategy for `de-nan` / `denan`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md`](../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md), the focused current-main recheck in [`../../../raw/binaryen/2026-05-05-de-nan-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-de-nan-current-main-recheck.md), and the 2026-05-06 line-anchor refresh in [`../../../raw/binaryen/2026-05-06-de-nan-current-main-line-anchor-refresh.md`](../../../raw/binaryen/2026-05-06-de-nan-current-main-line-anchor-refresh.md).
For exact current Starshine status and local code locations, see [`./starshine-strategy.md`](./starshine-strategy.md).

## What the pass really is

The reviewed implementation is a **behavior-changing instrumentation pass**.
It does not try to optimize floating code and it does not preserve NaN payloads in a canonical form.

The actual strategy is:

- if a value of type `f32`, `f64`, or `v128` is already a constant NaN, replace it with zero immediately
- if a nonconstant expression produces one of those types, route it through a helper call
- if a function parameter has one of those types, sanitize it at function entry
- do all of that while avoiding self-instrumentation and invalid module-context rewrites

So the best mental model is:

- **NaN-to-zero determinization through selective compile-time rewrites plus helper calls**
- not constant folding
- not floating optimization
- not default-preset optimization scheduling

## Public surface and scheduler meaning

`src/passes/pass.cpp` registers the public pass name:

- `denan`

with the description:

- `instrument the wasm to convert NaNs into 0 at runtime`

That public summary is accurate.
The local Starshine registry still tracks the pass under the alias:

- `de-nan`

So a future Starshine port should preserve the alias split explicitly, not silently pretend the names already match.

Unlike most dossiers in the no-DWARF parity campaign, this pass is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` path.
A future Starshine implementation should therefore treat it as an optional explicit pass with its own semantics, not as a missing required preset slot.
The 2026-05-05 current-main recheck did not find a scheduler or registration drift that would change that local teaching rule.

## Core structure

The pass type is:

- `WalkerPass<ControlFlowWalker<DeNaN, UnifiedExpressionVisitor<DeNaN>>>`

And it overrides:

- `bool addsEffects() override { return true; }`

That second detail is easy to overlook, but it matters a lot:

- the pass inserts helper **calls**,
- so Binaryen correctly advertises that it adds effects.

A future port must preserve that truth in whatever pass metadata or scheduler invalidation story Starshine uses.

## Core state

The pass stores three helper names:

- `deNan32`
- `deNan64`
- `deNan128`

These are chosen with `Names::getValidFunctionName(*module, root)` inside `doWalkModule(...)`.

That tells us two important things:

1. helper functions are generated per module, not globally shared
2. existing user names are respected and collision-safe suffixing is part of the real contract

The dedicated lit file explicitly covers that second point.

## Main algorithmic phases

## Phase 1: walk expressions and repair float/SIMD producers

`visitExpression(Expression* expr)` is the heart of the pass.
But before it rewrites anything, it applies two hard guards.

### Guard A: skip `local.get`

If `expr->is<LocalGet>()`, return immediately.

This matters because helper bodies and already-sanitized flows will naturally contain `local.get`.
If the pass wrapped those again, rerunning the pass would quickly self-instrument its own instrumentation.

### Guard B: skip result-fallthrough nodes

If `Properties::isResultFallthrough(expr)`, return immediately.

In `properties.h`, that includes structural nodes like:

- `local.set`
- `block`
- `if`
- `loop`
- `try`
- `try_table`
- `select`
- `break`

The idea is:

- if a node's result merely passes through from a child without modification,
- then the child is the place that should be sanitized,
- not the outer shell.

Without this guard, ordinary structured expressions would get wrapped multiple times.

## Phase 2: choose the replacement by type and const-ness

After those guards, the pass computes a replacement.

### `f32`

- constant NaN => `f32.const 0`
- nonconstant producer => `(call $deNan32 expr)`

### `f64`

- constant NaN => `f64.const 0`
- nonconstant producer => `(call $deNan64 expr)`

### `v128`

- constant with any NaN lane => zero vector constant
- nonconstant producer => `(call $deNan128 expr)`

### everything else

- untouched

That is the entire rewrite surface.
The pass does **not** ask whether the operation is arithmetic, a call, a conversion, or something else.
It only asks:

- what type does the expression produce?
- is it constant?
- is it in a skip family?

## Phase 3: respect module-context legality

After computing a replacement, Binaryen applies one more legality rule:

- if the replacement is a `Const`, it can be installed anywhere
- if the replacement is a `Call`, it can only be installed when `getFunction()` exists
- otherwise the pass warns that it cannot de-NaN outside function context

This is crucial for global initializers.
A global initializer may legally contain a constant replacement like `f32.const 0`, but it may not contain an inserted helper call.

So the pass's legality contract is:

- **constant repair works outside functions**
- **call-based repair is function-body-only**

## Phase 4: sanitize parameters on function entry

`visitFunction(Function* func)` performs a second, separate rewrite phase.

For each non-imported function:

- inspect its parameter locals
- if a parameter type is `f32`, `f64`, or `v128`
- prepend a `local.set param (call $deNanXX (local.get param))`

This means `denan` is not only about expression-producing instructions.
It also explicitly repairs incoming ABI values before the body runs.

That is why the lit file checks entry fixups even in functions whose bodies are empty or trivial.

## Phase 5: clean up the entry wrapper immediately

When entry fixups are inserted, Binaryen temporarily wraps the function body in a block and then immediately runs a nested pass runner containing:

- `merge-blocks`

The implementation comment says this is to avoid adding an unnecessary block.

This nested rerun is part of the shipped strategy.
It is not merely a nearby-pass recommendation.
A future port must either preserve it or prove an equivalent normalization another way.

## Phase 6: add helper functions after the walk

`doWalkModule(...)` runs the main walk first and only then appends helpers.

That ordering matters because otherwise the newly-added helpers would be visited and instrumented too.

The helpers added are:

- scalar `deNan32`
- scalar `deNan64`
- SIMD `deNan128` only when the module has SIMD enabled

This conditional SIMD emission means the pass depends on the module feature set honestly.
It does not create a `v128` helper in non-SIMD modules.

## Helper function strategy

## Scalar helpers

For `f32` and `f64`, Binaryen generates a helper with the conceptual body:

```wat
(if (result f*)
  (f*.eq (local.get 0) (local.get 0))
  (local.get 0)
  (f*.const 0)
)
```

This is tiny but semantically important.
Binaryen is using self-equality as the NaN test, then choosing between:

- original value when not NaN
- zero when NaN

So the helper is a value filter, not a trap or debug hook.

## SIMD helper

The SIMD helper is the subtle part.
The source explains two strategy choices.

### Choice 1: test the vector as `f32x4`

The pass comments that the f32 NaN pattern is a superset of the f64 pattern for this purpose, so checking four `f32` lanes is enough.

### Choice 2: do **not** use direct vector equality

An obvious vector-equality implementation would create all-ones lanes for equal comparisons.
Those all-ones bit patterns themselves look like NaN patterns.
That would make reruns or self-instrumentation interact badly.

So instead Binaryen:

- extracts each `f32x4` lane
- compares each lane to itself with scalar `EqFloat32`
- ANDs the scalar booleans together

That is a very specific strategy choice a future port must preserve.

## Constant vector strategy

For constant `v128`, the pass uses `hasNaNLane(Const* c)`.
That routine:

- computes `value.eqF32x4(value)`
- checks `allTrueI32x4()`
- and treats “not all true” as “some lane may be NaN”

If so, the whole vector constant is replaced with an all-zero vector literal.

## Why no heavier analysis is needed

This pass looks broad because it touches many expression kinds.
But the proof obligation is actually small.
It does not need:

- alias analysis
- effect analysis of child movement
- liveness
- CFG reasoning
- type refinalization

because it is not moving computations around.
It is only:

- replacing constants with constants, or
- wrapping existing producers in helper calls of the same result type.

The complexity is about **where not to wrap** and **where helper calls are legal**, not about value-flow proof.

## Important implementation boundaries

## 1. Not every floating node is wrapped

The skip families matter as much as the positive families.
`local.get` and result-fallthrough nodes are intentionally preserved.
So the pass should be described as repairing value-producing roots, not as blindly wrapping all float-typed AST nodes.

## 2. Imported functions are skipped for entry fixups

`visitFunction` returns immediately for imported functions.
The pass only repairs bodies and params of defined functions.

## 3. Global contexts only get constant repair

Global initializers and other nonfunction contexts cannot receive helper calls.
So only direct constant NaN replacement is legal there.

## 4. This is not NaN-preserving canonicalization

A common misunderstanding is to think the pass maps many NaNs to one canonical NaN.
It does not.
It maps NaNs to zero.
That is a stronger behavior change.

## 5. The pass is feature-sensitive for SIMD

`deNan128` is emitted only if `module->features.hasSIMD()`.
So a future port must not synthesize SIMD helpers in scalar-only modules.

## 6. Nested `merge-blocks` is part of correctness and output shape

Without nested cleanup, the pass would leave more structural noise around every sanitized parameter list.
The shipped output contract includes that cleanup.

## Important pass interactions

## Fuzzing and determinization workflows

The file header explicitly says the pass is useful when fuzzing between VMs that differ on wasm NaN nondeterminism.
That makes it conceptually adjacent to determinization and instrumentation workflows, not default optimization scheduling.

## `merge-blocks`

This pass directly depends on nested `merge-blocks` for output cleanup after entry-param instrumentation.

## Repeated application

The source comments show the implementation cares a lot about not instrumenting itself accidentally:

- skip `local.get`
- skip result-fallthrough nodes
- add helpers after walking
- avoid direct SIMD compare results that look NaN-like

That does **not** prove a formal whole-pass idempotence theorem.
It does prove the pass was designed with rerun safety in mind.
That is an inference worth preserving as a caution, not overstating as a formal guarantee.

## Beginner-facing summary of the real contract

If you want the shortest accurate rule, it is this:

- find float- or vector-typed values that could carry NaN,
- replace constant NaNs with zero constants,
- wrap nonconstant producers in de-NaN helper calls,
- sanitize float/vector params at function entry,
- and deliberately avoid wrapping `local.get` or structural fallthrough shells again.

That is the real Binaryen strategy for `denan`.

## Sources

- [`../../../raw/binaryen/2026-05-05-de-nan-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-de-nan-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md`](../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md)
- [`../../../raw/research/0478-2026-05-05-de-nan-current-main-recheck.md`](../../../raw/research/0478-2026-05-05-de-nan-current-main-recheck.md)
- [`../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md`](../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md`](../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeNaN.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/names.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-builder.h>
