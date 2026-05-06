# `remove-unused-non-function-elements` current-main line-anchor refresh

_Date:_ 2026-05-06  
_Category:_ wiki-health source-note

## Why this note exists

The living `remove-unused-non-function-elements` dossier already had a 2026-05-05 current-main recheck. This note records the 2026-05-06 line-anchor refresh that tightened the local Starshine code-map references and kept the upstream sibling contract unchanged.

## What was rechecked

Primary source anchors from the official Binaryen `main` branch:

- `src/passes/RemoveUnusedModuleElements.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/ir/module-utils.h`
- `test/passes/remove-unused-nonfunction-module-elements_all-features.wast`
- shared `remove-unused-module-elements*` fixtures for inherited behavior

## What changed in the living dossier

- The Starshine strategy page now points at the current local `optimize.mbt`, `pass_manager.mbt`, `cmd.mbt`, and `remove_unused_module_elements.mbt` line anchors.
- The Binaryen strategy and implementation-map pages now have a fresh source bridge for the 2026-05-06 exact-line recheck.
- The root wiki catalog entry for the folder can stay concise because the live pages now carry the line-accurate code map.

## Durable conclusion

The pass contract did not change:

- root all **defined** functions
- do not special-root imports
- keep ordinary RUME cleanup behavior
- preserve the shared-engine split from full `remove-unused-module-elements`

The value of this note is the line-accurate source map, not a new semantic claim.
