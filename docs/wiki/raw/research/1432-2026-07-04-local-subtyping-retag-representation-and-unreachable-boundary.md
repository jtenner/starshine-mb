# Local-subtyping retag representation and unreachable-before-write boundary

Date: 2026-07-04

## Question

Does Starshine need a Binaryen-style explicit `local.get` / `local.tee` expression retagging implementation after `local-subtyping` narrows a local declaration, or is that contract already satisfied by Starshine's representation? While probing the Binaryen lit-style unreachable tee/get shape, is the unreachable-before-write subset safe to narrow to a non-null local under Starshine validation?

## Source model

Binaryen `version_130` `LocalSubtyping.cpp` keeps explicit expression result types on local gets and tees. After changing a body-local declaration it walks collected `LocalGet*` and `LocalSet*` tee sites, assigns the new type to each expression, finalizes tees, and repeats after `ReFinalize()`.

The corresponding lit surface has an `unreachables` shape where an initial `unreachable` precedes a `block (result funcref)` whose value is a `local.tee` into a `funcref` local, followed by a later `local.get`. A local v130 probe confirmed Binaryen narrows that local to non-null exact function type and refinalizes the block result:

```sh
wasm-opt --all-features --local-subtyping .tmp/ls-retag-unreachable-probe.wat -S -o .tmp/ls-retag-unreachable-probe.out.wat
```

Observed Binaryen behavior: `$temp` becomes `(ref (exact $callee_t))`, the parent block result is refinalized to the same type, and the later get remains accepted.

## Starshine representation finding

Starshine's committed lib instruction representation does not store result types on `LocalGet` or `LocalTee` instructions:

- `src/lib/types.mbt` encodes `LocalGet(LocalIdx)`, `LocalSet(LocalIdx)`, and `LocalTee(LocalIdx)` with only the local index.
- HOT nodes have a `ty` field, but `local-subtyping` uses HOT only to collect assignment child result types. It does not mutate HOT locals or lower a stale HOT graph after changing declarations.
- `local_subtyping_run_module_pass` rebuilds the code section from the original lib body plus rewritten body-local declarations. Validation and later HOT lifts recompute local.get/local.tee expression result types from the current local declarations.

Therefore there is no emitted Starshine-side expression type field that can become stale in the way Binaryen's IR can. A focused guard now proves the representation invariant for a tee-parent shape without raw unreachable before the write: `local-subtyping retag representation validates tee parent after narrowing` narrows a `funcref` body local to non-null exact callee type, leaves the `block (result funcref)` body unchanged, and validates the optimized module without a retagging repair pass.

## Unreachable-before-write finding

Adding a test that exactly followed the Binaryen lit-style initial `unreachable` before the `local.tee` produced a red-first Starshine failure before implementation:

```sh
moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt
```

Initial result: the new `local-subtyping validates Binaryen-style unreachable tee and get after narrowing` test failed during final module validation with `uninitialized local: 1` after Starshine narrowed the local to a non-defaultable non-null exact function reference.

That failure is not a get/tee retagging problem. It is the same class as Starshine's other nondefaultable-local validator/tooling boundaries: Binaryen can prove the post-`unreachable` local.get safe for this shape, but Starshine validation does not treat writes after a raw `unreachable` as establishing initialization for a later nondefaultable local.get.

The fix is conservative: `ls_scan_branch_free_dominance_instrs` now treats a raw `Unreachable` instruction like other control-flow cuts for local-initialization evidence and prevents later writes from proving non-null local initialization. The resulting optimized type is the nullable exact callee reference instead of the non-null exact callee reference, so the module stays valid while still narrowing the heap type.

The focused guard is now `local-subtyping keeps nullable for unreachable-before-write tee boundary`.

## Classification

- Broad explicit get/tee retagging after declaration narrowing is no longer a Starshine behavior gap for the emitted lib representation. Starshine has no separate local.get/local.tee expression result type to repair, and focused validation covers a tee-parent declaration-narrowing shape.
- Binaryen's initial-`unreachable` tee/get lit subset remains a narrow validator/tooling divergence, not a Starshine win. Starshine keeps it nullable until validation can model Binaryen's unreachable nondefaultable-local proof.
- This does not close iterative refinalization/reanalysis. Starshine still runs one collection/rewrite pass and does not refinalize parent expression LUBs to discover further assignment-type narrowing.

## Validation

- Red-first focused run before the guard: `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` failed the new unreachable tee/get test with final validation error `uninitialized local: 1`.
- After the guard and test split: `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` passed `65/65`.

No full Moon or compare-pass lanes were run for this focused implementation slice yet. The change is intentionally small and validity-oriented; final closeout still needs the full LS evidence matrix once the remaining residuals are resolved.

## Reopening criteria

Reopen the retagging classification if Starshine adds emitted expression type annotations for local.get/local.tee, mutates and lowers the same HOT graph after local declaration rewrites, or a reduced direct mismatch shows stale local.get/local.tee result typing in emitted output.

Reopen the unreachable-before-write boundary when Starshine validation can prove Binaryen's unreachable nondefaultable-local initialization shape, or if a reduced case validates today while still missing a Binaryen-observable local-subtyping narrowing.
