---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md
  - ../../../raw/research/0222-2026-04-21-simplify-globals-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-single_use.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-non-init.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-read_only_to_write.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-dominance.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-offsets.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-nested.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-prefer_earlier.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals_func-effects.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./plain-vs-optimizing-and-safety.md
  - ./wat-shapes.md
  - ../simplify-globals-optimizing/index.md
  - ../propagate-globals-globally/index.md
---

# Upstream implementation structure and test map for `simplify-globals`

This page is the compact file/test map for the real Binaryen `version_129` plain `simplify-globals` contract.

## Main implementation file

## `src/passes/SimplifyGlobals.cpp`

This is the real owner file.
It owns the visible plain-pass algorithm:

- the module-wide `GlobalInfo` fact table
- whole-module scanning over function bodies plus module code
- practical-immutability discovery
- `foldSingleUses()` for startup-only later-global folding
- `removeUnneededWrites()` for dead / same-as-init / read-only-to-write write cleanup
- immutable-copy-chain canonicalization toward earlier compatible ancestors
- `propagateConstantsToGlobals()` for startup rewriting into later globals and active offsets
- `propagateConstantsToCode()` for cheap runtime current-trace substitution in function bodies
- targeted `ReFinalize()` after more refined replacements

That owner split proves the first durable correction:

- plain `simplify-globals` is not implemented in its own tiny standalone file
- it is one public mode of the shared `SimplifyGlobals.cpp` family that also covers `simplify-globals-optimizing` and `propagate-globals-globally`

## Registration and public pass identity

## `src/passes/pass.cpp`

This file proves the public identity split.
Binaryen `version_129` registers three distinct pass names from the same family surface:

- `simplify-globals`
- `simplify-globals-optimizing`
- `propagate-globals-globally`

That matters because it closes two easy beginner mistakes:

- the plain pass is a real public pass, not merely an undocumented alias for the optimizing sibling
- the startup-only sibling is also a real public pass, not a nickname for one phase of the full pass

So the best compact teaching split is:

- `SimplifyGlobals.cpp` owns the rewrite family
- `pass.cpp` owns which public names expose which mode of that family

## Pass-runner boundary

## `src/pass.h`

This file matters because it confirms the family uses the normal pass interface and runner lifecycle.
For the plain pass, the crucial source-confirmed lesson is:

- the main semantic split from `simplify-globals-optimizing` is the nested cleanup/rerun contract after the global rewrites,
- not a different owner file or wholly different core algorithm.

That makes the plain folder worth keeping separate even though much of the engine is shared.

## Helper files that affect visible behavior

## `src/ir/effects.h`

This helper matters because `EffectAnalyzer` owns the effect legality checks used by the family, especially for:

- proving that a `read-only-to-write` body effectively performs only the one relevant global write
- invalidating runtime current-value knowledge across calls or other barriers

## `src/ir/find_all.h`

This helper matters because the pass wants actual owned syntax in a few places, not only inferred facts.
It helps the family find and rewrite:

- actual `GlobalGet` / `GlobalSet` nodes
- nested startup rewrite sites inside later initializers and offsets

That source split keeps one durable correction explicit:

- `simplify-globals` does not accept every pattern that effect summaries could describe abstractly; some matcher families still care about the actual AST nodes present in the expression tree

## `src/ir/linear-execution.h`

This helper matters because it owns the cheap runtime current-trace model.
It is the reason the pass can do some adjacent-block propagation without becoming a full CFG or dominator-tree optimizer.

## `src/ir/properties.h`

This helper matters because the family uses Binaryen’s constant-expression and literal checks to decide things like:

- whether a write really differs from the initializer
- whether a startup expression can be safely copied or substituted

## `src/ir/utils.h`

This file is part of the general shared utility surface the family leans on while copying expressions, traversing the module, and building replacements.

## What the owner split means for future Starshine work

The file map keeps one high-level porting rule honest:

- even though the pass does rewrite ordinary function bodies, it is still a whole-module late-global pass family,
- not a hot locals pass and not a tiny peephole pass.

## Official test files and what each one proves

The shipped proof surface is a cluster of dedicated late-global lit files rather than one single everything-file.

## `test/lit/passes/simplify-globals-single_use.wast`

This file is the cleanest direct proof of startup-only one-use folding.
It shows that Binaryen will copy a one-time initializer into a later global initializer, but not generalize that rule into ordinary runtime-code cloning.

## `test/lit/passes/simplify-globals-non-init.wast`

This file proves the distinction between:

- writes that merely re-store the initializer value
- writes that create genuinely new state

It is the best direct test anchor for explaining why some `global.set`s can become `drop(value)` without proving the subtree has no effects.

## `test/lit/passes/simplify-globals-read_only_to_write.wast`

