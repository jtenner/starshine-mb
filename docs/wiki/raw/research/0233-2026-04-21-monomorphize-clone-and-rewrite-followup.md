# Binaryen `monomorphize` clone / signature / dropped-rewrite follow-up (`version_129`)

Date: 2026-04-21

## Why this follow-up exists

The existing `monomorphize` dossier already covered the pass at a good high level:

- direct-call candidate discovery
- effect-safe call-context extraction
- the usefulness gate
- the main lit-file families

But it still lacked one compact source-confirmed page for the part a future port is most likely to get subtly wrong:

- how Binaryen turns a built `CallContext` into a new specialized function,
- how the new signature is derived from surviving `LocalGet`s inside the context,
- how old params become locals while old vars shift upward,
- how local names are repaired,
- and how dropped-call specialization updates both the clone and the original callsite.

That gap mattered because the pass is easy to misremember as only:

- “move constants into a clone,” or
- “clone the callee and optimize it.”

The real `version_129` contract is more exact. Binaryen rebuilds the specialized function boundary from the context IR itself, rewrites local indexes systematically, optionally changes the result type to `none`, removes returns from the specialized clone in dropped-call cases, and then rewrites the original call plus surrounding `drop` to match.

## Scope reviewed

Official Binaryen `version_129` sources reviewed for this follow-up:

- `src/passes/Monomorphize.cpp`
- `src/passes/pass.cpp`
- `src/ir/find_all.h`
- `src/ir/manipulation.h`
- `src/ir/module-utils.h`
- `src/ir/names.h`
- `src/ir/return-utils.h`
- `src/ir/type-updating.h`
- `test/lit/passes/monomorphize-context.wast`
- `test/lit/passes/monomorphize-drop.wast`
- `test/lit/passes/monomorphize-consts.wast`
- `test/lit/passes/monomorphize-limits.wast`

Current-main drift spot check:

- a narrow 2026-04-21 check of the `processCall(...)`, `makeMonoFunctionWithContext(...)`, `updateCall(...)`, and `doOpts(...)` regions in `main/src/passes/Monomorphize.cpp` matched the reviewed `version_129` text on those surfaces.

## `agent-todo.md` status

`agent-todo.md` currently has **no dedicated `monomorphize` slice**.

## Durable findings

### 1. `processCall(...)` memoizes both wins and losses

The pass does not only memoize successful specializations.
It also stores `(target, context) -> original target` when a context is trivial or not worthwhile.

That means the real contract is:

- build context
- check cache
- maybe clone and test
- then memoize success **or** failure

A future port that only caches successful clones will re-do more work than Binaryen and may observe different path-dependent optimization timing.

### 2. The specialized signature is derived from surviving `LocalGet`s inside the context IR

`makeMonoFunctionWithContext(...)` does **not** simply say “every original dynamic operand becomes one new param.”
Instead it scans each context operand with `FindAll<LocalGet>` and appends the types of the surviving gets into `newParams`.

That matters because a context operand can contain partially moved structure:

- some children reverse-inlined into the clone,
- some children still represented as `local.get`s.

So the new signature is derived from the actual transformed context tree, not from the original source arity alone.

### 3. Dropped-call specialization changes the clone’s result type to `none`

If the original call was immediately dropped, the context records `dropped = true`.
In that case Binaryen rebuilds the cloned function type with:

- the new derived params, and
- `Type::none` results.

This is not a later cleanup accident. It is part of the primary clone-building contract.

### 4. Old params become locals inside the specialized clone

Because the new signature may keep fewer params than the original function, old params are not preserved as params by index.
Binaryen explicitly maps each old param to a newly allocated local var in the clone, then fills those locals from the reverse-inlined context prelude.

So the specialized clone conceptually becomes:

- new external params for the still-dynamic pieces,
- internal locals corresponding to the old callee params,
- a prelude of `local.set`s that reconstructs the old entry state,
- then the original body with remapped local indexes.

### 5. Old non-param locals shift by the param-count delta

For old vars, Binaryen does not create fresh unrelated locals.
It shifts their indexes by `newParamsMinusOld` so they stay aligned with the clone’s changed param prefix.

That is the exact local-index repair rule a future port must preserve.

### 6. Local names are intentionally copied and revalidated

If the source function had local names, Binaryen clears the clone’s default local-name tables and rebuilds them through the local mapping, using `Names::getValidLocalName(...)`.

This is small, but it proves the pass contract is not only semantic. It also preserves debug-facing local-name structure as far as the remap allows.

### 7. The reverse-inlined call context becomes a prelude of `local.set`s

After cloning, Binaryen emits one `local.set` per original parameter slot:

- the target local is the mapped old parameter local,
- the value is a copied context operand tree.

If any prelude work exists, Binaryen wraps:

- all prelude `local.set`s,
- then the old cloned body

into one outer block.

This is the exact source-backed reason the specialized function is not just “the old body with constants substituted.”

### 8. The cloned body gets a systematic local-index rewrite pass

Binaryen runs a small `LocalUpdater` postwalk over the cloned body to rewrite every `LocalGet` and `LocalSet` index through the `mappedLocals` table.

This is the core body-repair step after the signature and prelude change.

### 9. Dropped-call specialization removes returns from the clone

When `context.dropped` is true, Binaryen calls `ReturnUtils::removeReturns(newFunc.get(), wasm)` after building the clone.

So dropped-call specialization is a two-sided contract:

- the clone’s result type becomes `none`, and
- explicit returns are removed from the clone body.

The dedicated `monomorphize-drop.wast` file is the clearest public proof surface for this behavior.

### 10. Original callsite rewrite also removes the surrounding `drop`

`updateCall(...)` does three things together:

- rewrites the call target to the chosen specialized function,
- replaces the call operand list with the reduced `newOperands`,
- and, if the original call was dropped, replaces `(drop (call ...))` with the updated call itself after forcing the call type to `none`.

So a faithful port must update both sides:

- clone boundary and returns,
- caller-side `drop` wrapper and call type.

### 11. Nested usefulness measurement uses the rebuilt clone shape, not a symbolic estimate

`doOpts(...)` runs nested default function optimization passes at `optimizeLevel = 3` on the original function and specialized clone.
The comparison is then:

- optimized old body + context operand cost
- versus optimized specialized clone cost

That means the signature rebuild, local remap, prelude insertion, and dropped-result rewrite are all part of the actual measured artifact, not hidden behind an abstract front-end heuristic.

## Why this matters for the living dossier

The existing `monomorphize` pages already explained:

- effect-safe context extraction,
- usefulness thresholds,
- dropped-result and return-call boundaries.

What they did **not** yet isolate in one compact place was the exact clone-and-rewrite mechanics that connect those high-level decisions to the emitted WAT.

That missing bridge is now the durable focus for the living follow-up page.

## Living wiki updates needed

- Add a focused page under `docs/wiki/binaryen/passes/monomorphize/` for clone construction, signature rebuilding, local remap, return removal, and caller rewrite.
- Refresh the `monomorphize` landing page, strategy page, and implementation/test map so they point at that page explicitly.
- Update shared indexes and tracker notes so future threads can see that the former monomorphize clone/rewrite mechanics gap is closed.

## Sources

- Binaryen `version_129`:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-consts.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
- Current-main spot check:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Monomorphize.cpp>
- Local context:
  - `docs/wiki/binaryen/passes/monomorphize/`
  - `docs/wiki/binaryen/passes/tracker.md`
  - `docs/wiki/binaryen/passes/index.md`
  - `docs/wiki/index.md`
  - `docs/wiki/log.md`
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
  - `agent-todo.md`
