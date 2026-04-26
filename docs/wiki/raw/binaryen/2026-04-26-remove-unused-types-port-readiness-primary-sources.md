# Binaryen `remove-unused-types` port-readiness primary-source recheck

_Capture date:_ 2026-04-26  
_Status:_ immutable source manifest for the `remove-unused-types` Starshine port-readiness bridge

## Scope

This manifest rechecks the official Binaryen sources needed to turn the existing corrected `remove-unused-types` dossier into an implementation-readiness guide for a future Starshine port. It does not replace the fuller 2026-04-24 source correction; it records that the port plan below is still anchored in the same primary-source contract.

Use with:

- `docs/wiki/binaryen/passes/remove-unused-types/index.md`
- `docs/wiki/binaryen/passes/remove-unused-types/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-types/closed-world-visibility-and-rec-group-rewrite.md`
- `docs/wiki/binaryen/passes/remove-unused-types/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-types/starshine-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-types/starshine-port-readiness-and-validation.md`

## Official primary sources rechecked

- `RemoveUnusedTypes.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedTypes.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RemoveUnusedTypes.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedTypes.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/type-updating.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/type-updating.h>
- `module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.h>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/module-utils.h>
- official lit fixture
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-types.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/remove-unused-types.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-types.wast>

## Durable recheck observations

- No teaching-relevant drift was found from the corrected 2026-04-24 dossier contract.
- The public pass wrapper remains tiny: `RemoveUnusedTypes.cpp` gates on GC, rejects explicit open-world use, and delegates real rewriting to `GlobalTypeRewriter(*module).update()`.
- Port planning must therefore start with Starshine module/type-section infrastructure, not with a HOT expression walk.
- The Binaryen scheduler context remains separate from the explicit pass contract: default optimization scheduling reaches the pass only through the closed-world GC/type cluster, while explicit open-world pass use is a fatal usage error upstream.
- The important transformed shape remains helper-owned: public groups anchor the external boundary, unused private heap types disappear, used private heap types are topologically constrained by private supertypes and descriptor/described links, survivors are rebuilt into fresh private grouping, and module-wide type uses are remapped.
- The official lit fixture is still the compact oracle for private deletion, public retention, group rebuilding, descriptor/supertype constraints, and open-world/no-GC boundaries, but helper headers are required to understand why a one-file pass reading is insufficient.
- Starshine-specific recheck again found no local owner file. The only current in-tree status is the boundary-only registry spelling and the active request guard in `src/passes/optimize.mbt`.

## Uncertainties to preserve

- This recheck does not prove all Binaryen `main` helper internals are unchanged across every transitive include; it only found no teaching-relevant drift on the owner, scheduler, helper, and dedicated fixture surfaces above.
- Starshine still lacks a closed-world mode flag and shared `GlobalTypeRewriter`-equivalent abstraction. The port-readiness page recommends a scaffold/no-rewrite analyzer first because the final owner module and helper API remain architectural decisions.
