---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# `signature-pruning`: constant actuals, localization, and boundaries

This page exists because the easiest way to misunderstand `signature-pruning` is to think it is just:

- find dead params
- delete them

The real pass is more subtle.
The biggest teaching traps are:

- constant actuals can make a parameter dead only after a body rewrite
- operand localization can make removal safe only on a later cycle
- many signatures are frozen for public or unsupported-surface reasons long before the pass ever tries to prune them

## Constant actuals are a preparatory rewrite, not the final optimization

When a heap type survives the early blockers, Binaryen first calls:

- `ParamUtils::applyConstantValues(...)`

That helper scans the actual operands at every direct `call` and every `call_ref` using the heap type.
If a parameter is always passed the same constant value, Binaryen prepends a:

- `local.set(paramIndex, constantExpr)`

to every function body sharing that heap type.

The key beginner point is:

- the calls still pass the argument at this stage
- Binaryen only changed the callee body first
- the parameter becomes removable later because the incoming value is now ignored

So constant-actual promotion is **upstream of pruning**, not an afterthought.

## What counts as a constant here

The helper `PossibleConstantValues` accepts:

- literal constant expressions
- immutable `global.get`

And the dedicated lit file proves that the pass treats these as real positive families:

- `i32.const`
- `ref.func`
- `ref.null`

It also proves the important negative family:

- mixing two different values, even if both are individually constant, blocks the optimization

So the correct mental model is:

- Binaryen is looking for **one shared actual value** across all users of the heap type,
- not for “every actual is constant in some broad sense.”

## Removing a parameter is stricter than proving it is dead

Even if a parameter is unused, `removeParameter(...)` can still refuse to remove it.
The helper checks every corresponding direct-call and `call_ref` operand and bails out when:

- the operand type is `unreachable`
- the operand has unremovable side effects

That difference matters.

A dead parameter is about the **callee**.
A removable argument is about the **call site** too.

## Why Binaryen localizes after the signature rewrite, not before it

When removal fails, `SignaturePruning.cpp` saves one representative `Call` or `CallRef` expression in `callTargetsToLocalize`.
It does not save the old heap type directly.

That source comment is one of the most important lines in the file:

- `GlobalTypeRewriter::updateSignatures(...)` rewrites the module's function heap types into a new rebuilt world
- even unchanged types are not guaranteed to survive as the same identity object
- a representative call expression is a more stable thing to keep until after the rewrite finishes

Only after the signature rewrite does Binaryen re-derive the new target heap types from those saved expressions and then call:

- `ParamUtils::localizeCallsTo(...)`

So the ordering is:

1. attempt pruning
2. commit any successful signature rewrite
3. localize blocked call operands
4. rerun once

That ordering is part of the real algorithm.

## What localization buys the pass

`localizeCallsTo(...)` uses `ChildLocalizer`.
That helper can hoist operands out of a call when they:

- have unremovable side effects
- or interact with sibling operands in a way that makes simple deletion unsafe

After localization, the call sees simpler `local.get` children, which can make the next pruning attempt succeed.

This is why `signature-pruning` is intentionally a two-cycle pass.
Without the second cycle, the localization work would not actually unlock anything.

## EH repair is part of the localization contract

`ChildLocalizer` may add new blocks.
When that happens inside catch regions, Binaryen also needs:

- `EHUtils::handleBlockNestedPops(...)`

The lit file has explicit catch/pop regressions for this.
So EH pop repair is not unrelated helper trivia; it is part of the pass staying valid after delayed localization.

## Boundary matrix: which signatures Binaryen freezes and why

The table below is the easiest source-backed summary of the pass's main no-op families.

| Blocker | What Binaryen does | Why |
| --- | --- | --- |
| Any table exists anywhere in the module | Entire pass returns immediately | Current implementation does not model `call_indirect`, element segments, and other table-mediated uses |
| Imported function shares the heap type | Freeze that heap type | Imports cannot be rewritten locally |
| Heap type is public | Freeze that heap type | Binaryen will not change externally visible function types here |
| Tag uses the type | Freeze that heap type | Tag users are not updated here |
| Continuation uses the type | Freeze that heap type | Continuation instructions such as `cont.bind` / `resume` are not updated here |
| JS can signature-call the function | Freeze that heap type | External JS callers can still observe the original signature |
| `call.without.effects` targets that type | Freeze that heap type | The intrinsic-mediated target-use path is not fully rewritten here |
| Heap type has function subtypes or a function supertype | Freeze that heap type | Param/result counts must stay aligned across the subtype chain |

Two important beginner-friendly conclusions follow.

### 1. “Unused in the body” is not enough

A parameter can be unused in every function body and still remain because the heap type is public or unsupported for some other reason.

### 2. One sibling can block the whole type family

Because the pass works per heap type, one blocked function can freeze other sibling functions that share the same type.

## Public rec groups are a bigger deal than a plain export bit

The public-type rule is not merely:

- exported functions do not optimize

`ModuleUtils::getPublicHeapTypes(...)` publicizes whole rec groups and then recursively publicizes referenced types.
That is why the lit file includes two subtle no-op cases:

- an exported function makes another function type in the same rec group public
- a public struct field that mentions a function type prevents replacing the old public type with a new pruned private one

So the safest short version is:

- **public rec-group reachability freezes more than direct exports do**

## Constant actuals, boundaries, and localization fit together in one story

A good teaching sequence is:

1. start with a heap type that is not frozen by public or unsupported boundaries
2. see if a parameter is already dead by entry liveness
3. if not, see whether constant actual promotion can make it dead
4. if it is dead, see whether call-site operand deletion is safe immediately
5. if not, localize the problematic operands and try once more

That sequence is the real shape of the pass.
It is why the implementation is more than “remove params from signatures where possible.”

## Bottom line

For `signature-pruning`, the easy-to-miss rules are:

- constant actual promotion happens **before** final pruning
- localization happens **after** the signature rewrite and only then enables one more cycle
- the public / tag / continuation / JS / table / subtyping boundaries are real semantic no-op rules, not performance heuristics

If a future port loses any of those three points, it will not match upstream Binaryen's real behavior.

## Sources

- [`../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md`](../../../raw/research/0151-2026-04-21-signature-pruning-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SignaturePruning.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/param-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-constant.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/localize.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/eh-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/intrinsics.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/subtypes.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/signature-pruning.wast>
