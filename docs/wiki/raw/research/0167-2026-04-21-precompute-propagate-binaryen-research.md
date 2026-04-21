# Binaryen `precompute-propagate` research

Date: 2026-04-21

## Scope

This note widens the Binaryen pass wiki campaign to cover `precompute-propagate` as a separate upstream-only removed-registry dossier.

Why this pass is eligible now:

- the original no-DWARF / saved `-O4z` queue is already dossier-covered
- the first obvious tracker-expansion wave is also dossier-covered
- `precompute-propagate` is still a real local removed-registry name in `src/passes/optimize.mbt`
- the existing `precompute` folder already teaches the mode split, but it still does **not** give the upstream public pass name its own canonical landing page
- the pass matters beyond trivia because Binaryen uses it repeatedly in aggressive top-level schedules and in nested `optimizeAfterInlining(...)` cleanup reruns

I am therefore treating this as a source-backed tracker expansion, not as a claim that it belongs to the repo's current default no-DWARF `-O` / `-Os` path.

## Candidate selection result

Chosen pass: `precompute-propagate`

Why not a no-DWARF / saved-`-O4z` `none` entry:

- there are no remaining obvious `wiki status = none` targets in the main parity queue or the first expansion queue
- the tracker explicitly says future threads should either justify a major-gap fallback or add another genuinely eligible upstream-only registry candidate
- `precompute-propagate` meets that bar because it is both source-backed and separately named in the local removed registry

## Backlog slice check

`agent-todo.md` has **no dedicated `precompute-propagate` slice**.

It does mention the variant indirectly in neighboring work:

- `[PC]001` says to note the difference between top-level `precompute` and nested `precompute-propagate`
- the `dae-optimizing` and `inlining-optimizing` slices mention prepending `precompute-propagate` before rerunning the default function pipeline
- the `simplify-globals-optimizing` slice explicitly says its rerun happens **without** the extra `precompute-propagate` prefix

That means the pass is already operationally important in local planning even though it still lacked a dedicated living dossier.

## Sources reviewed

### Local repo sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `docs/wiki/binaryen/passes/precompute/index.md`
- `docs/wiki/binaryen/passes/precompute/binaryen-strategy.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`

### Official Binaryen `version_129` sources

- `src/passes/Precompute.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/ir/local-graph.h`
- `src/wasm-interpreter.h`
- `test/lit/passes/precompute-propagate-partial.wast`
- representative neighboring `precompute*` tests already cited from the existing dossier

## Main findings

## 1. `precompute-propagate` is a real public pass, not just an internal mode name

`pass.cpp` registers both:

- `precompute`
- `precompute-propagate`

The public description split is small but real:

- `precompute`: computes compile-time evaluatable expressions
- `precompute-propagate`: computes compile-time evaluatable expressions and propagates them through locals

So the upstream contract is already teaching users that the second pass is not just a scheduler alias.

## 2. The implementation is shared, but the public mode split is still semantically important

`Precompute.cpp` implements both public names behind one pass class with a `propagate` mode flag.

That shared implementation could tempt readers to collapse the difference away, but that would be a documentation mistake.

The reviewed source still makes the split operationally meaningful:

- plain mode runs the normal bottom-up speculative-evaluation walk and optional partial-select precompute
- propagate mode does all of that **plus** a later `LazyLocalGraph`-based local-constant propagation phase and then reruns the main walk once if propagation changed anything

So the public distinction is not “same pass, different spelling.”
It is “same core evaluator, different extra phase and therefore different reachable rewrites.”

## 3. Scheduler placement is one of the main reasons this pass deserves its own page

The existing `precompute` folder already recorded the scheduler split, and the upstream sources confirm it:

- no-DWARF top-level `-O` / `-Os` uses plain `precompute`
- more aggressive top-level settings use `precompute-propagate`
- `optimizeAfterInlining(...)` prepends `precompute-propagate` before rerunning the default function optimization pipeline on changed functions

That scheduler fact matters for at least three nearby dossier clusters:

- `dae-optimizing`
- `inlining-optimizing`
- any pass dossier that explains repeated aggressive reruns in saved `-O4z` traces

It also explains why `simplify-globals-optimizing` explicitly documents the opposite rule: it reruns the default function pipeline without the extra `precompute-propagate` prefix.

## 4. The real algorithm still starts as semantic compile-time execution, not syntax-only constant folding

Like plain `precompute`, the propagate variant is built around the `PrecomputingExpressionRunner`, which subclasses `ConstantExpressionRunner`.

That means the pass family reasons in terms of:

- concrete `Flow` results
- constant values that are still emitable as IR
- writes that must be preserved even if the outer expression becomes constant
- limited loop/depth exploration
- GC identity and heap-value caching

So `precompute-propagate` is not “local constant propagation first, then some peepholes.”
The core story stays:

