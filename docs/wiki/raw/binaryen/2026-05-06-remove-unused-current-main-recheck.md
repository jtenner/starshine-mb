# remove-unused current-main recheck (2026-05-06)

Reviewed official Binaryen sources:

- [`main/src/passes/pass.cpp`](https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp)
- [`version_129/src/passes/pass.cpp`](https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp)
- [`5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp`](https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp)
- [`98e9e604c7e2e4f928abe8f05691df90cddf09e4`](https://github.com/WebAssembly/binaryen/commit/98e9e604c7e2e4f928abe8f05691df90cddf09e4)
- [`98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/RemoveUnusedModuleElements.cpp`](https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/RemoveUnusedModuleElements.cpp)

Reviewed line anchors of interest:

- current `main` `pass.cpp`: `remove-unused-module-elements` / `remove-unused-nonfunction-module-elements` remain registered at lines 3618-3661, and no public `remove-unused` or `remove-unused-functions` spelling appears in the reviewed registration block.
- historical `RemoveUnusedFunctions.cpp`: the old pass roots start / export / table-segment functions, then uses `DirectCallGraphAnalyzer` and `updateFunctionsMap()` after deleting unreachable functions.
- supersession commit `98e9e604...`: the new `RemoveUnusedModuleElements.cpp` replaces the old function-only public pass with the broader module-element cleanup pass.

Takeaway for the wiki:

- the local `remove-unused` alias remains a lineage / registry-hygiene problem, not a current upstream public pass spelling;
- the historical function-only contract stays distinct from modern `remove-unused-module-elements`;
- the pass-shape catalog should stay historical and function-focused, not drift into modern RUME semantics.