This is the main direct proof surface for the exact self-guard matcher.
It is the most important file for teaching:

- the body-effect legality rule
- the actual-node versus mere-summary distinction
- the positive and bailout families around `read-only-to-write`

## `test/lit/passes/simplify-globals-dominance.wast`

This file proves that Binaryen uses a cheap runtime trace model with some adjacent-block positives.
It is the cleanest evidence that the pass is **not** full dominator-based constant propagation.

## `test/lit/passes/simplify-globals-offsets.wast`

This file proves that startup propagation reaches more than later globals.
The dedicated beginner-facing takeaway is that active data and elem offsets are part of the pass’s real rewrite surface.

## `test/lit/passes/simplify-globals-nested.wast`

This file proves that startup rewriting can reach nested startup expressions rather than only shallow top-level global initializers.

## `test/lit/passes/simplify-globals-prefer_earlier.wast`

This file is the best direct proof for immutable-copy-chain canonicalization toward the earliest compatible source.
It is the cleanest place to teach “prefer the earliest source” without blurring that story into generic constant propagation.

## `test/lit/passes/simplify-globals_func-effects.wast`

This file is especially useful because it keeps one easy overclaim from slipping in.
It proves that some matcher families want owned `global.get` / `global.set` syntax rather than merely inferred global effects from helper calls.

## `test/lit/passes/simplify-globals-gc.wast`

This file proves the GC/reference-typed boundary cases.
It is the strongest shipped anchor for:

- exact-type compatibility limits on some rewrites
- replacements that need or interact with later type repair

## `test/lit/passes/propagate-globals-globally.wast`

This sibling file matters even when the chosen pass is plain `simplify-globals`.
It proves the startup-only public sibling is a real separate stop point in the same family.
That keeps the family split honest:

- startup-only propagation is not merely a paragraph hidden inside the full pass
- plain `simplify-globals` really is the broader sibling

## What the shipped tests prove together

The reviewed roster is easiest to remember as four proof buckets.

### Startup-only proofs

- `simplify-globals-single_use.wast`
- `simplify-globals-nested.wast`
- `simplify-globals-offsets.wast`
- `propagate-globals-globally.wast`

These prove the family’s startup-time rewrite surface.

### Fake-state cleanup proofs

- `simplify-globals-non-init.wast`
- `simplify-globals-read_only_to_write.wast`

These prove how the family erases unnecessary global state while preserving operand evaluation.

### Runtime cheap-trace proofs

- `simplify-globals-dominance.wast`
- parts of `simplify-globals-read_only_to_write.wast`

These prove the deliberately narrow runtime story.

### GC / typing proofs

- `simplify-globals-gc.wast`
- parts of `simplify-globals-prefer_earlier.wast`

These prove the type-compatibility and refinalization-sensitive edge cases.

## What the tests do **not** isolate by themselves

The test filenames are good, but the combined source review still matters because no single lit file alone proves the biggest family-level lesson:

- plain `simplify-globals`, `simplify-globals-optimizing`, and `propagate-globals-globally` are one shared implementation family with three public identities.

That is why this implementation/test-map page still adds durable value even after the earlier behavioral pages existed.

## Practical reading order for future Starshine parity work

1. `src/passes/SimplifyGlobals.cpp`
   - understand the real owner file and the phase boundaries
2. `src/passes/pass.cpp`
   - confirm the public plain / optimizing / startup-only registration split
3. `src/pass.h`
   - keep the rerun / runner boundary honest
4. `effects.h`, `find_all.h`, `linear-execution.h`, `properties.h`, `utils.h`
   - understand the helper ownership behind legality and substitution
5. the reviewed lit cluster
   - map each visible rewrite family to an official proof file

## Porting checklist that falls out of this file map

Before calling a future Starshine port faithful, verify all of these against the official files:

- the pass stays module-shaped, not hot-pass-shaped
- the plain / optimizing / startup-only split stays explicit at the public registration surface
- startup propagation and runtime propagation remain distinct sub-algorithms
- `read-only-to-write` keeps the exact body-legality and actual-node ownership story
- removed writes preserve operand evaluation as `drop(value)`
- immutable-copy-chain rewrites keep their type-compatibility boundary
- the pass repairs types with targeted `ReFinalize()` when replacements become more refined
- parity signoff uses the whole lit cluster instead of pretending one file proves the whole family

## Sources

- [`../../../raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md`](../../../raw/research/0160-2026-04-21-simplify-globals-binaryen-research.md)
- [`../../../raw/research/0222-2026-04-21-simplify-globals-source-confirmation-followup.md`](../../../raw/research/0222-2026-04-21-simplify-globals-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-single_use.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-non-init.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-read_only_to_write.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-dominance.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-offsets.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-nested.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-prefer_earlier.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals_func-effects.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