1. evaluate expressions semantically and conservatively
2. rewrite only when the result can be re-emitted honestly
3. preserve child writes that still matter
4. optionally use propagated local facts to unlock more of the same rewrite family

## 5. The propagate-specific phase is `LazyLocalGraph`-driven and intentionally narrow

The local propagation work is not generic sparse conditional constant propagation.

The reviewed structure is much narrower:

- build or consult `LazyLocalGraph`
- discover concrete values for some `local.get`s
- record them in a map used by the interpreter
- rerun the main walk once if new propagated knowledge appeared

The pass does not become a broad CFG simplifier.
It remains a compile-time evaluator whose horizon is extended by local-flow facts.

This is a crucial beginner-facing distinction.

## 6. `precompute-propagate-partial.wast` proves that the extra phase changes real WAT shapes

The dedicated upstream test exists because propagate mode can enable shapes that plain mode does not reach as directly.

The core teaching examples are the same family already documented in the neighboring folder:

- `select` arm partial precompute where pushing parent work into the arms makes the whole expression simpler
- local-set/local-get carriers where a constant fact on the `get` lets the evaluator collapse a parent expression on the rerun
- preserved bailout shapes where effects, emitability limits, heap identity, or unsupported flows stop a rewrite even though some subpieces are known

So the extra phase is not a hidden micro-optimization. It changes which shapes reach a fixed point.

## 7. Important helper dependencies

The core helper surface that a future Starshine port must understand is:

- `ConstantExpressionRunner` / `Flow` from `wasm-interpreter.h`
- `LazyLocalGraph` from `local-graph.h`
- `Properties` and constant-emitability checks
- `EffectAnalyzer` for child-retention safety
- `ExpressionStackWalker` for the pass walk
- `ReFinalize` after rewrites

This is not a pass whose correctness lives only in one loop inside `Precompute.cpp`.
Its safety boundary depends on these helpers.

## 8. Important positive shapes

The pass family can rewrite or help rewrite:

- direct compile-time-evaluable arithmetic and boolean trees
- typed wrappers whose result becomes a simple constant after evaluation
- `select` families where partial precompute can push parent work into both arms and shrink the whole expression
- expressions that become constant only after local propagation exposes a concrete `local.get`
- some GC and string shapes that the interpreter can model while still respecting emitability and identity rules

For `precompute-propagate`, the fourth bullet is the pass-specific identity.

## 9. Important negative and bailout shapes

The reviewed source and tests keep several boundaries explicit:

- effects that cannot be erased must survive child retention
- some values can be known semantically but still cannot be emitted as legal constants
- loops and deep expressions are bounded conservatively
- GC identity must not collapse distinct allocations with equal contents
- propagation is not a generic whole-function lattice pass; only supported local facts participate
- plain no-DWARF `-O` / `-Os` should not be silently documented as if it used this variant

## 10. Biggest beginner misunderstandings to prevent

### Misunderstanding: “`precompute-propagate` is just `precompute` with a more aggressive name.”

Correction:

- it is the same core evaluator plus a real extra `LazyLocalGraph`-based propagation phase and one extra rerun opportunity

### Misunderstanding: “This is just constant folding through locals.”

Correction:

- it is still a bounded semantic evaluator with emitability, write-retention, and GC-identity constraints

### Misunderstanding: “If a value is known, the pass always replaces the expression.”

Correction:

- not if the value cannot be re-emitted honestly or if required side effects would be lost

### Misunderstanding: “This is part of the repo's normal no-DWARF top-level path.”

Correction:

- the current no-DWARF `-O` / `-Os` page still points to plain `precompute`; this pass matters there mainly through higher-aggression modes and nested optimizing reruns

## Future Starshine port invariants

A future Starshine port should preserve at least these invariants:

1. keep `precompute` and `precompute-propagate` as distinct public contracts even if they share an implementation core
2. keep the propagate-specific phase narrow and `LazyLocalGraph`-style rather than silently replacing it with a broader unsourced dataflow pass
3. preserve child-write retention and emitability checks when speculative evaluation succeeds
4. preserve scheduler distinctions:
   - plain no-DWARF `-O` / `-Os` top-level slots use `precompute`
   - aggressive and after-inlining reruns use `precompute-propagate`
   - `simplify-globals-optimizing` deliberately does **not** add the extra prefix
5. keep GC identity and constant-emission rules explicit

## Tracker and living-doc consequences

This research justifies adding `precompute-propagate` to the tracker's additional upstream-only registry table with `wiki status = dossier`.

It also justifies a dedicated living folder because the existing `precompute` dossier, while already good, still did not provide:

- a landing page for the exact public pass name
- a strategy page focused on the propagate-specific phase and scheduler meaning
- a shape page for the pass-specific positive/bailout local-propagation families

## Source URLs

- Binaryen `version_129` `Precompute.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` `local-graph.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
- Binaryen `version_129` `wasm-interpreter.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>
- Binaryen `version_129` `precompute-propagate-partial.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-propagate-partial.wast>
