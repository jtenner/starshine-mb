---
kind: concept
status: supported
last_reviewed: 2026-06-18
sources:
  - ../../../raw/research/0208-2026-04-21-global-refining-source-confirmation-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./exports-public-types-and-retagging.md
  - ./wat-shapes.md
  - ./parity.md
---

# `global-refining`: implementation structure and tests

This page is the compact file/test map for the real Binaryen `version_130` `global-refining` contract.

## Core implementation files

### `src/passes/GlobalRefining.cpp`

What it proves:

- `global-refining` is a small **module pass**, not a function pass or a generic function-local optimizer.
- The pass immediately bails out when GC is unavailable, so ordinary non-GC modules are out of scope from the start.
- The outer pass explicitly declares `requiresNonNullableLocalFixups() = false`, which matches the real rewrite surface: it changes globals and `global.get`s, not locals.
- Per-function fact gathering is tiny:
  - `ModuleUtils::ParallelFunctionAnalysis<GlobalInfo>` runs over defined functions only.
  - `FindAll<GlobalSet>(func->body)` is the only scan.
- The candidate-type engine is just one `std::unordered_map<Name, LUBFinder>` keyed by global name.
- Export legality is split in two:
  - `unoptimizable` eagerly excludes all closed-world exports and all open-world exported mutable globals.
  - `PublicTypeValidator` later filters the remaining exported immutable globals.
- Imported globals are skipped entirely.
- Initializer types are always folded into the same LUB as later `global.set` values.
- The declaration rewrite is tiny and direct: once legal, Binaryen simply mutates `global->type`.
- Correctness after that depends on the nested `GetUpdater` walker:
  - it updates cached `GlobalGet::type`
  - it refinalizes changed functions with `ReFinalize`
  - it also runs on module code through `runOnModuleCode(...)`, not only function bodies

Most important negative fact:

- there is no CFG reasoning, dominance analysis, effects analysis, dead-store removal, or constant propagation engine in this file.

### `src/ir/lubs.h`

What it proves:

- `LUBFinder` is the whole type-aggregation helper.
- It starts from `Type::unreachable`.
- `note(type)` just applies `Type::getLeastUpperBound(...)`.
- `noted()` only means “did we ever see a reachable value?”

That is why the core inference rule is so small:

- initializer type plus every observed `global.set` value type, joined incrementally by least upper bound.

### `src/ir/public-type-validator.h`

What it proves:

- the export/publicity rule is real helper-backed policy, not an ad hoc special case in the pass
- basic public types are accepted directly
- tuple publicity is checked elementwise
- exact reference types are rejected unless custom descriptors are enabled

That is the compact source-backed explanation for a key beginner confusion:

- an immutable exported global may still fail to refine all the way to the internal exact type that private globals can use.

### `src/passes/pass.cpp`

What it proves:

- `global-refining` is a real public pass name
- the public description is only `refine the types of globals`, which understates how boundary-sensitive the pass really is
- the default no-DWARF prepass scheduler inserts it only when:
  - `options.optimizeLevel >= 2`
  - and `wasm->features.hasGC()`
- in open world the practical neighborhood for this repo is:
  - `once-reduction -> global-refining -> remove-unused-module-elements -> gsi`
- in closed world it sits inside the larger GC/type-tightening cluster after:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
  and before:
  - optional `gto`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
  - `gsi`
  - optional `abstract-type-refining`
  - optional `unsubtyping`

## Official test surface

### `test/lit/passes/global-refining.wast`

What it directly proves:

- init-only null-ref globals can narrow from broad function refs to `nullfuncref`
- init-only `ref.func` globals can narrow to exact internal function-ref types, e.g. `(ref (exact $foo_t))`
- later null writes can produce nullable exact results instead of forcing a return to broad `funcref`, e.g. `(ref null (exact $foo_t))`
- all-non-null function-ref traffic can remove nullability while preserving exactness
- heterogeneous writes can shrink a broad declaration like `anyref` down to `eqref`
- a dependent global initializer using `global.get` remains valid after another global narrows
- exported mutable globals stay unoptimized in open world
- exported immutable globals can still refine in open world when the new type is public
- current closed-world Binaryen still preserves exported cases that open-world immutable globals can refine

The lit file also proves that both open-world and `--closed-world` behavior are intended public surfaces, because it checks both in the same dedicated harness.

## What the lit file does **not** isolate by itself

The dedicated test is good, but several important facts are easier to confirm from source ownership than from testcase headings alone:

- the pass uses `ParallelFunctionAnalysis` plus `FindAll<GlobalSet>`, not a CFG walk
- the exported-global rule is a two-stage filter (`unoptimizable` plus `PublicTypeValidator`), not one blanket check
- `GetUpdater` repairs both function code and module code, which is why global-initializer `global.get` users remain valid
- the pass and updater both intentionally opt out of non-nullable-local fixups

## Current Starshine-facing checklist

If Starshine tightens or re-ports `global-refining`, the local port should preserve all of these source-backed facts:

- module pass, not hot pass
- GC gate, or an explicit local feature-model proof when the Starshine execution mode always has GC enabled
- defined-functions-only `global.set` scan
- initializer-plus-writes LUB aggregation
- imported-global skip
- open-world exported mutable skip
- current closed-world exported-global skip
- public-type validation for the remaining exported immutable globals
- declaration rewrite only, with no hidden constant/global-store simplifier
- `global.get` cached-type repair in both functions and module code
- `ReFinalize` after changed `global.get`s
- no non-nullable-local fixups required

## Sources

- [`../../../raw/research/0208-2026-04-21-global-refining-source-confirmation-followup.md`](../../../raw/research/0208-2026-04-21-global-refining-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/GlobalRefining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/lubs.h>
- <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/public-type-validator.h>
- <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/global-refining.wast>
