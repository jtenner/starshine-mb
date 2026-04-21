# Binaryen `global-refining` source-confirmation follow-up

Date: 2026-04-21

## Why this follow-up exists

The existing `docs/wiki/binaryen/passes/global-refining/` folder was already a real deep dossier, so this was **not** a normal uncovered-pass pick.
I chose it anyway as an explicitly justified major-gap follow-up because the tracker no longer had obvious `none` targets, while `global-refining` still lacked one compact source-confirmed page answering a beginner-practical question the landing and strategy pages were still spreading across prose:

- which official files actually own the pass,
- which helper files matter to the contract,
- what the shipped Binaryen test file directly proves,
- and what behavior is source-derived rather than isolated by a dedicated lit check.

That owner/test-map gap matters here because `global-refining` is easy to mis-teach as a broad global dataflow optimizer when the real `version_129` implementation is tiny and very file-local.

## Process followed

Per repo rules I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/global-refining/` folder

`agent-todo.md` still has **no dedicated `GR` slice**. The pass only appears indirectly through the canonical no-DWARF pathway and neighboring GC/type-cluster notes.

## Official source set reviewed

Primary Binaryen `version_129` sources:

- `src/passes/GlobalRefining.cpp`
- `src/passes/pass.cpp`
- `src/ir/lubs.h`
- `src/ir/public-type-validator.h`
- `test/lit/passes/global-refining.wast`

Supporting context already reflected in the living dossier:

- `src/pass.h` because `GetUpdater` uses `runOnModuleCode(...)`
- the no-DWARF scheduler slice in `pass.cpp`

Freshness check:

- `src/passes/GlobalRefining.cpp` on `main` is byte-identical to `version_129`
- `test/lit/passes/global-refining.wast` on `main` is byte-identical to `version_129`

So `version_129` remains the correct released oracle for the dossier, with no active trunk-drift caveat on the pass file or dedicated lit file.

## Compact source-confirmed implementation map

## `src/passes/GlobalRefining.cpp`

This file owns essentially the whole pass contract.

What it directly proves:

- `global-refining` is a small **module pass**, not a function pass.
- The pass immediately bails out when `!module->features.hasGC()`.
- It explicitly opts out of non-nullable-local repair via `requiresNonNullableLocalFixups() = false`.
- It gathers facts with `ModuleUtils::ParallelFunctionAnalysis<GlobalInfo>` over defined functions only.
- The only per-function scan is `FindAll<GlobalSet>(func->body)`, so the analysis surface is just `global.set` nodes, not generic global reads or CFG facts.
- Candidate refined types are computed through one `std::unordered_map<Name, LUBFinder>` keyed by global name.
- Export legality is handled in two stages:
  - early `unoptimizable` filtering for all closed-world exports and all open-world exported mutable globals
  - later `PublicTypeValidator` filtering for the remaining exported immutable globals
- Imported globals are skipped entirely.
- Initializer types are always folded into the same LUB computation as later `global.set` values.
- Declaration rewriting is tiny: once the legality checks pass, Binaryen just mutates `global->type`.
- Correctness after rewriting depends on the nested `GetUpdater` walker:
  - it updates cached `GlobalGet::type`
  - it refinalizes changed functions with `ReFinalize`
  - it runs both on ordinary functions and on module code through `runOnModuleCode(...)`

Most important negative fact:

- there is **no** separate rewrite engine for `global.set`, constant propagation, dead-store removal, or global-use dataflow here.

## `src/ir/lubs.h`

This header proves that the aggregation story is deliberately tiny.

What it directly proves:

- `LUBFinder` starts from `Type::unreachable`
- `note(type)` just calls `Type::getLeastUpperBound(...)`
- `noted()` is equivalent to “did we see any reachable value at all?”
- there is no hidden extra policy layer inside the LUB helper

That means the real type-inference rule is exactly:

- initializer type plus every observed `global.set` value type, joined by repeated least-upper-bound computation

## `src/ir/public-type-validator.h`

This helper is the real reason open-world immutable exports are subtler than private globals.

What it directly proves:

- basic public types are accepted directly
- tuples recurse elementwise
- reference types with `type.isExact()` are rejected unless custom descriptors are enabled
- `global-refining` therefore cannot expose an exact private-looking refined type just because the LUB found one

This is the source-backed explanation for why some immutable exported globals can refine only to public nullable/basic ref forms, not all the way to an internal exact subtype.

## `src/passes/pass.cpp`

This file proves both identity and scheduler placement.

What it directly proves:

- `global-refining` is a real public pass name with the minimal description `refine the types of globals`
- the no-DWARF global-prepass builder schedules it only when:
  - `options.optimizeLevel >= 2`
  - and `wasm->features.hasGC()`
- in closed world it is preceded by:
  - `type-refining`
  - `signature-pruning`
  - `signature-refining`
- and followed by the broader GC/type cluster:
  - optional `gto`
  - `remove-unused-module-elements`
  - optional `remove-unused-types`
  - optional `cfp` / `cfp-reftest`
  - `gsi`
  - optional `abstract-type-refining`
  - optional `unsubtyping`

For the repo's main open-world no-DWARF path, the durable practical neighborhood stays:

- `once-reduction -> global-refining -> remove-unused-module-elements -> gsi`

## Compact official test map

## `test/lit/passes/global-refining.wast`

This is the dedicated shipped test surface for the pass.

What it directly proves:

- init-only null-ref globals can refine from broad function refs to `nullfuncref`
- init-only `ref.func` globals can refine to exact internal function-ref types
- later null writes produce nullable exact outcomes instead of forcing a fall back to broad `funcref`
- all-non-null function-ref flows can remove nullability
- heterogeneous writes can refine a broad declaration like `anyref` down to `eqref`
- dependent global initializers using `global.get` stay valid after another global's declaration narrows
- open-world exported mutable globals are preserved
- open-world exported immutable globals can still refine when the new type is public
- current closed-world Binaryen still preserves exports that the open-world immutable case could refine

The file also directly proves that both open-world and `--closed-world` modes are intended parts of the public contract, because it runs both in the lit harness.

## What the lit file does **not** isolate by itself

The dedicated test is good, but a few important facts are easier to see from source than from testcase headings alone:

- the pass uses `ParallelFunctionAnalysis` plus `FindAll<GlobalSet>` rather than any CFG or effect analysis
- the exact exported-global filter is a two-stage combination of `unoptimizable` plus `PublicTypeValidator`, not one monolithic “exports bad” check
- `GetUpdater` repairs both function bodies and module code; the lit file shows the effect through a global-initializer `global.get`, but source ownership is clearer than the test alone
- `requiresNonNullableLocalFixups() = false` is deliberate on both the outer pass and `GetUpdater`

## Corrected compact teaching summary

After this source sweep, the safest short explanation of Binaryen `version_129` `global-refining` is:

- a GC-gated module pass
- that scans defined functions for `global.set`
- folds those write-value types together with each global initializer through `LUBFinder`
- rejects imported globals and boundary-illegal exports
- mutates only the global declaration type
- then repairs cached `global.get` result types in both functions and module code

That is much smaller and more local than the pass name suggests.

## Living wiki changes required by this follow-up

This follow-up should add one dedicated living page under the existing dossier:

- `docs/wiki/binaryen/passes/global-refining/implementation-structure-and-tests.md`

And should refresh the landing page plus shared indexes so future threads can see that `global-refining` no longer lacks a source-confirmed owner/test map.

## Open questions after this follow-up

These are now clearly **secondary** questions, not owner/test-map gaps:

- whether Binaryen eventually relaxes the current closed-world exported-global conservatism noted by the inline TODO
- whether any future trunk change broadens the direct test surface beyond the current single lit file
- whether Starshine parity work wants to copy Binaryen's exact open-world immutable-export/public-type rule or intentionally diverge

## Sources

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalRefining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/public-type-validator.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/global-refining.wast>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalRefining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/global-refining.wast>
