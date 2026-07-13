# Binaryen `minimize-rec-groups` current-main world-mode recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source manifest and correction for the living `minimize-rec-groups` dossier

## Scope

This capture rechecked the released `version_129` teaching oracle against Binaryen current `main` for the pass owner, registration surface, and dedicated lit roster. It supersedes only the old 2026-04-24 **no teaching-relevant drift** freshness claim. The `version_129` sources remain the historical algorithm oracle used by the dossier.

## Official primary sources consulted

### Owner and registration

- `version_129` `MinimizeRecGroups.cpp`:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/MinimizeRecGroups.cpp>
- current `main` `MinimizeRecGroups.cpp`:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/MinimizeRecGroups.cpp>
- `version_129` `pass.cpp`:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- current `main` `pass.cpp`:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>

### Current helper and test context

- current `main` `module-utils.h`:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h>
- current `main` `type-updating.h`:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.h>
- current `main` `minimize-rec-groups.wast`:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups.wast>
- current `main` `minimize-rec-groups-brands.wast`:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-brands.wast>
- current `main` `minimize-rec-groups-desc.wast`:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-desc.wast>
- current `main` `minimize-rec-groups-exact.wast`:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-exact.wast>
- current `main` `minimize-rec-groups-ignore-exact.wast`:
  <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/minimize-rec-groups-ignore-exact.wast>

## Durable observations

- `pass.cpp` still registers the public `minimize-rec-groups` spelling. The reviewed default optimize scheduling still does not add it as a normal preset slot; direct invocation remains the relevant upstream entry point.
- The current owner preserves the pass's semantic core: GC gate; private/public visibility split; private-only SCC minimization; subtype and descriptor ordering; written-shape collision handling; permutation-before-brand selection; and final type/name/index repair.
- The prior freshness claim was nevertheless too broad. Current `main` obtains `getPassOptions().worldMode` and threads that one policy through both boundaries that determine the rewrite's externally visible type universe:
  1. heap-type visibility collection (`ModuleUtils::collectHeapTypeInfo(...)`), and
  2. final module-wide rewriting (`GlobalTypeRewriter`).
- This is an interface/policy correction, not evidence that the SCC, collision, permutation, or brand algorithms changed. A future Starshine port must not use one implicit visibility policy for candidate selection and a different policy for rewriting.
- The dedicated lit roster remains the appropriate behavior map for SCC splitting, public conflicts, permutations, brands, descriptors, and feature-sensitive exactness. This focused review did not establish a new fixture family specifically for every world mode.

## Supersession and uncertainty

- The 2026-04-24 raw capture remains useful provenance for the `version_129` owner, helpers, and fixtures, but its statement that current `main` had no teaching-relevant drift is superseded by this world-mode correction.
- This capture does **not** claim that every `WorldMode` value has been exhaustively characterized for `minimize-rec-groups`. It establishes the durable porting invariant: carry one explicit world/visibility policy through candidate classification and the final type rewrite, then add focused mode-specific fixtures before treating a local implementation as parity-complete.

## Living pages updated from this capture

- `docs/wiki/binaryen/passes/minimize-rec-groups/index.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/permutations-brands-and-public-conflicts.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/wat-shapes.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/starshine-strategy.md`
- `docs/wiki/binaryen/passes/minimize-rec-groups/fuzzing.md`
