# Binaryen `flatten` current-main and local-status recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable source and local-status bridge for the living [`flatten` dossier](../../binaryen/passes/flatten/index.md)

## Scope

This recheck separates three facts that are easy to conflate:

1. Binaryen's current `flatten` transform contract.
2. The formal Flat IR target contract that explains why the transform creates locals.
3. Starshine's current *name-status* and its unrelated helper names.

It refreshes the April 2026 current-main review. It is not evidence that Starshine implements `flatten`.

## Official primary sources consulted

- Binaryen transform owner: [`src/passes/Flatten.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/Flatten.cpp) ([raw](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Flatten.cpp))
- Binaryen Flat IR verifier contract: [`src/ir/flat.h`](https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h) ([raw](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/flat.h))
- Binaryen pass registration and aggressive scheduler: [`src/passes/pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp) ([raw](https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp))
- Binaryen public factory declaration: [`src/passes/passes.h`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h)
- Direct fixtures: [`flatten.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten.wast), [`flatten_all-features.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_all-features.wast), and [`flatten-eh-legacy.wast`](https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten-eh-legacy.wast).

The older `version_129` captures remain useful release-horizon provenance. This source set is the current-main freshness check.

## Current Binaryen contract: no teaching-relevant drift found

The reviewed current-main owner still implements `flatten` as a function-parallel structural normalization pass into the `flat.h` contract:

- `Flatten.cpp` still uses postorder `preludes` and named-target `breakTemps` to move nested evaluation into earlier statement positions without duplicating children.
- Value-carrying `block`, `if`, `loop`, and legacy `try` forms still route results through temporary locals; reachable `local.tee` still becomes explicit set/get traffic.
- Carried `br`, `br_if`, and `switch` values still use explicit temporary channels. The conditional-branch mismatch case still needs a distinct flowing-out temporary when the target and outer value types differ.
- The generic fallback still spills concrete values and keeps a real unreachable effect in a prelude while leaving an `unreachable` placeholder at the old position.
- `BrOn*` and `TryTable` remain explicit unsupported families in the owner rather than ordinary soft no-op cases.
- Function exit still attaches remaining preludes and runs legacy-EH nested-pop repair.
- `flat.h` still requires simple ordinary operands, forbids concrete value flow from control nodes and function bodies, excludes reachable tees, and allows nested `ref.as_non_null` as the deliberate non-nullability exception.
- `pass.cpp` still publicly registers `flatten` and keeps it in the aggressive Flat-IR neighborhood before `simplify-locals-notee-nostructure` and `local-cse`.

Accordingly, the older durable explanation remains current. The useful live-page changes are freshness metadata and local-pointer correction, not an invented algorithm change.

## Current Starshine status: removed pass name, not a hidden partial transform

Current local sources establish a narrower and more precise status:

- [`src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt) still puts `"flatten"` in `pass_registry_removed_names()`; it is neither active nor boundary-only.
- `simplify_locals_notee_nostructure_exact_neighborhood_ready()` deliberately asks whether `flatten`, `simplify-locals-notee-nostructure`, and `local-cse` are all active, and the public preset deliberately keeps that upstream neighborhood disabled while the predicate is false. The predicate is a readiness guard, **not** a registration or dispatcher for `flatten`.
- [`src/cli/cli_test.mbt`](../../../../src/cli/cli_test.mbt) still preserves explicit `--flatten` pass tokens while filtering trap flags and optimization-level flags. Token preservation does not make the removed pass runnable.
- [`src/passes/pass_manager.mbt`](../../../../src/passes/pass_manager.mbt) contains implementation-private helpers with `flatten` in their names for other passes' structural cleanup. A repository text match on those helpers is **not** evidence of a public `flatten` dispatcher case or `src/passes/flatten.mbt` owner.
- The compare-pass harness still omits `flatten`; `bun fuzz compare-pass --pass flatten ...` is therefore status failure, not parity evidence.

## Documentation corrections implied by this recheck

- Update stale `src/cli/cli_test.mbt` line pointers from `280-285` / `313-316` to the current `305-309` / `340-342` tests.
- Keep the `pass_manager.mbt` wording precise: there is no active public dispatcher case, even though unrelated helper identifiers include `flatten`.
- Do not reinterpret the readiness predicate or pass-token tests as partial implementation.

## Uncertainty and follow-up

This was a source/registry reconciliation, not a new implementation investigation. It does not prove byte-for-byte output stability across all current-main revisions, settle a future Starshine Flat-IR representation, or replace the existing first-slice validation ladder. A future port still needs the analyzer-first plan, direct shape tests, explicit `BrOn*` / `TryTable` policy, legacy-EH repair evidence, registry/dispatcher admission, and only then a harness lane.

## Related living pages

- [`../../binaryen/passes/flatten/index.md`](../../binaryen/passes/flatten/index.md)
- [`../../binaryen/passes/flatten/binaryen-strategy.md`](../../binaryen/passes/flatten/binaryen-strategy.md)
- [`../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md`](../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md)
- [`../../binaryen/passes/flatten/implementation-structure-and-tests.md`](../../binaryen/passes/flatten/implementation-structure-and-tests.md)
- [`../../binaryen/passes/flatten/starshine-strategy.md`](../../binaryen/passes/flatten/starshine-strategy.md)
- [`../../binaryen/passes/flatten/fuzzing.md`](../../binaryen/passes/flatten/fuzzing.md)
